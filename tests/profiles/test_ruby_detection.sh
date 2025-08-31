#!/bin/bash
# Test suite for Ruby version detection in ClaudeBox
# Run this with: bash test_ruby_detection.sh

set -euo pipefail

# Setup
echo "======================================"
echo "ClaudeBox Ruby Version Detection Test"
echo "======================================"
echo "Current Bash version: $BASH_VERSION"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="$(dirname "$TEST_DIR")"
ROOT_DIR="$(dirname "$PROFILES_DIR")"
CONFIG_SCRIPT="$ROOT_DIR/lib/config.sh"

# Create temporary test directory
TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claudebox-ruby-test.XXXXXX")
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

# Source the config script
source "$CONFIG_SCRIPT"

# Test function
run_test() {
    local test_name="$1"
    local expected="$2"
    local setup_cmd="$3"
    local cleanup_cmd="${4:-true}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "Test %2d: %-50s " "$TESTS_RUN" "$test_name..."
    
    # Setup test environment
    cd "$TEST_TEMP_DIR"
    eval "$cleanup_cmd" >/dev/null 2>&1 || true
    eval "$setup_cmd"
    
    # Run the test
    local actual
    actual=$(PROJECT_DIR="$TEST_TEMP_DIR" detect_ruby_version "$TEST_TEMP_DIR")
    
    # Check result
    if [[ "$actual" == "$expected" ]]; then
        printf "${GREEN}PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        eval "$cleanup_cmd" >/dev/null 2>&1 || true
        return 0
    else
        printf "${RED}FAIL${NC}\n"
        printf "  Expected: %s\n" "$expected"
        printf "  Actual:   %s\n" "$actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        eval "$cleanup_cmd" >/dev/null 2>&1 || true
        return 1
    fi
}

# Cleanup function for all test files
cleanup_all() {
    rm -f "$TEST_TEMP_DIR"/.ruby-version \
          "$TEST_TEMP_DIR"/mise.toml \
          "$TEST_TEMP_DIR"/.mise.toml \
          "$TEST_TEMP_DIR"/.tool-versions \
          "$TEST_TEMP_DIR"/Gemfile
}

echo "1. Testing individual version detection methods"
echo "------------------------------------------------"

# Test .ruby-version file
run_test ".ruby-version with version only" \
    "3.2.0" \
    'echo "3.2.0" > .ruby-version' \
    'rm -f .ruby-version'

run_test ".ruby-version with ruby- prefix" \
    "ruby-3.1.4" \
    'echo "ruby-3.1.4" > .ruby-version' \
    'rm -f .ruby-version'

run_test ".ruby-version with whitespace" \
    "3.0.6" \
    'echo "  3.0.6  " > .ruby-version' \
    'rm -f .ruby-version'

run_test ".ruby-version with newlines" \
    "2.7.8" \
    'printf "2.7.8\n\n" > .ruby-version' \
    'rm -f .ruby-version'

# Test mise.toml file
run_test "mise.toml with simple format" \
    "3.4.5" \
    'echo "ruby = \"3.4.5\"" > mise.toml' \
    'rm -f mise.toml'

run_test "mise.toml with object format" \
    "3.3.0" \
    'echo "ruby = { version = \"3.3.0\" }" > mise.toml' \
    'rm -f mise.toml'

run_test ".mise.toml (dot prefix)" \
    "3.2.2" \
    'echo "ruby = \"3.2.2\"" > .mise.toml' \
    'rm -f .mise.toml'

run_test "mise.toml with spaces" \
    "3.1.0" \
    'echo "ruby   =   \"3.1.0\"" > mise.toml' \
    'rm -f mise.toml'

# Test .tool-versions file
run_test ".tool-versions with ruby" \
    "3.3.1" \
    'echo "ruby 3.3.1" > .tool-versions' \
    'rm -f .tool-versions'

run_test ".tool-versions with multiple tools" \
    "2.7.6" \
    'printf "nodejs 20.0.0\nruby 2.7.6\npython 3.11.0\n" > .tool-versions' \
    'rm -f .tool-versions'

run_test ".tool-versions with tabs" \
    "3.0.5" \
    'printf "ruby\t3.0.5\n" > .tool-versions' \
    'rm -f .tool-versions'

# Test Gemfile
run_test "Gemfile with double quotes" \
    "3.2.0" \
    'echo "ruby \"3.2.0\"" > Gemfile' \
    'rm -f Gemfile'

run_test "Gemfile with single quotes" \
    "2.7.8" \
    'echo "ruby '"'"'2.7.8'"'"'" > Gemfile' \
    'rm -f Gemfile'

run_test "Gemfile with version operator ~>" \
    "3.1" \
    'echo "ruby \"~> 3.1\"" > Gemfile' \
    'rm -f Gemfile'

run_test "Gemfile with version operator >=" \
    "3.0.0" \
    'echo "ruby \">= 3.0.0\"" > Gemfile' \
    'rm -f Gemfile'

run_test "Gemfile with spaces" \
    "3.2.1" \
    'echo "  ruby   \"3.2.1\"  " > Gemfile' \
    'rm -f Gemfile'

run_test "Gemfile with comments" \
    "2.6.10" \
    'printf "# Ruby version\nruby \"2.6.10\" # Required version\n" > Gemfile' \
    'rm -f Gemfile'

# Test environment variable - special case, need to handle differently
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %2d: %-50s " "$TESTS_RUN" "Environment variable override..."
cd "$TEST_TEMP_DIR"
cleanup_all
actual=$(CLAUDEBOX_RUBY_VERSION=3.5.0 PROJECT_DIR="$TEST_TEMP_DIR" detect_ruby_version "$TEST_TEMP_DIR")
if [[ "$actual" == "3.5.0" ]]; then
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC}\n"
    printf "  Expected: 3.5.0\n"
    printf "  Actual:   %s\n" "$actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test default fallback
run_test "Default version (no files)" \
    "3.4.5" \
    'true' \
    'cleanup_all'

echo
echo "2. Testing priority order"
echo "--------------------------"

# Test priority: ENV > .ruby-version > mise.toml > .tool-versions > Gemfile
run_test "Priority: .ruby-version over mise.toml" \
    "3.2.0" \
    'echo "3.2.0" > .ruby-version; echo "ruby = \"3.4.5\"" > mise.toml' \
    'cleanup_all'

run_test "Priority: mise.toml over .tool-versions" \
    "3.4.5" \
    'echo "ruby = \"3.4.5\"" > mise.toml; echo "ruby 3.3.1" > .tool-versions' \
    'cleanup_all'

run_test "Priority: .tool-versions over Gemfile" \
    "3.3.1" \
    'echo "ruby 3.3.1" > .tool-versions; echo "ruby \"2.7.8\"" > Gemfile' \
    'cleanup_all'

# Test ENV priority - special case
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %2d: %-50s " "$TESTS_RUN" "Priority: ENV over all files..."
cd "$TEST_TEMP_DIR"
cleanup_all
echo "3.2.0" > .ruby-version
echo "ruby = \"3.4.5\"" > mise.toml
actual=$(CLAUDEBOX_RUBY_VERSION=3.5.0 PROJECT_DIR="$TEST_TEMP_DIR" detect_ruby_version "$TEST_TEMP_DIR")
if [[ "$actual" == "3.5.0" ]]; then
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC}\n"
    printf "  Expected: 3.5.0\n"
    printf "  Actual:   %s\n" "$actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
cleanup_all

echo
echo "3. Testing edge cases"
echo "---------------------"

# Test invalid versions and edge cases
run_test "Empty .ruby-version file" \
    "3.4.5" \
    'touch .ruby-version' \
    'rm -f .ruby-version'

run_test "Invalid content in .ruby-version" \
    "not-a-version" \
    'echo "not-a-version" > .ruby-version' \
    'rm -f .ruby-version'

run_test "Multiple Ruby directives in Gemfile" \
    "2.7.0" \
    'printf "ruby \"2.7.0\"\n# ruby \"3.0.0\"\n" > Gemfile' \
    'rm -f Gemfile'

run_test "Commented Ruby in .tool-versions" \
    "3.4.5" \
    'echo "# ruby 3.3.1" > .tool-versions' \
    'rm -f .tool-versions'

echo
echo "4. Testing get_profile_ruby function"
echo "-------------------------------------"

# Test the full profile generation
test_profile_generation() {
    local test_name="$1"
    local version="$2"
    local setup_cmd="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "Test %2d: %-50s " "$TESTS_RUN" "$test_name..."
    
    cd "$TEST_TEMP_DIR"
    cleanup_all
    eval "$setup_cmd"
    
    local output
    output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>/dev/null)
    
    if echo "$output" | grep -q "Install mise and Ruby ${version}"; then
        printf "${GREEN}PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        cleanup_all
        return 0
    else
        printf "${RED}FAIL${NC}\n"
        printf "  Expected Ruby %s in output\n" "$version"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        cleanup_all
        return 1
    fi
}

test_profile_generation "Profile with .ruby-version" \
    "3.2.0" \
    'echo "3.2.0" > .ruby-version'

test_profile_generation "Profile with ruby- prefix stripped" \
    "3.1.4" \
    'echo "ruby-3.1.4" > .ruby-version'

test_profile_generation "Profile with mise.toml" \
    "3.4.5" \
    'echo "ruby = \"3.4.5\"" > mise.toml'

test_profile_generation "Profile with invalid version (uses default)" \
    "3.4.5" \
    'echo "invalid-version" > .ruby-version'

# Test version validation
echo
echo "5. Testing version format validation"
echo "-------------------------------------"

test_version_validation() {
    local test_name="$1"
    local version="$2"
    local should_be_valid="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "Test %2d: %-50s " "$TESTS_RUN" "$test_name..."
    
    cd "$TEST_TEMP_DIR"
    cleanup_all
    echo "$version" > .ruby-version
    
    local output
    output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>&1)
    
    if [[ "$should_be_valid" == "valid" ]]; then
        if echo "$output" | grep -q "Warning: Invalid Ruby version format"; then
            printf "${RED}FAIL${NC}\n"
            printf "  Version %s should be valid but got warning\n" "$version"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        else
            printf "${GREEN}PASS${NC}\n"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        fi
    else
        if echo "$output" | grep -q "Warning: Invalid Ruby version format"; then
            printf "${GREEN}PASS${NC}\n"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            printf "${RED}FAIL${NC}\n"
            printf "  Version %s should be invalid but no warning\n" "$version"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

test_version_validation "Valid: X.Y.Z format" "3.2.0" "valid"
test_version_validation "Valid: X.Y format" "3.2" "valid"
test_version_validation "Invalid: jruby prefix" "jruby-9.4.0.0" "invalid"
test_version_validation "Invalid: v prefix" "v3.2.0" "invalid"
test_version_validation "Invalid: text only" "latest" "invalid"
test_version_validation "Invalid: missing dots" "320" "invalid"

# Summary
echo
echo "======================================"
echo "Test Summary"
echo "======================================"
printf "Tests run:    %d\n" "$TESTS_RUN"
printf "Tests passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
printf "Tests failed: ${RED}%d${NC}\n" "$TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo
    printf "${GREEN}All tests passed!${NC}\n"
    exit 0
else
    echo
    printf "${RED}Some tests failed.${NC}\n"
    exit 1
fi
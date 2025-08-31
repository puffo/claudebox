#!/bin/bash
# Test suite for Ruby mise integration in ClaudeBox
# This tests that the Ruby profile correctly installs mise and Ruby

set -euo pipefail

# Setup
echo "==========================================="
echo "ClaudeBox Ruby mise Integration Test"
echo "==========================================="
echo "Testing that Ruby profile generates correct Docker commands"
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
TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claudebox-mise-test.XXXXXX")
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

# Source the config script
source "$CONFIG_SCRIPT"

# Test function
run_test() {
    local test_name="$1"
    local search_pattern="$2"
    local setup_cmd="${3:-true}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "Test %2d: %-50s " "$TESTS_RUN" "$test_name..."
    
    # Setup test environment
    cd "$TEST_TEMP_DIR"
    eval "$setup_cmd"
    
    # Generate profile output
    local output
    output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>/dev/null)
    
    # Check for pattern in output
    if echo "$output" | grep -q "$search_pattern"; then
        printf "${GREEN}PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}FAIL${NC}\n"
        printf "  Did not find: %s\n" "$search_pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "1. Testing mise installation commands"
echo "--------------------------------------"

run_test "mise installation via curl" \
    "curl https://mise.run | sh"

run_test "mise PATH configuration" \
    'export PATH="/home/claude/.local/bin:\$PATH"'

run_test "mise activation for bash" \
    'eval "\$(/home/claude/.local/bin/mise activate bash)"'

run_test "mise activation for zsh" \
    'eval "\$(/home/claude/.local/bin/mise activate zsh)"'

run_test "mise experimental settings" \
    "mise settings set experimental true"

run_test "mise idiomatic version file settings" \
    "mise settings add idiomatic_version_file_enable_tools ruby"

run_test "mise trust workspace directory" \
    "mise trust /workspace"

run_test "mise trust workspace config files" \
    "mise trust /workspace/.mise.toml 2>/dev/null || true"

echo
echo "2. Testing Ruby installation commands"
echo "--------------------------------------"

run_test "Ruby installation with mise" \
    "mise use --global ruby@" \
    'echo "3.2.0" > .ruby-version'

run_test "Gem system update" \
    "gem update --system --no-document"

run_test "Bundler installation" \
    "gem install bundler --no-document"

run_test "Gem configuration file" \
    'echo "gem: --no-document --user-install" > /home/claude/.gemrc'

echo
echo "3. Testing environment variables"
echo "---------------------------------"

run_test "mise PATH in ENV" \
    'ENV PATH="/home/claude/.local/bin'

run_test "mise shims PATH" \
    '/home/claude/.local/share/mise/shims'

run_test "MISE_GLOBAL_CONFIG_FILE" \
    'ENV MISE_GLOBAL_CONFIG_FILE="/home/claude/.config/mise/config.toml"'

run_test "MISE_DATA_DIR" \
    'ENV MISE_DATA_DIR="/home/claude/.local/share/mise"'

run_test "MISE_CACHE_DIR" \
    'ENV MISE_CACHE_DIR="/home/claude/.cache/mise"'

run_test "GEM_HOME" \
    'ENV GEM_HOME="/home/claude/.gem"'

echo
echo "4. Testing Ruby build dependencies"
echo "-----------------------------------"

run_test "autoconf package" "autoconf"
run_test "bison package" "bison"
run_test "build-essential package" "build-essential"
run_test "libssl-dev package" "libssl-dev"
run_test "libyaml-dev package" "libyaml-dev"
run_test "libreadline-dev package" "libreadline-dev"
run_test "zlib1g-dev package" "zlib1g-dev"
run_test "libffi-dev package" "libffi-dev"

echo
echo "5. Testing version-specific installation"
echo "-----------------------------------------"

# Test with specific Ruby version
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %2d: %-50s " "$TESTS_RUN" "Specific Ruby version 3.3.0..."
cd "$TEST_TEMP_DIR"
echo "3.3.0" > .ruby-version
output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>/dev/null)
if echo "$output" | grep -q "ruby@3.3.0"; then
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC}\n"
    printf "  Expected ruby@3.3.0 in output\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test with invalid version (should use default)
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %2d: %-50s " "$TESTS_RUN" "Invalid version falls back to default..."
cd "$TEST_TEMP_DIR"
echo "invalid-version" > .ruby-version
output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>&1)
if echo "$output" | grep -q "Warning: Invalid Ruby version format"; then
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC}\n"
    printf "  Expected warning about invalid version\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo
echo "6. Testing Gemfile handling"
echo "----------------------------"

# Test with Gemfile present
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %2d: %-50s " "$TESTS_RUN" "Gemfile bundle install command..."
cd "$TEST_TEMP_DIR"
echo 'source "https://rubygems.org"' > Gemfile
echo 'gem "rails"' >> Gemfile
output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>/dev/null)
if echo "$output" | grep -q "bundle install"; then
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC}\n"
    printf "  Expected bundle install command\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test Gemfile copy with ownership
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %2d: %-50s " "$TESTS_RUN" "Gemfile copy with ownership..."
if echo "$output" | grep -q "COPY --chown=claude:claude Gemfile"; then
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL${NC}\n"
    printf "  Expected COPY --chown=claude:claude\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test without Gemfile
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %2d: %-50s " "$TESTS_RUN" "No bundle install without Gemfile..."
cd "$TEST_TEMP_DIR"
rm -f Gemfile
output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>/dev/null)
if echo "$output" | grep -q "bundle install"; then
    printf "${RED}FAIL${NC}\n"
    printf "  Should not include bundle install without Gemfile\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

echo
echo "7. Testing Docker layer optimization"
echo "-------------------------------------"

run_test "Single RUN command for mise setup" \
    "RUN curl https://mise.run | sh &&"

run_test "apt-get clean in dependencies" \
    "apt-get clean && rm -rf /var/lib/apt/lists"

run_test "USER claude for mise operations" \
    "USER claude"

run_test "USER root after mise setup" \
    "USER root"

# Summary
echo
echo "==========================================="
echo "Test Summary"
echo "==========================================="
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
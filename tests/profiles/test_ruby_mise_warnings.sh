#!/usr/bin/env bash
# Test that Ruby profile includes fixes for mise warnings
# This specifically tests that we've addressed:
# - Config files not trusted warnings (by adding mise trust commands)
# - Deprecated idiomatic_version_file_enable_tools warning (by using 'add' instead of 'set')

set -e

# Source test helpers and config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/config.sh"

echo "========================================="
echo "ClaudeBox Ruby mise Warnings Fix Test"
echo "========================================="
echo "Testing that Ruby profile includes mise warning fixes"
echo

# Create a temporary test directory
TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claudebox-mise-warnings-test.XXXXXX")

# Cleanup function
cleanup() {
    rm -rf "$TEST_TEMP_DIR"
}
trap cleanup EXIT

# Helper function for testing
run_test() {
    local test_name="$1"
    local pattern="$2"
    local should_exist="$3"  # true or false
    
    printf "Test: %-60s " "$test_name..."
    
    # Generate the Ruby profile Dockerfile content
    output=$(PROJECT_DIR="$TEST_TEMP_DIR" get_profile_ruby 2>/dev/null)
    
    if [[ "$should_exist" == "true" ]]; then
        if echo "$output" | grep -q "$pattern"; then
            printf "\033[0;32mPASS\033[0m\n"
            return 0
        else
            printf "\033[0;31mFAIL\033[0m\n"
            echo "  ERROR: Did not find required pattern: $pattern"
            return 1
        fi
    else
        if echo "$output" | grep -q "$pattern"; then
            printf "\033[0;31mFAIL\033[0m\n"
            echo "  ERROR: Found deprecated pattern: $pattern"
            echo "  Output snippet:"
            echo "$output" | grep -C 1 "$pattern" | sed 's/^/    /'
            return 1
        else
            printf "\033[0;32mPASS\033[0m\n"
            return 0
        fi
    fi
}

# Track test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
cd "$TEST_TEMP_DIR"

echo "1. Testing for deprecated patterns (should NOT be present)"
echo "-----------------------------------------------------------"

# Create test files that would trigger warnings if not handled
echo "3.2.0" > .ruby-version
cat > mise.toml <<EOF
[tools]
ruby = "3.2.0"
EOF

# Test for deprecated patterns that should be fixed
if run_test "No 'mise settings set' for idiomatic files" "mise settings set idiomatic_version_file_enable_tools" false; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

if run_test "No 'mise settings set trusted_config_paths'" "mise settings set trusted_config_paths" false; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo
echo "2. Testing for required fixes (MUST be present)"
echo "-------------------------------------------------"

# Test that our fixes are in place
if run_test "Has 'mise trust /workspace' command" "mise trust /workspace" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

if run_test "Has 'mise settings add' for idiomatic files" "mise settings add idiomatic_version_file_enable_tools ruby" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

if run_test "Trusts .mise.toml files" "mise trust /workspace/.mise.toml" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

if run_test "Trusts mise.toml files" "mise trust /workspace/mise.toml" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

if run_test "Handles trust failures gracefully" "|| true" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo
echo "3. Testing with different Ruby versions"
echo "----------------------------------------"

# Test with different version files
rm -f .ruby-version mise.toml
echo "ruby 3.3.0" > .tool-versions

if run_test "Works with .tool-versions file" "mise use --global ruby@" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test with Gemfile
rm -f .tool-versions
cat > Gemfile <<EOF
source 'https://rubygems.org'
ruby '2.7.4'
EOF

if run_test "Works with Gemfile Ruby version" "mise use --global ruby@" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test with default version
rm -f Gemfile
if run_test "Works with default Ruby version" "mise use --global ruby@3" true; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Clean up handled by trap

# Summary
echo
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: \033[0;32m$TESTS_PASSED\033[0m"
echo -e "Tests failed: \033[0;31m$TESTS_FAILED\033[0m"
echo

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "\033[0;32mAll tests passed!\033[0m"
    exit 0
else
    echo -e "\033[0;31mSome tests failed!\033[0m"
    exit 1
fi
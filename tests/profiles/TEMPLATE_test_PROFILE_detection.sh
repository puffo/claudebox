#!/bin/bash
# Test suite for PROFILE_NAME version detection in ClaudeBox
# 
# TO USE THIS TEMPLATE:
# 1. Copy this file to test_PROFILE_detection.sh (e.g., test_python_detection.sh)
# 2. Replace PROFILE_NAME with the actual profile name (e.g., Python)
# 3. Replace detect_PROFILE_version with actual function name (e.g., detect_python_version)
# 4. Update version examples to match the profile's versioning scheme
# 5. Add profile-specific test cases
#
# Run this with: bash test_PROFILE_detection.sh

set -euo pipefail

# Setup
echo "============================================"
echo "ClaudeBox PROFILE_NAME Version Detection Test"
echo "============================================"
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
TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claudebox-PROFILE-test.XXXXXX")
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
    
    # Run the test - REPLACE detect_PROFILE_version with actual function
    local actual
    actual=$(PROJECT_DIR="$TEST_TEMP_DIR" detect_PROFILE_version "$TEST_TEMP_DIR" 2>/dev/null || echo "DETECTION_FAILED")
    
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
    # Add profile-specific cleanup here
    # Example for Python:
    # rm -f "$TEST_TEMP_DIR"/.python-version \
    #       "$TEST_TEMP_DIR"/pyproject.toml \
    #       "$TEST_TEMP_DIR"/setup.py \
    #       "$TEST_TEMP_DIR"/.tool-versions
    true
}

echo "1. Testing individual version detection methods"
echo "------------------------------------------------"

# =============================================================================
# PROFILE-SPECIFIC TESTS GO HERE
# =============================================================================

# Example: Test version file detection
# run_test ".PROFILE-version file" \
#     "3.11.0" \
#     'echo "3.11.0" > .PROFILE-version' \
#     'rm -f .PROFILE-version'

# Example: Test configuration file detection
# run_test "PROFILE.toml configuration" \
#     "3.11.0" \
#     'echo "version = \"3.11.0\"" > PROFILE.toml' \
#     'rm -f PROFILE.toml'

# Example: Test environment variable
# TESTS_RUN=$((TESTS_RUN + 1))
# printf "Test %2d: %-50s " "$TESTS_RUN" "Environment variable override..."
# cd "$TEST_TEMP_DIR"
# cleanup_all
# actual=$(CLAUDEBOX_PROFILE_VERSION=3.11.0 PROJECT_DIR="$TEST_TEMP_DIR" detect_PROFILE_version "$TEST_TEMP_DIR" 2>/dev/null || echo "DETECTION_FAILED")
# if [[ "$actual" == "3.11.0" ]]; then
#     printf "${GREEN}PASS${NC}\n"
#     TESTS_PASSED=$((TESTS_PASSED + 1))
# else
#     printf "${RED}FAIL${NC}\n"
#     printf "  Expected: 3.11.0\n"
#     printf "  Actual:   %s\n" "$actual"
#     TESTS_FAILED=$((TESTS_FAILED + 1))
# fi

echo
echo "2. Testing priority order"
echo "--------------------------"

# Add priority tests here

echo
echo "3. Testing edge cases"
echo "---------------------"

# Add edge case tests here

# =============================================================================
# END OF PROFILE-SPECIFIC TESTS
# =============================================================================

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
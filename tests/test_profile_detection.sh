#!/bin/bash
# Master test suite for ClaudeBox profile version detection
# This orchestrates tests for all profile types that support version detection
# Run this with: bash test_profile_detection.sh [profile_name]

set -euo pipefail

# Setup
echo "=========================================="
echo "ClaudeBox Profile Version Detection Tests"
echo "=========================================="
echo "Current Bash version: $BASH_VERSION"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
PROFILE_TESTS_DIR="$TEST_DIR/profiles"

# Parse arguments
PROFILE_FILTER="${1:-all}"

# Tracking
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
PROFILES_TESTED=0
PROFILES_PASSED=0

# Function to run profile-specific tests
run_profile_test() {
    local profile_name="$1"
    local test_script="$PROFILE_TESTS_DIR/test_${profile_name}_detection.sh"
    
    if [[ ! -f "$test_script" ]]; then
        printf "${YELLOW}SKIP${NC} - No test file found: %s\n" "$test_script"
        return 2
    fi
    
    printf "\n${BLUE}Running %s tests...${NC}\n" "$profile_name"
    printf "=====================================\n"
    
    local output
    local exit_code=0
    
    # Run the test and capture output
    if output=$(bash "$test_script" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Parse test results from output
    local tests_run=$(echo "$output" | grep -E "^Tests run:" | awk '{print $3}' || echo "0")
    local tests_passed=$(echo "$output" | grep -E "^Tests passed:" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $3}' || echo "0")
    local tests_failed=$(echo "$output" | grep -E "^Tests failed:" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $3}' || echo "0")
    
    # Update totals
    TOTAL_TESTS=$((TOTAL_TESTS + tests_run))
    TOTAL_PASSED=$((TOTAL_PASSED + tests_passed))
    TOTAL_FAILED=$((TOTAL_FAILED + tests_failed))
    PROFILES_TESTED=$((PROFILES_TESTED + 1))
    
    if [[ $exit_code -eq 0 ]]; then
        printf "${GREEN}✓ %s: All %d tests passed${NC}\n" "$profile_name" "$tests_passed"
        PROFILES_PASSED=$((PROFILES_PASSED + 1))
    else
        printf "${RED}✗ %s: %d/%d tests failed${NC}\n" "$profile_name" "$tests_failed" "$tests_run"
        # Show failing tests only
        echo "$output" | grep -E "FAIL|Expected:|Actual:" | head -10
    fi
    
    return $exit_code
}

# Ensure profile tests directory exists
if [[ ! -d "$PROFILE_TESTS_DIR" ]]; then
    mkdir -p "$PROFILE_TESTS_DIR"
    echo "Created profile tests directory: $PROFILE_TESTS_DIR"
fi

# Determine which profiles to test
if [[ "$PROFILE_FILTER" == "all" ]]; then
    # Find all test files in the profiles directory
    PROFILES_TO_TEST=()
    if [[ -d "$PROFILE_TESTS_DIR" ]]; then
        for test_file in "$PROFILE_TESTS_DIR"/test_*_detection.sh; do
            if [[ -f "$test_file" ]]; then
                # Extract profile name from filename
                profile=$(basename "$test_file" | sed 's/test_\(.*\)_detection.sh/\1/')
                PROFILES_TO_TEST+=("$profile")
            fi
        done
    fi
    
    if [[ ${#PROFILES_TO_TEST[@]} -eq 0 ]]; then
        echo "No profile test files found in $PROFILE_TESTS_DIR"
        echo
        echo "To add tests for a profile, create:"
        echo "  $PROFILE_TESTS_DIR/test_PROFILE_detection.sh"
        echo
        echo "Available profiles that could have version detection:"
        echo "  - ruby (currently implemented)"
        echo "  - python"
        echo "  - javascript (Node.js)"
        echo "  - go"
        echo "  - rust"
        echo "  - java"
        echo "  - php"
        exit 0
    fi
else
    # Test specific profile
    PROFILES_TO_TEST=("$PROFILE_FILTER")
fi

# Run tests for each profile
echo
echo "Testing profiles: ${PROFILES_TO_TEST[*]}"
echo "=========================================="

FAILED_PROFILES=()
for profile in "${PROFILES_TO_TEST[@]}"; do
    if ! run_profile_test "$profile"; then
        FAILED_PROFILES+=("$profile")
    fi
done

# Summary
echo
echo "=========================================="
echo "Overall Test Summary"
echo "=========================================="
printf "Profiles tested:  %d\n" "$PROFILES_TESTED"
printf "Profiles passed:  ${GREEN}%d${NC}\n" "$PROFILES_PASSED"
printf "Profiles failed:  ${RED}%d${NC}\n" "$((PROFILES_TESTED - PROFILES_PASSED))"
echo
printf "Total tests run:    %d\n" "$TOTAL_TESTS"
printf "Total tests passed: ${GREEN}%d${NC}\n" "$TOTAL_PASSED"
printf "Total tests failed: ${RED}%d${NC}\n" "$TOTAL_FAILED"

if [[ $TOTAL_FAILED -eq 0 ]] && [[ $PROFILES_TESTED -gt 0 ]]; then
    echo
    printf "${GREEN}All tests passed!${NC}\n"
    exit 0
elif [[ ${#FAILED_PROFILES[@]} -gt 0 ]]; then
    echo
    printf "${RED}Failed profiles: %s${NC}\n" "${FAILED_PROFILES[*]}"
    exit 1
else
    echo
    printf "${YELLOW}No tests were run${NC}\n"
    exit 0
fi
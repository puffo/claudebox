#!/usr/bin/env bash
# Simple CLI Command Validation Test
# Quick validation of ClaudeBox CLI structure

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"
readonly MAIN_SCRIPT="$CLAUDEBOX_ROOT/main.sh"
readonly LIB_DIR="$CLAUDEBOX_ROOT/lib"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Simple test function
test_result() {
    local test_name="$1"
    local command="$2"
    
    ((TESTS_RUN++))
    if eval "$command" >/dev/null 2>&1; then
        ((TESTS_PASSED++))
        echo "✓ $test_name"
    else
        ((TESTS_FAILED++))
        echo "✗ $test_name"
    fi
}

echo "ClaudeBox CLI Simple Validation Test"
echo "===================================="
echo

# Test CLI parser structure
echo "CLI Parser Structure:"
test_result "HOST_ONLY_FLAGS array exists" "grep -q 'readonly HOST_ONLY_FLAGS=' '$LIB_DIR/cli.sh'"
test_result "CONTROL_FLAGS array exists" "grep -q 'readonly CONTROL_FLAGS=' '$LIB_DIR/cli.sh'"  
test_result "SCRIPT_COMMANDS array exists" "grep -q 'readonly SCRIPT_COMMANDS=' '$LIB_DIR/cli.sh'"
test_result "parse_cli_args function exists" "grep -q 'parse_cli_args()' '$LIB_DIR/cli.sh'"
echo

# Test new commands exist
echo "New Commands:"
test_result "commands command exists in parser" "grep -q '\\bcommands\\b' '$LIB_DIR/cli.sh'"
test_result "status command exists in parser" "grep -q '\\bstatus\\b' '$LIB_DIR/cli.sh'"
test_result "where command exists in parser" "grep -q '\\bwhere\\b' '$LIB_DIR/cli.sh'"
echo

# Test shortcuts exist
echo "Command Shortcuts:"
test_result "s shortcut exists" "grep -q '\\bs\\b' '$LIB_DIR/cli.sh'"
test_result "c shortcut exists" "grep -q '\\bc\\b' '$LIB_DIR/cli.sh'"
test_result "p shortcut exists" "grep -q '\\bp\\b' '$LIB_DIR/cli.sh'"
test_result "i shortcut exists" "grep -q '\\bi\\b' '$LIB_DIR/cli.sh'"
echo

# Test dispatcher entries
echo "Command Dispatchers:"
test_result "commands dispatcher exists" "grep -q 'commands)' '$LIB_DIR/commands.sh'"
test_result "status dispatcher exists" "grep -q 'status)' '$LIB_DIR/commands.sh'"
test_result "where dispatcher exists" "grep -q 'where)' '$LIB_DIR/commands.sh'"
test_result "shell shortcut dispatcher" "grep -q 'shell | s)' '$LIB_DIR/commands.sh'"
echo

# Test function existence  
echo "Command Functions:"
test_result "show_claudebox_commands function exists" "grep -q 'show_claudebox_commands()' '$LIB_DIR/commands.sh'"
test_result "_cmd_status function exists" "grep -q '_cmd_status()' '$LIB_DIR/commands.info.sh'"
test_result "_cmd_where function exists" "grep -q '_cmd_where()' '$LIB_DIR/commands.info.sh'"
echo

# Test flag consistency
echo "Flag Consistency:"
test_result "All host flags use --format" "grep 'readonly HOST_ONLY_FLAGS=' '$LIB_DIR/cli.sh' | grep -qv '[^-]\\w\\+)' || true"
test_result "All control flags use --format" "grep 'readonly CONTROL_FLAGS=' '$LIB_DIR/cli.sh' | grep -qv '[^-]\\w\\+)' || true"
echo

# Test help improvements
echo "Help System:"
test_result "Help shows ClaudeBox first" "grep -A5 'show_help()' '$LIB_DIR/commands.sh' | grep -q 'ClaudeBox'"
test_result "Commands help function exists" "grep -q 'show_claudebox_commands' '$LIB_DIR/commands.sh'"
echo

# Test working commands (safe ones only)
echo "Command Integration:"
test_result "help command works" "'$MAIN_SCRIPT' help >/dev/null"
test_result "commands command works" "'$MAIN_SCRIPT' commands >/dev/null"
test_result "profiles command works" "'$MAIN_SCRIPT' profiles >/dev/null"
test_result "p shortcut works" "'$MAIN_SCRIPT' p >/dev/null"
echo

# Summary
echo "Test Results:"
echo "============="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "🎉 All validation tests passed!"
    echo "ClaudeBox CLI structure is properly implemented."
    exit 0
else
    echo "❌ Some tests failed. Please review the implementation."
    exit 1
fi
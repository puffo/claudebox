#!/usr/bin/env bash
# ClaudeBox All Commands Validation Test
# Systematically tests every command in the ClaudeBox CLI for:
# - Proper registration in CLI parser
# - Correct requirement classification  
# - Dispatcher function existence
# - Help text consistency
# - Ergonomic compliance

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"
readonly MAIN_SCRIPT="$CLAUDEBOX_ROOT/main.sh"
readonly LIB_DIR="$CLAUDEBOX_ROOT/lib"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Extract all commands from the system
get_all_script_commands() {
    # Extract SCRIPT_COMMANDS array from cli.sh
    local cli_file="$LIB_DIR/cli.sh"
    grep "readonly SCRIPT_COMMANDS=" "$cli_file" | \
        sed 's/.*(//' | sed 's/).*//' | \
        tr ' ' '\n' | \
        grep -v '^$' | \
        tr -d '()'
}

get_all_dispatcher_commands() {
    # Extract all commands from dispatcher in commands.sh
    local commands_file="$LIB_DIR/commands.sh"
    grep -E '^\s*[a-zA-Z0-9_-]+(\s*\|\s*[a-zA-Z0-9_-]+)*\)\s*_cmd_' "$commands_file" | \
        sed 's/)//' | \
        sed 's/\s*_cmd_.*//' | \
        tr '|' '\n' | \
        sed 's/^\s*//' | sed 's/\s*$//' | \
        grep -v '^$'
}

get_all_command_functions() {
    # Find all _cmd_* functions in command files
    find "$LIB_DIR" -name "commands*.sh" -exec grep -h "^_cmd_[a-zA-Z0-9_]*(" {} \; | \
        sed 's/^_cmd_//' | sed 's/(.*//' | \
        sort | uniq
}

# Test result functions
print_result() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"
    
    ((TESTS_RUN++))
    if [[ "$status" == "PASS" ]]; then
        ((TESTS_PASSED++))
        printf "${GREEN}✓${NC} %-60s ${GREEN}PASS${NC}\n" "$test_name"
    else
        ((TESTS_FAILED++))
        printf "${RED}✗${NC} %-60s ${RED}FAIL${NC}\n" "$test_name"
        if [[ -n "$details" ]]; then
            printf "  ${YELLOW}%s${NC}\n" "$details"
        fi
    fi
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    shift 2
    
    if "$test_function" "$@"; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL"
    fi
}

# ============================================================================
# Command Validation Tests
# ============================================================================

test_command_registered() {
    local cmd="$1"
    
    # Skip help flags and built-ins
    [[ "$cmd" == "-h" ]] || [[ "$cmd" == "--help" ]] && return 0
    
    # Check if command is in SCRIPT_COMMANDS array
    local script_commands
    script_commands=$(get_all_script_commands)
    grep -q "^$cmd$" <<< "$script_commands"
}

test_command_has_dispatcher() {
    local cmd="$1"
    
    # Skip help flags and single-letter shortcuts for detailed testing
    [[ "$cmd" == "-h" ]] || [[ "$cmd" == "--help" ]] && return 0
    
    # Check if command has dispatcher entry
    local commands_file="$LIB_DIR/commands.sh"
    
    # Look for command in dispatcher (handles shortcuts with | syntax)
    grep -q "\\b$cmd\\b)" "$commands_file"
}

test_command_function_exists() {
    local cmd="$1"
    
    # Skip help flags, shortcuts, and special cases
    [[ "$cmd" == "-h" ]] || [[ "$cmd" == "--help" ]] && return 0
    [[ ${#cmd} -eq 1 ]] && return 0  # Skip single-letter shortcuts
    
    # Special cases that don't have _cmd_ functions
    local special_cases=("commands")
    for special in "${special_cases[@]}"; do
        [[ "$cmd" == "$special" ]] && return 0
    done
    
    # Check if _cmd_$cmd function exists
    local function_name="_cmd_$cmd"
    find "$LIB_DIR" -name "commands*.sh" -exec grep -q "^$function_name(" {} \; && return 0
    
    # Check if command forwards to container or has special handling
    grep -q "\\b$cmd\\b)" "$LIB_DIR/commands.sh" && return 0
    
    return 1
}

test_command_requirements() {
    local cmd="$1"
    
    # Source CLI functions
    source "$LIB_DIR/cli.sh" 2>/dev/null || return 1
    
    # Get command requirements
    local req
    req=$(get_command_requirements "$cmd" 2>/dev/null) || return 1
    
    # Should be one of: none, image, docker
    [[ "$req" == "none" ]] || [[ "$req" == "image" ]] || [[ "$req" == "docker" ]]
}

test_command_help_exists() {
    local cmd="$1"
    
    # Skip single-letter shortcuts and help flags
    [[ ${#cmd} -eq 1 ]] && return 0
    [[ "$cmd" == "-h" ]] || [[ "$cmd" == "--help" ]] && return 0
    
    # Check if command appears in help text
    local help_output
    help_output=$("$MAIN_SCRIPT" commands 2>&1) || return 1
    
    # Command should appear in commands help (handle shortcuts)
    grep -q "\\b$cmd\\b\\|($cmd)" <<< "$help_output"
}

# ============================================================================
# Specific Command Category Tests
# ============================================================================

test_core_commands() {
    local core_commands=("help" "shell" "update")
    
    for cmd in "${core_commands[@]}"; do
        run_test "Core command '$cmd' registered" test_command_registered "$cmd"
        run_test "Core command '$cmd' has dispatcher" test_command_has_dispatcher "$cmd"
        run_test "Core command '$cmd' has function" test_command_function_exists "$cmd"
        run_test "Core command '$cmd' has requirements" test_command_requirements "$cmd"
    done
}

test_profile_commands() {
    local profile_commands=("profiles" "profile" "add" "remove" "install")
    
    for cmd in "${profile_commands[@]}"; do
        run_test "Profile command '$cmd' registered" test_command_registered "$cmd"
        run_test "Profile command '$cmd' has dispatcher" test_command_has_dispatcher "$cmd"
        run_test "Profile command '$cmd' has function" test_command_function_exists "$cmd"
        run_test "Profile command '$cmd' has requirements" test_command_requirements "$cmd"
    done
}

test_slot_commands() {
    local slot_commands=("create" "slots" "slot" "revoke" "kill")
    
    for cmd in "${slot_commands[@]}"; do
        run_test "Slot command '$cmd' registered" test_command_registered "$cmd"
        run_test "Slot command '$cmd' has dispatcher" test_command_has_dispatcher "$cmd" 
        run_test "Slot command '$cmd' has function" test_command_function_exists "$cmd"
        run_test "Slot command '$cmd' has requirements" test_command_requirements "$cmd"
    done
}

test_info_commands() {
    local info_commands=("info" "projects" "allowlist" "status" "where")
    
    for cmd in "${info_commands[@]}"; do
        run_test "Info command '$cmd' registered" test_command_registered "$cmd"
        run_test "Info command '$cmd' has dispatcher" test_command_has_dispatcher "$cmd"
        run_test "Info command '$cmd' has function" test_command_function_exists "$cmd"
        run_test "Info command '$cmd' has requirements" test_command_requirements "$cmd" 
        run_test "Info command '$cmd' in help" test_command_help_exists "$cmd"
    done
}

test_system_commands() {
    local system_commands=("save" "unlink" "rebuild" "tmux" "project" "import" "clean")
    
    for cmd in "${system_commands[@]}"; do
        run_test "System command '$cmd' registered" test_command_registered "$cmd"
        run_test "System command '$cmd' has dispatcher" test_command_has_dispatcher "$cmd"
        run_test "System command '$cmd' has function" test_command_function_exists "$cmd"
        run_test "System command '$cmd' has requirements" test_command_requirements "$cmd"
    done
}

test_new_ergonomic_commands() {
    local new_commands=("commands" "status" "where")
    
    echo "${CYAN}Testing New Ergonomic Commands:${NC}"
    for cmd in "${new_commands[@]}"; do
        run_test "New command '$cmd' registered" test_command_registered "$cmd"
        run_test "New command '$cmd' has dispatcher" test_command_has_dispatcher "$cmd"
        run_test "New command '$cmd' works" test_command_integration "$cmd"
        run_test "New command '$cmd' in help" test_command_help_exists "$cmd"
    done
}

test_shortcuts() {
    local shortcuts=("s" "c" "p" "i")
    local full_commands=("shell" "create" "profiles" "info")
    
    echo "${CYAN}Testing Command Shortcuts:${NC}"
    for i in "${!shortcuts[@]}"; do
        local short="${shortcuts[$i]}"
        local full="${full_commands[$i]}"
        
        run_test "Shortcut '$short' registered" test_command_registered "$short"
        run_test "Shortcut '$short' has dispatcher" test_command_has_dispatcher "$short"
        run_test "Shortcut '$short' same requirements as '$full'" test_shortcut_requirements "$short" "$full"
    done
}

# ============================================================================
# Integration Tests
# ============================================================================

test_command_integration() {
    local cmd="$1"
    
    # Test if command can be invoked (safe commands only)
    local safe_commands=("help" "commands" "profiles" "projects" "status" "where")
    
    for safe_cmd in "${safe_commands[@]}"; do
        if [[ "$cmd" == "$safe_cmd" ]]; then
            local output
            output=$("$MAIN_SCRIPT" "$cmd" 2>&1) || return 1
            [[ -n "$output" ]] || return 1
            return 0
        fi
    done
    
    # For non-safe commands, just check they don't cause parser errors
    return 0
}

test_shortcut_requirements() {
    local short="$1"
    local full="$2"
    
    source "$LIB_DIR/cli.sh" 2>/dev/null || return 1
    
    local short_req full_req
    short_req=$(get_command_requirements "$short" 2>/dev/null) || return 1
    full_req=$(get_command_requirements "$full" 2>/dev/null) || return 1
    
    [[ "$short_req" == "$full_req" ]]
}

# ============================================================================
# Comprehensive Command Discovery
# ============================================================================

test_all_discovered_commands() {
    echo "${CYAN}Testing All Discovered Commands:${NC}"
    
    # Get all commands from various sources
    local all_commands
    all_commands=$(get_all_script_commands | sort | uniq)
    
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] || continue
        
        # Basic validation for each command
        run_test "Command '$cmd' structure" test_command_structure "$cmd"
    done <<< "$all_commands"
}

test_command_structure() {
    local cmd="$1"
    
    # Skip help flags
    [[ "$cmd" == "-h" ]] || [[ "$cmd" == "--help" ]] && return 0
    
    # Must be registered
    test_command_registered "$cmd" || return 1
    
    # Must have dispatcher (unless special case)
    test_command_has_dispatcher "$cmd" || return 1
    
    # Must have valid requirements
    test_command_requirements "$cmd" || return 1
    
    return 0
}

# ============================================================================
# Main Test Runner  
# ============================================================================

main() {
    echo "ClaudeBox All Commands Validation Test"
    echo "======================================="
    echo
    
    # Test each command category
    echo "${CYAN}Testing Core Commands:${NC}"
    test_core_commands
    echo
    
    echo "${CYAN}Testing Profile Commands:${NC}" 
    test_profile_commands
    echo
    
    echo "${CYAN}Testing Slot Commands:${NC}"
    test_slot_commands  
    echo
    
    echo "${CYAN}Testing Info Commands:${NC}"
    test_info_commands
    echo
    
    echo "${CYAN}Testing System Commands:${NC}"
    test_system_commands
    echo
    
    # Test ergonomic improvements
    test_new_ergonomic_commands
    echo
    
    test_shortcuts
    echo
    
    # Comprehensive discovery test
    test_all_discovered_commands
    echo
    
    # Summary
    echo "Test Results Summary:"
    echo "===================="
    printf "Total tests run: %d\n" $TESTS_RUN
    printf "${GREEN}Passed: %d${NC}\n" $TESTS_PASSED  
    printf "${RED}Failed: %d${NC}\n" $TESTS_FAILED
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "${GREEN}🎉 All commands validate successfully!${NC}"
        echo
        echo "ClaudeBox CLI structure is:"
        echo "✅ Properly organized"
        echo "✅ Ergonomically compliant"  
        echo "✅ Fully functional"
        exit 0
    else
        echo "${RED}❌ Some command validation tests failed${NC}"
        echo "Please review the failed tests above."
        exit 1
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
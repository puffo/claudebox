#!/usr/bin/env bash
# ClaudeBox CLI Structure and Ergonomics Test Framework
# Tests CLI parsing, command structure, help consistency, and ergonomic rules
#
# This test framework validates:
# 1. Command structure and organization
# 2. Help text consistency and formatting
# 3. Flag validation and normalization  
# 4. Command requirements classification
# 5. Ergonomic compliance (shortcuts, discoverability, etc.)

set -euo pipefail

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"
readonly MAIN_SCRIPT="$CLAUDEBOX_ROOT/main.sh"
readonly LIB_DIR="$CLAUDEBOX_ROOT/lib"

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test Framework Functions
# ============================================================================

# Print test result
print_result() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"
    
    ((TESTS_RUN++))
    if [[ "$status" == "PASS" ]]; then
        ((TESTS_PASSED++))
        printf "${GREEN}✓${NC} %-50s ${GREEN}PASS${NC}\n" "$test_name"
    else
        ((TESTS_FAILED++))
        printf "${RED}✗${NC} %-50s ${RED}FAIL${NC}\n" "$test_name"
        if [[ -n "$details" ]]; then
            printf "  ${YELLOW}%s${NC}\n" "$details"
        fi
    fi
}

# Run a test with error handling
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    if "$test_function"; then
        print_result "$test_name" "PASS"
    else
        print_result "$test_name" "FAIL" "Test function failed"
    fi
}

# Check if command exists in CLI parser
command_exists() {
    local cmd="$1"
    grep -q "\\b$cmd\\b" "$LIB_DIR/cli.sh"
}

# Get command requirements
get_command_requirements() {
    local cmd="$1"
    # Source the CLI functions to get requirements
    source "$LIB_DIR/cli.sh"
    get_command_requirements "$cmd"
}

# ============================================================================
# CLI Structure Tests
# ============================================================================

test_four_bucket_architecture() {
    # Verify the four-bucket CLI architecture is maintained
    local cli_file="$LIB_DIR/cli.sh"
    
    # Check that all required arrays exist
    grep -q "readonly HOST_ONLY_FLAGS=" "$cli_file" &&
    grep -q "readonly CONTROL_FLAGS=" "$cli_file" &&
    grep -q "readonly SCRIPT_COMMANDS=" "$cli_file" &&
    grep -q "parse_cli_args()" "$cli_file"
}

test_flag_consistency() {
    # All host-only flags should use --flag format
    local cli_file="$LIB_DIR/cli.sh"
    
    # Extract HOST_ONLY_FLAGS array contents
    local flags
    flags=$(grep "readonly HOST_ONLY_FLAGS=" "$cli_file" | sed 's/.*(//' | sed 's/).*//' | tr -d '()' | tr ' ' '\n')
    
    # Check each flag starts with --
    while IFS= read -r flag; do
        [[ -n "$flag" ]] || continue
        [[ "$flag" == --* ]] || return 1
    done <<< "$flags"
}

test_control_flags_format() {
    # All control flags should use --flag format
    local cli_file="$LIB_DIR/cli.sh"
    
    # Extract CONTROL_FLAGS array contents  
    local flags
    flags=$(grep "readonly CONTROL_FLAGS=" "$cli_file" | sed 's/.*(//' | sed 's/).*//' | tr -d '()' | tr ' ' '\n')
    
    # Check each flag starts with --
    while IFS= read -r flag; do
        [[ -n "$flag" ]] || continue
        [[ "$flag" == --* ]] || return 1
    done <<< "$flags"
}

test_script_commands_exist() {
    # All script commands should have dispatcher entries
    local cli_file="$LIB_DIR/cli.sh"
    local commands_file="$LIB_DIR/commands.sh"
    
    # Extract SCRIPT_COMMANDS array
    local commands
    commands=$(grep "readonly SCRIPT_COMMANDS=" "$cli_file" | sed 's/.*(//' | sed 's/).*//' | tr -d '()' | tr ' ' '\n')
    
    # Check each command has dispatcher entry (excluding help flags and shortcuts)
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] || continue
        # Skip help flags and single-letter shortcuts for this test
        [[ "$cmd" == "-h" ]] || [[ "$cmd" == "--help" ]] || [[ ${#cmd} -eq 1 ]] && continue
        
        # Check if command exists in dispatcher
        grep -q "\\b$cmd\\b)" "$commands_file" || return 1
    done <<< "$commands"
}

# ============================================================================
# Command Requirements Tests
# ============================================================================

test_command_requirements_classification() {
    # Test that command requirements are correctly classified
    local test_cases=(
        "help:none"
        "profiles:none"  
        "commands:none"
        "create:none"
        "info:image"
        "status:image"
        "shell:docker"
        "project:docker"
    )
    
    for test_case in "${test_cases[@]}"; do
        local cmd="${test_case%:*}"
        local expected="${test_case#*:}"
        
        # Source CLI functions
        source "$LIB_DIR/cli.sh"
        local actual
        actual=$(get_command_requirements "$cmd")
        
        [[ "$actual" == "$expected" ]] || {
            printf "Command '%s': expected '%s', got '%s'\n" "$cmd" "$expected" "$actual" >&2
            return 1
        }
    done
}

test_shortcuts_work() {
    # Test that shortcuts are properly mapped
    local shortcuts=(
        "s:shell"
        "c:create"  
        "p:profiles"
        "i:info"
    )
    
    source "$LIB_DIR/cli.sh"
    
    for shortcut_pair in "${shortcuts[@]}"; do
        local short="${shortcut_pair%:*}"
        local full="${shortcut_pair#*:}"
        
        # Both should have same requirements
        local short_req
        local full_req
        short_req=$(get_command_requirements "$short")
        full_req=$(get_command_requirements "$full")
        
        [[ "$short_req" == "$full_req" ]] || {
            printf "Shortcut '%s' -> '%s': requirements mismatch (%s != %s)\n" "$short" "$full" "$short_req" "$full_req" >&2
            return 1
        }
    done
}

test_interactive_menu_structure() {
    # Test that interactive menu cases properly exit
    local menu_file="$LIB_DIR/commands.sh"
    
    # Check that interactive menu cases have proper exit statements
    # This prevents fall-through bugs where menu options continue to Claude CLI
    local case_pattern="[0-9]+\)"
    local exit_pattern="exit \$?"
    
    # Look for interactive menu function
    if grep -q "show_interactive_menu()" "$menu_file"; then
        # Check that non-default cases have exit statements
        local cases_with_exits
        cases_with_exits=$(grep -A3 "[2-9])" "$menu_file" | grep -c "exit")
        
        # Should have at least 5 menu options with exits (options 2-6)
        [[ $cases_with_exits -ge 5 ]] || {
            printf "Interactive menu cases missing proper exit statements\n" >&2
            return 1
        }
    fi
}

# ============================================================================
# Help Text Consistency Tests
# ============================================================================

test_help_commands_exist() {
    # Test that all help subcommands work
    local help_commands=("" "full" "claude" "commands")
    
    for subcmd in "${help_commands[@]}"; do
        local output
        if ! output=$("$MAIN_SCRIPT" help $subcmd 2>&1); then
            printf "Help command 'help %s' failed\n" "$subcmd" >&2
            return 1
        fi
        
        # Should contain ClaudeBox branding
        grep -q "ClaudeBox\\|claudebox" <<< "$output" || {
            printf "Help command 'help %s' missing ClaudeBox branding\n" "$subcmd" >&2
            return 1
        }
    done
}

test_commands_reference_formatting() {
    # Test that 'claudebox commands' has proper formatting
    local output
    output=$("$MAIN_SCRIPT" commands 2>&1)
    
    # Should have section headers
    grep -q "Container Management:" <<< "$output" &&
    grep -q "Development Profiles:" <<< "$output" &&
    grep -q "Project Information:" <<< "$output" &&
    grep -q "System & Utilities:" <<< "$output" &&
    grep -q "Help & Information:" <<< "$output"
}

test_shortcuts_documented() {
    # Test that shortcuts are shown in help text
    local output
    output=$("$MAIN_SCRIPT" commands 2>&1)
    
    # Should show shortcuts in parentheses
    grep -q "create (c)" <<< "$output" &&
    grep -q "shell (s)" <<< "$output" &&
    grep -q "profiles (p)" <<< "$output" &&
    grep -q "info (i)" <<< "$output"
}

# ============================================================================
# Ergonomic Compliance Tests  
# ============================================================================

test_new_commands_exist() {
    # Test that new ergonomic commands exist
    local new_commands=("status" "where" "commands")
    
    for cmd in "${new_commands[@]}"; do
        command_exists "$cmd" || {
            printf "New command '%s' not found in CLI parser\n" "$cmd" >&2
            return 1
        }
        
        # Should have dispatcher entry
        grep -q "\\b$cmd\\b)" "$LIB_DIR/commands.sh" || {
            printf "New command '%s' not found in dispatcher\n" "$cmd" >&2
            return 1
        }
    done
}

test_help_priority() {
    # Test that 'claudebox help' shows ClaudeBox commands first, not Claude help
    local output
    output=$("$MAIN_SCRIPT" help 2>&1)
    
    # Should contain ClaudeBox commands section
    grep -q "ClaudeBox Commands:" <<< "$output" ||
    grep -q "Commands:" <<< "$output"
}

test_no_slots_message_improved() {
    # Test that no slots message is contextual and helpful
    # This is harder to test without triggering the condition, so we check the function exists
    grep -q "show_no_slots_menu()" "$LIB_DIR/commands.sh" &&
    grep -q "Quick Setup Required" "$LIB_DIR/commands.sh"
}

# ============================================================================
# Function Existence Tests
# ============================================================================

test_required_functions_exist() {
    # Test that all required functions are defined and exported
    local required_functions=(
        "parse_cli_args"
        "get_command_requirements"
        "dispatch_command"
        "show_help"
        "show_claudebox_commands"
        "show_no_slots_menu"
        "show_interactive_menu"
    )
    
    # Source the library files
    for lib in cli common commands; do
        source "$LIB_DIR/${lib}.sh" 2>/dev/null || true
    done
    
    for func in "${required_functions[@]}"; do
        if ! type -t "$func" >/dev/null 2>&1; then
            printf "Required function '%s' not found\n" "$func" >&2
            return 1
        fi
    done
}

# ============================================================================
# Integration Tests
# ============================================================================

test_command_integration() {
    # Test that key commands can be invoked without error (dry-run style)
    local safe_commands=("help" "commands" "profiles")
    
    for cmd in "${safe_commands[@]}"; do
        local output
        if ! output=$("$MAIN_SCRIPT" "$cmd" 2>&1); then
            printf "Command '%s' failed to execute\n" "$cmd" >&2
            return 1
        fi
        
        # Should produce some output
        [[ -n "$output" ]] || {
            printf "Command '%s' produced no output\n" "$cmd" >&2
            return 1
        }
    done
}

test_shortcut_integration() {
    # Test that shortcuts work the same as full commands
    local output_full
    local output_short
    
    # Test profiles vs p
    output_full=$("$MAIN_SCRIPT" profiles 2>&1)
    output_short=$("$MAIN_SCRIPT" p 2>&1)
    
    # Outputs should be identical
    [[ "$output_full" == "$output_short" ]] || {
        printf "Shortcut 'p' output differs from 'profiles'\n" >&2
        return 1
    }
}

# ============================================================================
# Main Test Runner
# ============================================================================

main() {
    echo "ClaudeBox CLI Structure and Ergonomics Tests"
    echo "============================================"
    echo
    
    # CLI Structure Tests
    echo "${CYAN}CLI Structure Tests:${NC}"
    run_test "Four-bucket architecture" test_four_bucket_architecture
    run_test "Host-only flags consistency" test_flag_consistency  
    run_test "Control flags format" test_control_flags_format
    run_test "Script commands exist" test_script_commands_exist
    echo
    
    # Command Requirements Tests
    echo "${CYAN}Command Requirements Tests:${NC}"
    run_test "Command requirements classification" test_command_requirements_classification
    run_test "Shortcuts work correctly" test_shortcuts_work
    echo
    
    # Help Text Tests  
    echo "${CYAN}Help Text Consistency Tests:${NC}"
    run_test "Help commands exist" test_help_commands_exist
    run_test "Commands reference formatting" test_commands_reference_formatting
    run_test "Shortcuts documented" test_shortcuts_documented
    echo
    
    # Ergonomic Tests
    echo "${CYAN}Ergonomic Compliance Tests:${NC}"
    run_test "New commands exist" test_new_commands_exist
    run_test "Help shows ClaudeBox first" test_help_priority
    run_test "No slots message improved" test_no_slots_message_improved
    echo
    
    # Function Tests
    echo "${CYAN}Function Existence Tests:${NC}"
    run_test "Required functions exist" test_required_functions_exist
    echo
    
    # Integration Tests
    echo "${CYAN}Integration Tests:${NC}"
    run_test "Command integration" test_command_integration
    run_test "Shortcut integration" test_shortcut_integration
    echo
    
    # Summary
    echo "Test Results:"
    echo "============="
    printf "Tests run: %d\n" $TESTS_RUN
    printf "${GREEN}Passed: %d${NC}\n" $TESTS_PASSED
    printf "${RED}Failed: %d${NC}\n" $TESTS_FAILED
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "${GREEN}All tests passed! ✅${NC}"
        exit 0
    else
        echo "${RED}Some tests failed! ❌${NC}"
        exit 1
    fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
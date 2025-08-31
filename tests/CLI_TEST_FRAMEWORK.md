# ClaudeBox CLI Test Framework

## Overview

This directory contains a comprehensive test framework for validating ClaudeBox's CLI structure, ergonomics, and functionality. The framework ensures that all CLI improvements maintain backward compatibility while following ergonomic best practices.

## Test Structure

```
tests/
├── CLI_TEST_FRAMEWORK.md           # This documentation
├── run_all_tests.sh               # Master test runner  
├── test_cli_structure.sh          # Comprehensive CLI structure tests
├── test_all_commands.sh           # All commands validation 
├── test_commands_simple.sh        # Simple CLI validation
├── test_bash32_compat.sh          # Bash 3.2 compatibility (existing)
├── test_profile_detection.sh      # Profile detection (existing)
└── profiles/                      # Profile-specific tests (existing)
```

## Test Categories

### 1. CLI Structure Tests (`test_cli_structure.sh`)
Tests the fundamental four-bucket CLI architecture:
- **Host-only flags** validation (`--verbose`, `--rebuild`, `--tmux`)
- **Control flags** validation (`--enable-sudo`, `--disable-firewall`)
- **Script commands** registration and dispatcher mapping
- **Pass-through args** handling

### 2. Command Validation (`test_all_commands.sh`)
Comprehensive validation of all ClaudeBox commands:
- Command registration in CLI parser
- Dispatcher function existence
- Requirement classification (none/image/docker)
- Help text consistency
- Function implementation verification

### 3. Ergonomic Compliance
Validates all ergonomic improvements:
- Command shortcuts (`s`, `c`, `p`, `i`)
- New discovery commands (`commands`, `status`, `where`)
- Help system improvements
- Error message enhancements
- Interactive menu functionality

### 4. Integration Tests
- Safe command execution testing
- Shortcut-to-command equivalence
- Help text formatting validation
- Cross-compatibility verification

## Key Test Principles

### 1. **Four-Bucket Architecture**
All CLI arguments must be classified into exactly one bucket:
```bash
HOST_ONLY_FLAGS=(--verbose --rebuild --tmux)
CONTROL_FLAGS=(--enable-sudo --disable-firewall) 
SCRIPT_COMMANDS=(shell create slot profiles ...)
# Everything else goes to pass-through
```

### 2. **Command Requirements Classification**
Every command must be properly classified:
- **`none`**: Pure host commands (help, profiles, create)
- **`image`**: Need image name but not Docker (info, status, where)
- **`docker`**: Need Docker running (shell, interactive Claude)

### 3. **Dispatcher Consistency**
Every script command must have a corresponding dispatcher entry:
```bash
case "${cmd}" in
    profiles | p) _cmd_profiles "$@" ;;
    status) _cmd_status "$@" ;;
    # ...
esac
```

### 4. **Flag Normalization**
All flags use consistent `--flag` format:
- ✅ `--verbose`, `--rebuild`, `--tmux`
- ❌ `verbose`, `rebuild` (old inconsistent style)

## Running Tests

### Quick Validation
```bash
./tests/run_all_tests.sh
```

### Individual Test Suites
```bash
# Comprehensive CLI structure tests
./tests/test_cli_structure.sh

# All commands validation  
./tests/test_all_commands.sh

# Simple smoke tests
./tests/test_commands_simple.sh
```

### Existing Compatibility Tests
```bash
# Bash 3.2 compatibility
./tests/test_bash32_compat.sh

# Profile detection
./tests/test_profile_detection.sh
```

## Test Results Interpretation

### Expected Output
All tests should pass with output like:
```
✅ ClaudeBox CLI structure has been validated
✅ New ergonomic features are working  
✅ Backward compatibility is maintained
✅ All command categories are functional
```

### Failure Scenarios
Tests may fail if:
- Commands are not registered in CLI parser
- Dispatcher entries are missing
- Functions are not implemented
- Requirements are incorrectly classified
- Help text is inconsistent

## Adding New Commands

When adding new commands, ensure:

1. **Register in CLI parser** (`lib/cli.sh`):
```bash
readonly SCRIPT_COMMANDS=(... newcommand ...)
```

2. **Add requirement classification**:
```bash
get_command_requirements() {
    case "$cmd" in
        newcommand) echo "none" ;;  # or "image" or "docker"
        # ...
    esac
}
```

3. **Add dispatcher entry** (`lib/commands.sh`):
```bash
case "${cmd}" in
    newcommand) _cmd_newcommand "$@" ;;
    # ...
esac
```

4. **Implement function** (appropriate `lib/commands.*.sh`):
```bash
_cmd_newcommand() {
    # Implementation
}
export -f _cmd_newcommand
```

5. **Update help text** if user-facing

6. **Run tests** to verify integration

## Ergonomic Validation

The framework validates key ergonomic principles:

### Command Discoverability
- `claudebox help` shows ClaudeBox commands first
- `claudebox commands` provides categorized reference
- Shortcuts are documented in help text

### User Experience
- Contextual error messages with next steps
- Interactive menus for common workflows  
- Status commands for project awareness
- Path commands for troubleshooting

### Consistency
- All flags use `--format`
- All commands follow same structure
- Help text is properly formatted
- Shortcuts work identically to full commands

## Continuous Validation

Run the test suite when:
- Adding new commands
- Modifying CLI parsing logic
- Changing help text
- Refactoring command structure
- Before releases

The framework ensures ClaudeBox maintains its high-quality CLI experience for all 1000+ users while supporting future enhancements.

## Framework Architecture

The test framework follows ClaudeBox's own architectural principles:

1. **Modularity**: Separate test files for different concerns
2. **Bash 3.2 Compatibility**: All tests work on macOS and Linux
3. **Error Safety**: Uses `set -euo pipefail` consistently  
4. **Clear Output**: Descriptive test names and results
5. **Fast Execution**: Efficient testing with timeouts
6. **Comprehensive Coverage**: Tests structure, function, and integration

This ensures the CLI remains robust, discoverable, and user-friendly across all improvements.
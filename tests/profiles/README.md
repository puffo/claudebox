# ClaudeBox Profile Detection Tests

This directory contains version detection tests for ClaudeBox profiles that support automatic version detection.

## Structure

```
tests/
├── test_profile_detection.sh    # Master test runner
└── profiles/                     # Profile-specific tests
    ├── README.md                 # This file
    ├── TEMPLATE_test_PROFILE_detection.sh  # Template for new tests
    └── test_ruby_detection.sh   # Ruby version detection tests
```

## Running Tests

### Run all profile tests:
```bash
bash tests/test_profile_detection.sh
```

### Run tests for a specific profile:
```bash
bash tests/test_profile_detection.sh ruby
```

### Run individual profile test directly:
```bash
bash tests/profiles/test_ruby_detection.sh
```

## Adding Tests for New Profiles

1. Copy the template:
   ```bash
   cp tests/profiles/TEMPLATE_test_PROFILE_detection.sh \
      tests/profiles/test_PROFILENAME_detection.sh
   ```

2. Edit the new test file and replace:
   - `PROFILE_NAME` with the display name (e.g., "Python")
   - `PROFILE` with the profile identifier (e.g., "python")
   - `detect_PROFILE_version` with the actual function name

3. Add test cases for:
   - Version file detection (e.g., `.python-version`, `.node-version`)
   - Configuration file detection (e.g., `pyproject.toml`, `package.json`)
   - Environment variable overrides
   - Priority order between different sources
   - Edge cases and invalid inputs

4. The master test runner will automatically discover and run your new test

## Currently Supported Profiles

| Profile | Version Detection | Test Coverage |
|---------|------------------|---------------|
| Ruby | ✅ Implemented | ✅ Complete |
| Python | ❌ Not yet | ❌ None |
| JavaScript | ❌ Not yet | ❌ None |
| Go | ❌ Not yet | ❌ None |
| Rust | ❌ Not yet | ❌ None |
| Java | ❌ Not yet | ❌ None |
| PHP | ❌ Not yet | ❌ None |

## Test Guidelines

1. **Isolation**: Each test should be independent and not affect others
2. **Cleanup**: Always clean up test files after each test
3. **Temporary Directory**: Use a unique temp directory for each test run
4. **Error Handling**: Test both success and failure cases
5. **Priority Testing**: Verify correct precedence order for version sources
6. **Edge Cases**: Include tests for empty files, invalid formats, etc.

## Version Detection Priority

Most profiles should follow this priority order (highest to lowest):

1. Environment variable (e.g., `CLAUDEBOX_PYTHON_VERSION`)
2. Version-specific file (e.g., `.python-version`, `.node-version`)
3. Tool configuration files (e.g., `mise.toml`, `.tool-versions`)
4. Language-specific files (e.g., `pyproject.toml`, `package.json`)
5. Default version (fallback)

## Test Output Format

Tests should output:
- Number of tests run
- Number of tests passed
- Number of tests failed
- Clear PASS/FAIL indicators for each test
- Expected vs. actual values for failures

This standardized format allows the master test runner to aggregate results across all profiles.
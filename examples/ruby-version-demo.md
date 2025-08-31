# Ruby Version Detection Demo

This demonstrates how ClaudeBox automatically detects and uses the appropriate Ruby version for your project.

## How It Works

ClaudeBox checks for Ruby version in this priority order:

1. **Environment Variable** (highest priority)
   ```bash
   CLAUDEBOX_RUBY_VERSION=3.2.0 claudebox start --profile ruby
   ```

2. **.ruby-version file** (rbenv/rvm/chruby standard)
   ```bash
   echo "3.2.2" > .ruby-version
   claudebox start --profile ruby
   ```

3. **mise.toml file** (mise version manager)
   ```toml
   # In your mise.toml or .mise.toml
   ruby = "3.1.4"
   # or
   ruby = { version = "3.1.4" }
   ```

4. **.tool-versions file** (asdf/mise version manager)
   ```bash
   echo "ruby 3.1.4" >> .tool-versions
   claudebox start --profile ruby
   ```

5. **Gemfile ruby directive**
   ```ruby
   # In your Gemfile
   source "https://rubygems.org"
   ruby "3.3.0"
   ```

6. **Default fallback** - Uses Ruby 3.4.5 if no version is specified

## How Ruby Version Management Works

ClaudeBox uses **mise** (formerly rtx) as its Ruby version manager. Mise is a modern, polyglot runtime manager that provides fast, reliable version management for Ruby and many other languages.

When you start a container with the Ruby profile, ClaudeBox:
1. Detects the Ruby version from your project files
2. Installs mise in the container
3. Uses mise to install and activate the detected Ruby version
4. Configures the environment to use that Ruby version globally

## Examples

### Example 1: Rails Project with .ruby-version

```bash
# Your Rails project has a .ruby-version file
$ cat .ruby-version
3.2.2

# Start ClaudeBox - it will automatically use Ruby 3.2.2
$ claudebox start --profile ruby
```

### Example 2: Manual Override for Testing

```bash
# Test your app with a different Ruby version
$ CLAUDEBOX_RUBY_VERSION=3.1.0 claudebox start --profile ruby
```

### Example 3: Multiple Projects with Different Ruby Versions

```bash
# Project A uses Ruby 3.2
$ cd ~/projects/app-a
$ cat .ruby-version
3.2.2
$ claudebox start --profile ruby  # Uses Ruby 3.2.2

# Project B uses Ruby 3.3
$ cd ~/projects/app-b
$ cat Gemfile | grep ruby
ruby "3.3.0"
$ claudebox start --profile ruby  # Uses Ruby 3.3.0
```

### Example 4: Using mise.toml for Ruby Version

```bash
# Create a mise.toml file
$ cat mise.toml
[tools]
ruby = "3.2.2"

# ClaudeBox will detect and use this version
$ claudebox start --profile ruby
```

## Best Practices

1. **Use .ruby-version for consistency** - This file is recognized by most Ruby version managers (mise, rbenv, rvm, chruby)

2. **Commit version files to your repository** - This ensures all developers use the same Ruby version

3. **Use exact versions in production** - Avoid version ranges like "~> 3.2" for production apps

4. **Test with multiple versions** - Use the CLAUDEBOX_RUBY_VERSION override to test compatibility

## Troubleshooting

If you see warnings about invalid Ruby versions:
- Check that your version format is correct (e.g., "3.2.0" not "ruby-3.2.0")
- Ensure the version is available in mise's Ruby plugin
- Use `mise list-remote ruby` inside the container to see available versions

## Verbose Mode

To see which Ruby version is being detected and why:

```bash
claudebox start --profile ruby --verbose
```

This will show messages like:
```
Using Ruby version from .ruby-version: 3.2.2
```
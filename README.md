# gem-scaffold

A template repository for creating Ruby gems with automated Ruby version management.

## Prerequisites

The initialization script requires the following commands:

- **[zsh](https://www.zsh.org/)** - Z shell (usually pre-installed on macOS/Linux)
- **[gh](https://cli.github.com/)** - GitHub CLI for repository configuration
- **[git](https://git-scm.com/)** - Version control (usually pre-installed)
- **[jq](https://jqlang.github.io/jq/)** - JSON processor
- **[mise](https://mise.jdx.dev/)** - Development environment manager
- **[openssl](https://www.openssl.org/)** - Cryptography toolkit (usually pre-installed)

## Usage

1. Create a new repository from this template:

   **Option A: Using GitHub CLI (recommended)**
   ```bash
   gh repo create my-gem --template sakuro/gem-scaffold --clone
   cd my-gem
   ```

   **Option B: Using GitHub web interface**
   - Click the "Use this template" button on GitHub
   - See [Creating a repository from a template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)
   - Clone your new repository

2. Run the initialization script:
   ```bash
   ./bin/initialize
   ```

   This script will:
   - Update all files with your gem name
   - Generate proper Ruby module namespacing
   - Set up repository-specific cron schedule
   - Configure GitHub settings automatically
   - Remove setup script and amend changes into initial commit

3. Push the initialized changes:
   ```bash
   git push -f origin main
   ```

## Features

This template provides a modern Ruby gem setup with automated Ruby version management:

- **Always up-to-date Ruby support**: Automatically tracks maintained Ruby versions from [Ruby's official branches.yml](https://github.com/ruby/www.ruby-lang.org/blob/master/_data/branches.yml)
- **Zero-maintenance CI matrix**: Tests run against current Ruby versions without manual updates
- **Repository-specific scheduling**: Each cloned repository gets a unique cron schedule to distribute API load
- **One-command initialization**: Single script transforms the template into a ready-to-use gem

## What's Included in the Generated Gem

The initialization script creates a fully-configured gem with:

### Code Structure
- **Zeitwerk autoloading**: Automatic code loading with proper namespace handling
- **Proper module nesting**: Multi-level module structure based on gem name (e.g., `my-awesome-gem` → `My::Awesome::Gem`)

### Development Tools
- **Ruby LSP**: Language server for IDE features and code intelligence
- **RSpec with SimpleCov**: Testing framework with code coverage analysis (configurable via `.simplecov`)
- **RuboCop with docquet**: Code style enforcement with [docquet](https://github.com/sakuro/docquet) configuration
- **Mise integration**: Development environment uses minimum supported Ruby version

### CI/CD
- **Dynamic test matrix**: CI automatically tests against all maintained Ruby versions
- **Twice-yearly Ruby version updates**: GitHub Actions workflow keeps Ruby versions current (runs January 2-8 and April 2-8)

### Automatic Configuration
- **Author information**: Extracted from git config (user.name, user.email)
- **Dependency versions**: Latest compatible versions detected from remote (zeitwerk, etc.)

## License

This template is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

### License for Generated Code

Code generated from this template can be licensed under any license chosen by the author. The initialization script:
- Preserves this template's MIT license as `LICENSE-TEMPLATE.txt` (for template-derived code)
- Creates a new `LICENSE.txt` (MIT) with the author's name and year (for the generated gem)

Authors are free to replace `LICENSE.txt` with any license of their choosing.

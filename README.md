# gem-scaffold

A template repository for creating Ruby gems with automated Ruby version management.

## Prerequisites

The initialization script requires the following commands:

- **[zsh](https://www.zsh.org/)** - Z shell (usually pre-installed on macOS/Linux)
- **[gh](https://cli.github.com/)** - GitHub CLI for repository configuration
- **[mise](https://mise.jdx.dev/)** - Development environment manager
- **[jq](https://jqlang.github.io/jq/)** - JSON processor
- **[curl](https://curl.se/)** - HTTP client (usually pre-installed)
- **git** - Version control (usually pre-installed)

## Usage

1. Create a new repository from this template:

   **Option A: Using GitHub CLI (recommended)**
   ```bash
   gh repo create my-gem-name --template sakuro/gem-scaffold --private --clone
   cd my-gem-name
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
   - Create initial `.ruby_versions.json`
   - Configure GitHub settings automatically
   - Remove setup script and amend changes into initial commit

3. Push the initialized changes:
   ```bash
   git push -f origin main
   ```

## Features

This template provides a modern Ruby gem setup with automated Ruby version management:

- **Always up-to-date Ruby support**: Automatically tracks maintained Ruby versions from [endoflife.date](https://endoflife.date/ruby)
- **Zero-maintenance CI matrix**: Tests run against current Ruby versions without manual updates
- **Repository-specific scheduling**: Each cloned repository gets a unique cron schedule to distribute API load
- **One-command initialization**: Single script transforms the template into a ready-to-use gem

## What's Included in the Generated Gem

The initialization script creates a fully-configured gem with:

### Code Structure
- **Zeitwerk autoloading**: Automatic code loading with proper namespace handling
- **Proper module nesting**: Multi-level module structure based on gem name (e.g., `my-awesome-gem` → `My::Awesome::Gem`)
- **RBS type signatures**: Type definition files in `sig/` directory

### Development Tools
- **RSpec with SimpleCov**: Testing framework with code coverage analysis (configurable via `.simplecov`)
- **RuboCop with docquet**: Code style enforcement with [docquet](https://github.com/sakuro/docquet) configuration
- **Pre-generated binstubs**: Executables for common tools (docquet, irb, rake, rspec, rubocop, yard)
- **Mise integration**: Development environment uses minimum supported Ruby version from `.ruby_versions.json`

### CI/CD
- **Dynamic test matrix**: CI automatically tests against all maintained Ruby versions from `.ruby_versions.json`
- **Daily Ruby version updates**: GitHub Actions workflow keeps `.ruby_versions.json` current

### Automatic Configuration
- **Author information**: Extracted from git config (user.name, user.email)
- **Dependency versions**: Latest compatible versions detected from remote (zeitwerk, etc.)
- **Required Ruby version**: Set to oldest maintained version from `.ruby_versions.json`

## Development

After initialization:

- Run `bin/setup` to install dependencies
- Run `rake spec` to run tests
- Run `bin/console` for an interactive prompt

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

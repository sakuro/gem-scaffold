# gem-scaffold

A template repository for creating Ruby gems with automated Ruby version management.

## Usage

1. Clone this repository with your gem name:
   ```bash
   git clone https://github.com/sakuro/gem-scaffold.git my-gem-name
   cd my-gem-name
   ```

2. Run the initialization script:
   ```bash
   ./scripts/initialize.zsh
   ```

   This script will:
   - Update all files with your gem name
   - Generate proper Ruby module namespacing
   - Set up repository-specific cron schedule
   - Create initial `.ruby_versions.json`
   - Remove setup scripts and amend changes into initial commit

3. Push to your new repository:
   ```bash
   git remote set-url origin https://github.com/YOUR_USERNAME/my-gem-name.git
   git push -f origin main
   ```

## Features

- **Automated Ruby version management**: Daily GitHub Actions workflow updates `.ruby_versions.json` with maintained Ruby versions from [endoflife.date](https://endoflife.date/ruby)
- **Dynamic CI matrix**: CI workflow automatically uses Ruby versions from `.ruby_versions.json`
- **Mise integration**: Development environment uses minimum supported Ruby version
- **Repository-specific scheduling**: Each repository gets unique cron schedule to avoid API rate limits

## Development

After initialization:

- Run `bin/setup` to install dependencies
- Run `rake spec` to run tests
- Run `bin/console` for an interactive prompt

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

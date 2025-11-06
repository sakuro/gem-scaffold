#!/usr/bin/env zsh

set -euo pipefail

# Change to project root directory
cd "$(dirname "$0")/.."

source scripts/functions.zsh

# Update Ruby Versions workflow schedule
cron_schedule=$(cron-schedule)
inplace .github/workflows/update-ruby-versions.yml sed \
  -e "s|# Run at .* UTC every day.*|# Run at repository-specific time every day to distribute API load|" \
  -e "s|cron: '[^']*'|cron: $cron_schedule|"

# Generate .ruby_versions.json
scripts/update-ruby-versions.zsh > .ruby_versions.json

# Trust mise configuration to use correct Ruby version
mise trust

# Replace gem names based on current repository name
repo_name=$(basename "$PWD")
path_name=$(echo "$repo_name" | tr '-' '/')
underscore_name=$(echo "$repo_name" | tr '-' '_')

# Generate module nesting for Ruby files
# Example: "my-awesome-gem" -> ["My", "Awesome", "Gem"]
# Example: "my-foo_bar-gem" -> ["My", "FooBar", "Gem"]
IFS='-' read -rA parts <<< "$repo_name"
module_names=()
for part in "${parts[@]}"; do
  # Convert foo_bar to FooBar (capitalize after _ and remove _)
  module_names+=($(echo "$part" | sed -E 's/(^|_)(.)/\U\2/g'))
done

# Generate class name with :: separator from module_names
class_name="${(j.::.)module_names}"

# Get minimum Ruby version from .ruby_versions.json
min_ruby_version=$(jq -r '.ruby[0]' .ruby_versions.json)

# Get author information from git config
author_name=$(git config user.name)
author_email=$(git config user.email)
current_year=$(date +%Y)

# Get repository URL from GitHub
repo_url=$(gh repo view --json url -q .url)

# Replace content in files (README.md is excluded as it contains template instructions)
# Note: lib/sig files are excluded as they will be completely rewritten later
files_to_update=(
  bin/console
  gem-scaffold.gemspec
  spec/spec_helper.rb
)

for file in "${files_to_update[@]}"; do
  [[ -f "$file" ]] || continue
  inplace "$file" sed \
    -e "s/gem-scaffold/$repo_name/g" \
    -e "s/Gem::Scaffold/$class_name/g" \
    -e "s|gem/scaffold|$path_name|g"
done

# Restore executable bit on bin/console (lost during sed inplace edit)
chmod +x bin/console

# Rename gemspec file
git mv gem-scaffold.gemspec "${repo_name}.gemspec"

# Update required_ruby_version in gemspec
inplace "${repo_name}.gemspec" sed \
  -e "s/required_ruby_version = \">= [0-9.]*\"/required_ruby_version = \">= $min_ruby_version\"/"

# Update author information and URLs in gemspec
inplace "${repo_name}.gemspec" sed \
  -e "s/spec.authors = \\[\"[^\"]*\"\\]/spec.authors = [\"$author_name\"]/" \
  -e "s/spec.email = \\[\"[^\"]*\"\\]/spec.email = [\"$author_email\"]/" \
  -e "s|spec.homepage = \"[^\"]*\"|spec.homepage = \"$repo_url\"|"

# Update LICENSE.txt with current year and author
inplace LICENSE.txt sed \
  -e "s/Copyright (c) [0-9]\\{4\\} .*/Copyright (c) $current_year $author_name/"

# Get latest zeitwerk version and update gemspec
zeitwerk_version=$(mise exec -- gem search --remote --exact zeitwerk | grep "^zeitwerk" | sed -E 's/^zeitwerk \(([0-9]+\.[0-9]+)\..*/\1/')
inplace "${repo_name}.gemspec" sed \
  -e "s/\"zeitwerk\", \"~> [0-9.]*\"/\"zeitwerk\", \"~> $zeitwerk_version\"/"

# Remove scaffold files (will be completely rewritten later)
git rm -f lib/gem/scaffold.rb lib/gem/scaffold/version.rb sig/gem/scaffold.rbs
[[ -d lib/gem/scaffold ]] && rmdir lib/gem/scaffold
[[ -d lib/gem ]] && rmdir lib/gem
[[ -d sig/gem ]] && rmdir sig/gem

# Create destination directories for new files
mkdir -p "lib/$(dirname "$path_name")"
mkdir -p "lib/${path_name}"
mkdir -p "sig/$(dirname "$path_name")"

# Rewrite main lib file with proper module nesting and zeitwerk loader
content=$(cat <<EOF
class Error < StandardError; end

loader = Zeitwerk::Loader.for_gem
loader.ignore("\#{__dir__}/${path_name:t}/version.rb")
# loader.inflector.inflect(
#   "html" => "HTML",
#   "ssl" => "SSL"
# )
loader.setup
EOF
)
content=$(wrap-modules "$content" module_names)

cat > "lib/${path_name}.rb" <<EOF
# frozen_string_literal: true

require "zeitwerk"
require_relative "${path_name:t}/version"

$content
EOF

# Rewrite version.rb with proper module nesting
content=$(cat <<'EOF'
VERSION = "0.1.0"
public_constant :VERSION
EOF
)
content=$(wrap-modules "$content" module_names)

cat > "lib/${path_name}/version.rb" <<EOF
# frozen_string_literal: true

$content
EOF

# Rewrite rbs file with proper module nesting
content=$(cat <<EOF
VERSION: String

class Error < StandardError
end
EOF
)
content=$(wrap-modules "$content" module_names)

echo "$content" > "sig/${path_name}.rbs"

# Rewrite README.md with simple gem documentation
cat > README.md <<EOF
# ${class_name}

TODO: Add a brief description of what this gem does.

## Installation

Add this line to your application's Gemfile:

\`\`\`ruby
gem '${repo_name}'
\`\`\`

And then execute:

\`\`\`bash
bundle install
\`\`\`

Or install it yourself as:

\`\`\`bash
gem install ${repo_name}
\`\`\`

## Usage

\`\`\`ruby
require '${path_name}'

# TODO: Add usage examples
\`\`\`

## Development

After checking out the repo, run \`bin/setup\` to install dependencies. Then, run \`rake spec\` to run the tests. You can also run \`bin/console\` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at ${repo_url}.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
EOF

# Remove this script and other temporary setup scripts (except update-ruby-versions.zsh)
scripts_to_remove=(scripts/*.zsh)
scripts_to_remove=(${scripts_to_remove:#scripts/update-ruby-versions.zsh})
git rm -f "${scripts_to_remove[@]}"

# Generate binstubs for common gems (using mise to ensure correct Ruby version)
mise exec -- bundle install --quiet
mise exec -- bundle binstubs docquet irb rake rspec-core rubocop yard --force 2>/dev/null || true

# Install RuboCop configuration via docquet
mise exec -- bundle exec docquet install-config --force

# Amend the initial commit with all changes
git add .
git commit --amend -m ":new: Initial commit"

# Configure GitHub repository settings via API
echo ""
echo "Configuring GitHub repository settings..."

# Set workflow permissions to read/write and allow PR creation
if gh api --method PUT repos/:owner/:repo/actions/permissions/workflow \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true 2>/dev/null; then
  echo "✓ Workflow permissions set to 'Read and write'"
  echo "✓ GitHub Actions allowed to create and approve pull requests"
else
  echo "⚠ Could not configure workflow permissions (may need to be set manually)"
fi

# Create release environment
if gh api --method PUT repos/:owner/:repo/environments/release 2>/dev/null; then
  echo "✓ Created 'release' environment"
else
  echo "⚠ Could not create 'release' environment (may need to be created manually)"
fi

# Print completion message
echo ""
echo "=========================================="
echo "✓ Gem initialization complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Configure RubyGems Trusted Publishing at:"
echo "     https://rubygems.org/oidc/pending_trusted_publishers"
echo ""
echo "  2. Review the release preparation checklist:"
echo "     See .github/workflows/release-preparation.yml for details"
echo ""
echo "  3. Push your changes:"
echo "     git push -f origin main"
echo ""

#!/usr/bin/env zsh

set -euo pipefail

# Change to project root directory
cd "$(dirname "$0")/.."

source scripts/functions.zsh

# Update Ruby Versions workflow schedule
cron_schedule=$(cron-schedule)
inplace .github/workflows/update-ruby-versions.yml sed "s|cron: '[^']*'|cron: $cron_schedule|"

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

# Remove scaffold files (will be completely rewritten later)
git rm -f lib/gem/scaffold.rb lib/gem/scaffold/version.rb sig/gem/scaffold.rbs
[[ -d lib/gem/scaffold ]] && rmdir lib/gem/scaffold
[[ -d lib/gem ]] && rmdir lib/gem
[[ -d sig/gem ]] && rmdir sig/gem

# Create destination directories for new files
mkdir -p "lib/$(dirname "$path_name")"
mkdir -p "lib/${path_name}"
mkdir -p "sig/$(dirname "$path_name")"

# Rewrite main lib file with proper module nesting
content=$(cat <<EOF
class Error < StandardError; end
# Your code goes here...
EOF
)
content=$(wrap-modules "$content" module_names)

cat > "lib/${path_name}.rb" <<EOF
# frozen_string_literal: true

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

# Remove scaffold spec file
git rm -f spec/gem/scaffold_spec.rb
[[ -d spec/gem ]] && rmdir spec/gem

# Remove this script and other temporary setup scripts (except update-ruby-versions.zsh)
scripts_to_remove=(scripts/*.zsh)
scripts_to_remove=(${scripts_to_remove:#scripts/update-ruby-versions.zsh})
git rm -f "${scripts_to_remove[@]}"

# Generate binstubs for common gems (using mise to ensure correct Ruby version)
mise exec -- bundle install --quiet
mise exec -- bundle binstubs docquet irb rake rspec-core rubocop yard --force 2>/dev/null || true

# Install RuboCop configuration via docquet
mise exec -- bundle exec docquet install-config

# Amend the initial commit with all changes
git add .
git commit --amend -m ":new: Initial commit"

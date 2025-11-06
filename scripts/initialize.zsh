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

# Replace content in files
files_to_update=(
  README.md
  bin/console
  gem-scaffold.gemspec
  lib/gem/scaffold.rb
  lib/gem/scaffold/version.rb
  sig/gem/scaffold.rbs
  spec/spec_helper.rb
)

for file in "${files_to_update[@]}"; do
  [[ -f "$file" ]] || continue
  inplace "$file" sed \
    -e "s/gem-scaffold/$repo_name/g" \
    -e "s/Gem::Scaffold/$class_name/g" \
    -e "s|gem/scaffold|$path_name|g"
done

# Rename gemspec file
git mv gem-scaffold.gemspec "${repo_name}.gemspec"

# Move lib files
# Create destination directories first
mkdir -p "lib/$(dirname "$path_name")"
mkdir -p "lib/${path_name}"
git mv lib/gem/scaffold.rb "lib/${path_name}.rb"
git mv lib/gem/scaffold/version.rb "lib/${path_name}/version.rb"

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
content='VERSION = "0.1.0"'
content=$(wrap-modules "$content" module_names)

cat > "lib/${path_name}/version.rb" <<EOF
# frozen_string_literal: true

$content
EOF

rmdir lib/gem/scaffold lib/gem

# Move sig files
mkdir -p "sig/$(dirname "$path_name")"
git mv sig/gem/scaffold.rbs "sig/${path_name}.rbs"

# Rewrite rbs file with proper module nesting
content=$(cat <<EOF
VERSION: String

class Error < StandardError
end
EOF
)
content=$(wrap-modules "$content" module_names)

echo "$content" > "sig/${path_name}.rbs"

rmdir sig/gem

# Remove scaffold spec file
git rm -f spec/gem/scaffold_spec.rb
rmdir spec/gem 2>/dev/null || true

# Remove this script and other temporary setup scripts (except update-ruby-versions.zsh)
scripts_to_remove=(scripts/*.zsh)
scripts_to_remove=(${scripts_to_remove:#scripts/update-ruby-versions.zsh})
git rm -f "${scripts_to_remove[@]}"

# Amend the initial commit with all changes
git add .
git commit --amend -m ":new: Initial commit"

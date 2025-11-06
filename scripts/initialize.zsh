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

# Generate class name with :: separator
class_name=$(echo "$repo_name" | tr '-' '_' | sed -E 's/(^|_)(.)/\U\2/g' | tr '_' ':' | sed 's/:/::/g')

# Generate module nesting for Ruby files
# Example: "my-awesome-gem" -> ["My", "Awesome", "Gem"]
IFS='-' read -rA parts <<< "$repo_name"
module_names=()
for part in "${parts[@]}"; do
  module_names+=($(echo "$part" | sed -E 's/^(.)/\U\1/'))
done

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
git mv lib/gem/scaffold.rb "lib/${path_name}.rb"
mkdir -p "lib/$(dirname "$path_name")/$(basename "$path_name")"
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

require_relative "${path_name}/version"

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
rmdir spec/gem

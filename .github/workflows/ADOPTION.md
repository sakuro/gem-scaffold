# Adopting gem-scaffold Workflows

This guide helps you adopt gem-scaffold's automated workflows into your existing Ruby gem project.

## Three-Phase Adoption

You can adopt workflows incrementally:

1. **Phase 1: Ruby Version Management** - Automated Ruby version testing (low risk, high value)
2. **Phase 2: Automated Releases** - Secure, automated gem publishing (medium risk, high automation)
3. **Phase 3: Development Environment** - Consistent local development setup (optional)

Each phase builds on the previous one, allowing gradual adoption.

---

## Phase 1: Ruby Version Management

**What you get:**
- Dynamic CI test matrix across all maintained Ruby versions
- Automatic updates via pull requests when Ruby versions change
- Zero-maintenance version tracking

### Required Files

1. `.ruby_versions.json` - List of maintained Ruby versions
2. `.github/workflows/ci.yml` - CI workflow with dynamic matrix
3. `.github/workflows/update-ruby-versions.yml` - Auto-update workflow

### Step-by-Step Instructions

#### 1. Generate .ruby_versions.json

```bash
gh api -H "Accept: application/vnd.github.raw" \
  repos/ruby/www.ruby-lang.org/contents/_data/branches.yml | \
  ruby -ryaml -rjson -e 'puts JSON.generate(YAML.safe_load(ARGF.read, permitted_classes: [Date]))' | \
  jq '{ruby: [.[] | select(.status | test("maintenance")) | {name, date}] | sort_by(.date) | map(.name | tostring)]}' \
  > .ruby_versions.json
```

This creates a file like:
```json
{
  "ruby": ["3.2", "3.3", "3.4"]
}
```

#### 2. Copy CI Workflow

```bash
# Copy from gem-scaffold repository
cp /path/to/gem-scaffold/.github/workflows/ci.yml .github/workflows/
```

This workflow runs `bundle exec rake` by default. Ensure your Rakefile defines a default task:

```ruby
task default: %i[spec rubocop]  # Or your preferred tasks
```

#### 3. Copy Auto-Update Workflow

```bash
cp /path/to/gem-scaffold/.github/workflows/update-ruby-versions.yml .github/workflows/
```

**Important**: Customize the cron schedule to avoid API rate limits. Edit line 8:

```yaml
- cron: '23 13 2-8 1,4 *'  # Change to a unique time
```

Generate a unique schedule:
```bash
input="${PWD}:$(date +%s)"
hash=$(echo -n "$input" | openssl sha256 -r | cut -d' ' -f1)
minute=$((0x${hash:0:8} % 59 + 1))
hour=$((0x${hash:8:8} % 23 + 1))
echo "'$minute $hour 2-8 1,4 *'"
```

#### 4. Configure GitHub Repository Settings

Enable workflows to create pull requests:

```bash
gh api --method PUT repos/:owner/:repo/actions/permissions/workflow \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```

#### 5. Update Gemspec (Optional)

Make `required_ruby_version` dynamic:

```ruby
spec.required_ruby_version = ">= #{JSON.parse(File.read('.ruby_versions.json'))['ruby'].first}"
```

### Testing Phase 1

```bash
# Test CI workflow
git checkout -b test-ci
git commit --allow-empty -m "Test CI"
git push origin test-ci
gh pr create --title "Test CI workflow"
gh pr checks  # Verify tests run on all Ruby versions

# Test auto-update workflow
gh workflow run update-ruby-versions.yml
sleep 10
gh pr list  # Check if PR was created
```

### Commit Phase 1

```bash
git add .ruby_versions.json .github/workflows/ci.yml .github/workflows/update-ruby-versions.yml
git commit -m "Add automated Ruby version management"
```

---

## Phase 2: Automated Releases

**What you get:**
- One-command release preparation with version bumps and changelog updates
- Comprehensive validation before publishing
- Secure gem publishing via RubyGems Trusted Publishing (no API keys!)
- Automatic GitHub release creation

### Prerequisites

Before adopting Phase 2, ensure:

1. **Phase 1 is working** (Ruby version management in place)
2. **VERSION constant exists** at `lib/{gem-name-with-slashes}/version.rb`
   - Example: `my-gem` → `lib/my/gem/version.rb`
   - Must define `My::Gem::VERSION = "x.y.z"`
3. **CHANGELOG.md exists** with this format:
   ```markdown
   ## [Unreleased]

   - Changes go here

   ## [1.0.0] - 2024-01-15

   - Previous release
   ```

### Step-by-Step Instructions

#### 1. Copy Release Workflows

```bash
cp /path/to/gem-scaffold/.github/workflows/release-preparation.yml .github/workflows/
cp /path/to/gem-scaffold/.github/workflows/release-validation.yml .github/workflows/
cp /path/to/gem-scaffold/.github/workflows/release-publish.yml .github/workflows/
```

#### 2. Verify Version File Structure

Ensure your version file path matches the convention:

```
Repository name: my-awesome-gem
Expected path:   lib/my/awesome/gem/version.rb
Module:          My::Awesome::Gem::VERSION
```

**If your structure differs**, edit `release-preparation.yml` lines 39-41 to adjust the path transformation.

#### 3. Create Release Environment

```bash
gh api --silent --method PUT repos/:owner/:repo/environments/release
```

#### 4. Configure RubyGems.org

**Account Requirements:**

1. **Verify your email** at https://rubygems.org/profile/edit
2. **Enable MFA** (recommended): https://rubygems.org/profile/edit
   - Trusted Publishing works with MFA at "UI and API" level
   - No API keys needed, so MFA doesn't break automation
   - Guide: https://guides.rubygems.org/setting-up-multifactor-authentication/
3. **Check gem name availability**: https://rubygems.org/gems/your-gem-name
   - Verify the name is available or already owned by you

**Trusted Publishing Setup:**

1. Go to: https://rubygems.org/oidc/pending_trusted_publishers
2. Fill in:
   - **Gem name**: `your-gem-name`
   - **Repository owner**: `your-username` (or org name)
   - **Repository name**: `your-repo-name`
   - **Workflow filename**: `release-publish.yml`
   - **Environment name**: `release`
3. Save as "pending" (it activates after first successful release)
4. Guide: https://guides.rubygems.org/trusted-publishing/releasing-gems/

#### 5. Test Release Workflow

**⚠️ Test with caution:**

```bash
# Trigger release preparation with a test version
gh workflow run release-preparation.yml -f version=0.0.1-test

# Wait for PR creation
sleep 10
gh pr list

# The PR will be created, but validation will fail (expected behavior)
# Version format 'x.y.z-test' violates the x.y.z requirement
# This prevents accidental publishing while testing
# Review the PR structure, then close it without merging
```

### Commit Phase 2

```bash
git add .github/workflows/release-*.yml
git commit -m "Add automated release workflows with Trusted Publishing"
```

### Using the Release Workflow

```bash
# Create a release (generates PR)
gh workflow run release-preparation.yml -f version=1.2.3

# Review and merge the PR
# Gem automatically publishes after PR merge
```

---

## Phase 3: Development Environment (Optional)

**What you get:**
- Consistent Ruby version across all developers
- Automatic switching based on `.ruby_versions.json`

### Step-by-Step Instructions

```bash
# 1. Copy mise.toml
cp /path/to/gem-scaffold/mise.toml .

# 2. Install mise (if needed)
# See: https://mise.jdx.dev/

# 3. Trust the configuration
mise trust

# 4. Verify it works
mise exec -- ruby --version  # Should use .ruby_versions.json[0]
```

### Commit Phase 3

```bash
git add mise.toml
git commit -m "Add mise for development environment management"
```

---

## Customization Points

### Gem Name → Path Mapping

If your gem structure doesn't follow the `gem-name` → `lib/gem/name/version.rb` convention, edit `release-preparation.yml` lines 39-41:

```yaml
GEM_PATH="${{ env.GEM_NAME }}"
GEM_PATH="${GEM_PATH//-//}"  # Customize this transformation
```

### Cron Schedule Uniqueness

Change `.github/workflows/update-ruby-versions.yml` line 8 to a unique time per repository (see Phase 1 for generation command).

### Custom Test Command

If your tests don't run via `bundle exec rake`, edit `.github/workflows/ci.yml` line 40:

```yaml
- name: Run tests
  run: bundle exec rspec  # Or your custom command
```

---

## Common Issues

- **Version file not found**: Verify path matches `lib/{gem-name-with-slashes}/version.rb` convention
- **CHANGELOG.md validation fails**: Must have `## [Unreleased]` section at the top
- **PR creation fails**: Check Settings > Actions > General > Workflow permissions (set to "Read and write")
- **First release fails**: RubyGems Trusted Publisher must be configured as "pending" before first release
- **Cron schedule conflicts**: Use unique time per repository to avoid rate limits

---

## Quick Reference

### Minimum Files for Phase 1
- `.ruby_versions.json`
- `.github/workflows/ci.yml`
- `.github/workflows/update-ruby-versions.yml`

### Minimum Files for Phase 2 (Additional)
- `lib/{path}/version.rb` with `VERSION` constant
- `CHANGELOG.md` with `## [Unreleased]` section
- `.github/workflows/release-preparation.yml`
- `.github/workflows/release-validation.yml`
- `.github/workflows/release-publish.yml`

### GitHub Settings Checklist
- [ ] Workflow permissions: Read and write
- [ ] Allow GitHub Actions to create and approve PRs: Enabled
- [ ] Environment `release` created (Phase 2 only)
- [ ] RubyGems Trusted Publisher configured (Phase 2 only)

### Key Commands

```bash
# Generate .ruby_versions.json
gh api -H "Accept: application/vnd.github.raw" repos/ruby/www.ruby-lang.org/contents/_data/branches.yml | ruby -ryaml -rjson -e 'puts JSON.generate(YAML.safe_load(ARGF.read, permitted_classes: [Date]))' | jq '{ruby: [.[] | select(.status | test("maintenance")) | {name, date}] | sort_by(.date) | map(.name | tostring)]}' > .ruby_versions.json

# Configure GitHub workflow permissions
gh api --method PUT repos/:owner/:repo/actions/permissions/workflow -f default_workflow_permissions=write -F can_approve_pull_request_reviews=true

# Create release environment
gh api --silent --method PUT repos/:owner/:repo/environments/release

# Trigger release
gh workflow run release-preparation.yml -f version=1.2.3
```

---

## Support

For detailed workflow documentation, see [README.md](./README.md) in this directory.

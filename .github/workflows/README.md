# Ruby Gem Release Workflows

GitHub Actions workflows for automating Ruby gem releases using RubyGems Trusted Publishing (OIDC authentication).

## Overview

These workflows provide a complete CI/CD pipeline for Ruby gems:

1. **CI Workflow** - Continuous integration testing
2. **Release Preparation** - Automated release branch and PR creation
3. **Release Validation** - Pre-merge release checks
4. **Release Publishing** - Automated gem publishing to RubyGems.org
5. **Update Ruby Versions** - Automated Ruby version maintenance

## Workflows

### 1. CI Workflow (`ci.yml`)

Runs tests and quality checks across multiple Ruby versions.

**Triggers:**
- Push to `main` branch
- Pull requests

**Matrix Testing:**
- Tests against Ruby versions defined in `.ruby_versions.json`
- Automatically uses all maintained Ruby versions
- See [Ruby Maintenance Branches](https://www.ruby-lang.org/en/downloads/branches/) for current supported versions

**Steps:**
- Reads Ruby versions from `.ruby_versions.json`
- Checks out code
- Sets up Ruby with bundler cache
- Runs `bundle exec rake` (default task)

### 2. Release Preparation Workflow (`release-preparation.yml`)

Creates a release branch with updated version files and opens a pull request.

**Trigger:**
- Manual dispatch with version input (e.g., `1.0.0`)

**Actions:**
- Creates release branch `release-v{version}`
- Updates `lib/{gem_name}/version.rb` with new version
- Updates `CHANGELOG.md`:
  - Converts `[Unreleased]` to versioned section with date
  - Adds new `[Unreleased]` section for future changes
- Creates git tag `v{version}`
- Pushes branch and tag to remote
- Creates pull request with detailed checklist

**Requirements:**
- Repository permissions: `contents: write`, `pull-requests: write`

### 3. Release Validation Workflow (`release-validation.yml`)

Validates release PRs to ensure everything is correct before merging.

**Trigger:**
- Pull requests to `main` branch (only for `release-v*` branches)

**Ruby Version:**
- Uses the minimum supported Ruby version from `.ruby_versions.json`

**Validations:**
- Version format (must be `x.y.z`)
- Version consistency between branch name and `version.rb`
- Git tag existence check
- RubyGems version availability check
- CHANGELOG.md format validation

**Special Features:**
- Automatically updates git tag to latest commit when PR is updated
- Ensures tagged commit is always the one that will be published

**Requirements:**
- Repository permissions: `contents: write`

### 4. Release Publishing Workflow (`release-publish.yml`)

Publishes the gem to RubyGems.org and creates a GitHub release when a release PR is merged.

**Trigger:**
- Pull request closure (only when merged and from `release-v*` branches)

**Ruby Version:**
- Uses the minimum supported Ruby version from `.ruby_versions.json`

**Actions:**
- Extracts version from branch name
- Checks out the release tag
- Builds gem with `bundle exec rake build`
- Configures RubyGems credentials using Trusted Publishing
- Pushes gem to RubyGems.org
- Extracts version-specific changelog
- Creates GitHub release with changelog and gem file

**Requirements:**
- Repository permissions: `contents: write`, `id-token: write`
- Environment: `release` (configured in GitHub repository settings)
- RubyGems Trusted Publishing configured

### 5. Update Ruby Versions Workflow (`update-ruby-versions.yml`)

Automatically maintains `.ruby_versions.json` with the latest maintained Ruby versions.

**Triggers:**
- Scheduled: Daily at a repository-specific time (set during initialization)
- Manual dispatch

**Actions:**
- Fetches maintained Ruby versions from [endoflife.date API](https://endoflife.date/ruby)
- Updates `.ruby_versions.json` with all maintained versions (excluding EOL versions)
- Creates a pull request if changes are detected

**Configuration:**
- Schedule is automatically set to a unique time per repository during initialization
- Automatically excludes EOL (End of Life) Ruby versions

**Requirements:**
- Repository permissions: `contents: write`, `pull-requests: write`

## Initial Setup

### Automated Configuration

The initialization script automatically configures:

**Repository Settings** (`https://github.com/{owner}/{repo}/settings/actions`):
- **Workflow permissions**: Set to "Read and write permissions"
- **Pull request permissions**: Enable "Allow GitHub Actions to create and approve pull requests"

**GitHub Environment** (`https://github.com/{owner}/{repo}/settings/environments`):
- Creates `release` environment for deployment protection

### RubyGems Trusted Publishing

Configure OIDC authentication for secure, token-less gem publishing:

1. Go to https://rubygems.org/oidc/pending_trusted_publishers
2. Create a new pending trusted publisher with:
   - **Gem name**: `{your_gem_name}`
   - **Repository owner**: `{github_username}`
   - **Repository name**: `{repository_name}`
   - **Workflow filename**: `release-publish.yml`
   - **Environment name**: `release`

3. The pending publisher will automatically convert to an active publisher after the first successful gem push.

**Note:** Trusted Publishing works seamlessly with MFA enabled on RubyGems.org. You can safely use "UI and API" MFA level without breaking CI/CD.

Reference: https://guides.rubygems.org/trusted-publishing/releasing-gems/

## Project Structure

Ensure your project has the following structure:

```
your-gem/
├── .ruby_versions.json       # Maintained Ruby versions (auto-updated)
├── lib/
│   └── {gem_name}/
│       └── version.rb        # Contains VERSION constant
├── CHANGELOG.md              # Keep a Changelog format
├── Rakefile                  # With build task
└── .github/
    └── workflows/
        ├── ci.yml
        ├── release-preparation.yml
        ├── release-validation.yml
        ├── release-publish.yml
        └── update-ruby-versions.yml
```

**version.rb** should contain:
```ruby
module YourGem
  VERSION = "0.1.0"
end
```

**CHANGELOG.md** should follow [Keep a Changelog](https://keepachangelog.com/) format:
```markdown
## [Unreleased]

### Added
- New feature descriptions

## [0.1.0] - 2024-01-15
- Initial release
```

## Release Procedure

### Step 1: Prepare for Release

1. Ensure all changes are merged to `main` branch
2. Update `CHANGELOG.md` with changes in the `[Unreleased]` section
3. Commit and push changes to `main`

### Step 2: Trigger Release Preparation

**Option A: Using GitHub UI**

1. Go to Actions tab in your repository
2. Select "Release Preparation" workflow
3. Click "Run workflow"
4. Enter the version number (e.g., `1.0.0`)
5. Click "Run workflow"

**Option B: Using GitHub CLI**

```bash
gh workflow run release-preparation.yml -f version=1.0.0
```

The workflow will:
- Create a release branch
- Update version files
- Create a git tag
- Open a pull request

### Step 3: Review the Release PR

**Finding the Pull Request:**

```bash
# Find PR for the release branch
gh pr list --head release-v1.0.0

# Or view it directly in the browser
gh pr view --web --head release-v1.0.0
```

1. Review the automatically created pull request
2. Check the "Files changed" tab to verify:
   - `version.rb` has the correct version
   - `CHANGELOG.md` has the correct date and format
3. CI and validation workflows will run automatically
4. Review the checklist in the PR description

**Important:** If you push new commits to the release branch, the validation workflow will automatically update the git tag to point to the latest commit.

### Step 4: Merge and Publish

**Finding and Merging the Release PR:**

```bash
# Check PR status and CI results
gh pr view release-v1.0.0

# Check if all checks have passed
gh pr checks release-v1.0.0

# Get PR number and branch name for merge commit message
PR_NUMBER=$(gh pr view release-v1.0.0 --json number -q .number)
BRANCH_NAME=$(gh pr view release-v1.0.0 --json headRepositoryOwner,headRefName -q '.headRepositoryOwner.login + "/" + .headRefName')

# Merge the PR with proper commit message
gh pr merge release-v1.0.0 --merge --subject ":inbox_tray: Merge pull request #$PR_NUMBER from $BRANCH_NAME"

# Or use other merge strategies (if project conventions require):
# gh pr merge release-v1.0.0 --squash   # Squash and merge
# gh pr merge release-v1.0.0 --rebase   # Rebase and merge
```

**Option: Using GitHub UI**

1. Once all checks pass and requirements are met, merge the PR from the GitHub web interface

**After Merging:**

The Release Publishing workflow will automatically:
- Build the gem from the tagged commit
- Publish to RubyGems.org using Trusted Publishing
- Create a GitHub release with changelog and gem file

### Step 5: Verify Publication

1. Check RubyGems.org: `https://rubygems.org/gems/{gem_name}`
2. Check GitHub releases: `https://github.com/{owner}/{repo}/releases`
3. Verify the published version: `gem list {gem_name} --remote`

## Troubleshooting

### Release Preparation Fails

**Problem:** "Version already exists on RubyGems"
- **Solution:** The version has already been published. Use a higher version number.

**Problem:** "Git tag already exists"
- **Solution:** The tag was created outside the release process. Delete it or use a different version.

### Release Validation Fails

**Problem:** "Version mismatch"
- **Solution:** Ensure the version in `version.rb` matches the version in the branch name.

**Problem:** "CHANGELOG.md missing section"
- **Solution:** Ensure CHANGELOG.md has a section for the release version.

### Release Publishing Fails

**Problem:** "Trusted Publishing authentication failed"
- **Solution:** Verify the pending trusted publisher configuration on RubyGems.org matches your repository settings.

**Problem:** "Missing permissions"
- **Solution:** Check that repository workflow permissions are set to "Read and write permissions".

**Problem:** "Environment not found"
- **Solution:** Create the `release` environment in repository settings.

## Security Considerations

- **No API tokens required**: Trusted Publishing uses OIDC, eliminating the need for long-lived API tokens
- **MFA compatible**: Works seamlessly with RubyGems MFA requirements
- **Principle of least privilege**: Workflows only request necessary permissions
- **Tag immutability**: Once a release is published, the git tag represents the exact code that was published

## Maintenance

### Ruby Version Management

Ruby versions are automatically managed through `.ruby_versions.json`, which is maintained by the `update-ruby-versions.yml` workflow.

**Automatic Updates:**
- The workflow runs daily and fetches the latest maintained Ruby versions from [endoflife.date API](https://endoflife.date/ruby)
- Automatically updates `.ruby_versions.json` with all maintained versions (typically 3-4 versions)
- Creates a pull request when changes are detected
- All workflows (CI, release validation, and release publishing) automatically use the updated versions

**Manual Updates:**
You can manually trigger the update workflow:

```bash
# Using GitHub CLI
gh workflow run update-ruby-versions.yml

# Or generate .ruby_versions.json locally
curl -s https://endoflife.date/api/v1/products/ruby | \
  jq '{ruby: [.result.releases | sort_by(.releaseDate) | reverse | .[] | select(.isEol == false) | .name] | reverse}' \
  > .ruby_versions.json
```

**`.ruby_versions.json` Format:**
```json
{
  "ruby": ["3.2", "3.3", "3.4"]
}
```

**Note:** When a new Ruby version is released (e.g., Ruby 3.5 in December 2024), the array will temporarily contain 4 versions until the oldest version reaches EOL.

**How Workflows Use Ruby Versions:**
- **CI Workflow**: Tests against all versions in the `ruby` array (oldest to newest)
- **Release Validation**: Uses the first (oldest) version as the minimum supported version
- **Release Publishing**: Uses the first (oldest) version to build and publish the gem

**Update Schedule:**
The cron schedule in `update-ruby-versions.yml` is automatically set to a repository-specific time during initialization to distribute API load and avoid simultaneous requests from multiple repositories.

**Important:** When the minimum Ruby version changes (e.g., when Ruby 3.2 reaches EOL), the workflows will automatically use the new minimum version. Ensure your gem's code is compatible with the updated Ruby versions.

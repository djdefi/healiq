# GitHub Actions Workflows

This repository uses GitHub Actions for automated testing and releases.

## Test Workflow (`.github/workflows/test.yml`)

**Triggers:** Pull requests and pushes to main branch

**What it does:**
- Installs Lua 5.4 and luacheck
- Validates Lua syntax using `luac -p` on all .lua files
- Runs luacheck linting with World of Warcraft addon-specific settings
- Validates addon structure:
  - Checks that all required files exist (Core.lua, Engine.lua, UI.lua, Tracker.lua, Config.lua)
  - Validates HealIQ.toc file format and required fields
  - Ensures all files listed in .toc actually exist
- Verifies version consistency between HealIQ.toc and Core.lua

## Release Workflow (`.github/workflows/release.yml`)

**Triggers:** 
- Pushes to main branch (automatically publishes to CurseForge)
- Manual workflow dispatch (with optional CurseForge publishing)

**What it does:**
- Extracts version from HealIQ.toc file
- Checks if a git tag for this version already exists
- If tag doesn't exist:
  - Creates a new git tag (v{version})
  - Packages all addon files into a downloadable .zip file
  - Creates a GitHub release with:
    - Version-specific changelog from CHANGELOG.md
    - Installation instructions
    - Downloadable addon package
  - Conditionally uploads to CurseForge based on trigger type and configuration

### CurseForge Integration

The release workflow includes optional CurseForge publishing:

- **Automatic**: When triggered by a push to main branch, always publishes to CurseForge (if configured)
- **Manual**: When triggered by workflow dispatch, only publishes if "Publish to CurseForge" option is checked

**Required GitHub Secrets:**
- `CURSEFORGE_TOKEN`: API token from CurseForge
- `CURSEFORGE_PROJECT_ID`: Your CurseForge project ID

**Game versions are automatically detected** from the addon's `.toc` file interface version.

If these secrets are not configured, the workflow will skip CurseForge upload but still create GitHub releases.

## Luacheck Settings

The workflows use luacheck with WoW-specific settings:
- `--globals _G` - Allow access to global table
- `--std none` - No standard library assumptions
- Various ignore codes for common WoW addon patterns

## Bump TOC Workflow (`.github/workflows/bump-toc.yml`)

**Triggers:** Manual workflow dispatch

**What it does:**
- Provides a manual way to bump the addon version consistently
- Supports semantic versioning (major, minor, patch) or custom versions
- Updates version in both HealIQ.toc and Core.lua automatically
- Optionally creates a changelog entry template
- Commits and pushes changes to the current branch
- Optionally triggers the release workflow with configurable CurseForge publishing

**Usage:**
1. Go to the "Actions" tab in GitHub
2. Select "Bump TOC Version" workflow
3. Click "Run workflow"
4. Choose version bump type (patch, minor, major, or custom)
5. Optionally provide a custom version or disable changelog creation
6. Choose whether to create a release after version bump
7. If creating a release, choose whether to publish to CurseForge (defaults to false for beta testing)
8. The workflow will update files and commit changes

## Version Management

The release workflow automatically detects the version from the `## Version:` field in HealIQ.toc and ensures it matches the version in Core.lua. To create a new release:

**Beta Testing (recommended for development):**
1. Use the "Bump TOC Version" workflow dispatch to update version
2. Enable "Create release after version bump"
3. Leave "Publish release to CurseForge" unchecked (default)
4. This creates a GitHub release for testing without publishing to CurseForge

**Stable Release (automated):**
1. Use the "Bump TOC Version" workflow dispatch to update version
2. Edit the changelog entry created by the workflow
3. Merge to main branch
4. The release workflow will automatically create the tag and release AND publish to CurseForge

**Stable Release (manual):**
1. Update the version in both HealIQ.toc and Core.lua
2. Update CHANGELOG.md with the new version section
3. Merge to main branch
4. The release workflow will automatically create the tag and release AND publish to CurseForge

**Manual Release with CurseForge Control:**
1. Go to "Actions" tab and select "Release" workflow
2. Click "Run workflow"
3. Choose whether to publish to CurseForge
4. This allows manual control over CurseForge publishing for any branch
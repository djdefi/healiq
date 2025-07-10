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

**Triggers:** Pushes to main branch

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

## Luacheck Settings

The workflows use luacheck with WoW-specific settings:
- `--globals _G` - Allow access to global table
- `--std none` - No standard library assumptions
- Various ignore codes for common WoW addon patterns

## Version Management

The release workflow automatically detects the version from the `## Version:` field in HealIQ.toc and ensures it matches the version in Core.lua. To create a new release:

1. Update the version in both HealIQ.toc and Core.lua
2. Update CHANGELOG.md with the new version section
3. Merge to main branch
4. The release workflow will automatically create the tag and release
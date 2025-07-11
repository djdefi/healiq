# CurseForge Automatic Publishing Setup

This guide explains how to set up automatic publishing to CurseForge for the HealIQ addon.

## Overview

The repository is configured for automatic CurseForge publishing when new releases are created. This integration allows addon updates to be automatically published to CurseForge whenever a new version is released on GitHub.

## Required Setup

### 1. CurseForge API Token

1. Log into [CurseForge Console](https://console.curseforge.com/)
2. Navigate to your project
3. Go to "API Keys" section
4. Generate a new API key with upload permissions
5. Add this as a GitHub repository secret named `CURSEFORGE_TOKEN`

### 2. Project ID

1. In your CurseForge project, note the project ID from the URL or project settings
2. Add this as a GitHub repository secret named `CURSEFORGE_PROJECT_ID`

### 3. Game Versions

1. Determine which WoW versions your addon supports (e.g., "1.15.0,10.2.5,11.0.7")
2. Add this as a GitHub repository secret named `CURSEFORGE_GAME_VERSIONS`

### 4. GitHub Repository Secrets

In your GitHub repository, go to Settings > Secrets and Variables > Actions, and add:

- `CURSEFORGE_TOKEN`: Your CurseForge API token
- `CURSEFORGE_PROJECT_ID`: Your CurseForge project ID  
- `CURSEFORGE_GAME_VERSIONS`: Comma-separated list of supported WoW versions

## How It Works

### Automatic Publishing

When you create a new release (either manually or via the automated release workflow):

1. The GitHub Actions workflow builds the addon package
2. Creates a GitHub release with the packaged addon
3. Automatically uploads the same package to CurseForge
4. Uses the changelog from CHANGELOG.md as the CurseForge release notes

### Package Configuration

The `.pkgmeta` file defines how the addon is packaged:

- Includes all necessary Lua files and the .toc file
- Includes documentation (README, LICENSE, CHANGELOG, INSTALL)
- Excludes development files (.git, .github, backups, etc.)
- Uses the CHANGELOG.md for release notes

### Supported Workflow

1. **Development**: Make changes to addon files
2. **Version Bump**: Use the "Bump TOC Version" workflow or manually update versions
3. **Release**: Push to main branch or manually trigger release workflow
4. **Automatic Publishing**: 
   - GitHub release is created
   - CurseForge upload happens automatically
   - Both platforms have the same version and changelog

## Troubleshooting

### CurseForge Upload Fails

1. Check that all required secrets are set correctly
2. Verify the CurseForge API token has upload permissions
3. Ensure the project ID is correct
4. Check that the game versions are in the correct format

### Missing Uploads

If GitHub releases are created but CurseForge uploads don't happen:

1. Check the Actions logs for error messages
2. Verify the secrets are accessible to the workflow
3. Ensure the CurseForge project allows API uploads

### Version Conflicts

If CurseForge rejects uploads due to existing versions:

1. Ensure version numbers in HealIQ.toc are unique
2. Check if the version already exists on CurseForge
3. Use the version bump workflow to ensure proper versioning

## Manual Override

If you need to disable CurseForge uploads temporarily:

1. Remove or rename the CURSEFORGE_TOKEN secret
2. The workflow will skip CurseForge upload but still create GitHub releases

## Security Notes

- API tokens should never be committed to the repository
- Use GitHub repository secrets for all sensitive configuration
- The workflow only uploads when secrets are properly configured
- CurseForge uploads are conditional and won't break GitHub releases if they fail

## Files Involved

- `.pkgmeta`: CurseForge packaging configuration
- `.github/workflows/release.yml`: Release workflow with CurseForge integration
- `CHANGELOG.md`: Used for both GitHub and CurseForge release notes
- `HealIQ.toc`: Version information source
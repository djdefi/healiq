# Changelog Automation

This repository uses automated changelog generation to ensure that release notes are always up-to-date and meaningful.

## How It Works

The changelog automation works by:

1. **Analyzing git commits** between releases to extract meaningful changes
2. **Categorizing changes** into Added, Changed, and Fixed sections based on commit message patterns
3. **Skipping empty sections** to prevent cluttered changelogs with placeholder entries
4. **Enhancing with AI-powered WoW flair** to match the World of Warcraft theme of this healing addon
5. **Automatically updating** the CHANGELOG.md file during the release process
6. **Validating** that changelog entries have meaningful content before creating releases

## New Features

### Empty Section Skipping
The changelog generator now skips sections that have no content, eliminating empty "Added", "Changed", or "Fixed" sections with just placeholder dashes.

### WoW Flair Enhancement
Changelog entries are automatically enhanced with World of Warcraft-themed language appropriate for a Restoration Druid healing addon using AI models to generate engaging, thematically consistent descriptions while maintaining technical accuracy.

### AI Enhancement (Required)
The system uses AI via GitHub models to generate rich, creative WoW-themed descriptions that transform technical changelog entries into engaging content suitable for the healing addon's target audience.

## Usage

### Standard Generation (with AI WoW flair)
```bash
./.github/scripts/generate-changelog-enhanced.sh
```

### Basic Generation (without WoW enhancement)
```bash
./.github/scripts/generate-changelog.sh
```

## Commit Message Guidelines

To ensure your changes are properly categorized in the changelog, use these commit message patterns:

### Added Features
- `feat: add new healing suggestions`
- `add: support for new WoW version`
- `feature: implement trinket tracking`

### Bug Fixes
- `fix: resolve UI scaling issues`
- `bugfix: correct spell cooldown detection`
- `resolve: address memory leak`

### Changes/Improvements
- `update: improve spell priority logic`
- `improve: enhance error handling`
- `change: modify default configuration`
- `refactor: restructure code organization`
- `docs: update installation guide`

### Breaking Changes
- `breaking: change API interface`
- `break: remove deprecated functions`

## Automated Process

### During Version Bumps
When using the "Bump TOC Version" workflow:
1. The workflow automatically generates changelog entries from commits since the last version
2. Entries are categorized based on commit message patterns
3. Empty sections are automatically skipped
4. AI-powered WoW flair is applied to make entries thematically appropriate
5. The changelog is updated with meaningful content instead of empty templates

### During Releases
When the release workflow runs:
1. It automatically updates the changelog for the current version
2. Validates that the changelog has meaningful content
3. Commits any changelog updates back to the repository
4. Includes the changelog content in the GitHub release notes

## Manual Override

If the automated changelog generation doesn't capture your changes correctly, you can:

1. **Edit CHANGELOG.md manually** after the version bump but before creating a release
2. **Use more descriptive commit messages** following the patterns above
3. **Add additional details** to the generated changelog entries
4. **Use AI enhancement** to apply WoW flair to manually edited entries

## Files

- `.github/scripts/generate-changelog-enhanced.sh` - **NEW**: Enhanced changelog generation with AI-powered WoW flair
- `.github/scripts/enhance-changelog-with-wow-flair.sh` - **NEW**: AI WoW flair enhancement script
- `.github/scripts/generate-changelog.sh` - **UPDATED**: Main changelog generation script (now skips empty sections)
- `CHANGELOG.md` - The changelog file that gets automatically updated
- `.github/workflows/release.yml` - Release workflow with changelog integration
- `.github/workflows/bump-toc.yml` - Version bump workflow with changelog generation

## Benefits

1. **Consistent Format**: All changelog entries follow the same structure
2. **No Empty Releases**: Prevents releases with empty or meaningless changelog entries
3. **No Empty Sections**: Skips sections that would only contain placeholder dashes
4. **Thematic Consistency**: AI-generated WoW-themed language maintains immersion for addon users
5. **Automatic Generation**: Reduces manual work while maintaining quality
6. **Better Release Notes**: GitHub releases automatically include relevant changelog content
7. **Historical Tracking**: Complete history of changes is maintained automatically
8. **AI-Enhanced Readability**: WoW flair makes changelogs more engaging for the target audience

## Troubleshooting

If the changelog generation fails or produces unexpected results:

1. Check that commit messages follow the recommended patterns
2. Review the generated changelog and edit manually if needed
3. Ensure the script has executable permissions
4. Check the GitHub Actions logs for specific error messages
5. For AI enhancement issues, verify GitHub CLI authentication and models extension installation

The automation is designed to be helpful while still allowing manual intervention when needed.
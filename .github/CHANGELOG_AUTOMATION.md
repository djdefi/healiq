# Changelog Automation

This repository uses automated changelog generation to ensure that release notes are always up-to-date and meaningful.

## How It Works

The changelog automation works by:

1. **Analyzing git commits** between releases to extract meaningful changes
2. **Categorizing changes** into Added, Changed, and Fixed sections based on commit message patterns
3. **Automatically updating** the CHANGELOG.md file during the release process
4. **Validating** that changelog entries have meaningful content before creating releases

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
3. The changelog is updated with meaningful content instead of empty templates

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

## Files

- `.github/scripts/generate-changelog.sh` - The main changelog generation script
- `CHANGELOG.md` - The changelog file that gets automatically updated
- `.github/workflows/release.yml` - Release workflow with changelog integration
- `.github/workflows/bump-toc.yml` - Version bump workflow with changelog generation

## Benefits

1. **Consistent Format**: All changelog entries follow the same structure
2. **No Empty Releases**: Prevents releases with empty or meaningless changelog entries
3. **Automatic Generation**: Reduces manual work while maintaining quality
4. **Better Release Notes**: GitHub releases automatically include relevant changelog content
5. **Historical Tracking**: Complete history of changes is maintained automatically

## Troubleshooting

If the changelog generation fails or produces unexpected results:

1. Check that commit messages follow the recommended patterns
2. Review the generated changelog and edit manually if needed
3. Ensure the script has executable permissions
4. Check the GitHub Actions logs for specific error messages

The automation is designed to be helpful while still allowing manual intervention when needed.
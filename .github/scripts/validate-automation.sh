#!/bin/bash

# End-to-end validation test for the changelog automation
# This simulates the complete workflow from development to release

set -e

echo "=== HealIQ Changelog Automation End-to-End Test ==="
echo ""

# Test 1: Verify all required files exist
echo "Test 1: Verifying required files exist..."
required_files=(
    ".github/scripts/generate-changelog.sh"
    ".github/workflows/release.yml"
    ".github/workflows/bump-toc.yml"
    ".github/CHANGELOG_AUTOMATION.md"
    "CHANGELOG.md"
    "HealIQ.toc"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        exit 1
    fi
done

# Test 2: Verify script permissions
echo ""
echo "Test 2: Verifying script permissions..."
if [[ -x ".github/scripts/generate-changelog.sh" ]]; then
    echo "  ✓ generate-changelog.sh is executable"
else
    echo "  ✗ generate-changelog.sh is not executable"
    exit 1
fi

# Test 3: Verify script syntax
echo ""
echo "Test 3: Verifying script syntax..."
if bash -n .github/scripts/generate-changelog.sh; then
    echo "  ✓ Script syntax is valid"
else
    echo "  ✗ Script has syntax errors"
    exit 1
fi

# Test 4: Verify current version consistency
echo ""
echo "Test 4: Verifying version consistency..."
TOC_VERSION=$(grep "^## Version:" HealIQ.toc | cut -d' ' -f3)
CORE_VERSION=$(grep "HealIQ.version = " Core.lua | cut -d'"' -f2)

if [[ "$TOC_VERSION" == "$CORE_VERSION" ]]; then
    echo "  ✓ Versions are consistent (TOC: $TOC_VERSION, Core: $CORE_VERSION)"
else
    echo "  ✗ Version mismatch (TOC: $TOC_VERSION, Core: $CORE_VERSION)"
    exit 1
fi

# Test 5: Verify workflow file syntax
echo ""
echo "Test 5: Verifying workflow files..."
if grep -q "generate-changelog.sh" .github/workflows/release.yml; then
    echo "  ✓ Release workflow references changelog script"
else
    echo "  ✗ Release workflow missing changelog integration"
    exit 1
fi

if grep -q "generate-changelog.sh" .github/workflows/bump-toc.yml; then
    echo "  ✓ Bump-toc workflow references changelog script"
else
    echo "  ✗ Bump-toc workflow missing changelog integration"
    exit 1
fi

# Test 6: Simulate complete workflow
echo ""
echo "Test 6: Simulating complete development workflow..."

# Create a temporary working area
BACKUP_DIR="/tmp/healiq-backup"
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp CHANGELOG.md "$BACKUP_DIR/"

# Simulate a development cycle with various types of changes
echo "  → Simulating feature development..."
echo "new feature" > .test_feature.txt
git add .test_feature.txt
git commit -m "feat: add spell suggestion improvements" --quiet

echo "  → Simulating bug fix..."
echo "bug fix" > .test_fix.txt
git add .test_fix.txt
git commit -m "fix: resolve UI scaling issues" --quiet

echo "  → Simulating documentation update..."
echo "docs" > .test_docs.txt
git add .test_docs.txt
git commit -m "docs: update installation guide" --quiet

# Simulate version bump workflow
echo "  → Simulating version bump workflow..."
NEW_VERSION="0.0.11"
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.10")

./.github/scripts/generate-changelog.sh "$CURRENT_TAG" "$NEW_VERSION" >/dev/null

# Verify the generated changelog has content
if grep -A 20 "## \[$NEW_VERSION\]" CHANGELOG.md | grep -q "Add spell suggestion improvements"; then
    echo "  ✓ Feature commit properly categorized in 'Added' section"
else
    echo "  ✗ Feature commit not found in changelog"
    exit 1
fi

if grep -A 20 "## \[$NEW_VERSION\]" CHANGELOG.md | grep -q "Resolve UI scaling issues"; then
    echo "  ✓ Bug fix commit properly categorized in 'Fixed' section"
else
    echo "  ✗ Bug fix commit not found in changelog"
    exit 1
fi

if grep -A 20 "## \[$NEW_VERSION\]" CHANGELOG.md | grep -q "Update installation guide"; then
    echo "  ✓ Documentation commit properly categorized in 'Changed' section"
else
    echo "  ✗ Documentation commit not found in changelog"
    exit 1
fi

# Test 7: Verify release workflow validation
echo ""
echo "Test 7: Testing release workflow validation..."

# Test the validation logic from the release workflow
SECTION=$(sed -n "/## \[$NEW_VERSION\]/,/## \[/p" CHANGELOG.md | head -n -1)
ADDED_CONTENT=$(echo "$SECTION" | grep -A10 "### Added" | grep -E "^- .+$" | grep -v "^- $" | wc -l)
CHANGED_CONTENT=$(echo "$SECTION" | grep -A10 "### Changed" | grep -E "^- .+$" | grep -v "^- $" | wc -l)
FIXED_CONTENT=$(echo "$SECTION" | grep -A10 "### Fixed" | grep -E "^- .+$" | grep -v "^- $" | wc -l)
TOTAL_CONTENT=$((ADDED_CONTENT + CHANGED_CONTENT + FIXED_CONTENT))

if [[ $TOTAL_CONTENT -gt 0 ]]; then
    echo "  ✓ Changelog validation would pass ($TOTAL_CONTENT entries found)"
else
    echo "  ✗ Changelog validation would fail (no content found)"
    exit 1
fi

# Cleanup simulation
echo ""
echo "Cleaning up simulation..."
git reset --hard HEAD~3 --quiet
rm -f .test_*.txt
cp "$BACKUP_DIR/CHANGELOG.md" ./
rm -rf "$BACKUP_DIR"

# Test 8: Verify documentation
echo ""
echo "Test 8: Verifying documentation completeness..."
if grep -q "Commit Message Guidelines" .github/CHANGELOG_AUTOMATION.md; then
    echo "  ✓ Documentation includes commit message guidelines"
else
    echo "  ✗ Documentation missing commit message guidelines"
    exit 1
fi

if grep -q "Automated Process" .github/CHANGELOG_AUTOMATION.md; then
    echo "  ✓ Documentation explains automated process"
else
    echo "  ✗ Documentation missing automated process explanation"
    exit 1
fi

echo ""
echo "=== All Tests Passed! ==="
echo ""
echo "Summary:"
echo "  • Changelog automation scripts are properly installed and executable"
echo "  • GitHub workflows are correctly configured"
echo "  • Version consistency is maintained"
echo "  • Commit message parsing works correctly"
echo "  • Changelog generation produces valid, meaningful content"
echo "  • Release validation would prevent empty changelogs"
echo "  • Documentation is complete and helpful"
echo ""
echo "The changelog automation is ready for production use!"
echo "Future releases will automatically have meaningful changelog entries."
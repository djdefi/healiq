#!/bin/bash

# Test script for changelog generation
# This tests the changelog automation without modifying the actual changelog

set -e

echo "Testing changelog generation automation..."

# Create a temporary directory for testing
TEST_DIR="/tmp/changelog-test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Initialize a git repository
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create a mock HealIQ.toc file
cat > HealIQ.toc << 'EOF'
## Interface: 110107
## Title: HealIQ
## Notes: Smart healing spell suggestion addon for Restoration Druids
## Author: djdefi
## Version: 0.0.10
## SavedVariables: HealIQDB
## DefaultState: enabled

# Core files
Core.lua
EOF

# Create a basic changelog
cat > CHANGELOG.md << 'EOF'
# HealIQ Changelog

## [0.0.10] - 2025-07-10

### Added
- Initial version

### Changed
- 

### Fixed
- 

EOF

# Create some test files
echo "test" > Core.lua
echo "test" > test.txt

# Make initial commit
git add .
git commit -m "Initial commit"

# Create a tag for the initial version
git tag v0.0.10

# Make some test commits with different types
echo "feature addition" >> test.txt
git add test.txt
git commit -m "feat: add new feature"

echo "bug fix" >> test.txt
git add test.txt
git commit -m "fix: resolve critical bug"

echo "improvement" >> test.txt
git add test.txt
git commit -m "improve: enhance performance"

echo "documentation" >> test.txt
git add test.txt
git commit -m "docs: update documentation"

# Copy the changelog script to our test directory
cp /home/runner/work/healiq/healiq/.github/scripts/generate-changelog.sh ./

# Make it executable
chmod +x generate-changelog.sh

# Test changelog generation
echo "Generating changelog from v0.0.10 to 0.0.11..."
./generate-changelog.sh v0.0.10 0.0.11

# Verify the generated changelog
echo ""
echo "Generated changelog content:"
echo "=============================="
head -n 20 CHANGELOG.md
echo "=============================="

# Check if the changelog contains expected entries
echo ""
echo "Validation tests:"

# Test 1: Check if new version entry was added
if grep -q "## \[0.0.11\]" CHANGELOG.md; then
    echo "✓ Version 0.0.11 entry was created"
else
    echo "✗ Version 0.0.11 entry was NOT created"
    exit 1
fi

# Test 2: Check if "Added" section has content
if grep -A 5 "### Added" CHANGELOG.md | grep -q "Add new feature"; then
    echo "✓ 'Added' section has content from feat commit"
else
    echo "✗ 'Added' section missing expected content"
    exit 1
fi

# Test 3: Check if "Fixed" section has content
if grep -A 5 "### Fixed" CHANGELOG.md | grep -q "Resolve critical bug"; then
    echo "✓ 'Fixed' section has content from fix commit"
else
    echo "✗ 'Fixed' section missing expected content"
    exit 1
fi

# Test 4: Check if "Changed" section has content
if grep -A 10 "### Changed" CHANGELOG.md | grep -q -E "(enhance performance|update documentation)"; then
    echo "✓ 'Changed' section has content from improvement commits"
else
    echo "✗ 'Changed' section missing expected content"
    exit 1
fi

# Test 5: Test with no commits (should generate empty but valid structure)
echo ""
echo "Testing with no new commits..."
git tag v0.0.11
./generate-changelog.sh v0.0.11 0.0.12

if grep -q "## \[0.0.12\]" CHANGELOG.md; then
    echo "✓ Empty version entry was created correctly"
else
    echo "✗ Empty version entry was NOT created"
    exit 1
fi

echo ""
echo "All tests passed! Changelog automation is working correctly."

# Cleanup
cd /home/runner/work/healiq/healiq
rm -rf "$TEST_DIR"

echo "Test completed successfully!"
#!/bin/bash

# Enhanced changelog generation script with AI-powered WoW flair
# This script extends the original generate-changelog.sh with AI WoW-themed enhancements
# Usage: ./generate-changelog-enhanced.sh [from_version] [to_version]

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments (no AI flag needed since it's always enabled)
ARGS=("$@")

# Function to display usage
usage() {
    echo "Usage: $0 [from_version] [to_version]"
    echo "  from_version: Previous version tag (e.g., v0.0.9)"
    echo "  to_version: Current version (e.g., 0.0.10)"
    echo "  If no arguments provided, will generate from latest tag to current version"
    echo "  Note: Requires GitHub CLI with models extension for AI-powered WoW flair"
    exit 1
}

# Main execution
main() {
    echo "HealIQ Enhanced Changelog Generator"
    echo "=================================="
    echo "Generating changelog with AI-powered WoW flair..."
    echo ""
    
    # Step 1: Run the original changelog generation
    echo "Step 1: Generating base changelog..."
    if ! "$SCRIPT_DIR/generate-changelog.sh" "${ARGS[@]}"; then
        echo "Error: Failed to generate base changelog"
        exit 1
    fi
    
    echo ""
    echo "Step 2: Enhancing with AI-powered WoW flair..."
    
    # Step 2: Enhance with AI WoW flair
    # AI enhancement is optional - don't fail the workflow if it's unavailable
    if "$SCRIPT_DIR/enhance-changelog-with-wow-flair.sh" "CHANGELOG.md"; then
        echo "✨ AI enhancement completed successfully!"
    else
        echo "Warning: AI enhancement failed or unavailable"
        echo "Continuing with basic changelog generation..."
        echo "Note: For AI enhancement, ensure GitHub CLI is installed with models extension:"
        echo "  gh extension install github/gh-models"
        echo "  and GH_TOKEN is properly configured in the environment"
    fi
    
    echo ""
    echo "✨ Enhanced changelog generation completed! ✨"
    echo ""
    echo "The changelog now features:"
    echo "• No empty sections (skipped when no content)"
    echo "• AI-powered WoW-themed language and terminology"
    echo "• Restoration Druid healing addon flair"
    echo "• Rich fantasy language while maintaining technical accuracy"
    echo ""
    echo "Backup of original saved as CHANGELOG.md.backup"
}

# Run with parsed arguments
main
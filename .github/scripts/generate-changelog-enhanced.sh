#!/bin/bash

# Enhanced changelog generation script with WoW flair
# This script extends the original generate-changelog.sh with WoW-themed enhancements
# Usage: ./generate-changelog-enhanced.sh [from_version] [to_version] [--use-ai]

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
USE_AI=false

# Parse arguments for AI flag
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --use-ai)
            USE_AI=true
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Function to display usage
usage() {
    echo "Usage: $0 [from_version] [to_version] [--use-ai]"
    echo "  from_version: Previous version tag (e.g., v0.0.9)"
    echo "  to_version: Current version (e.g., 0.0.10)"
    echo "  --use-ai: Use GitHub models for AI-enhanced WoW flair (requires gh CLI and models extension)"
    echo "  If no arguments provided, will generate from latest tag to current version"
    exit 1
}

# Main execution
main() {
    echo "HealIQ Enhanced Changelog Generator"
    echo "=================================="
    echo "Generating changelog with WoW flair..."
    echo ""
    
    # Step 1: Run the original changelog generation
    echo "Step 1: Generating base changelog..."
    if ! "$SCRIPT_DIR/generate-changelog.sh" "${ARGS[@]}"; then
        echo "Error: Failed to generate base changelog"
        exit 1
    fi
    
    echo ""
    echo "Step 2: Enhancing with WoW flair..."
    
    # Step 2: Enhance with WoW flair
    local enhance_args=("CHANGELOG.md")
    if [[ "$USE_AI" == true ]]; then
        enhance_args+=("--use-ai")
        echo "Using AI enhancement with GitHub models..."
    else
        echo "Using local WoW flair patterns..."
    fi
    
    if ! "$SCRIPT_DIR/enhance-changelog-with-wow-flair.sh" "${enhance_args[@]}"; then
        echo "Warning: Failed to enhance changelog with WoW flair"
        echo "Changelog was generated but not enhanced"
        exit 1
    fi
    
    echo ""
    echo "✨ Enhanced changelog generation completed! ✨"
    echo ""
    echo "The changelog now features:"
    echo "• No empty sections (skipped when no content)"
    echo "• WoW-themed language and terminology"
    echo "• Restoration Druid healing addon flair"
    echo ""
    
    if [[ "$USE_AI" == true ]]; then
        echo "• AI-enhanced descriptions with rich fantasy language"
    else
        echo "• Local pattern-based WoW terminology"
        echo "• Tip: Use --use-ai flag for AI-enhanced descriptions"
    fi
    
    echo ""
    echo "Backup of original saved as CHANGELOG.md.backup"
}

# Run with parsed arguments
main
#!/bin/bash

# Script to enhance changelog entries with World of Warcraft flair using AI
# Usage: ./enhance-changelog-with-wow-flair.sh [changelog_file]

# Don't exit on errors - we want to handle them gracefully
set +e

# Default values
CHANGELOG_FILE="CHANGELOG.md"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        *)
            CHANGELOG_FILE="$1"
            shift
            ;;
    esac
done

# Function to check if GitHub models is available
check_github_models() {
    if ! command -v gh &> /dev/null; then
        echo "GitHub CLI not found"
        return 1
    fi
    
    if ! gh extension list | grep -q "github/gh-models"; then
        echo "GitHub models extension not installed"
        return 1
    fi
    
    # Try to run a simple command to check authentication
    if ! gh models list &> /dev/null; then
        echo "GitHub models not accessible (authentication required)"
        return 1
    fi
    
    return 0
}

# Function to enhance text with AI using GitHub models
enhance_with_ai() {
    local text="$1"
    local category="$2"
    
    local prompt="Transform this technical changelog entry into World of Warcraft-themed language suitable for a Restoration Druid healing addon. Keep the meaning clear but add fantasy flair. Use WoW healing/nature terminology where appropriate:

Category: $category
Entry: $text

Enhanced entry:"

    # Check if GitHub models is available
    if ! check_github_models; then
        echo "Warning: GitHub models not available, keeping original text" >&2
        echo "$text"
        return 1
    fi
    
    echo "Enhancing with AI..." >&2
    local enhanced_text
    enhanced_text=$(gh models chat -m gpt-4o-mini --prompt "$prompt" 2>/dev/null | head -n 1)
    
    if [[ -n "$enhanced_text" && "$enhanced_text" != "$text" ]]; then
        echo "$enhanced_text"
        return 0
    else
        echo "Warning: AI enhancement failed, keeping original text" >&2
        echo "$text"
        return 1
    fi
}

# Function to process changelog file
process_changelog() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: Changelog file '$file' not found"
        return 1
    fi
    
    echo "Enhancing changelog with WoW flair..."
    
    # Create backup
    if ! cp "$file" "${file}.backup"; then
        echo "Warning: Failed to create backup of changelog file"
        return 1
    fi
    
    # Process the file
    local in_version_section=false
    local current_category=""
    local temp_file=$(mktemp)
    
    if [[ ! -f "$temp_file" ]]; then
        echo "Error: Failed to create temporary file"
        return 1
    fi
    
    local enhancement_attempted=false
    local enhancement_succeeded=false
    
    while IFS= read -r line; do
        # Check if we're starting a version section
        if [[ "$line" =~ ^##\ \[.*\] ]]; then
            # If we were already in a version section, end it
            if [[ "$in_version_section" == true ]]; then
                in_version_section=false
                current_category=""
            fi
            # Start new version section
            in_version_section=true
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # Check for category headers
        if [[ "$line" =~ ^###\ (Added|Changed|Fixed) ]]; then
            current_category=$(echo "$line" | sed -E 's/^### ([A-Za-z]+).*/\1/' | tr '[:upper:]' '[:lower:]')
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # Process bullet points in version sections
        if [[ "$in_version_section" == true ]] && [[ "$line" =~ ^-\ .+ ]] && [[ -n "$current_category" ]]; then
            # Extract the text after the bullet
            local bullet_text=$(echo "$line" | sed 's/^- //')
            
            # Skip empty or placeholder entries
            if [[ "$bullet_text" =~ ^[[:space:]]*$ ]] || [[ "$bullet_text" == "" ]]; then
                echo "$line" >> "$temp_file"
                continue
            fi
            
            # Enhance the text
            enhancement_attempted=true
            local enhanced_text
            enhanced_text=$(enhance_with_ai "$bullet_text" "$current_category")
            if [[ $? -eq 0 ]]; then
                enhancement_succeeded=true
                echo "- $enhanced_text" >> "$temp_file"
            else
                echo "- $bullet_text" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace original with enhanced version
    if mv "$temp_file" "$file"; then
        if [[ "$enhancement_attempted" == true ]]; then
            if [[ "$enhancement_succeeded" == true ]]; then
                echo "Changelog enhanced with AI-powered WoW flair! Backup saved as ${file}.backup"
            else
                echo "Changelog processed (AI enhancement attempted but failed). Backup saved as ${file}.backup"
            fi
        else
            echo "Changelog processed (no content found to enhance). Backup saved as ${file}.backup"
        fi
        return 0
    else
        echo "Warning: Failed to update changelog file. Original file unchanged." >&2
        rm -f "$temp_file" 2>/dev/null || true
        echo "Skipped AI enhancement due to file processing error"
        return 1
    fi
}

# Main execution
main() {
    echo "AI-Powered WoW Flair Changelog Enhancer for HealIQ"
    echo "=================================================="
    
    echo "Using AI models for WoW-themed enhancements"
    
    if ! check_github_models; then
        echo "Warning: GitHub models not available."
        echo "AI enhancement requires: gh extension install github/gh-models"
        echo "Proceeding with basic changelog (no AI enhancement applied)"
        echo "Note: In GitHub Actions, ensure GH_TOKEN is set and models extension is available"
        echo ""
        # Just exit successfully without AI enhancement
        echo "Skipped AI enhancement - changelog remains unchanged"
        exit 0
    fi
    
    # Try to process the changelog with AI enhancement
    # Even if it fails, we don't want to fail the entire workflow
    if process_changelog "$CHANGELOG_FILE"; then
        echo ""
        echo "✨ AI enhancement completed successfully! ✨"
    else
        echo "Warning: AI enhancement encountered errors, but changelog processing completed"
        echo "The basic changelog was generated successfully without AI enhancement"
    fi
    
    # Always exit successfully - AI enhancement is not critical to the workflow
    echo ""
    echo "Changelog processing completed."
}

# Run main function
main "$@"
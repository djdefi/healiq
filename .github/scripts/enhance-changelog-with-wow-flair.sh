#!/bin/bash

# Script to enhance changelog entries with World of Warcraft flair
# Usage: ./enhance-changelog-with-wow-flair.sh [changelog_file] [--use-ai]

set -e

# Default values
CHANGELOG_FILE="CHANGELOG.md"
USE_AI=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --use-ai)
            USE_AI=true
            shift
            ;;
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

# Function to enhance text with WoW flair using local patterns
enhance_with_local_flair() {
    local text="$1"
    local category="$2"
    
    # Define WoW-themed replacements based on category
    case "$category" in
        "added")
            # Replace common terms with WoW-appropriate language
            text=$(echo "$text" | sed -E 's/\badded?\b/conjured/gi')
            text=$(echo "$text" | sed -E 's/\bimplemented?\b/forged/gi')
            text=$(echo "$text" | sed -E 's/\bcreated?\b/summoned/gi')
            text=$(echo "$text" | sed -E 's/\bintroduced?\b/awakened/gi')
            text=$(echo "$text" | sed -E 's/\bnew feature/mystical enhancement/gi')
            text=$(echo "$text" | sed -E 's/\bfeature/power/gi')
            text=$(echo "$text" | sed -E 's/\bfunction/spell/gi')
            text=$(echo "$text" | sed -E 's/\boption/enchantment/gi')
            text=$(echo "$text" | sed -E 's/\bsupport for/blessing of/gi')
            ;;
        "changed")
            # Enhancement and improvement language
            text=$(echo "$text" | sed -E 's/\bimproved?\b/empowered/gi')
            text=$(echo "$text" | sed -E 's/\benhanced?\b/blessed/gi')
            text=$(echo "$text" | sed -E 's/\bupdated?\b/renewed/gi')
            text=$(echo "$text" | sed -E 's/\bmodified?\b/reforged/gi')
            text=$(echo "$text" | sed -E 's/\brefactored?\b/restructured the magical weave of/gi')
            text=$(echo "$text" | sed -E 's/\boptimized?\b/harmonized/gi')
            text=$(echo "$text" | sed -E 's/\bperformance/channeling efficiency/gi')
            text=$(echo "$text" | sed -E 's/\balgorithm/arcane formula/gi')
            ;;
        "fixed")
            # Bug fix language with healing/restoration theme
            text=$(echo "$text" | sed -E 's/\bfixed?\b/mended/gi')
            text=$(echo "$text" | sed -E 's/\bresolved?\b/cleansed/gi')
            text=$(echo "$text" | sed -E 's/\bcorrected?\b/purified/gi')
            text=$(echo "$text" | sed -E 's/\bbug/corruption/gi')
            text=$(echo "$text" | sed -E 's/\berror/hex/gi')
            text=$(echo "$text" | sed -E 's/\bissue/malady/gi')
            text=$(echo "$text" | sed -E 's/\bcrash/magical instability/gi')
            text=$(echo "$text" | sed -E 's/\bmemory leak/mana drain/gi')
            text=$(echo "$text" | sed -E 's/\bnull.*pointer/void essence/gi')
            ;;
    esac
    
    # Universal WoW-themed replacements
    text=$(echo "$text" | sed -E 's/\bUI\b/interface crystal/gi')
    text=$(echo "$text" | sed -E 's/\buser interface/druidic interface/gi')
    text=$(echo "$text" | sed -E 's/\bsettings/sacred configurations/gi')
    text=$(echo "$text" | sed -E 's/\bconfiguration/ritual setup/gi')
    text=$(echo "$text" | sed -E 's/\bloading/channeling/gi')
    text=$(echo "$text" | sed -E 's/\bhealing/restoration/gi')
    text=$(echo "$text" | sed -E 's/\bspell/incantation/gi')
    text=$(echo "$text" | sed -E 's/\bability/gift/gi')
    text=$(echo "$text" | sed -E 's/\bcooldown/ritual recovery/gi')
    text=$(echo "$text" | sed -E 's/\bdamage/harm/gi')
    text=$(echo "$text" | sed -E 's/\btarget/ally/gi')
    text=$(echo "$text" | sed -E 's/\bplayer/keeper/gi')
    text=$(echo "$text" | sed -E 's/\bdetection/divination/gi')
    text=$(echo "$text" | sed -E 's/\banalysis/mystic insight/gi')
    
    echo "$text"
}

# Function to enhance text with AI using GitHub models
enhance_with_ai() {
    local text="$1"
    local category="$2"
    
    local prompt="Transform this technical changelog entry into World of Warcraft-themed language suitable for a Restoration Druid healing addon. Keep the meaning clear but add fantasy flair. Use WoW healing/nature terminology where appropriate:

Category: $category
Entry: $text

Enhanced entry:"

    # Try to use GitHub models
    if check_github_models; then
        echo "Enhancing with AI..." >&2
        local enhanced_text
        enhanced_text=$(gh models chat -m gpt-4o-mini --prompt "$prompt" 2>/dev/null | head -n 1)
        
        if [[ -n "$enhanced_text" && "$enhanced_text" != "$text" ]]; then
            echo "$enhanced_text"
            return 0
        fi
    fi
    
    # Fallback to local enhancement
    echo "AI enhancement not available, using local flair..." >&2
    enhance_with_local_flair "$text" "$category"
}

# Function to process changelog file
process_changelog() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: Changelog file '$file' not found"
        exit 1
    fi
    
    echo "Enhancing changelog with WoW flair..."
    
    # Create backup
    cp "$file" "${file}.backup"
    
    # Process the file
    local in_version_section=false
    local current_category=""
    local temp_file=$(mktemp)
    
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
            local enhanced_text
            if [[ "$USE_AI" == true ]]; then
                enhanced_text=$(enhance_with_ai "$bullet_text" "$current_category")
            else
                enhanced_text=$(enhance_with_local_flair "$bullet_text" "$current_category")
            fi
            
            echo "- $enhanced_text" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace original with enhanced version
    mv "$temp_file" "$file"
    
    echo "Changelog enhanced! Backup saved as ${file}.backup"
}

# Main execution
main() {
    echo "WoW Flair Changelog Enhancer for HealIQ"
    echo "========================================"
    
    if [[ "$USE_AI" == true ]]; then
        echo "AI enhancement mode enabled"
        if ! check_github_models; then
            echo "Warning: AI enhancement requested but GitHub models not available"
            echo "Falling back to local enhancement patterns"
            USE_AI=false
        fi
    else
        echo "Using local WoW flair patterns"
    fi
    
    process_changelog "$CHANGELOG_FILE"
}

# Run main function
main "$@"
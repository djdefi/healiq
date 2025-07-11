#!/bin/bash

# Script to generate changelog entries from git commits
# Usage: ./generate-changelog.sh [from_version] [to_version]

set -e

# Function to display usage
usage() {
    echo "Usage: $0 [from_version] [to_version]"
    echo "  from_version: Previous version tag (e.g., v0.0.9)"
    echo "  to_version: Current version (e.g., 0.0.10)"
    echo "  If no arguments provided, will generate from latest tag to current version"
    exit 1
}

# Function to get current version from .toc file
get_current_version() {
    grep "^## Version:" HealIQ.toc | cut -d' ' -f3
}

# Function to get latest git tag
get_latest_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Function to categorize commit message
categorize_commit() {
    local commit_msg="$1"
    local subject=$(echo "$commit_msg" | head -n1)
    
    # Convert to lowercase for matching
    local lower_subject=$(echo "$subject" | tr '[:upper:]' '[:lower:]')
    
    # Skip version bump commits
    if [[ "$lower_subject" =~ ^bump\ version ]]; then
        echo "skip"
        return
    fi
    
    # Categorize based on commit message patterns
    if [[ "$lower_subject" =~ ^(feat|feature|add): ]] || [[ "$lower_subject" =~ ^add[[:space:]] ]] || [[ "$lower_subject" =~ added ]]; then
        echo "added"
    elif [[ "$lower_subject" =~ ^(fix|bugfix|bug): ]] || [[ "$lower_subject" =~ ^fix[[:space:]] ]] || [[ "$lower_subject" =~ fixed ]] || [[ "$lower_subject" =~ resolve ]]; then
        echo "fixed"
    elif [[ "$lower_subject" =~ ^(chore|docs|doc|refactor|perf|style|test): ]] || [[ "$lower_subject" =~ update ]] || [[ "$lower_subject" =~ change ]] || [[ "$lower_subject" =~ improve ]]; then
        echo "changed"
    elif [[ "$lower_subject" =~ ^(breaking|break): ]] || [[ "$lower_subject" =~ breaking ]]; then
        echo "changed"
    else
        # Default to "changed" for unclear commits
        echo "changed"
    fi
}

# Function to clean up commit message for changelog
clean_commit_message() {
    local commit_msg="$1"
    local subject=$(echo "$commit_msg" | head -n1)
    
    # Remove conventional commit prefixes
    subject=$(echo "$subject" | sed -E 's/^(feat|feature|add|fix|bugfix|bug|chore|docs|doc|refactor|perf|style|test|breaking|break):\s*//')
    
    # Capitalize first letter
    subject=$(echo "$subject" | sed 's/^./\U&/')
    
    # Ensure it doesn't end with a period (we'll add our own formatting)
    subject=$(echo "$subject" | sed 's/\.$//')
    
    echo "$subject"
}

# Main function to generate changelog entries
generate_changelog_entries() {
    local from_version="$1"
    local to_version="$2"
    
    echo "Generating changelog entries from $from_version to $to_version..." >&2
    
    # Get commit range
    local commit_range
    if [ "$from_version" = "initial" ]; then
        # Get all commits if no previous version
        commit_range=$(git rev-list --reverse HEAD)
    else
        # Get commits between versions
        commit_range=$(git rev-list --reverse "$from_version"..HEAD)
    fi
    
    # Initialize arrays for different categories
    local -a added_items=()
    local -a changed_items=()
    local -a fixed_items=()
    
    # Process each commit
    while IFS= read -r commit_hash; do
        if [ -z "$commit_hash" ]; then
            continue
        fi
        
        # Get commit message
        local commit_msg=$(git log --format="%s%n%b" -n 1 "$commit_hash")
        local subject=$(echo "$commit_msg" | head -n1)
        
        # Skip merge commits and empty commits
        if [[ "$subject" =~ ^Merge ]] || [ -z "$subject" ]; then
            continue
        fi
        
        # Categorize and clean the commit
        local category=$(categorize_commit "$commit_msg")
        local clean_msg=$(clean_commit_message "$commit_msg")
        
        # Skip version bump commits
        if [ "$category" = "skip" ]; then
            continue
        fi
        
        # Add to appropriate category
        case "$category" in
            "added")
                added_items+=("$clean_msg")
                ;;
            "changed")
                changed_items+=("$clean_msg")
                ;;
            "fixed")
                fixed_items+=("$clean_msg")
                ;;
        esac
    done <<< "$commit_range"
    
    # Generate changelog content
    local changelog_content=""
    
    # Added section
    if [ ${#added_items[@]} -gt 0 ]; then
        changelog_content+="### Added\n"
        for item in "${added_items[@]}"; do
            changelog_content+="- $item\n"
        done
        changelog_content+="\n"
    else
        changelog_content+="### Added\n- \n\n"
    fi
    
    # Changed section
    if [ ${#changed_items[@]} -gt 0 ]; then
        changelog_content+="### Changed\n"
        for item in "${changed_items[@]}"; do
            changelog_content+="- $item\n"
        done
        changelog_content+="\n"
    else
        changelog_content+="### Changed\n- \n\n"
    fi
    
    # Fixed section
    if [ ${#fixed_items[@]} -gt 0 ]; then
        changelog_content+="### Fixed\n"
        for item in "${fixed_items[@]}"; do
            changelog_content+="- $item\n"
        done
        changelog_content+="\n"
    else
        changelog_content+="### Fixed\n- \n\n"
    fi
    
    echo -e "$changelog_content"
}

# Function to update changelog file
update_changelog_file() {
    local version="$1"
    local changelog_entries="$2"
    local current_date=$(date +"%Y-%m-%d")
    
    # Check if version already exists in changelog
    if grep -q "## \[$version\]" CHANGELOG.md; then
        echo "Updating existing changelog entry for version $version..."
        
        # Create temporary file with updated content
        {
            # Keep everything before this version
            sed "/## \[$version\]/q" CHANGELOG.md | head -n -1
            
            # Add the new version entry
            echo "## [$version] - $current_date"
            echo ""
            echo -e "$changelog_entries"
            
            # Add everything after this version (skip the old entry)
            sed -n "/## \[$version\]/,/## \[/p" CHANGELOG.md | tail -n +1 | grep -A999999 "^## \[" | tail -n +2
        } > CHANGELOG.md.tmp
        
        mv CHANGELOG.md.tmp CHANGELOG.md
    else
        echo "Adding new changelog entry for version $version..."
        
        # Create new changelog entry at the top
        {
            echo "# HealIQ Changelog"
            echo ""
            echo "## [$version] - $current_date"
            echo ""
            echo -e "$changelog_entries"
            
            # Add rest of changelog after the first line
            tail -n +2 CHANGELOG.md
        } > CHANGELOG.md.tmp
        
        mv CHANGELOG.md.tmp CHANGELOG.md
    fi
    
    echo "Changelog updated for version $version"
}

# Function to validate that changelog entry is not empty
validate_changelog_entry() {
    local version="$1"
    
    # Extract the changelog section for this version
    local section=$(sed -n "/## \[$version\]/,/## \[/p" CHANGELOG.md | head -n -1)
    
    # Count non-empty entries (exclude lines that are just "- " or "- " with whitespace)
    local added_content=$(echo "$section" | grep -A20 "### Added" | grep -E "^- .+$" | grep -v -E "^- *$" | wc -l)
    local changed_content=$(echo "$section" | grep -A20 "### Changed" | grep -E "^- .+$" | grep -v -E "^- *$" | wc -l)
    local fixed_content=$(echo "$section" | grep -A20 "### Fixed" | grep -E "^- .+$" | grep -v -E "^- *$" | wc -l)
    
    local total_content=$((added_content + changed_content + fixed_content))
    
    if [ $total_content -eq 0 ]; then
        echo "WARNING: Changelog entry for version $version appears to be empty (all sections have empty bullets)"
        return 1
    fi
    
    echo "Changelog entry for version $version has $total_content entries"
    return 0
}

# Main execution
main() {
    local from_version=""
    local to_version=""
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        # No arguments - auto-detect versions
        to_version=$(get_current_version)
        from_version=$(get_latest_tag)
        
        if [ -z "$from_version" ]; then
            echo "No previous version tag found. Generating changelog from initial commit..."
            from_version="initial"
        fi
    elif [ $# -eq 2 ]; then
        from_version="$1"
        to_version="$2"
    else
        usage
    fi
    
    echo "Generating changelog from $from_version to $to_version"
    
    # Generate changelog entries
    local changelog_entries=$(generate_changelog_entries "$from_version" "$to_version")
    
    # Update changelog file
    update_changelog_file "$to_version" "$changelog_entries"
    
    # Validate the result
    if validate_changelog_entry "$to_version"; then
        echo "Changelog generation completed successfully!"
    else
        echo "Changelog generated but may need manual review."
    fi
}

# Run main function with all arguments
main "$@"
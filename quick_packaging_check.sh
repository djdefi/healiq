#!/bin/bash
# Quick packaging validation script
# Validates that all TOC files are included in .pkgmeta

echo "🔍 Quick Packaging Validation"
echo "============================="

# Check that key files exist
echo "Checking critical files..."
missing_files=()
for file in HealIQ.toc .pkgmeta Core.lua Engine.lua rules/BaseRule.lua; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo "❌ Missing critical files: ${missing_files[*]}"
    exit 1
fi

echo "✅ All critical files present"

# Quick check that rules/ is in .pkgmeta
if ! grep -q "rules/" .pkgmeta; then
    echo "❌ rules/ directory not found in .pkgmeta"
    exit 1
fi

echo "✅ rules/ directory included in packaging"

# Quick check that Performance.lua and Validation.lua are in .pkgmeta  
if ! grep -q "Performance.lua" .pkgmeta; then
    echo "❌ Performance.lua not found in .pkgmeta"
    exit 1
fi

if ! grep -q "Validation.lua" .pkgmeta; then
    echo "❌ Validation.lua not found in .pkgmeta"
    exit 1
fi

echo "✅ Performance.lua and Validation.lua included in packaging"

echo ""
echo "🎉 Quick packaging validation passed!"
echo "For comprehensive validation, run: lua5.1 test_packaging.lua"
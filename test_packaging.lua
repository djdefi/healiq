#!/usr/bin/env lua
-- HealIQ Packaging Validation Test
-- Prevents critical packaging issues like the v0.1.12 TOC loading error
-- Validates that all files referenced in HealIQ.toc are included in .pkgmeta

local function print_result(passed, message)
    if passed then
        print("✓ " .. message)
    else
        print("✗ " .. message)
        error("Test failed: " .. message)
    end
end

local function read_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil, "Cannot read file: " .. filepath
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function parse_toc_files()
    local content, err = read_file("HealIQ.toc")
    if not content then
        error(err)
    end

    local files = {}
    for line in content:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
        if line:match("%.lua$") and not line:match("^#") then
            table.insert(files, line)
        end
    end

    return files
end

local function parse_pkgmeta_files()
    local content, err = read_file(".pkgmeta")
    if not content then
        error(err)
    end

    local includedFiles = {}
    local inMoveSection = false
    local inHealIQSection = false

    for line in content:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
        
        if line:match("^move%-folders:") then
            inMoveSection = true
        elseif line:match("^%s*HealIQ:") then
            inHealIQSection = true
        elseif inMoveSection and inHealIQSection then
            if line:match("^%s*%-") then
                -- Extract file or directory name
                local file = line:gsub("^%s*%-%s*", "")
                table.insert(includedFiles, file)
            elseif not line:match("^%s*$") and not line:match("^%s*#") then
                -- End of section if we hit a non-indented, non-comment line
                break
            end
        end
    end

    return includedFiles
end

local function normalize_path(path)
    -- Remove trailing slashes for directories
    return path:gsub("/$", "")
end

local function is_file_covered_by_pkgmeta(tocFile, pkgmetaFiles)
    -- Check direct file inclusion
    for _, pkgFile in ipairs(pkgmetaFiles) do
        if normalize_path(pkgFile) == normalize_path(tocFile) then
            return true
        end
    end

    -- Check directory inclusion (e.g., rules/ covers rules/BaseRule.lua)
    for _, pkgFile in ipairs(pkgmetaFiles) do
        local normalizedPkg = normalize_path(pkgFile)
        if normalizedPkg:match("/$") or normalizedPkg:match("/[^/]*$") then
            -- This is a directory or contains directory structure
            local dirPath = normalizedPkg:gsub("/[^/]*$", "") .. "/"
            if tocFile:match("^" .. dirPath:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) then
                return true
            end
        end
        -- Also check if pkgmeta entry is a directory that would include this file
        if tocFile:match("^" .. normalizedPkg:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. "/") then
            return true
        end
    end

    return false
end

local function test_toc_pkgmeta_consistency()
    print("\n=== Testing TOC and .pkgmeta Consistency ===")

    local tocFiles = parse_toc_files()
    local pkgmetaFiles = parse_pkgmeta_files()

    print("Found " .. #tocFiles .. " files in HealIQ.toc")
    print("Found " .. #pkgmetaFiles .. " entries in .pkgmeta move-folders section")

    -- Verify all TOC files are covered by .pkgmeta
    local uncoveredFiles = {}
    for _, tocFile in ipairs(tocFiles) do
        if not is_file_covered_by_pkgmeta(tocFile, pkgmetaFiles) then
            table.insert(uncoveredFiles, tocFile)
        end
    end

    print_result(#uncoveredFiles == 0, "All TOC files are covered by .pkgmeta packaging")
    
    if #uncoveredFiles > 0 then
        print("Uncovered files:")
        for _, file in ipairs(uncoveredFiles) do
            print("  - " .. file)
        end
    end

    return #uncoveredFiles == 0
end

local function test_file_existence()
    print("\n=== Testing File Existence ===")

    local tocFiles = parse_toc_files()
    local missingFiles = {}

    for _, tocFile in ipairs(tocFiles) do
        local file = io.open(tocFile, "r")
        if file then
            file:close()
        else
            table.insert(missingFiles, tocFile)
        end
    end

    print_result(#missingFiles == 0, "All TOC-referenced files exist on filesystem")
    
    if #missingFiles > 0 then
        print("Missing files:")
        for _, file in ipairs(missingFiles) do
            print("  - " .. file)
        end
    end

    return #missingFiles == 0
end

local function test_critical_files_in_pkgmeta()
    print("\n=== Testing Critical Files in .pkgmeta ===")

    local pkgmetaFiles = parse_pkgmeta_files()
    
    -- Critical individual files that must be explicitly listed
    local criticalFiles = {
        "Core.lua",
        "Engine.lua",
        "UI.lua",
        "Tracker.lua",
        "Config.lua",
        "Logging.lua",
        "Performance.lua",
        "Validation.lua",
        "HealIQ.toc"
    }

    -- Critical directories that must be included
    local criticalDirs = {
        "rules/",
        "rules"  -- Support both with and without trailing slash
    }

    for _, criticalFile in ipairs(criticalFiles) do
        local found = false
        for _, pkgFile in ipairs(pkgmetaFiles) do
            if normalize_path(pkgFile) == normalize_path(criticalFile) then
                found = true
                break
            end
        end
        print_result(found, criticalFile .. " is included in .pkgmeta")
    end

    -- Check that at least one rules directory entry exists
    local rulesFound = false
    for _, pkgFile in ipairs(pkgmetaFiles) do
        for _, criticalDir in ipairs(criticalDirs) do
            if normalize_path(pkgFile) == normalize_path(criticalDir) then
                rulesFound = true
                break
            end
        end
        if rulesFound then break end
    end
    print_result(rulesFound, "rules/ directory is included in .pkgmeta")

    return true
end

local function test_version_consistency()
    print("\n=== Testing Version Consistency ===")

    -- Read TOC version
    local tocContent, err = read_file("HealIQ.toc")
    if not tocContent then
        error(err)
    end

    local tocVersion = tocContent:match("## Version: ([^\r\n]+)")
    if not tocVersion then
        error("Cannot find version in HealIQ.toc")
    end
    tocVersion = tocVersion:gsub("^%s*", ""):gsub("%s*$", "") -- trim

    -- Read Core.lua version
    local coreContent, coreErr = read_file("Core.lua")
    if not coreContent then
        error(coreErr)
    end

    local coreVersion = coreContent:match("HealIQ%.version%s*=%s*[\"']([^\"']+)[\"']")
    if not coreVersion then
        error("Cannot find version in Core.lua")
    end

    print("TOC version: " .. tocVersion)
    print("Core.lua version: " .. coreVersion)

    print_result(tocVersion == coreVersion, "Versions match between HealIQ.toc and Core.lua")

    return tocVersion == coreVersion
end

local function test_packaging_ignore_list()
    print("\n=== Testing Packaging Ignore List ===")

    local content, err = read_file(".pkgmeta")
    if not content then
        error(err)
    end

    -- Essential files that should be ignored (not packaged)
    local essentialIgnores = {
        ".git",
        ".github",
        "Tests.lua",
        "test_runner.lua",
        "test_packaging.lua",
        "test_loading_order.lua",
        "validate_runner.lua",
        "WoWAPIMock.lua",
        "setup-dev.sh",
        ".pkgmeta"
    }

    -- Parse ignore section properly
    local ignoreLines = {}
    local inIgnoreSection = false
    
    for line in content:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
        
        if line:match("^ignore:") then
            inIgnoreSection = true
        elseif inIgnoreSection then
            if line:match("^%s*%-") then
                -- Extract ignored file/pattern
                local ignored = line:gsub("^%s*%-%s*", ""):gsub('"', '') -- remove quotes too
                table.insert(ignoreLines, ignored)
            elseif not line:match("^%s*$") and not line:match("^%s*#") then
                -- End of ignore section
                break
            end
        end
    end
    
    for _, essential in ipairs(essentialIgnores) do
        local found = false
        for _, ignored in ipairs(ignoreLines) do
            if ignored == essential then
                found = true
                break
            end
        end
        print_result(found, essential .. " is properly ignored in packaging")
    end

    return true
end

local function test_no_missing_dependencies()
    print("\n=== Testing for Missing Dependencies ===")

    -- Check if there are any require() calls in TOC files that might not be satisfied
    local tocFiles = parse_toc_files()
    local dependencyIssues = {}

    for _, tocFile in ipairs(tocFiles) do
        local content, err = read_file(tocFile)
        if content then
            -- Look for require() calls
            for requirePath in content:gmatch('require%s*%(%s*["\']([^"\']+)["\']%s*%)') do
                -- Check if the required file exists
                local requiredFile = requirePath .. ".lua"
                local file = io.open(requiredFile, "r")
                if file then
                    file:close()
                else
                    table.insert(dependencyIssues, {file = tocFile, dependency = requiredFile})
                end
            end
        end
    end

    print_result(#dependencyIssues == 0, "No missing dependencies found in TOC files")

    if #dependencyIssues > 0 then
        print("Dependency issues:")
        for _, issue in ipairs(dependencyIssues) do
            print("  " .. issue.file .. " requires " .. issue.dependency .. " (missing)")
        end
    end

    return #dependencyIssues == 0
end

local function test_additional_consistency_checks()
    print("\n=== Testing Additional Consistency Checks ===")

    -- Check for hardcoded paths that might break in packaging
    local tocFiles = parse_toc_files()
    local hardcodedPaths = {}

    for _, tocFile in ipairs(tocFiles) do
        local content, err = read_file(tocFile)
        if content then
            -- Look for potentially problematic hardcoded paths
            for line in content:gmatch("[^\r\n]+") do
                if line:find("Interface/AddOns/HealIQ/") and not line:find("%-%-") then
                    table.insert(hardcodedPaths, {file = tocFile, line = line:gsub("^%s*", "")})
                end
            end
        end
    end

    print_result(#hardcodedPaths == 0, "No hardcoded addon paths found that could break packaging")

    if #hardcodedPaths > 0 then
        print("Hardcoded paths found:")
        for _, pathInfo in ipairs(hardcodedPaths) do
            print("  " .. pathInfo.file .. ": " .. pathInfo.line)
        end
    end

    -- Check TOC metadata consistency
    local tocContent, err = read_file("HealIQ.toc")
    if not tocContent then
        error(err)
    end

    local interface = tocContent:match("## Interface: (%d+)")
    local title = tocContent:match("## Title: ([^\r\n]+)")
    local author = tocContent:match("## Author: ([^\r\n]+)")

    print_result(interface ~= nil, "TOC file has Interface version specified")
    print_result(title ~= nil, "TOC file has Title specified")
    print_result(author ~= nil, "TOC file has Author specified")

    -- Warn about interface version (this should be updated for new WoW patches)
    if interface then
        print("Current Interface version: " .. interface .. " (update for new WoW patches)")
    end

    return true
end

local function test_file_size_sanity()
    print("\n=== Testing File Size Sanity ===")

    local tocFiles = parse_toc_files()
    local largeSizeFiles = {}
    local maxReasonableSize = 1024 * 1024 -- 1MB limit for any single file

    for _, tocFile in ipairs(tocFiles) do
        local file = io.open(tocFile, "r")
        if file then
            local size = file:seek("end")
            file:close()
            
            if size > maxReasonableSize then
                table.insert(largeSizeFiles, {file = tocFile, size = size})
            end
        end
    end

    print_result(#largeSizeFiles == 0, "No abnormally large files found in TOC")

    if #largeSizeFiles > 0 then
        print("Large files found:")
        for _, fileInfo in ipairs(largeSizeFiles) do
            print(string.format("  %s: %.2f MB", fileInfo.file, fileInfo.size / (1024 * 1024)))
        end
    end

    return true
end

local function run_all_tests()
    print("HealIQ Packaging Validation Test Suite")
    print("=====================================")
    print("Prevents critical packaging issues like v0.1.12 TOC loading errors")

    local tests = {
        test_toc_pkgmeta_consistency,
        test_file_existence,
        test_critical_files_in_pkgmeta,
        test_version_consistency,
        test_packaging_ignore_list,
        test_no_missing_dependencies,
        test_additional_consistency_checks,
        test_file_size_sanity
    }

    local passed = 0
    local total = #tests

    for i, test in ipairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            print("Test " .. i .. " failed: " .. tostring(err))
        end
    end

    print(string.format("\n=== Results: %d/%d packaging tests passed ===", passed, total))

    if passed == total then
        print("✅ All packaging validation tests passed!")
        print("✅ The addon is properly configured for distribution packaging.")
        return true
    else
        print("❌ Some packaging tests failed!")
        print("❌ The addon may have packaging issues that could cause distribution problems.")
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_packaging%.lua") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
end

-- Export for use in other test files
return {
    test_toc_pkgmeta_consistency = test_toc_pkgmeta_consistency,
    test_file_existence = test_file_existence,
    test_critical_files_in_pkgmeta = test_critical_files_in_pkgmeta,
    test_version_consistency = test_version_consistency,
    test_packaging_ignore_list = test_packaging_ignore_list,
    test_no_missing_dependencies = test_no_missing_dependencies,
    test_additional_consistency_checks = test_additional_consistency_checks,
    test_file_size_sanity = test_file_size_sanity,
    run_all_tests = run_all_tests
}
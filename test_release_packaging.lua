#!/usr/bin/env lua
-- HealIQ Release Package Validation Test
-- Focused test to prevent regression of missing rules directory issue
-- This test simulates the exact release packaging process to ensure all files are included

local function print_result(passed, message)
    if passed then
        print("✓ " .. message)
    else
        print("✗ " .. message)
        error("Test failed: " .. message)
    end
end

local function get_command_output_number(command)
    local output = io.popen(command):read("*a"):match("%d+")
    return tonumber(output) or 0
end

local function test_release_package_creation()
    print("\n=== Testing Release Package Creation Process ===")
    
    -- Clean up any previous test artifacts
    os.execute("rm -rf test_release_package 2>/dev/null")
    
    -- Create test package directory
    local mkdir_result = os.execute("mkdir -p test_release_package/HealIQ")
    print_result(mkdir_result == 0, "Test package directory created")
    
    -- Simulate the exact file copying process from the release workflow
    local copy_commands = {
        "cp *.lua test_release_package/HealIQ/",
        "cp HealIQ.toc test_release_package/HealIQ/",
        "cp README.md test_release_package/HealIQ/ 2>/dev/null || true",
        "cp LICENSE test_release_package/HealIQ/ 2>/dev/null || true",
        "cp CHANGELOG.md test_release_package/HealIQ/ 2>/dev/null || true",
        "cp INSTALL.md test_release_package/HealIQ/ 2>/dev/null || true"
    }
    
    for _, cmd in ipairs(copy_commands) do
        local result = os.execute(cmd)
        if not cmd:find("2>/dev/null") then
            print_result(result == 0, "Basic file copy completed: " .. cmd:match("cp ([^%s]+)"))
        end
    end
    
    -- Critical test: Copy rules directory
    local rules_exists = os.execute("test -d rules")
    print_result(rules_exists == 0, "rules/ directory exists in source")
    
    local rules_copy = os.execute("cp -r rules/ test_release_package/HealIQ/")
    print_result(rules_copy == 0, "rules/ directory copied to package")
    
    -- Verify rules directory was copied correctly
    local rules_package_exists = os.execute("test -d test_release_package/HealIQ/rules")
    print_result(rules_package_exists == 0, "rules/ directory exists in package")
    
    return true
end

local function test_toc_files_validation()
    print("\n=== Testing TOC Files Validation ===")
    
    -- Read TOC file and extract Lua files
    local toc_file = io.open("HealIQ.toc", "r")
    if not toc_file then
        error("Cannot read HealIQ.toc file")
    end
    
    local toc_files = {}
    for line in toc_file:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        -- Skip comments and empty lines
        if trimmed and not trimmed:match("^#") and trimmed ~= "" and trimmed:match("%.lua$") then
            table.insert(toc_files, trimmed)
        end
    end
    toc_file:close()
    
    print("Found " .. #toc_files .. " Lua files listed in HealIQ.toc")
    
    -- Check that all TOC files exist in the package
    local missing_files = {}
    for _, lua_file in ipairs(toc_files) do
        local file_exists = os.execute("test -f test_release_package/HealIQ/" .. lua_file .. " 2>/dev/null")
        if file_exists ~= 0 then
            table.insert(missing_files, lua_file)
        end
    end
    
    print_result(#missing_files == 0, "All TOC-referenced files exist in package")
    
    if #missing_files > 0 then
        print("Missing files from package:")
        for _, file in ipairs(missing_files) do
            print("  - " .. file)
        end
    end
    
    return #missing_files == 0
end

local function test_rules_files_specifically()
    print("\n=== Testing Rules Files Specifically ===")
    
    -- List of expected rule files (matches the problem statement)
    local expected_rules = {
        "rules/BaseRule.lua",
        "rules/DefensiveCooldowns.lua",
        "rules/HealingCooldowns.lua",
        "rules/UtilityRules.lua",
        "rules/AoERules.lua",
        "rules/OffensiveRules.lua"
    }
    
    local missing_rules = {}
    for _, rule_file in ipairs(expected_rules) do
        local rule_exists = os.execute("test -f test_release_package/HealIQ/" .. rule_file .. " 2>/dev/null")
        if rule_exists ~= 0 then
            table.insert(missing_rules, rule_file)
        else
            print("✓ Found: " .. rule_file)
        end
    end
    
    print_result(#missing_rules == 0, "All expected rule files are present in package")
    
    if #missing_rules > 0 then
        print("Missing rule files that would cause the original issue:")
        for _, file in ipairs(missing_rules) do
            print("  - " .. file)
        end
    end
    
    return #missing_rules == 0
end

local function test_package_statistics()
    print("\n=== Testing Package Statistics ===")
    
    -- Get file counts using helper function
    local total_files = get_command_output_number("find test_release_package/HealIQ -type f | wc -l")
    local lua_files = get_command_output_number("find test_release_package/HealIQ -name '*.lua' | wc -l")
    local rules_files = get_command_output_number("find test_release_package/HealIQ/rules -name '*.lua' 2>/dev/null | wc -l")
    
    print("Package statistics:")
    print("  - Total files: " .. total_files)
    print("  - Lua files: " .. lua_files)
    print("  - Rules files: " .. rules_files)
    
    print_result(total_files > 10, "Package contains reasonable number of files")
    print_result(lua_files > 5, "Package contains Lua files")
    print_result(rules_files == 6, "Package contains exactly 6 rule files (prevents regression)")
    
    return true
end

local function cleanup()
    print("\n=== Cleanup ===")
    os.execute("rm -rf test_release_package")
    print("✓ Test artifacts cleaned up")
end

local function run_all_tests()
    print("HealIQ Release Package Validation Test Suite")
    print("==========================================")
    print("This test prevents regression of the missing rules directory issue")
    print("by validating the exact release packaging process.")
    print("")
    
    local tests = {
        test_release_package_creation,
        test_toc_files_validation,
        test_rules_files_specifically,
        test_package_statistics
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
    
    cleanup()
    
    print(string.format("\n=== Results: %d/%d tests passed ===", passed, total))
    
    if passed == total then
        print("✅ All release packaging tests passed!")
        print("✅ The rules directory issue has been fixed and is protected against regression.")
        return true
    else
        print("❌ Some release packaging tests failed!")
        print("❌ The release workflow may still have issues with missing files.")
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_release_packaging%.lua") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
end

-- Export for use in other test files
return {
    test_release_package_creation = test_release_package_creation,
    test_toc_files_validation = test_toc_files_validation,
    test_rules_files_specifically = test_rules_files_specifically,
    test_package_statistics = test_package_statistics,
    run_all_tests = run_all_tests
}
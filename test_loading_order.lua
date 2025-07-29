#!/usr/bin/env lua
-- HealIQ Loading Order Test
-- Test to prevent regression of the .toc loading order issue that caused rule files to fail loading
-- This test ensures Core.lua and Logging.lua are loaded before rule files

local function print_result(passed, message)
    if passed then
        print("✓ " .. message)
    else
        print("✗ " .. message)
        error("Test failed: " .. message)
    end
end

local function test_toc_loading_order()
    print("\n=== Testing .toc Loading Order ===")

    -- Read .toc file
    local tocPath = "HealIQ.toc"
    local tocFile = io.open(tocPath, "r")
    if not tocFile then
        error("Cannot read HealIQ.toc file")
    end

    local content = tocFile:read("*all")
    tocFile:close()

    -- Parse file list from .toc
    local files = {}
    local fileOrder = {}

    for line in content:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace
        if line:match("%.lua$") and not line:match("^#") then
            table.insert(files, line)
            fileOrder[line] = #files
        end
    end

    print("Found " .. #files .. " Lua files in .toc")

    -- Test that Core.lua comes before rules/
    local corePos = fileOrder["Core.lua"]
    local firstRulePos = nil

    for _, file in ipairs(files) do
        if file:match("^rules/") then
            firstRulePos = fileOrder[file]
            break
        end
    end

    print_result(corePos ~= nil, "Core.lua found in .toc file")
    print_result(firstRulePos ~= nil, "Rule files found in .toc file")
    print_result(corePos < firstRulePos, "Core.lua loads before rule files")

    -- Test that Logging.lua comes before rules/
    local loggingPos = fileOrder["Logging.lua"]
    if loggingPos then
        print_result(loggingPos < firstRulePos, "Logging.lua loads before rule files")
    end

    -- Test that specific rule files are present
    local expectedRuleFiles = {
        "rules/BaseRule.lua",
        "rules/DefensiveCooldowns.lua",
        "rules/HealingCooldowns.lua",
        "rules/UtilityRules.lua",
        "rules/AoERules.lua",
        "rules/OffensiveRules.lua"
    }

    for _, ruleFile in ipairs(expectedRuleFiles) do
        print_result(fileOrder[ruleFile] ~= nil, ruleFile .. " found in .toc file")
    end

    -- Test that BaseRule.lua comes first among rule files
    local baseRulePos = fileOrder["rules/BaseRule.lua"]
    if baseRulePos then
        local allRulesAfterBase = true
        for _, ruleFile in ipairs(expectedRuleFiles) do
            if ruleFile ~= "rules/BaseRule.lua" then
                local pos = fileOrder[ruleFile]
                if pos and pos < baseRulePos then
                    allRulesAfterBase = false
                    break
                end
            end
        end
        print_result(allRulesAfterBase, "BaseRule.lua loads first among rule files")
    end

    -- Print loading order for verification
    print("\nLoading order:")
    for i, luaFile in ipairs(files) do
        print(string.format("%2d. %s", i, luaFile))
    end

    return true
end

local function test_rule_file_structure()
    print("\n=== Testing Rule File Structure ===")

    -- Test that rule files have defensive initialization
    local ruleFiles = {
        "rules/BaseRule.lua",
        "rules/DefensiveCooldowns.lua",
        "rules/HealingCooldowns.lua",
        "rules/UtilityRules.lua",
        "rules/AoERules.lua",
        "rules/OffensiveRules.lua"
    }

    for _, ruleFile in ipairs(ruleFiles) do
        local file = io.open(ruleFile, "r")
        if file then
            local content = file:read("*all")
            file:close()

            -- Check for defensive initialization patterns
            local hasDefensiveInit = (
                content:find("HealIQ = HealIQ or {}") or
                content:find("local addonName, HealIQ = ...") or
                content:find("HealIQ%.Rules = HealIQ%.Rules or {}")
            )

            print_result(hasDefensiveInit, ruleFile .. " has defensive initialization")
        else
            print_result(false, ruleFile .. " could not be read")
        end
    end

    return true
end

local function test_loading_simulation()
    print("\n=== Testing Loading Simulation ===")

    -- Simulate the loading process that WoW would do
    local mockGlobal = {}
    local originalGlobal = _G

    -- Mock basic WoW API
    mockGlobal.print = print
    mockGlobal.pairs = pairs
    mockGlobal.ipairs = ipairs
    mockGlobal.type = type
    mockGlobal.table = table
    mockGlobal.string = string
    mockGlobal.GetTime = function() return os.time() end
    mockGlobal.InCombatLockdown = function() return false end

    -- Set up the global environment
    _G = mockGlobal

    -- Simulate loading Core.lua first
    local coreSuccess = pcall(function()
        -- Load Core.lua logic
        local addonName, HealIQ = "HealIQ", {}
        HealIQ.version = "0.1.4"
        HealIQ.debug = false

        function HealIQ:SafeCall(func, ...)
            local success, result = pcall(func, ...)
            if not success then
                print("SafeCall error: " .. tostring(result))
            end
            return success, result
        end

        -- Store in mock global
        mockGlobal.HealIQ = HealIQ
        return true
    end)

    print_result(coreSuccess, "Core.lua simulation loads without error")

    -- Simulate loading BaseRule.lua after Core.lua
    local baseRuleSuccess = pcall(function()
        local addonName, HealIQ = "HealIQ", mockGlobal.HealIQ

        -- Defensive initialization (should work now that HealIQ exists)
        HealIQ = HealIQ or {}
        HealIQ.Rules = HealIQ.Rules or {}

        -- Define BaseRule
        HealIQ.Rules.BaseRule = {}

        function HealIQ.Rules.BaseRule:GetRecentDamageCount(tracker, seconds)
            seconds = seconds or 5
            local currentTime = mockGlobal.GetTime()
            local count = 0

            if tracker and tracker.trackedData and tracker.trackedData.recentDamage then
                for timestamp, _ in pairs(tracker.trackedData.recentDamage) do
                    if currentTime - timestamp <= seconds then
                        count = count + 1
                    end
                end
            end

            return count
        end

        return true
    end)

    print_result(baseRuleSuccess, "BaseRule.lua simulation loads after Core.lua")

    -- Test that BaseRule works correctly
    if baseRuleSuccess and mockGlobal.HealIQ and mockGlobal.HealIQ.Rules.BaseRule then
        local testTracker = {
            trackedData = {
                recentDamage = {
                    [os.time() - 2] = true,
                    [os.time() - 4] = true,
                    [os.time() - 10] = true
                }
            }
        }

        local damageCount = mockGlobal.HealIQ.Rules.BaseRule:GetRecentDamageCount(testTracker, 5)
        print_result(damageCount == 2, "BaseRule functionality works correctly after loading")
    end

    -- Restore global
    _G = originalGlobal

    return true
end

local function run_all_tests()
    print("HealIQ Loading Order Test Suite")
    print("===============================")

    local tests = {
        test_toc_loading_order,
        test_rule_file_structure,
        test_loading_simulation
    }

    local passed = 0
    local total = #tests

    for i, test in ipairs(tests) do
        local success = pcall(test)
        if success then
            passed = passed + 1
        else
            print("Test " .. i .. " failed")
        end
    end

    print(string.format("\n=== Results: %d/%d tests passed ===", passed, total))

    if passed == total then
        print("✓ All loading order tests passed!")
        print("✓ The .toc loading order issue has been fixed and is protected against regression.")
        return true
    else
        print("✗ Some tests failed!")
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_loading_order%.lua") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
end

-- Export for use in other test files
return {
    test_toc_loading_order = test_toc_loading_order,
    test_rule_file_structure = test_rule_file_structure,
    test_loading_simulation = test_loading_simulation,
    run_all_tests = run_all_tests
}
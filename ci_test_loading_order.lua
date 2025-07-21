#!/usr/bin/env lua
-- HealIQ Loading Order CI Test
-- Focused regression test for the .toc loading order issue
-- This test validates that the fix for issue #98 prevents future regressions

local function validate_loading_order()
    print("🔍 Validating .toc loading order (Issue #98 regression test)")
    
    -- Read .toc file
    local file = io.open("HealIQ.toc", "r")
    if not file then
        print("❌ ERROR: Cannot read HealIQ.toc file")
        return false
    end
    
    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    
    -- Extract Lua files in loading order
    local lua_files = {}
    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed and trimmed:match("%.lua$") and not trimmed:match("^#") then
            table.insert(lua_files, trimmed)
        end
    end
    
    print(string.format("📋 Found %d Lua files in loading order", #lua_files))
    
    -- Find positions of key files
    local core_pos = nil
    local logging_pos = nil
    local base_rule_pos = nil
    local first_rule_pos = nil
    
    for i, luaFile in ipairs(lua_files) do
        if luaFile == "Core.lua" then
            core_pos = i
        elseif luaFile == "Logging.lua" then
            logging_pos = i
        elseif luaFile == "rules/BaseRule.lua" then
            base_rule_pos = i
        end
        
        -- Track the first rule file we encounter
        if luaFile:match("^rules/") and not first_rule_pos then
            first_rule_pos = i
        end
    end
    
    -- Validate loading order
    local errors = {}
    
    if not core_pos then
        table.insert(errors, "Core.lua not found in .toc file")
    end
    
    if not logging_pos then
        table.insert(errors, "Logging.lua not found in .toc file")
    end
    
    if not base_rule_pos then
        table.insert(errors, "rules/BaseRule.lua not found in .toc file")
    end
    
    if not first_rule_pos then
        table.insert(errors, "No rule files found in .toc file")
    end
    
    if core_pos and first_rule_pos and core_pos >= first_rule_pos then
        table.insert(errors, string.format("Core.lua (pos %d) must load before rule files (pos %d)", core_pos, first_rule_pos))
    end
    
    if logging_pos and first_rule_pos and logging_pos >= first_rule_pos then
        table.insert(errors, string.format("Logging.lua (pos %d) must load before rule files (pos %d)", logging_pos, first_rule_pos))
    end
    
    if not base_rule_pos then
        table.insert(errors, "BaseRule.lua not found in .toc file")
    elseif base_rule_pos ~= first_rule_pos then
        table.insert(errors, string.format("BaseRule.lua (pos %d) should be the first rule file (first rule at pos %d)", base_rule_pos, first_rule_pos or 0))
    end
    -- If base_rule_pos == first_rule_pos, then BaseRule.lua is correctly the first rule file
    
    -- Report results
    if #errors > 0 then
        print("❌ LOADING ORDER VALIDATION FAILED:")
        for _, error in ipairs(errors) do
            print("   • " .. error)
        end
        return false
    else
        print("✅ Loading order validation passed!")
        print(string.format("   • Core.lua loads at position %d", core_pos))
        print(string.format("   • Logging.lua loads at position %d", logging_pos))
        print(string.format("   • First rule file loads at position %d", first_rule_pos))
        print(string.format("   • BaseRule.lua loads at position %d", base_rule_pos))
        return true
    end
end

local function validate_rule_files()
    print("🔍 Validating rule file defensive initialization")
    
    local rule_files = {
        "rules/BaseRule.lua",
        "rules/DefensiveCooldowns.lua",
        "rules/HealingCooldowns.lua",
        "rules/UtilityRules.lua",
        "rules/AoERules.lua",
        "rules/OffensiveRules.lua"
    }
    
    local errors = {}
    
    for _, rule_file in ipairs(rule_files) do
        local file = io.open(rule_file, "r")
        if not file then
            table.insert(errors, rule_file .. " not found")
        else
            local content = file:read("*all")
            file:close()
            
            -- Check for defensive initialization patterns
            local has_defensive = (
                content:find("HealIQ = HealIQ or {}") or
                content:find("local addonName, HealIQ = ...") or
                content:find("HealIQ%.Rules = HealIQ%.Rules or {}")
            )
            
            if not has_defensive then
                table.insert(errors, rule_file .. " lacks defensive initialization")
            end
        end
    end
    
    if #errors > 0 then
        print("❌ RULE FILE VALIDATION FAILED:")
        for _, error in ipairs(errors) do
            print("   • " .. error)
        end
        return false
    else
        print("✅ Rule file validation passed!")
        print(string.format("   • All %d rule files have defensive initialization", #rule_files))
        return true
    end
end

local function main()
    print("=== HealIQ Loading Order Regression Test ===")
    print("This test validates the fix for issue #98:")
    print("'Error loading Interface/AddOns/HealIQ/rules/BaseRule.lua'")
    print("")
    
    local success1 = validate_loading_order()
    print("")
    local success2 = validate_rule_files()
    print("")
    
    if success1 and success2 then
        print("🎉 ALL TESTS PASSED!")
        print("✅ The .toc loading order issue has been fixed")
        print("✅ Rule files are protected against loading failures")
        print("✅ Regression protection is in place")
        return true
    else
        print("💥 TESTS FAILED!")
        print("❌ Loading order issue may have regressed")
        print("❌ Manual intervention required")
        return false
    end
end

-- Run the test
local success = main()
os.exit(success and 0 or 1)
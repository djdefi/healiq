#!/usr/bin/env lua
-- HealIQ Test Runner for CI
-- This script can run HealIQ tests in a CI environment without WoW

-- Mock WoW API and globals for testing
local function setupMockEnvironment()
    -- Mock global functions that HealIQ might use
    _G.print = print
    _G.error = error
    _G.type = type
    _G.pairs = pairs
    _G.ipairs = ipairs
    _G.table = table
    _G.string = string
    _G.math = math
    _G.tostring = tostring
    
    -- Mock basic WoW API functions
    _G.GetAddOnMetadata = function(addon, field)
        if addon == "HealIQ" and field == "Version" then
            return "0.0.25"
        end
        return nil
    end
    
    -- Mock saved variables
    _G.HealIQDB = {}
    
    -- Mock slash commands (just empty tables)
    _G.SLASH_HEALIQ1 = "/healiq"
    _G.SlashCmdList = {}
end

-- Load and initialize the addon in a controlled environment
local function loadAddon()
    setupMockEnvironment()
    
    -- Create addon namespace
    local addonName = "HealIQ"
    local HealIQ = {}
    _G[addonName] = HealIQ
    
    -- Set version
    HealIQ.version = "0.0.25"
    
    -- Mock essential functions
    HealIQ.SafeCall = function(self, func)
        local success, result = pcall(func)
        if not success then
            print("Error in SafeCall: " .. tostring(result))
        end
        return success, result
    end
    
    HealIQ.Print = function(self, message)
        print("HealIQ: " .. tostring(message))
    end
    
    HealIQ.DebugLog = function(self, message, level)
        -- Silent in tests unless debug enabled
    end
    
    HealIQ.Message = function(self, message)
        print("HealIQ: " .. tostring(message))
    end
    
    -- Mock database
    HealIQ.db = {
        debug = false,
        ui = {
            scale = 1.0,
            opacity = 1.0
        },
        general = {
            debug = false
        }
    }
    
    -- Mock UI module
    HealIQ.UI = {
        GetFrameInfo = function()
            return {
                scale = 1.0,
                opacity = 1.0
            }
        end
    }
    
    -- Mock Config module
    HealIQ.Config = {
        GetOption = function(self, category, option)
            if category == "general" and option == "debug" then
                return HealIQ.db.general.debug
            end
            return nil
        end,
        SetOption = function(self, category, option, value)
            if category == "general" and option == "debug" then
                HealIQ.db.general.debug = value
            end
        end
    }
    
    -- Mock Tracker module
    HealIQ.Tracker = {
        Initialize = function() end,
        IsSpellKnown = function(self, spellName)
            -- Mock some known spells for druids
            local knownSpells = {
                ["Rejuvenation"] = true,
                ["Regrowth"] = true,
                ["Healing Touch"] = true
            }
            return knownSpells[spellName] or false
        end
    }
    
    return HealIQ
end

-- Run the tests
local function runTests()
    print("=== HealIQ CI Test Runner ===")
    
    -- Load addon
    local HealIQ = loadAddon()
    if not HealIQ then
        print("ERROR: Failed to load HealIQ addon")
        return false
    end
    
    -- Load the test module
    local testFile = "Tests.lua"
    local testChunk, err = loadfile(testFile)
    if not testChunk then
        print("ERROR: Failed to load " .. testFile .. ": " .. tostring(err))
        return false
    end
    
    -- Execute the test file in our environment
    local success, result = pcall(testChunk, "HealIQ", HealIQ)
    if not success then
        print("ERROR: Failed to execute " .. testFile .. ": " .. tostring(result))
        return false
    end
    
    -- Run the tests
    if HealIQ.Tests then
        print("Running HealIQ tests...")
        HealIQ.Tests:RunAll()
        return true
    else
        print("ERROR: Test module not loaded properly")
        return false
    end
end

-- Main execution
local function main()
    local success = runTests()
    if success then
        print("Test execution completed")
        os.exit(0)
    else
        print("Test execution failed")
        os.exit(1)
    end
end

-- Run if this is the main script
if arg and arg[0] and arg[0]:match("test_runner%.lua$") then
    main()
end
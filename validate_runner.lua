#!/usr/bin/env lua
-- HealIQ Quick Validation Runner for CI
-- This script runs quick validation checks on HealIQ

-- Mock environment (reuse from test_runner.lua)
local function setupMockEnvironment()
    _G.print = print
    _G.error = error
    _G.type = type
    _G.pairs = pairs
    _G.ipairs = ipairs
    _G.table = table
    _G.string = string
    _G.math = math
    _G.tostring = tostring

    _G.GetAddOnMetadata = function(addon, field)
        if addon == "HealIQ" and field == "Version" then
            return "0.0.25"
        end
        return nil
    end

    _G.HealIQDB = {}
    _G.SLASH_HEALIQ1 = "/healiq"
    _G.SlashCmdList = {}
end

local function loadAddon()
    setupMockEnvironment()

    local addonName = "HealIQ"
    local HealIQ = {}
    _G[addonName] = HealIQ

    HealIQ.version = "0.0.25"

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

    HealIQ.DebugLog = function(self, message, level) end
    HealIQ.Message = function(self, message)
        print("HealIQ: " .. tostring(message))
    end

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

    HealIQ.UI = {
        GetFrameInfo = function()
            return { scale = 1.0, opacity = 1.0 }
        end
    }

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

    HealIQ.Tracker = {
        Initialize = function() end,
        IsSpellKnown = function(self, spellName)
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

local function runValidation()
    print("=== HealIQ CI Quick Validation ===")

    local HealIQ = loadAddon()
    if not HealIQ then
        print("ERROR: Failed to load HealIQ addon")
        return false
    end

    local testFile = "Tests.lua"
    local testChunk, err = loadfile(testFile)
    if not testChunk then
        print("ERROR: Failed to load " .. testFile .. ": " .. tostring(err))
        return false
    end

    local success, result = pcall(testChunk, "HealIQ", HealIQ)
    if not success then
        print("ERROR: Failed to execute " .. testFile .. ": " .. tostring(result))
        return false
    end

    if HealIQ.Tests then
        print("Running quick validation...")
        local validationPassed = HealIQ.Tests:RunQuickValidation()
        return validationPassed
    else
        print("ERROR: Test module not loaded properly")
        return false
    end
end

local function main()
    local success = runValidation()
    if success then
        print("Quick validation completed successfully")
        os.exit(0)
    else
        print("Quick validation failed")
        os.exit(1)
    end
end

if arg and arg[0] and arg[0]:match("validate_runner%.lua$") then
    main()
end

#!/usr/bin/env lua
-- Enhanced Test Runner for HealIQ with WoW API Mocking
-- Runs comprehensive tests including mocked WoW API functionality

-- Add current directory to package path for WoWAPIMock
package.path = package.path .. ";./?;./?.lua"

-- Load WoW API Mock first
local WoWAPIMock = dofile("WoWAPIMock.lua")

-- Mock WoW addon environment
local addonName = "HealIQ"
local HealIQ = {
    version = "0.0.25",
    debug = true,
    db = {
        enabled = true,
        ui = {
            scale = 1.0,
            position = {x = 0, y = 0},
            locked = false,
            showOnMinimapButton = true
        },
        rules = {
            emergencyHealthThreshold = 0.3,
            lowHealthThreshold = 0.5,
            enableAutoCasting = true
        },
        strategy = {
            prioritizeByHealth = true,
            considerBuffs = true,
            checkCooldowns = true
        }
    },
    sessionStats = {
        suggestions = 0,
        rulesProcessed = 0,
        errorsLogged = 0,
        eventsHandled = 0,
        startTime = os.time(),
        ruleTriggers = {}
    }
}

-- Mock addon globals
_G[addonName] = HealIQ

-- Install WoW API mocks
WoWAPIMock.Install()

-- Add additional WoW API mocks needed for addon functionality
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SLASH_HEALIQ1 = "/healiq"
_G.SLASH_HEALIQ2 = "/hiq"
_G.date = os.date
_G.time = os.time
_G.debugstack = function() return debug.traceback() end
_G.geterrorhandler = function() return function(err) print("Error:", err) end end

-- SafeCall implementation
function HealIQ:SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        print("Error: " .. tostring(result))
        if self.sessionStats then
            self.sessionStats.errorsLogged = (self.sessionStats.errorsLogged or 0) + 1
        end
    end
    return success, result
end

-- Print implementation
function HealIQ:Print(message)
    print("[HealIQ] " .. tostring(message))
end

-- DebugLog implementation
function HealIQ:DebugLog(message, level)
    if self.debug then
        local prefix = level and ("[" .. level .. "]") or "[DEBUG]"
        print("[HealIQ] " .. prefix .. " " .. tostring(message))
    end
end

-- LogError implementation
function HealIQ:LogError(message)
    print("[HealIQ] [ERROR] " .. tostring(message))
    if self.sessionStats then
        self.sessionStats.errorsLogged = (self.sessionStats.errorsLogged or 0) + 1
    end
end

-- LogRuleTrigger implementation
function HealIQ:LogRuleTrigger(ruleName)
    if self.sessionStats then
        self.sessionStats.ruleTriggers = self.sessionStats.ruleTriggers or {}
        self.sessionStats.ruleTriggers[ruleName] = (self.sessionStats.ruleTriggers[ruleName] or 0) + 1
        self.sessionStats.rulesProcessed = (self.sessionStats.rulesProcessed or 0) + 1
    end
end

-- LogSuggestionMade implementation
function HealIQ:LogSuggestionMade()
    if self.sessionStats then
        self.sessionStats.suggestions = (self.sessionStats.suggestions or 0) + 1
    end
end

-- Mock additional functions that might be called
function HealIQ:InitializeSessionStats()
    if not self.sessionStats then
        self.sessionStats = {}
    end
    self.sessionStats.startTime = os.time()
    self.sessionStats.suggestions = self.sessionStats.suggestions or 0
    self.sessionStats.rulesProcessed = self.sessionStats.rulesProcessed or 0
    self.sessionStats.errorsLogged = self.sessionStats.errorsLogged or 0
    self.sessionStats.eventsHandled = self.sessionStats.eventsHandled or 0
    self.sessionStats.ruleTriggers = self.sessionStats.ruleTriggers or {}
end

function HealIQ:GenerateDiagnosticDump()
    local dump = "=== HealIQ Diagnostic Dump ===\n"
    dump = dump .. "Version: " .. (self.version or "unknown") .. "\n"
    dump = dump .. "Debug Mode: " .. tostring(self.debug) .. "\n"
    dump = dump .. "Database Loaded: " .. tostring(self.db ~= nil) .. "\n"
    if self.sessionStats then
        dump = dump .. "Session Stats:\n"
        for key, value in pairs(self.sessionStats) do
            dump = dump .. "  " .. key .. ": " .. tostring(value) .. "\n"
        end
    end
    dump = dump .. "=== End Diagnostic Dump ===\n"
    return dump
end

function HealIQ:CountSettings()
    local count = 0
    if self.db then
        local function countTable(t)
            local c = 0
            for k, v in pairs(t) do
                c = c + 1
                if type(v) == "table" then
                    c = c + countTable(v)
                end
            end
            return c
        end
        count = countTable(self.db)
    end
    return count
end

function HealIQ:OnVersionUpgrade(oldVersion, newVersion)
    self:Print("Upgrading from version " .. tostring(oldVersion) .. " to " .. tostring(newVersion))
    return true
end

function HealIQ:FormatDuration(seconds)
    if seconds < 60 then
        return string.format("%.1fs", seconds)
    elseif seconds < 3600 then
        return string.format("%.1fm", seconds / 60)
    else
        return string.format("%.1fh", seconds / 3600)
    end
end

-- Load addon modules with proper addon environment simulation
local function loadAddonModule(filename, moduleAddonName, addonTable)
    local env = setmetatable({}, {__index = _G})
    local chunk = loadfile(filename, "t", env)
    if chunk then
        -- Simulate the ... parameters that WoW passes to addon files
        return chunk(moduleAddonName, addonTable)
    else
        error("Failed to load " .. filename)
    end
end

-- Load addon modules with proper environment
loadAddonModule("Core.lua", addonName, HealIQ)
loadAddonModule("Config.lua", addonName, HealIQ)
loadAddonModule("Logging.lua", addonName, HealIQ)
loadAddonModule("Engine.lua", addonName, HealIQ)
loadAddonModule("UI.lua", addonName, HealIQ)
loadAddonModule("Tracker.lua", addonName, HealIQ)
loadAddonModule("Tests.lua", addonName, HealIQ)

-- Initialize modules
if HealIQ.Core and HealIQ.Core.Initialize then
    HealIQ.Core:Initialize()
end

if HealIQ.Config and HealIQ.Config.Initialize then
    HealIQ.Config:Initialize()
end

-- Run enhanced tests
print("=== Running Enhanced HealIQ Tests with WoW API Mocking ===")
print("Coverage Target: 40%+ overall, 60%+ for testable modules")
print("")

local totalTests, passedTests = HealIQ.Tests.RunAllTestsEnhanced()

print("\n=== Test Coverage Assessment ===")
print("With WoW API mocking, we can now test:")
print("• Engine logic with simulated game state")
print("• UI frame creation and manipulation")
print("• Tracker functions with mock buffs/combat")
print("• Configuration management with state changes")
print("")

-- Calculate expected coverage improvement
local expectedCoverage = {
    ["Overall"] = "35-45%",
    ["Core.lua"] = "70%+",
    ["Config.lua"] = "50%+",
    ["Logging.lua"] = "85%+",
    ["Engine.lua"] = "45%+",
    ["UI.lua"] = "25%+",
    ["Tracker.lua"] = "30%+"
}

print("=== Expected Coverage Improvements ===")
for module, target in pairs(expectedCoverage) do
    print(string.format("%-12s: %s", module, target))
end

print("\n=== Critical Coverage Thresholds ===")
print("🟢 Excellent (80%+): Pure utility functions")
print("🟡 Good (60-80%):    Business logic modules")
print("🟠 Acceptable (40-60%): Mixed logic with WoW dependencies")
print("🔴 Poor (<40%):       UI-heavy or combat-dependent code")

local success = passedTests == totalTests
if success then
    print("\n✅ All tests passed! Enhanced test coverage should significantly improve metrics.")
else
    print(string.format("\n❌ %d tests failed. See details above.", totalTests - passedTests))
end

os.exit(success and 0 or 1)
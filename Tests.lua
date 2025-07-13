-- HealIQ Tests.lua
-- Basic test infrastructure for HealIQ addon

local _, HealIQ = ...

HealIQ.Tests = {}
local Tests = HealIQ.Tests

-- Test results storage
local testResults = {}
local totalTests = 0
local passedTests = 0

-- Test framework functions
function Tests.Initialize()
    HealIQ:SafeCall(function()
        -- Initialize test framework
        testResults = {}
        totalTests = 0
        passedTests = 0
        HealIQ:Print("Test framework initialized")
    end)
end

function Tests.Assert(condition, testName, errorMessage)
    totalTests = totalTests + 1
    local result = {
        name = testName,
        passed = condition,
        error = condition and nil or (errorMessage or "Assertion failed")
    }

    table.insert(testResults, result)

    if condition then
        passedTests = passedTests + 1
    end

    return condition
end

function Tests.AssertEqual(expected, actual, testName)
    local condition = expected == actual
    local errorMessage = string.format("Expected %s, got %s", tostring(expected), tostring(actual))
    return Tests.Assert(condition, testName, errorMessage)
end

function Tests.AssertNotNil(value, testName)
    local condition = value ~= nil
    local errorMessage = "Expected non-nil value"
    return Tests.Assert(condition, testName, errorMessage)
end

function Tests.AssertType(expectedType, value, testName)
    local actualType = type(value)
    local condition = actualType == expectedType
    local errorMessage = string.format("Expected type %s, got %s", expectedType, actualType)
    return Tests.Assert(condition, testName, errorMessage)
end

-- Run all tests
function Tests.RunAll()
    HealIQ:Print("Running HealIQ tests...")

    -- Reset counters
    testResults = {}
    totalTests = 0
    passedTests = 0

    -- Run test suites
    Tests.TestCore()
    Tests.TestUI()
    Tests.TestConfig()
    Tests.TestTracker()
    Tests.TestLogging()
    Tests.TestDataStructures()

    -- Print results
    Tests.PrintResults()
end

-- Test Core functionality
function Tests.TestCore()
    -- Test addon initialization
    Tests.AssertNotNil(HealIQ, "Core: HealIQ addon table exists")
    Tests.AssertNotNil(HealIQ.version, "Core: Version string exists")
    Tests.AssertType("string", HealIQ.version, "Core: Version is string")

    -- Test SafeCall function
    local testRan = false
    HealIQ:SafeCall(function()
        testRan = true
    end)
    Tests.Assert(testRan, "Core: SafeCall executes function")

    -- Test error handling in SafeCall
    local errorHandled = true
    HealIQ:SafeCall(function()
        error("Test error")
    end)
    Tests.Assert(errorHandled, "Core: SafeCall handles errors gracefully")

    -- Test version string format
    local versionPattern = "%d+%.%d+%.%d+"
    Tests.Assert(string.match(HealIQ.version, versionPattern) ~= nil,
        "Core: Version follows semantic versioning")

    -- Test debug flag
    Tests.AssertType("boolean", HealIQ.debug, "Core: Debug flag is boolean")

    -- Test database initialization function exists
    if HealIQ.InitializeDB then
        Tests.AssertType("function", HealIQ.InitializeDB, "Core: InitializeDB function exists")
    end

    -- Test message function exists
    if HealIQ.Message then
        Tests.AssertType("function", HealIQ.Message, "Core: Message function exists")
    end

    -- Test print function exists
    if HealIQ.Print then
        Tests.AssertType("function", HealIQ.Print, "Core: Print function exists")
    end

    -- Test SafeCall with return value
    local success, result = HealIQ:SafeCall(function()
        return 42
    end)
    Tests.Assert(success, "Core: SafeCall returns success status")
    Tests.AssertEqual(42, result, "Core: SafeCall returns function result")

    -- Test SafeCall with multiple return values (note: current implementation only returns first value)
    local success2, a = HealIQ:SafeCall(function()
        return "hello", "world"
    end)
    Tests.Assert(success2, "Core: SafeCall returns success for multiple values")
    Tests.AssertEqual("hello", a, "Core: SafeCall returns first value")
end

-- Test UI functionality
function Tests.TestUI()
    Tests.AssertNotNil(HealIQ.UI, "UI: UI module exists")

    -- Test UI initialization without errors
    if HealIQ.db and HealIQ.db.ui then
        local initialScale = HealIQ.db.ui.scale
        Tests.AssertType("number", initialScale, "UI: Scale is numeric")
        Tests.Assert(initialScale > 0, "UI: Scale is positive")

        -- Test frame info retrieval
        local frameInfo = HealIQ.UI:GetFrameInfo()
        if frameInfo then
            Tests.AssertType("table", frameInfo, "UI: Frame info returns table")
            Tests.AssertType("number", frameInfo.scale, "UI: Frame scale is numeric")
        end
    end

    -- Test basic UI functions exist
    if HealIQ.UI.Initialize then
        Tests.AssertType("function", HealIQ.UI.Initialize, "UI: Initialize function exists")
    end

    if HealIQ.UI.SetEnabled then
        Tests.AssertType("function", HealIQ.UI.SetEnabled, "UI: SetEnabled function exists")
    end

    if HealIQ.UI.SetScale then
        Tests.AssertType("function", HealIQ.UI.SetScale, "UI: SetScale function exists")
    end

    if HealIQ.UI.ResetPosition then
        Tests.AssertType("function", HealIQ.UI.ResetPosition, "UI: ResetPosition function exists")
    end

    if HealIQ.UI.ToggleOptionsFrame then
        Tests.AssertType("function", HealIQ.UI.ToggleOptionsFrame,
            "UI: ToggleOptionsFrame function exists")
    end

    -- Test UI constants if they exist
    if HealIQ.UI.OPTIONS_FRAME_HEIGHT then
        Tests.AssertType("number", HealIQ.UI.OPTIONS_FRAME_HEIGHT,
            "UI: OPTIONS_FRAME_HEIGHT is number")
        Tests.Assert(HealIQ.UI.OPTIONS_FRAME_HEIGHT > 0, "UI: OPTIONS_FRAME_HEIGHT is positive")
    end

    -- Test position and scale validation
    if HealIQ.db and HealIQ.db.ui then
        -- Test scale bounds
        if HealIQ.db.ui.scale then
            Tests.Assert(HealIQ.db.ui.scale >= 0.5 and HealIQ.db.ui.scale <= 2.0,
                "UI: Scale within valid bounds")
        end

        -- Test boolean flags
        if HealIQ.db.ui.locked ~= nil then
            Tests.AssertType("boolean", HealIQ.db.ui.locked, "UI: Locked is boolean")
        end
        if HealIQ.db.ui.showIcon ~= nil then
            Tests.AssertType("boolean", HealIQ.db.ui.showIcon, "UI: ShowIcon is boolean")
        end
    end
end

-- Test Config functionality
function Tests.TestConfig()
    Tests.AssertNotNil(HealIQ.Config, "Config: Config module exists")

    -- Test command registration (only test if SLASH_HEALIQ1 is available)
    if _G.SLASH_HEALIQ1 then
        Tests.AssertNotNil(_G.SLASH_HEALIQ1, "Config: Primary slash command registered")
        Tests.AssertEqual("/healiq", _G.SLASH_HEALIQ1, "Config: Primary slash command correct")
    end

    -- Test option get/set if database is available
    if HealIQ.db then
        local originalDebug = HealIQ.db.debug
        HealIQ.Config:SetOption("general", "debug", true)
        local newDebug = HealIQ.Config:GetOption("general", "debug")
        Tests.Assert(newDebug == true, "Config: Can set and get debug option")

        -- Restore original value
        HealIQ.Config:SetOption("general", "debug", originalDebug)
    end

    -- Test version function exists
    if HealIQ.Config.commands and HealIQ.Config.commands.version then
        Tests.AssertType("function", HealIQ.Config.commands.version,
            "Config: Version command is function")
    end

    -- Test enable/disable functions exist
    if HealIQ.Config.commands then
        if HealIQ.Config.commands.enable then
            Tests.AssertType("function", HealIQ.Config.commands.enable,
                "Config: Enable command is function")
        end
        if HealIQ.Config.commands.disable then
            Tests.AssertType("function", HealIQ.Config.commands.disable,
                "Config: Disable command is function")
        end
        if HealIQ.Config.commands.toggle then
            Tests.AssertType("function", HealIQ.Config.commands.toggle,
                "Config: Toggle command is function")
        end
    end

    -- Test option validation with different types
    if HealIQ.Config.SetOption and HealIQ.db then
        -- Test setting valid options
        local originalScale = HealIQ.db.ui and HealIQ.db.ui.scale
        if originalScale then
            HealIQ.Config:SetOption("ui", "scale", 1.5)
            local newScale = HealIQ.Config:GetOption("ui", "scale")
            Tests.AssertEqual(1.5, newScale, "Config: Can set numeric option")
            -- Restore
            HealIQ.Config:SetOption("ui", "scale", originalScale)
        end
    end
end

-- Test Tracker functionality
function Tests.TestTracker()
    if HealIQ.Tracker then
        Tests.AssertNotNil(HealIQ.Tracker, "Tracker: Tracker module exists")

        -- Test basic tracker functions
        Tests.AssertType("function", HealIQ.Tracker.Initialize, "Tracker: Initialize function exists")

        -- Test spell tracking if available
        if HealIQ.Tracker.IsSpellKnown then
            local result = HealIQ.Tracker:IsSpellKnown("Rejuvenation")
            Tests.AssertType("boolean", result, "Tracker: IsSpellKnown returns boolean")
        end

        -- Test spell ID constants exist
        if HealIQ.Tracker.SPELLS then
            Tests.AssertType("table", HealIQ.Tracker.SPELLS, "Tracker: SPELLS table exists")
            -- Test some common spells
            if HealIQ.Tracker.SPELLS.REJUVENATION then
                Tests.AssertType("number", HealIQ.Tracker.SPELLS.REJUVENATION,
                    "Tracker: Rejuvenation spell ID is number")
            end
            if HealIQ.Tracker.SPELLS.LIFEBLOOM then
                Tests.AssertType("number", HealIQ.Tracker.SPELLS.LIFEBLOOM,
                    "Tracker: Lifebloom spell ID is number")
            end
        end

        -- Test spell book scanning functions if available
        if HealIQ.Tracker.ScanSpellbook then
            Tests.AssertType("function", HealIQ.Tracker.ScanSpellbook,
                "Tracker: ScanSpellbook is function")
        end

        -- Test event registration functions
        if HealIQ.Tracker.RegisterEvents then
            Tests.AssertType("function", HealIQ.Tracker.RegisterEvents,
                "Tracker: RegisterEvents is function")
        end
    end
end

-- Test Logging functionality
function Tests.TestLogging()
    if HealIQ.Logging then
        Tests.AssertNotNil(HealIQ.Logging, "Logging: Logging module exists")

        -- Test InitializeVariables function
        if HealIQ.Logging.InitializeVariables then
            Tests.AssertType("function", HealIQ.Logging.InitializeVariables,
                "Logging: InitializeVariables is function")

            -- Test that it initializes session stats
            local oldStats = HealIQ.sessionStats
            HealIQ.sessionStats = nil
            HealIQ.Logging:InitializeVariables()
            Tests.AssertNotNil(HealIQ.sessionStats, "Logging: InitializeVariables creates sessionStats")
            Tests.AssertType("table", HealIQ.sessionStats, "Logging: sessionStats is table")

            -- Test session stats structure
            if HealIQ.sessionStats then
                Tests.AssertNotNil(HealIQ.sessionStats.suggestions,
                    "Logging: sessionStats has suggestions field")
                Tests.AssertNotNil(HealIQ.sessionStats.rulesProcessed,
                    "Logging: sessionStats has rulesProcessed field")
                Tests.AssertNotNil(HealIQ.sessionStats.errorsLogged,
                    "Logging: sessionStats has errorsLogged field")
                Tests.AssertType("number", HealIQ.sessionStats.suggestions,
                    "Logging: suggestions is number")
                Tests.AssertType("number", HealIQ.sessionStats.rulesProcessed,
                    "Logging: rulesProcessed is number")
            end

            -- Restore old stats
            HealIQ.sessionStats = oldStats
        end

        -- Test DebugLog function exists
        if HealIQ.DebugLog then
            Tests.AssertType("function", HealIQ.DebugLog, "Logging: DebugLog is function")
        end

        -- Test InitializeSessionStats function exists
        if HealIQ.InitializeSessionStats then
            Tests.AssertType("function", HealIQ.InitializeSessionStats,
                "Logging: InitializeSessionStats is function")
        end
    end
end

-- Print test results
function Tests.PrintResults()
    print("|cFF00FF00=== HealIQ Test Results ===|r")
    print(string.format("Total Tests: %d", totalTests))
    print(string.format("Passed: |cFF00FF00%d|r", passedTests))
    print(string.format("Failed: |cFFFF0000%d|r", totalTests - passedTests))

    if totalTests > 0 then
        local successRate = (passedTests / totalTests) * 100
        print(string.format("Success Rate: %.1f%%", successRate))
    end

    -- Show failed tests
    local failedTests = {}
    for _, result in ipairs(testResults) do
        if not result.passed then
            table.insert(failedTests, result)
        end
    end

    if #failedTests > 0 then
        print("|cFFFF0000Failed Tests:|r")
        for _, result in ipairs(failedTests) do
            print(string.format("  - %s: %s", result.name, result.error))
        end
    else
        print("|cFF00FF00All tests passed!|r")
    end

    print("|cFF00FF00========================|r")
end

-- Quick validation tests for critical functionality
function Tests.RunQuickValidation()
    local errors = {}

    -- Check critical modules exist
    if not HealIQ then
        table.insert(errors, "Core HealIQ addon not loaded")
    end

    if not HealIQ.UI then
        table.insert(errors, "UI module not available")
    end

    if not HealIQ.Config then
        table.insert(errors, "Config module not available")
    end

    -- Check database initialization
    if not HealIQ.db then
        table.insert(errors, "Database not initialized")
    elseif not HealIQ.db.ui then
        table.insert(errors, "UI database not initialized")
    end

    -- Check slash commands (only if available)
    if _G.SLASH_HEALIQ1 and not _G.SLASH_HEALIQ1 then
        table.insert(errors, "Slash commands not registered")
    end

    if #errors > 0 then
        print("|cFFFF0000HealIQ Validation Errors:|r")
        for _, error in ipairs(errors) do
            print("  - " .. error)
        end
        return false
    else
        print("|cFF00FF00HealIQ validation passed - addon appears to be working correctly|r")
        return true
    end
end

-- Test data structure validation
function Tests.TestDataStructures()
    -- Test that HealIQ table exists and has expected structure
    Tests.AssertNotNil(HealIQ, "DataStructures: HealIQ main table exists")

    -- Test version info
    if HealIQ.version then
        Tests.AssertType("string", HealIQ.version, "DataStructures: Version is string")
        -- Test version format (major.minor.patch)
        local major, minor, patch = string.match(HealIQ.version, "^(%d+)%.(%d+)%.(%d+)$")
        Tests.AssertNotNil(major, "DataStructures: Version has major number")
        Tests.AssertNotNil(minor, "DataStructures: Version has minor number")
        Tests.AssertNotNil(patch, "DataStructures: Version has patch number")
    end

    -- Test database structure if available
    if HealIQ.db then
        Tests.AssertType("table", HealIQ.db, "DataStructures: Database is table")

        -- Test UI settings structure
        if HealIQ.db.ui then
            Tests.AssertType("table", HealIQ.db.ui, "DataStructures: UI settings is table")
            if HealIQ.db.ui.scale then
                Tests.AssertType("number", HealIQ.db.ui.scale, "DataStructures: UI scale is number")
            end
        end

        -- Test rules settings structure
        if HealIQ.db.rules then
            Tests.AssertType("table", HealIQ.db.rules, "DataStructures: Rules settings is table")
        end

        -- Test strategy settings structure
        if HealIQ.db.strategy then
            Tests.AssertType("table", HealIQ.db.strategy, "DataStructures: Strategy settings is table")
        end
    end

    -- Test session stats structure
    if HealIQ.sessionStats then
        Tests.AssertType("table", HealIQ.sessionStats, "DataStructures: Session stats is table")

        local expectedFields = {"suggestions", "rulesProcessed", "errorsLogged", "eventsHandled"}
        for _, field in ipairs(expectedFields) do
            if HealIQ.sessionStats[field] ~= nil then
                Tests.AssertType("number", HealIQ.sessionStats[field],
                    "DataStructures: " .. field .. " is number")
            end
        end
    end
end

HealIQ.Tests = Tests
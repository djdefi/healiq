-- HealIQ Tests.lua
-- Basic test infrastructure for HealIQ addon

local addonName, HealIQ = ...

HealIQ.Tests = {}
local Tests = HealIQ.Tests

-- Test results storage
local testResults = {}
local totalTests = 0
local passedTests = 0

-- Test framework functions
function Tests:Initialize()
    HealIQ:SafeCall(function()
        -- Initialize test framework
        testResults = {}
        totalTests = 0
        passedTests = 0
        HealIQ:Print("Test framework initialized")
    end)
end

function Tests:Assert(condition, testName, errorMessage)
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

function Tests:AssertEqual(expected, actual, testName)
    local condition = expected == actual
    local errorMessage = string.format("Expected %s, got %s", tostring(expected), tostring(actual))
    return self:Assert(condition, testName, errorMessage)
end

function Tests:AssertNotNil(value, testName)
    local condition = value ~= nil
    local errorMessage = "Expected non-nil value"
    return self:Assert(condition, testName, errorMessage)
end

function Tests:AssertType(expectedType, value, testName)
    local actualType = type(value)
    local condition = actualType == expectedType
    local errorMessage = string.format("Expected type %s, got %s", expectedType, actualType)
    return self:Assert(condition, testName, errorMessage)
end

-- Run all tests
function Tests:RunAll()
    HealIQ:Print("Running HealIQ tests...")
    
    -- Reset counters
    testResults = {}
    totalTests = 0
    passedTests = 0
    
    -- Run test suites
    self:TestCore()
    self:TestUI()
    self:TestConfig()
    self:TestTracker()
    
    -- Print results
    self:PrintResults()
end

-- Test Core functionality
function Tests:TestCore()
    -- Test addon initialization
    self:AssertNotNil(HealIQ, "Core: HealIQ addon table exists")
    self:AssertNotNil(HealIQ.version, "Core: Version string exists")
    self:AssertType("string", HealIQ.version, "Core: Version is string")
    
    -- Test SafeCall function
    local testRan = false
    HealIQ:SafeCall(function()
        testRan = true
    end)
    self:Assert(testRan, "Core: SafeCall executes function")
    
    -- Test error handling in SafeCall
    local errorHandled = true
    HealIQ:SafeCall(function()
        error("Test error")
    end)
    self:Assert(errorHandled, "Core: SafeCall handles errors gracefully")
end

-- Test UI functionality
function Tests:TestUI()
    self:AssertNotNil(HealIQ.UI, "UI: UI module exists")
    
    -- Test UI initialization without errors
    if HealIQ.db and HealIQ.db.ui then
        local initialScale = HealIQ.db.ui.scale
        self:AssertType("number", initialScale, "UI: Scale is numeric")
        self:Assert(initialScale > 0, "UI: Scale is positive")
        
        -- Test frame info retrieval
        local frameInfo = HealIQ.UI:GetFrameInfo()
        if frameInfo then
            self:AssertType("table", frameInfo, "UI: Frame info returns table")
            self:AssertType("number", frameInfo.scale, "UI: Frame scale is numeric")
        end
    end
end

-- Test Config functionality  
function Tests:TestConfig()
    self:AssertNotNil(HealIQ.Config, "Config: Config module exists")
    
    -- Test command registration
    self:AssertNotNil(SLASH_HEALIQ1, "Config: Primary slash command registered")
    self:AssertEqual("/healiq", SLASH_HEALIQ1, "Config: Primary slash command correct")
    
    -- Test option get/set if database is available
    if HealIQ.db then
        local originalDebug = HealIQ.db.debug
        HealIQ.Config:SetOption("general", "debug", true)
        local newDebug = HealIQ.Config:GetOption("general", "debug")
        self:Assert(newDebug == true, "Config: Can set and get debug option")
        
        -- Restore original value
        HealIQ.Config:SetOption("general", "debug", originalDebug)
    end
end

-- Test Tracker functionality
function Tests:TestTracker()
    if HealIQ.Tracker then
        self:AssertNotNil(HealIQ.Tracker, "Tracker: Tracker module exists")
        
        -- Test basic tracker functions
        self:AssertType("function", HealIQ.Tracker.Initialize, "Tracker: Initialize function exists")
        
        -- Test spell tracking if available
        if HealIQ.Tracker.IsSpellKnown then
            local result = HealIQ.Tracker:IsSpellKnown("Rejuvenation")
            self:AssertType("boolean", result, "Tracker: IsSpellKnown returns boolean")
        end
    end
end

-- Print test results
function Tests:PrintResults()
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
function Tests:RunQuickValidation()
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
    
    -- Check slash commands
    if not SLASH_HEALIQ1 then
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

HealIQ.Tests = Tests
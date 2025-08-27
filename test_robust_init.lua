#!/usr/bin/env lua
-- HealIQ Robust Initialization Test
-- Test to verify the new initialization system prevents TOC loading errors
-- This test simulates more realistic WoW loading conditions

local function print_result(passed, message)
    if passed then
        print("✅ " .. message)
    else
        print("❌ " .. message)
        error("Test failed: " .. message)
    end
end

-- Test 1: Verify Init.lua can be loaded independently
local function test_independent_init_loading()
    print("\n=== Testing Independent Init.lua Loading ===")

    -- Clear any existing global state
    _G.HealIQ = nil

    -- Try to load Init.lua in isolation
    local success, error = pcall(dofile, "Init.lua")

    print_result(success, "Init.lua loads independently without errors")

    if success then
        print_result(_G.HealIQ ~= nil, "Init.lua creates HealIQ global object")
        print_result(type(_G.HealIQ) == "table", "HealIQ is a valid table")
        print_result(_G.HealIQ.InitRegistry ~= nil, "InitRegistry system is available")
        print_result(type(_G.HealIQ.SafeCall) == "function", "SafeCall function is available")
    end

    return success
end

-- Test 2: Verify files can load out of order
local function test_out_of_order_loading()
    print("\n=== Testing Out-of-Order Loading Resilience ===")

    -- Clear state
    _G.HealIQ = nil

    -- Load Init.lua first (this should work)
    local init_success, init_error = pcall(dofile, "Init.lua")
    print_result(init_success, "Init.lua loads first successfully")

    if not init_success then
        print("Init error: " .. tostring(init_error))
        return false
    end

    -- Try loading BaseRule.lua before other components
    local baserule_success, baserule_error = pcall(dofile, "rules/BaseRule.lua")
    print_result(baserule_success, "BaseRule.lua loads after Init.lua without Core.lua")

    if not baserule_success then
        print("BaseRule error: " .. tostring(baserule_error))
    end

    -- Try loading Core.lua after BaseRule
    local core_success, core_error = pcall(dofile, "Core.lua")
    print_result(core_success, "Core.lua loads after BaseRule.lua")

    if not core_success then
        print("Core error: " .. tostring(core_error))
    end

    -- Check that initialization system is working
    if _G.HealIQ and _G.HealIQ.InitRegistry then
        local status = _G.HealIQ.InitRegistry:GetStatus()
        print_result(status.totalComponents > 0, "Components are registered with init system")
        print("  Registered components: " .. tostring(status.totalComponents))
        print("  Initialized components: " .. tostring(status.initializedComponents))
    end

    return baserule_success and core_success
end

-- Test 3: Verify error recovery
local function test_error_recovery()
    print("\n=== Testing Error Recovery ===")

    -- Clear state
    _G.HealIQ = nil

    -- Load Init.lua
    local success = pcall(dofile, "Init.lua")
    print_result(success, "Init.lua loaded for error recovery test")

    if not success or not _G.HealIQ then
        return false
    end

    -- Register a component that will fail
    local failureRegistered = _G.HealIQ.InitRegistry:RegisterComponent("test_failure", function()
        error("Intentional test failure")
    end, {})

    print_result(failureRegistered, "Failing component registered successfully")

    -- Register a component that will succeed
    local successRegistered = _G.HealIQ.InitRegistry:RegisterComponent("test_success", function()
        -- This should work fine
        return true
    end, {})

    print_result(successRegistered, "Successful component registered successfully")

    -- Try to initialize all components
    _G.HealIQ.InitRegistry:InitializeAll()

    -- Check status
    local status = _G.HealIQ.InitRegistry:GetStatus()
    print_result(status.initializedComponents >= 1, "At least one component initialized successfully")
    print_result(status.failedComponents >= 1, "Failed component was handled gracefully")
    print_result(#status.errors > 0, "Error information was captured")

    print("  Total components: " .. status.totalComponents)
    print("  Successful: " .. status.initializedComponents)
    print("  Failed: " .. status.failedComponents)
    print("  Errors captured: " .. #status.errors)

    return status.initializedComponents > 0
end

-- Test 4: Test WoW API availability checking
local function test_wow_api_checking()
    print("\n=== Testing WoW API Availability Checking ===")

    -- This test verifies that the system can handle missing WoW API functions

    -- Clear state
    _G.HealIQ = nil

    -- Mock some WoW API functions
    _G.CreateFrame = function() return {} end
    _G.GetTime = function() return 0 end
    _G.UnitExists = function() return true end

    -- Load Init.lua with partial API
    local success = pcall(dofile, "Init.lua")
    print_result(success, "Init.lua handles partial WoW API availability")

    -- Clean up mocks
    _G.CreateFrame = nil
    _G.GetTime = nil
    _G.UnitExists = nil

    return success
end

local function run_all_tests()
    print("HealIQ Robust Initialization Test Suite")
    print("=======================================")
    print("Testing the new initialization system to prevent TOC loading errors")
    print("")

    local tests = {
        test_independent_init_loading,
        test_out_of_order_loading,
        test_error_recovery,
        test_wow_api_checking
    }

    local passed = 0
    local total = #tests

    for i, test in ipairs(tests) do
        local success = pcall(test)
        if success then
            passed = passed + 1
        else
            print("Test " .. i .. " failed with error")
        end
    end

    print(string.format("\n=== Results: %d/%d tests passed ===", passed, total))

    if passed == total then
        print("🎉 All robust initialization tests passed!")
        print("✅ The new initialization system provides resilient loading")
        print("✅ Files can load in any order without errors")
        print("✅ Error recovery mechanisms are working")
        print("✅ WoW API availability is handled properly")
        return true
    else
        print("💥 Some tests failed!")
        print("❌ Initialization system needs further work")
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_robust_init.lua$") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
end

return run_all_tests
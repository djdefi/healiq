-- HealIQ Init.lua
-- Robust addon initialization system to prevent TOC loading errors
--
-- This module provides:
-- * Event-driven initialization that doesn't depend on loading order
-- * Robust error recovery for failed file loading
-- * WoW API availability checking before initialization
-- * Registry system for components to self-register
-- * Comprehensive logging of initialization process

-- Robust parameter handling - works regardless of loading order
local addonName, HealIQ = ...

-- Create addon object if it doesn't exist
HealIQ = HealIQ or {}

-- Global initialization registry
local InitRegistry = {
    components = {},
    initialized = false,
    errors = {},
    startTime = 0
}

-- Initialize the core HealIQ object with minimal required structure
local function initializeCore()
    -- Ensure basic structure exists
    HealIQ.version = HealIQ.version or "0.2.0"
    HealIQ.addonName = addonName
    HealIQ.debug = HealIQ.debug or false

    -- Create namespaces
    HealIQ.Rules = HealIQ.Rules or {}
    HealIQ.Components = HealIQ.Components or {}

    -- Core utility functions
    HealIQ.SafeCall = HealIQ.SafeCall or function(func, ...)
        if type(func) ~= "function" then
            return false, "Invalid function"
        end

        local success, result = pcall(func, ...)
        if not success then
            local errorMsg = tostring(result or "unknown error")
            if HealIQ.debug and print then
                print("|cFFFF0000HealIQ Init Error:|r " .. errorMsg)
            end
            return false, errorMsg
        end
        return success, result
    end

    -- Message function
    HealIQ.Message = HealIQ.Message or function(message, isError)
        local prefix = isError and "|cFFFF0000HealIQ Error:|r " or "|cFF00FF00HealIQ:|r "
        if print then
            print(prefix .. tostring(message))
        end
    end

    -- Debug logging
    HealIQ.DebugLog = HealIQ.DebugLog or function(message, level)
        if HealIQ.debug and print then
            local color = "|cFF888888"
            if level == "ERROR" then color = "|cFFFF0000"
            elseif level == "WARN" then color = "|cFFFFFF00"
            elseif level == "INFO" then color = "|cFF00FF00"
            end
            print(color .. "[HealIQ Init] " .. tostring(message) .. "|r")
        end
    end

    -- Global reference
    _G.HealIQ = HealIQ

    HealIQ:DebugLog("Core HealIQ object initialized", "INFO")
    return true
end

-- Check if WoW API is available for safe initialization
local function checkWoWAPIAvailability()
    local requiredFunctions = {
        "CreateFrame",
        "GetTime",
        "UnitExists",
        "IsInCombatLockdown"
    }

    local available = 0
    local total = #requiredFunctions

    for _, funcName in ipairs(requiredFunctions) do
        if _G[funcName] and type(_G[funcName]) == "function" then
            available = available + 1
        end
    end

    return available >= (total * 0.75) -- 75% of functions must be available
end

-- Component registration system
function InitRegistry:RegisterComponent(name, initFunc, dependencies)
    if type(name) ~= "string" or type(initFunc) ~= "function" then
        HealIQ:DebugLog("Invalid component registration: " .. tostring(name), "ERROR")
        return false
    end

    self.components[name] = {
        name = name,
        initFunc = initFunc,
        dependencies = dependencies or {},
        initialized = false,
        error = nil,
        retries = 0
    }

    HealIQ:DebugLog("Component registered: " .. name, "INFO")

    -- Try immediate initialization if system is ready
    if self.initialized then
        self:InitializeComponent(name)
    end

    return true
end

-- Initialize a single component with dependency checking
function InitRegistry:InitializeComponent(name)
    local component = self.components[name]
    if not component then
        HealIQ:DebugLog("Component not found: " .. name, "ERROR")
        return false
    end

    if component.initialized then
        return true
    end

    -- Check dependencies
    for _, depName in ipairs(component.dependencies) do
        local dep = self.components[depName]
        if not dep or not dep.initialized then
            HealIQ:DebugLog("Component " .. name .. " waiting for dependency: " .. depName, "WARN")
            return false
        end
    end

    -- Initialize component
    HealIQ:DebugLog("Initializing component: " .. name, "INFO")

    local success, error = HealIQ:SafeCall(component.initFunc)

    if success then
        component.initialized = true
        HealIQ:DebugLog("Component initialized successfully: " .. name, "INFO")
        return true
    else
        component.error = error
        component.retries = component.retries + 1
        table.insert(self.errors, {
            component = name,
            error = error,
            retries = component.retries,
            timestamp = GetTime and GetTime() or 0
        })

        HealIQ:DebugLog("Component initialization failed: " .. name .. " - " .. tostring(error), "ERROR")

        -- Retry logic for recoverable errors
        if component.retries < 3 and not string.find(tostring(error), "critical") then
            HealIQ:DebugLog("Will retry component: " .. name, "WARN")
        end

        return false
    end
end

-- Initialize all registered components
function InitRegistry:InitializeAll()
    if self.initialized then
        return
    end

    self.startTime = GetTime and GetTime() or 0
    HealIQ:DebugLog("Starting component initialization", "INFO")

    -- Multiple passes to handle dependencies
    local maxPasses = 10
    local pass = 1

    repeat
        local initializedThisPass = 0
        local totalPending = 0

        for name, component in pairs(self.components) do
            if not component.initialized then
                totalPending = totalPending + 1
                if self:InitializeComponent(name) then
                    initializedThisPass = initializedThisPass + 1
                end
            end
        end

        pass = pass + 1

        if initializedThisPass == 0 and totalPending > 0 then
            HealIQ:DebugLog("No progress in initialization pass " .. (pass - 1) .. ", retrying failed components", "WARN")
            -- Retry failed components
            for name, component in pairs(self.components) do
                if not component.initialized and component.retries < 3 then
                    self:InitializeComponent(name)
                end
            end
        end

    until initializedThisPass == 0 or totalPending == 0 or pass > maxPasses

    self.initialized = true

    -- Report results
    local initialized = 0
    local failed = 0

    for name, component in pairs(self.components) do
        if component.initialized then
            initialized = initialized + 1
        else
            failed = failed + 1
            HealIQ:DebugLog("Component failed to initialize: " .. name, "ERROR")
        end
    end

    local endTime = GetTime and GetTime() or 0
    local duration = endTime - self.startTime

    HealIQ:Message(string.format("HealIQ initialization complete: %d successful, %d failed in %.2fs",
        initialized, failed, duration))

    if failed > 0 then
        HealIQ:Message("Some components failed to initialize. Addon may have reduced functionality.", true)
    end
end

-- Get initialization status
function InitRegistry:GetStatus()
    local status = {
        initialized = self.initialized,
        totalComponents = 0,
        initializedComponents = 0,
        failedComponents = 0,
        errors = self.errors,
        startTime = self.startTime
    }

    for name, component in pairs(self.components) do
        status.totalComponents = status.totalComponents + 1
        if component.initialized then
            status.initializedComponents = status.initializedComponents + 1
        else
            status.failedComponents = status.failedComponents + 1
        end
    end

    return status
end

-- Initialize core system
local coreInitialized = false

local function performInitialization()
    if coreInitialized then
        return
    end

    -- Initialize core HealIQ object
    local coreSuccess, coreError = pcall(initializeCore)
    if not coreSuccess then
        if print then print("|cFFFF0000HealIQ Critical Error:|r Failed to initialize core object - " .. tostring(coreError)) end
        return
    end

    -- Check WoW API availability
    if not checkWoWAPIAvailability() then
        if HealIQ.DebugLog then
            HealIQ:DebugLog("WoW API not fully available yet, deferring initialization", "WARN")
        end
        -- Try again later
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, performInitialization)
        end
        return
    end

    coreInitialized = true
    if HealIQ.DebugLog then
        HealIQ:DebugLog("Core initialization complete, starting component initialization", "INFO")
    end

    -- Initialize all registered components
    InitRegistry:InitializeAll()
end

-- Expose registry to HealIQ
HealIQ.InitRegistry = InitRegistry

-- Safe initialization that works regardless of when this file loads
local success, error = pcall(performInitialization)
if not success then
    if print then
        print("|cFFFF0000HealIQ Init Error:|r " .. tostring(error))
    end
end

-- Register for ADDON_LOADED event to ensure initialization happens
if not coreInitialized then
    local initFrame = CreateFrame and CreateFrame("Frame") or nil
    if initFrame then
        initFrame:RegisterEvent("ADDON_LOADED")
        initFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
            if loadedAddonName == "HealIQ" then
                pcall(performInitialization)
                initFrame:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- Also try initialization on next frame if WoW API becomes available
if not coreInitialized and C_Timer and C_Timer.After then
    C_Timer.After(0.1, function()
        pcall(performInitialization)
    end)
end
-- HealIQ Validation.lua
-- Input validation and safety checks
--
-- This module provides:
-- * Input parameter validation
-- * Data structure integrity checks
-- * WoW API availability checks
-- * Safe type conversion utilities
-- * Error prevention mechanisms

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    error("HealIQ Validation.lua: Init system not loaded - check TOC loading order")
end

HealIQ.Validation = HealIQ.Validation or {}
local Validation = HealIQ.Validation

-- Type validation utilities
local typeValidators = {
    number = function(value, min, max)
        if type(value) ~= "number" then return false, "Expected number, got " .. type(value) end
        if min and value < min then return false, "Value " .. value .. " below minimum " .. min end
        if max and value > max then return false, "Value " .. value .. " above maximum " .. max end
        return true
    end,

    string = function(value, minLength, maxLength)
        if type(value) ~= "string" then return false, "Expected string, got " .. type(value) end
        local len = string.len(value)
        if minLength and len < minLength then return false, "String too short (min: " .. minLength .. ")" end
        if maxLength and len > maxLength then return false, "String too long (max: " .. maxLength .. ")" end
        return true
    end,

    boolean = function(value)
        if type(value) ~= "boolean" then return false, "Expected boolean, got " .. type(value) end
        return true
    end,

    table = function(value, requiredKeys)
        if type(value) ~= "table" then return false, "Expected table, got " .. type(value) end
        if requiredKeys then
            for _, key in ipairs(requiredKeys) do
                if value[key] == nil then
                    return false, "Missing required key: " .. tostring(key)
                end
            end
        end
        return true
    end,

    ["function"] = function(value)
        if type(value) ~= "function" then return false, "Expected function, got " .. type(value) end
        return true
    end
}

-- Validate a single parameter
-- @param value The value to validate
-- @param expectedType The expected type (string)
-- @param constraints Optional constraints (table)
-- @return boolean, string Success status and error message
function Validation:ValidateParameter(value, expectedType, constraints)
    constraints = constraints or {}

    local validator = typeValidators[expectedType]
    if not validator then
        return false, "Unknown type: " .. tostring(expectedType)
    end

    return validator(value, constraints.min or constraints.minLength,
                    constraints.max or constraints.maxLength, constraints.requiredKeys)
end

-- Validate multiple parameters at once
-- @param parameters Table of {value, type, constraints} entries
-- @return boolean, string Success status and error message
function Validation:ValidateParameters(parameters)
    for i, param in ipairs(parameters) do
        local value, expectedType, constraints = param[1], param[2], param[3]
        local success, error = self:ValidateParameter(value, expectedType, constraints)
        if not success then
            return false, "Parameter " .. i .. ": " .. error
        end
    end
    return true
end

-- Validate database structure integrity
-- @param db The database table to validate
-- @return boolean, string Success status and error message
function Validation:ValidateDatabase(db)
    if not db then
        return false, "Database is nil"
    end

    if type(db) ~= "table" then
        return false, "Database is not a table"
    end

    -- Required top-level keys
    local requiredKeys = {"enabled", "ui", "rules", "strategy"}
    for _, key in ipairs(requiredKeys) do
        if db[key] == nil then
            return false, "Missing required database key: " .. key
        end
    end

    -- Validate UI settings structure
    if type(db.ui) ~= "table" then
        return false, "UI settings must be a table"
    end

    local uiValidations = {
        {db.ui.scale, "number", {min = 0.1, max = 3.0}},
        {db.ui.x, "number"},
        {db.ui.y, "number"},
        {db.ui.locked, "boolean"},
        {db.ui.showIcon, "boolean"},
        {db.ui.showSpellName, "boolean"},
        {db.ui.queueSize, "number", {min = 1, max = 10}}
    }

    for _, validation in ipairs(uiValidations) do
        local value, expectedType, constraints = validation[1], validation[2], validation[3]
        if value ~= nil then -- Allow nil values for optional settings
            local success, error = self:ValidateParameter(value, expectedType, constraints)
            if not success then
                return false, "UI validation error: " .. error
            end
        end
    end

    -- Validate rules structure
    if type(db.rules) ~= "table" then
        return false, "Rules settings must be a table"
    end

    -- Validate strategy structure
    if type(db.strategy) ~= "table" then
        return false, "Strategy settings must be a table"
    end

    return true
end

-- Validate spell suggestion structure
-- @param suggestion The suggestion table to validate
-- @return boolean, string Success status and error message
function Validation:ValidateSuggestion(suggestion)
    if not suggestion then
        return false, "Suggestion is nil"
    end

    local success, error = self:ValidateParameter(suggestion, "table", {
        requiredKeys = {"spellId", "name", "icon", "priority"}
    })

    if not success then
        return false, error
    end

    -- Validate individual fields
    local validations = {
        {suggestion.spellId, "number", {min = 1}},
        {suggestion.name, "string", {minLength = 1, maxLength = 100}},
        {suggestion.icon, "string", {minLength = 1}},
        {suggestion.priority, "number", {min = 0, max = 100}}
    }

    for _, validation in ipairs(validations) do
        local value, expectedType, constraints = validation[1], validation[2], validation[3]
        local fieldSuccess, fieldError = self:ValidateParameter(value, expectedType, constraints)
        if not fieldSuccess then
            return false, "Suggestion field validation error: " .. fieldError
        end
    end

    return true
end

-- Safe type conversion utilities
local safeConverters = {
    toNumber = function(value, default)
        local num = tonumber(value)
        return num or (default or 0)
    end,

    toString = function(value, default)
        if value == nil then return default or "" end
        return tostring(value)
    end,

    toBoolean = function(value, default)
        if value == nil then return default or false end
        if type(value) == "boolean" then return value end
        if type(value) == "string" then
            return value:lower() == "true" or value:lower() == "yes" or value == "1"
        end
        if type(value) == "number" then
            return value ~= 0
        end
        return default or false
    end
}

-- Safely convert value to specified type
-- @param value The value to convert
-- @param targetType The target type ("number", "string", "boolean")
-- @param default Default value if conversion fails
-- @return any Converted value or default
function Validation:SafeConvert(value, targetType, default)
    local converter = safeConverters["to" .. targetType:sub(1,1):upper() .. targetType:sub(2)]
    if converter then
        return converter(value, default)
    end
    return default
end

-- Check if WoW API function is available
-- @param apiName The name of the API function
-- @return boolean True if API is available
function Validation:IsAPIAvailable(apiName)
    return _G[apiName] ~= nil and type(_G[apiName]) == "function"
end

-- Check if addon is in a valid state for operation
-- @return boolean, string Success status and error message
function Validation:ValidateAddonState()
    -- Check if HealIQ object exists
    if not HealIQ then
        return false, "HealIQ addon object not initialized"
    end

    -- Check if database is initialized
    if not HealIQ.db then
        return false, "HealIQ database not initialized"
    end

    -- Validate database structure
    local dbSuccess, dbError = self:ValidateDatabase(HealIQ.db)
    if not dbSuccess then
        return false, "Database validation failed: " .. dbError
    end

    -- Check if player is in game
    if not self:IsAPIAvailable("UnitExists") or not UnitExists("player") then
        return false, "Player not in game or API not available"
    end

    -- Check if addon is enabled
    if not HealIQ.db.enabled then
        return false, "Addon is disabled"
    end

    return true
end

-- Validate configuration values before applying them
-- @param category The configuration category (string)
-- @param key The configuration key (string)
-- @param value The value to validate
-- @return boolean, string, any Success status, error message, sanitized value
function Validation:ValidateConfigValue(category, key, value)
    -- Configuration validation rules
    local configRules = {
        ui = {
            scale = {type = "number", min = 0.1, max = 3.0},
            x = {type = "number", min = -2000, max = 2000},
            y = {type = "number", min = -2000, max = 2000},
            locked = {type = "boolean"},
            showIcon = {type = "boolean"},
            showSpellName = {type = "boolean"},
            showCooldown = {type = "boolean"},
            showQueue = {type = "boolean"},
            queueSize = {type = "number", min = 1, max = 10},
            queueLayout = {type = "string", validValues = {"horizontal", "vertical"}},
            opacity = {type = "number", min = 0.0, max = 1.0}
        },
        rules = {
            -- All rule settings should be booleans
            default = {type = "boolean"}
        },
        strategy = {
            -- Strategy settings validation
            wildGrowthMinTargets = {type = "number", min = 1, max = 40},
            tranquilityMinTargets = {type = "number", min = 1, max = 40},
            lifebloomRefreshWindow = {type = "number", min = 1.0, max = 10.0},
            recentDamageWindow = {type = "number", min = 1, max = 10},
            lowHealthThreshold = {type = "number", min = 0.1, max = 1.0}
        }
    }

    local categoryRules = configRules[category]
    if not categoryRules then
        return false, "Unknown configuration category: " .. tostring(category), value
    end

    local rule = categoryRules[key] or categoryRules.default
    if not rule then
        return false, "Unknown configuration key: " .. tostring(key), value
    end

    -- Validate type
    local success, error = self:ValidateParameter(value, rule.type, rule)
    if not success then
        return false, error, value
    end

    -- Check valid values
    if rule.validValues then
        local isValid = false
        for _, validValue in ipairs(rule.validValues) do
            if value == validValue then
                isValid = true
                break
            end
        end
        if not isValid then
            return false, "Invalid value. Must be one of: " .. table.concat(rule.validValues, ", "), value
        end
    end

    -- Sanitize numeric values
    if rule.type == "number" then
        if rule.min then
            value = math.max(value, rule.min)
        end
        if rule.max then
            value = math.min(value, rule.max)
        end
    end

    return true, nil, value
end

-- Comprehensive addon health check
-- @return table Health check results
function Validation:HealthCheck()
    local results = {
        timestamp = GetTime(),
        overall_status = "UNKNOWN",
        checks = {}
    }

    local checksPassed = 0
    local totalChecks = 0

    -- Helper function to add check result
    local function addCheck(name, success, message)
        totalChecks = totalChecks + 1
        if success then checksPassed = checksPassed + 1 end

        table.insert(results.checks, {
            name = name,
            status = success and "PASS" or "FAIL",
            message = message or (success and "OK" or "Failed")
        })
    end

    -- Core addon checks
    addCheck("Addon Object", HealIQ ~= nil, "HealIQ object exists")
    addCheck("Database", HealIQ and HealIQ.db ~= nil, "Database initialized")

    -- Database validation
    if HealIQ and HealIQ.db then
        local dbSuccess, dbError = self:ValidateDatabase(HealIQ.db)
        addCheck("Database Structure", dbSuccess, dbError)
    end

    -- Module availability checks
    local modules = {"UI", "Engine", "Config", "Tracker", "Logging", "Performance", "Validation"}
    for _, moduleName in ipairs(modules) do
        local moduleExists = HealIQ and HealIQ[moduleName] ~= nil
        addCheck("Module: " .. moduleName, moduleExists, moduleExists and "Available" or "Missing")
    end

    -- WoW API availability checks
    local criticalAPIs = {"UnitExists", "GetTime", "CreateFrame", "GetSpellInfo"}
    for _, apiName in ipairs(criticalAPIs) do
        local apiAvailable = self:IsAPIAvailable(apiName)
        addCheck("API: " .. apiName, apiAvailable, apiAvailable and "Available" or "Missing")
    end

    -- Performance check
    if HealIQ.Performance then
        local hasPerformanceIssues = HealIQ.Performance:HasPerformanceIssues()
        addCheck("Performance", not hasPerformanceIssues, hasPerformanceIssues and "Issues detected" or "Good")
    end

    -- Calculate overall status
    local successRate = checksPassed / totalChecks
    if successRate >= 0.9 then
        results.overall_status = "HEALTHY"
    elseif successRate >= 0.7 then
        results.overall_status = "WARNING"
    else
        results.overall_status = "CRITICAL"
    end

    results.success_rate = successRate
    results.checks_passed = checksPassed
    results.total_checks = totalChecks

    return results
end

-- Initialize validation system
function Validation:Initialize()
    HealIQ:SafeCall(function()
        -- Run initial health check
        local healthCheck = self:HealthCheck()

        if healthCheck.overall_status == "CRITICAL" then
            HealIQ:Message("Addon health check failed. Some features may not work correctly.", true)
        elseif healthCheck.overall_status == "WARNING" then
            HealIQ:DebugLog("Addon health check passed with warnings", "WARN")
        end

        HealIQ:Print("Validation system initialized")
    end)
end

-- Register Validation module with the initialization system
local function initializeValidation()
    Validation:Initialize()
    HealIQ:DebugLog("Validation module initialized successfully", "INFO")
end

-- Register with initialization system
if HealIQ.InitRegistry then
    HealIQ.InitRegistry:RegisterComponent("Validation", initializeValidation, {"Core"})
else
    -- Fallback if Init.lua didn't load properly
    HealIQ:DebugLog("Init system not available, using fallback initialization for Validation", "WARN")
    HealIQ:SafeCall(initializeValidation)
end
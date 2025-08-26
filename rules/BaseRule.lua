-- HealIQ Rules/BaseRule.lua
-- Base interface and common functionality for spell rules
--
-- REFACTORED: New robust initialization pattern
-- This file demonstrates the new WoW addon pattern for rule files:
-- 1. Uses global namespace access that doesn't depend on loading order
-- 2. Self-registers with the initialization system
-- 3. Works independently of other rule files
-- 4. Provides robust error recovery

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    -- Fallback error handling for extreme cases
    if print then
        print("|cFFFF0000HealIQ Critical Error:|r BaseRule.lua loaded before Init.lua - addon not properly initialized")
    end
    return -- Exit gracefully
end

-- Initialize Rules namespace
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Base rule interface
Rules.BaseRule = {}
local BaseRule = Rules.BaseRule

-- Safe method call helper to prevent runtime errors
function Rules.safeCallBaseRule(methodName, fallback, ...)
    if not BaseRule or not BaseRule[methodName] or type(BaseRule[methodName]) ~= "function" then
        return fallback
    end
    return BaseRule[methodName](BaseRule, ...)
end

-- Rule registry for dynamic rule management
local ruleRegistry = {}

-- Register a rule with the system
function Rules:RegisterRule(ruleName, ruleImplementation)
    if type(ruleName) ~= "string" or type(ruleImplementation) ~= "table" then
        HealIQ:DebugLog("Invalid rule registration: " .. tostring(ruleName), "ERROR")
        return false
    end

    ruleRegistry[ruleName] = ruleImplementation
    HealIQ:DebugLog("Rule registered: " .. ruleName, "INFO")
    return true
end

-- Get registered rule
function Rules:GetRule(ruleName)
    return ruleRegistry[ruleName]
end

-- Get all registered rules
function Rules:GetAllRules()
    return ruleRegistry
end

-- Core BaseRule methods for all rules to inherit

-- Check recent damage on group members
function BaseRule:GetRecentlyDamagedCount(seconds)
    seconds = seconds or 3
    local currentTime = GetTime and GetTime() or 0
    local count = 0

    local tracker = HealIQ.Tracker
    if tracker and tracker.trackedData and tracker.trackedData.recentDamage then
        for timestamp, _ in pairs(tracker.trackedData.recentDamage) do
            if currentTime - timestamp <= seconds then
                count = count + 1
            end
        end
    end

    return count
end

function BaseRule:IsInCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function BaseRule:GetGroupSize()
    if IsInRaid and IsInRaid() then
        return GetNumGroupMembers and GetNumGroupMembers() or 1
    elseif IsInGroup and IsInGroup() then
        return GetNumSubgroupMembers and GetNumSubgroupMembers() or 1
    else
        return 1
    end
end

function BaseRule:GetHealthPercent(unit)
    unit = unit or "player"
    local health = UnitHealth and UnitHealth(unit) or 100
    local maxHealth = UnitHealthMax and UnitHealthMax(unit) or 100

    if maxHealth == 0 then
        return 100
    end

    return (health / maxHealth) * 100
end

-- Helper to check if spell is ready (not on cooldown)
function BaseRule:IsSpellReady(spellID)
    if not GetSpellCooldown then
        return false
    end
    local start, duration = GetSpellCooldown(spellID)
    local currentTime = GetTime and GetTime() or 0
    return start == 0 or (start > 0 and (start + duration - currentTime) <= 0)
end

-- Template method that all rules should implement
function BaseRule:ShouldTrigger()
    -- Override this in specific rule implementations
    return false
end

function BaseRule:GetPriority()
    -- Override this in specific rule implementations
    return 50 -- Default medium priority
end

function BaseRule:GetSuggestion()
    -- Override this in specific rule implementations
    return {
        spellID = nil,
        spellName = "Unknown",
        reason = "Base rule - should be overridden",
        priority = self:GetPriority()
    }
end

-- Register BaseRule module with the initialization system
local function initializeBaseRule()
    if HealIQ and HealIQ.DebugLog then
        HealIQ:DebugLog("BaseRule initialized - rule registry ready", "INFO")
    end
end

-- Register with initialization system
if HealIQ.InitRegistry then
    HealIQ.InitRegistry:RegisterComponent("BaseRule", initializeBaseRule, {})
else
    -- Fallback if Init.lua didn't load properly
    if HealIQ and HealIQ.DebugLog then
        HealIQ:DebugLog("Init system not available, using fallback initialization for BaseRule", "WARN")
    end
    if HealIQ and HealIQ.SafeCall then
        HealIQ:SafeCall(initializeBaseRule)
    else
        -- Last resort - call directly but handle errors
        local success, err = pcall(initializeBaseRule)
        if not success and print then
            print("HealIQ Error: Failed to initialize BaseRule: " .. tostring(err))
        end
    end
end

-- Common rule utilities that can be used by all rule types
function BaseRule:GetRecentDamageCount(tracker, seconds)
    seconds = seconds or 5
    local currentTime = GetTime and GetTime() or 0
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

function BaseRule:IsInCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function BaseRule:GetGroupSize()
    if IsInRaid and IsInRaid() then
        return GetNumGroupMembers and GetNumGroupMembers() or 1
    elseif IsInGroup and IsInGroup() then
        return GetNumSubgroupMembers and GetNumSubgroupMembers() or 1
    else
        return 1
    end
end

function BaseRule:GetHealthPercent(unit)
    unit = unit or "player"
    local health = UnitHealth and UnitHealth(unit) or 100
    local maxHealth = UnitHealthMax and UnitHealthMax(unit) or 100

    if maxHealth == 0 then
        return 100
    end

    return (health / maxHealth) * 100
end

-- Helper to check if spell is ready (not on cooldown)
function BaseRule:IsSpellReady(spellID)
    if not GetSpellCooldown then
        return false
    end
    local start, duration = GetSpellCooldown(spellID)
    local currentTime = GetTime and GetTime() or 0
    return start == 0 or (start > 0 and (start + duration - currentTime) <= 0)
end
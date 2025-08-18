-- HealIQ Rules/BaseRule.lua
-- Base interface and common functionality for spell rules
--
-- BEST PRACTICE: Global Namespace Access Pattern
-- This file demonstrates the correct WoW addon pattern for secondary files:
-- 1. Main addon file (Core.lua) uses: local addonName, HealIQ = ...
-- 2. Secondary files (like this) use: local HealIQ = _G.HealIQ
-- This pattern is used by successful addons like MDT, WoWPro, AdiBags, etc.

-- Access HealIQ from global namespace (established by Core.lua)
-- This is the correct pattern for WoW addon files loaded after the main file
local HealIQ = _G.HealIQ

-- BEST PRACTICE: Defensive initialization with detailed error reporting
if not HealIQ or type(HealIQ) ~= "table" then
    -- Enhanced error reporting for better debugging
    local errorMsg = string.format(
        "HealIQ Error: BaseRule.lua loaded before Core.lua - addon not properly initialized. " ..
        "HealIQ type: %s, expected: table",
        type(HealIQ)
    )
    print(errorMsg)
    
    -- Create minimal fallback structure to prevent crashes
    _G.HealIQ = _G.HealIQ or {}
    HealIQ = _G.HealIQ
    
    -- Log this for debugging
    if _G.HealIQ.Logging and _G.HealIQ.Logging.Error then
        _G.HealIQ.Logging.Error("BaseRule.lua initialization error: " .. errorMsg)
    end
end

-- Initialize Rules namespace
HealIQ.Rules = HealIQ.Rules or {}

local Rules = HealIQ.Rules

-- Note: WoW API functions (GetTime, InCombatLockdown, etc.) should be available when loaded by WoW

-- Base rule interface
Rules.BaseRule = {}
local BaseRule = Rules.BaseRule

-- Safe method call helper to prevent runtime errors when BaseRule methods are called before BaseRule is ready
function Rules.safeCallBaseRule(methodName, fallback, ...)
    if not BaseRule or not BaseRule[methodName] or type(BaseRule[methodName]) ~= "function" then
        return fallback
    end
    return BaseRule[methodName](BaseRule, ...)
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
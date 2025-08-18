-- HealIQ Rules/BaseRule.lua
-- Base interface and common functionality for spell rules

-- Robust parameter handling for WoW addon loading
-- Handle both parameter passing and global namespace scenarios
local addonName, HealIQ = ...

-- Enhanced defensive initialization to prevent loading failures
local function initializeHealIQ()
    -- Check if parameters were passed correctly
    if type(HealIQ) ~= "table" then
        -- Fallback to global namespace
        HealIQ = _G.HealIQ
        if type(HealIQ) ~= "table" then
            -- Last resort: create minimal structure
            HealIQ = {}
            print("HealIQ Warning: BaseRule.lua loaded without proper HealIQ initialization")
        end
    end
    
    -- Ensure global reference is always set
    _G.HealIQ = HealIQ
    
    -- Initialize Rules namespace with error handling
    HealIQ.Rules = HealIQ.Rules or {}
    
    return HealIQ
end

-- Initialize with error handling
local success, result = pcall(initializeHealIQ)
if not success then
    print("HealIQ Error: Failed to initialize BaseRule.lua - " .. tostring(result))
    -- Create minimal fallback structure
    _G.HealIQ = _G.HealIQ or {}
    _G.HealIQ.Rules = _G.HealIQ.Rules or {}
    HealIQ = _G.HealIQ
end

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
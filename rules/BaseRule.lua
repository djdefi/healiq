-- HealIQ Rules/BaseRule.lua
-- Base interface and common functionality for spell rules

local addonName, HealIQ = ...

-- Ensure HealIQ is initialized before accessing its properties
HealIQ = HealIQ or {}
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Base rule interface
Rules.BaseRule = {}
local BaseRule = Rules.BaseRule

-- Common rule utilities that can be used by all rule types
function BaseRule:GetRecentDamageCount(tracker, seconds)
    seconds = seconds or 5
    local currentTime = GetTime()
    local count = 0
    
    for timestamp, _ in pairs(tracker.trackedData.recentDamage) do
        if currentTime - timestamp <= seconds then
            count = count + 1
        end
    end
    
    return count
end

function BaseRule:IsInCombat()
    return InCombatLockdown()
end

function BaseRule:GetGroupSize()
    if IsInRaid() then
        return GetNumGroupMembers()
    elseif IsInGroup() then
        return GetNumSubgroupMembers()
    else
        return 1
    end
end

function BaseRule:GetHealthPercent(unit)
    unit = unit or "player"
    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)
    
    if maxHealth == 0 then
        return 100
    end
    
    return (health / maxHealth) * 100
end

-- Helper to check if spell is ready (not on cooldown)
function BaseRule:IsSpellReady(spellID)
    local start, duration = GetSpellCooldown(spellID)
    return start == 0 or (start > 0 and (start + duration - GetTime()) <= 0)
end
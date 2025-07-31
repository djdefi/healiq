-- HealIQ Rules/BaseRule.lua
-- Base interface and common functionality for spell rules

local addonName, HealIQ = ...

-- Ensure HealIQ is initialized before accessing its properties
HealIQ = HealIQ or {}
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Note: WoW API functions (GetTime, InCombatLockdown, etc.) should be available when loaded by WoW

-- Base rule interface
Rules.BaseRule = {}
local BaseRule = Rules.BaseRule

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
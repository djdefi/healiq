-- HealIQ Rules/OffensiveRules.lua
-- Offensive/DPS rules (Wrath)

local addonName, HealIQ = ...

-- Ensure HealIQ is initialized before accessing its properties
HealIQ = HealIQ or {}
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Defensive check: ensure BaseRule is loaded before proceeding
if not Rules.BaseRule then
    print("HealIQ Warning: OffensiveRules loaded before BaseRule")
    -- Create a dummy BaseRule to prevent errors
    Rules.BaseRule = {}
end

local BaseRule = Rules.BaseRule

Rules.OffensiveRules = {}
local OffensiveRules = Rules.OffensiveRules

function OffensiveRules:ShouldUseWrath(tracker)
    -- Suggest Wrath for mana restoration during downtime
    local wrathReady = not tracker:IsSpellReady("wrath") or true -- Wrath has no cooldown typically
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local useForMana = strategy.useWrathForMana ~= false -- default true
    
    if not useForMana then
        return false
    end
    
    -- Only suggest Wrath during low activity periods
    local inCombat = HealIQ.Rules.safeCallBaseRule("IsInCombat", false)
    local recentDamageCount = tracker:GetRecentDamageCount()
    local hasTarget = UnitExists("target")
    local targetIsEnemy = hasTarget and UnitIsEnemy("player", "target")
    
    -- Suggest if:
    -- 1. Not in combat and have enemy target, OR
    -- 2. In combat but low damage activity and have enemy target, OR
    -- 3. No immediate healing needs
    local lowActivity = recentDamageCount == 0
    local noHealingNeeds = not OffensiveRules:HasImmediateHealingNeeds(tracker)
    
    return wrathReady and ((not inCombat and targetIsEnemy) or (inCombat and lowActivity and targetIsEnemy) or (inCombat and noHealingNeeds and targetIsEnemy))
end

function OffensiveRules:HasImmediateHealingNeeds(tracker)
    -- Check if there are immediate healing needs
    local hasTarget = UnitExists("target")
    local targetIsFriendly = hasTarget and UnitIsFriend("player", "target")
    
    if targetIsFriendly then
        -- Check if target has low health
        local healthPercent = HealIQ.Rules.safeCallBaseRule("GetHealthPercent", 100, "target")
        local strategy = HealIQ.db and HealIQ.db.strategy or {}
        local lowHealthThreshold = strategy.lowHealthThreshold or 30
        
        if healthPercent <= lowHealthThreshold then
            return true
        end
        
        -- Check if target is missing important buffs
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        local isTank = UnitGroupRolesAssigned("target") == "TANK"
        local isFocus = UnitIsUnit("target", "focus")
        
        -- Tank missing Lifebloom is high priority
        if (isTank or isFocus) and (not lifeboomInfo or not lifeboomInfo.active) then
            return true
        end
    end
    
    return false
end
-- HealIQ Rules/HealingCooldowns.lua
-- Healing cooldown rules (Tranquility, Nature's Swiftness, Incarnation)

local addonName, HealIQ = ...

-- Ensure HealIQ is initialized before accessing its properties
HealIQ = HealIQ or {}
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules
local BaseRule = Rules.BaseRule

Rules.HealingCooldowns = {}
local HealingCooldowns = Rules.HealingCooldowns

function HealingCooldowns:ShouldUseTranquility(tracker)
    -- Suggest Tranquility if available and high group damage
    local tranquilityReady = tracker:IsSpellReady("tranquility")
    local recentDamageCount = tracker:GetRecentDamageCount()
    
    -- Use configurable threshold
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = strategy.tranquilityMinTargets or 4
    
    return tranquilityReady and recentDamageCount >= minTargets
end

function HealingCooldowns:ShouldUseIncarnation(tracker)
    -- Suggest Incarnation during high damage phases
    local incarnationReady = tracker:IsSpellReady("incarnationTree")
    local recentDamageCount = tracker:GetRecentDamageCount()
    
    -- Use more aggressive threshold for major cooldown
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = math.max(2, strategy.wildGrowthMinTargets or 1)
    
    return incarnationReady and recentDamageCount >= minTargets
end

function HealingCooldowns:ShouldUseNaturesSwiftness(tracker)
    -- Suggest Nature's Swiftness if available and healing is needed
    local naturesSwiftnessReady = tracker:IsSpellReady("naturesSwiftness")
    local targetExists = UnitExists("target")
    local targetIsFriendly = targetExists and UnitIsFriend("player", "target")
    
    -- Enhanced logic: suggest more proactively, not just in emergencies
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local shouldSuggest = false
    
    -- Emergency situations (low health targets)
    if targetExists and targetIsFriendly then
        local healthPercent = BaseRule:GetHealthPercent("target")
        local lowHealthThreshold = strategy.lowHealthThreshold or 30
        if healthPercent <= lowHealthThreshold then
            shouldSuggest = true
        end
    end
    
    -- Proactive use during combat with group damage
    if not shouldSuggest and BaseRule:IsInCombat() then
        local recentDamageCount = tracker:GetRecentDamageCount()
        local groupSize = BaseRule:GetGroupSize()
        -- Suggest if significant group damage (25% of group or 2+ people)
        if recentDamageCount >= math.max(2, math.floor(groupSize * 0.25)) then
            shouldSuggest = true
        end
    end
    
    -- Allow manual override via strategy setting
    local emergencyOnly = strategy.emergencyNaturesSwiftness == true
    if emergencyOnly then
        -- Only suggest in emergency situations when this setting is true
        shouldSuggest = targetExists and targetIsFriendly and BaseRule:GetHealthPercent("target") <= (strategy.lowHealthThreshold or 30)
    end
    
    return naturesSwiftnessReady and shouldSuggest
end
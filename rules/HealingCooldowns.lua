-- HealIQ Rules/HealingCooldowns.lua
-- Healing cooldown rules (Tranquility, Nature's Swiftness, Incarnation)

-- Robust parameter handling for WoW addon loading
local addonName, HealIQ = ...

-- Enhanced defensive initialization to prevent loading failures
local function initializeHealIQ()
    -- Check if parameters were passed correctly
    if type(HealIQ) ~= "table" then
        -- Fallback to global namespace
        HealIQ = _G.HealIQ
        if type(HealIQ) ~= "table" then
            print("HealIQ Error: HealingCooldowns.lua loaded before Core.lua - addon not initialized")
            return nil
        end
    end
    
    -- Ensure global reference is set and initialize Rules namespace
    _G.HealIQ = HealIQ
    HealIQ.Rules = HealIQ.Rules or {}
    
    return HealIQ.Rules
end

-- Initialize with error handling
local Rules
local success, result = pcall(initializeHealIQ)
if success and result then
    Rules = result
else
    print("HealIQ Error: Failed to initialize HealingCooldowns.lua - " .. tostring(result or "unknown error"))
    -- Minimal fallback
    _G.HealIQ = _G.HealIQ or {}
    _G.HealIQ.Rules = _G.HealIQ.Rules or {}
    Rules = _G.HealIQ.Rules
end

-- Defensive check: ensure BaseRule is loaded before proceeding
if not Rules.BaseRule then
    print("HealIQ Warning: HealingCooldowns loaded before BaseRule")
    -- Create a dummy BaseRule to prevent errors
    Rules.BaseRule = {}
end

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
        local healthPercent = HealIQ.Rules.safeCallBaseRule("GetHealthPercent", 100, "target")
        local lowHealthThreshold = strategy.lowHealthThreshold or 30
        if healthPercent <= lowHealthThreshold then
            shouldSuggest = true
        end
    end
    
    -- Proactive use during combat with group damage
    if not shouldSuggest and HealIQ.Rules.safeCallBaseRule("IsInCombat", false) then
        local recentDamageCount = tracker:GetRecentDamageCount()
        local groupSize = HealIQ.Rules.safeCallBaseRule("GetGroupSize", 1)
        -- Suggest if significant group damage (25% of group or 2+ people)
        if recentDamageCount >= math.max(2, math.floor(groupSize * 0.25)) then
            shouldSuggest = true
        end
    end
    
    -- Allow manual override via strategy setting
    local emergencyOnly = strategy.emergencyNaturesSwiftness == true
    if emergencyOnly then
        -- Only suggest in emergency situations when this setting is true
        local hasTarget = targetExists
        local isFriendly = targetIsFriendly
        local healthPercent = HealIQ.Rules.safeCallBaseRule("GetHealthPercent", 100, "target")
        local lowHealthThreshold = strategy.lowHealthThreshold or 30
        shouldSuggest = hasTarget and isFriendly and healthPercent <= lowHealthThreshold
    end
    
    return naturesSwiftnessReady and shouldSuggest
end
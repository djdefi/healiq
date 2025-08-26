-- HealIQ Rules/HealingCooldowns.lua
-- Healing cooldown rules (Tranquility, Nature's Swiftness, Incarnation)

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    -- Graceful exit if init system not ready
    if print then print("|cFFFF0000HealIQ Error:|r HealingCooldowns.lua loaded before Init.lua - addon not properly initialized") end
    return
end

-- Initialize Rules namespace
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Access BaseRule safely (might not be loaded yet)
local BaseRule = Rules.BaseRule or {}

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

-- Register HealingCooldowns rules with the initialization system
local function initializeHealingCooldowns()
    -- Rule-specific initialization would go here
    if HealIQ and HealIQ.DebugLog then
        HealIQ:DebugLog("HealingCooldowns rules initialized successfully", "INFO")
    end
end

-- Register with initialization system
if HealIQ.InitRegistry then
    HealIQ.InitRegistry:RegisterComponent("HealingCooldowns", initializeHealingCooldowns, {"BaseRule"})
else
    -- Fallback if Init.lua didn't load properly
    if HealIQ and HealIQ.DebugLog then
        HealIQ:DebugLog("Init system not available, using fallback initialization for HealingCooldowns", "WARN")
    end
    if HealIQ and HealIQ.SafeCall then
        HealIQ:SafeCall(initializeHealingCooldowns)
    else
        -- Last resort - call directly but handle errors
        local success, err = pcall(initializeHealingCooldowns)
        if not success and print then
            print("HealIQ Error: Failed to initialize HealingCooldowns: " .. tostring(err))
        end
    end
end
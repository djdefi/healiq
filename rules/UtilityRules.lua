-- HealIQ Rules/UtilityRules.lua
-- Utility and buff rules (Flourish)

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    -- Graceful exit if init system not ready
    if print then print("|cFFFF0000HealIQ Error:|r UtilityRules.lua loaded before Init.lua - addon not properly initialized") end
    return
end

-- Initialize Rules namespace
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Defensive check: ensure BaseRule is loaded before proceeding
if not Rules.BaseRule then
    if print then print("HealIQ Warning: UtilityRules loaded before BaseRule") end
    -- Create a dummy BaseRule to prevent errors
    Rules.BaseRule = {}
end

local BaseRule = Rules.BaseRule

Rules.UtilityRules = {}
local UtilityRules = Rules.UtilityRules

function UtilityRules:ShouldUseFlourish(tracker)
    -- Suggest Flourish if available and multiple HoTs are about to expire
    local flourishReady = tracker:IsSpellReady("flourish")
    local expiringHots = 0
    
    -- Use configurable threshold for expiring HoTs
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minHots = strategy.flourishMinHots or 2
    local expirationWindow = 6 -- HoTs expiring in next 6 seconds
    
    -- Check for expiring HoTs on target
    if UnitExists("target") then
        local trackedData = tracker.trackedData
        local rejuv = trackedData.targetHots.rejuvenation
        local regrowth = trackedData.targetHots.regrowth
        local lifebloom = trackedData.targetHots.lifebloom
        
        if rejuv and rejuv.active and rejuv.remaining < expirationWindow then
            expiringHots = expiringHots + 1
        end
        if regrowth and regrowth.active and regrowth.remaining < expirationWindow then
            expiringHots = expiringHots + 1
        end
        if lifebloom and lifebloom.active and lifebloom.remaining < expirationWindow then
            expiringHots = expiringHots + 1
        end
    end
    
    return flourishReady and expiringHots >= minHots
end

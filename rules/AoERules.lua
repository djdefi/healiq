-- HealIQ Rules/AoERules.lua
-- Area of effect healing rules (Efflorescence)

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    -- Graceful exit if init system not ready
    if print then print("|cFFFF0000HealIQ Error:|r AoERules.lua loaded before Init.lua - addon not properly initialized") end
    return
end

-- Initialize Rules namespace
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Note: AoERules doesn't use BaseRule, so no defensive check needed for it

Rules.AoERules = {}
local AoERules = Rules.AoERules

function AoERules:ShouldUseEfflorescence(tracker)
    -- Suggest Efflorescence if available, not currently active, and multiple people took damage
    local efflorescenceReady = tracker:IsSpellReady("efflorescence")
    local trackedData = tracker.trackedData
    local notActive = not trackedData.efflorescenceActive
    local recentDamageCount = tracker:GetRecentDamageCount()
    
    -- Use configurable threshold
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = strategy.efflorescenceMinTargets or 2
    
    return efflorescenceReady and notActive and recentDamageCount >= minTargets
end
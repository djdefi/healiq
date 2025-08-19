-- HealIQ Rules/AoERules.lua
-- Area of effect healing rules (Efflorescence)

-- Access HealIQ from global namespace (established by Core.lua)
-- This is the correct pattern for WoW addon files loaded after the main file
local HealIQ = _G.HealIQ

-- Defensive initialization to ensure HealIQ exists
if not HealIQ or type(HealIQ) ~= "table" then
    if print then print("HealIQ Error: AoERules.lua loaded before Core.lua - addon not properly initialized") end
    -- Create minimal fallback structure to prevent crashes
    _G.HealIQ = _G.HealIQ or {}
    HealIQ = _G.HealIQ
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
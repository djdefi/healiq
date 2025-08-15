-- HealIQ Rules/AoERules.lua
-- Area of effect healing rules (Efflorescence)

local addonName, HealIQ = ...

-- Ensure HealIQ is initialized before accessing its properties
if type(HealIQ) ~= "table" then
    HealIQ = _G.HealIQ or {}
end
HealIQ = HealIQ or {}
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
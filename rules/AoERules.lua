-- HealIQ Rules/AoERules.lua
-- Area of effect healing rules (Efflorescence)

-- Robust parameter handling for WoW addon loading
local addonName, HealIQ = ...

-- Enhanced defensive initialization to prevent loading failures
local function initializeHealIQ()
    -- Check if parameters were passed correctly
    if type(HealIQ) ~= "table" then
        -- Fallback to global namespace
        HealIQ = _G.HealIQ
        if type(HealIQ) ~= "table" then
            print("HealIQ Error: AoERules.lua loaded before Core.lua - addon not initialized")
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
    print("HealIQ Error: Failed to initialize AoERules.lua - " .. tostring(result or "unknown error"))
    -- Minimal fallback
    _G.HealIQ = _G.HealIQ or {}
    _G.HealIQ.Rules = _G.HealIQ.Rules or {}
    Rules = _G.HealIQ.Rules
end

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
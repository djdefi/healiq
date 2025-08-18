-- HealIQ Rules/DefensiveCooldowns.lua
-- Defensive cooldown rules (Ironbark, Barkskin)

-- Robust parameter handling for WoW addon loading
local addonName, HealIQ = ...

-- Enhanced defensive initialization to prevent loading failures
local function initializeHealIQ()
    -- Check if parameters were passed correctly
    if type(HealIQ) ~= "table" then
        -- Fallback to global namespace
        HealIQ = _G.HealIQ
        if type(HealIQ) ~= "table" then
            print("HealIQ Error: DefensiveCooldowns.lua loaded before Core.lua - addon not initialized")
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
    print("HealIQ Error: Failed to initialize DefensiveCooldowns.lua - " .. tostring(result or "unknown error"))
    -- Minimal fallback
    _G.HealIQ = _G.HealIQ or {}
    _G.HealIQ.Rules = _G.HealIQ.Rules or {}
    Rules = _G.HealIQ.Rules
end

-- Defensive check: ensure BaseRule is loaded before proceeding
if not Rules.BaseRule then
    print("HealIQ Warning: DefensiveCooldowns loaded before BaseRule")
    -- Create a dummy BaseRule to prevent errors
    Rules.BaseRule = {}
end

local BaseRule = Rules.BaseRule

-- Spell IDs (shared from main Tracker)
local SPELL_IDS = {
    IRONBARK = 102342,
    IRONBARK_BUFF = 102342,
    BARKSKIN = 22812,
    BARKSKIN_BUFF = 22812,
}

Rules.DefensiveCooldowns = {}
local DefensiveCooldowns = Rules.DefensiveCooldowns

function DefensiveCooldowns:ShouldUseIronbark(tracker)
    -- Suggest Ironbark if available and target is taking damage
    local ironbarkReady = tracker:IsSpellReady("ironbark")
    local targetExists = UnitExists("target")
    local targetIsFriendly = targetExists and UnitIsFriend("player", "target")
    
    -- Check if target doesn't already have Ironbark
    local hasIronbark = false
    if targetExists then
        local spellName = C_Spell.GetSpellName(SPELL_IDS.IRONBARK_BUFF)
        local auraData = spellName and C_UnitAuras.GetAuraDataBySpellName("target", spellName, "HELPFUL")
        hasIronbark = auraData ~= nil
    end
    
    -- Enhanced logic: suggest with target if ready and needed, or without target as reminder
    if targetIsFriendly then
        return ironbarkReady and not hasIronbark
    elseif ironbarkReady and (HealIQ.Rules.safeCallBaseRule("IsInCombat", false) and (IsInGroup() or IsInRaid())) then
        -- Suggest as reminder when in combat with group but no target
        return true
    end
    
    return false
end

function DefensiveCooldowns:ShouldUseBarkskin(tracker)
    -- Suggest Barkskin if available and player is taking damage
    local barkskinReady = tracker:IsSpellReady("barkskin")
    local inCombat = HealIQ.Rules.safeCallBaseRule("IsInCombat", false)
    
    -- Enhanced logic: consider player health and threat
    local playerHealthPercent = HealIQ.Rules.safeCallBaseRule("GetHealthPercent", 100, "player")
    local lowHealthThreshold = (HealIQ.db and HealIQ.db.strategy and HealIQ.db.strategy.lowHealthThreshold) or 50
    
    return barkskinReady and inCombat and (playerHealthPercent <= lowHealthThreshold)
end
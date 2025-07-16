-- HealIQ Rules/DefensiveCooldowns.lua
-- Defensive cooldown rules (Ironbark, Barkskin)

local addonName, HealIQ = ...

HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules
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
    
    return ironbarkReady and targetIsFriendly and not hasIronbark
end

function DefensiveCooldowns:ShouldUseBarkskin(tracker)
    -- Suggest Barkskin if available and player is taking damage
    local barkskinReady = tracker:IsSpellReady("barkskin")
    local inCombat = BaseRule:IsInCombat()
    
    -- Enhanced logic: consider player health and threat
    local playerHealthPercent = BaseRule:GetHealthPercent("player")
    local lowHealthThreshold = (HealIQ.db and HealIQ.db.strategy and HealIQ.db.strategy.lowHealthThreshold) or 50
    
    return barkskinReady and inCombat and (playerHealthPercent <= lowHealthThreshold)
end
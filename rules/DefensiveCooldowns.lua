-- HealIQ Rules/DefensiveCooldowns.lua
-- Defensive cooldown rules (Ironbark, Barkskin)

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    -- Graceful exit if init system not ready
    if print then print("|cFFFF0000HealIQ Error:|r DefensiveCooldowns.lua loaded before Init.lua - addon not properly initialized") end
    return
end

-- Initialize Rules namespace
HealIQ.Rules = HealIQ.Rules or {}
local Rules = HealIQ.Rules

-- Access BaseRule safely (might not be loaded yet)
local BaseRule = Rules.BaseRule or {}

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

-- Register DefensiveCooldowns rules with the initialization system
local function initializeDefensiveCooldowns()
    -- Register individual rules
    if Rules.RegisterRule then
        Rules:RegisterRule("ironbark", Rules.DefensiveCooldowns.Ironbark)
        Rules:RegisterRule("barkskin", Rules.DefensiveCooldowns.Barkskin)
        if HealIQ and HealIQ.DebugLog then
            HealIQ:DebugLog("DefensiveCooldowns rules registered successfully", "INFO")
        end
    else
        if HealIQ and HealIQ.DebugLog then
            HealIQ:DebugLog("Rule registration system not available yet", "WARN")
        end
    end
end

-- Register with initialization system
if HealIQ.InitRegistry then
    HealIQ.InitRegistry:RegisterComponent("DefensiveCooldowns", initializeDefensiveCooldowns, {"BaseRule"})
else
    -- Fallback if Init.lua didn't load properly
    if HealIQ and HealIQ.DebugLog then
        HealIQ:DebugLog("Init system not available, using fallback initialization for DefensiveCooldowns", "WARN")
    end
    if HealIQ and HealIQ.SafeCall then
        HealIQ:SafeCall(initializeDefensiveCooldowns)
    else
        -- Last resort - call directly but handle errors
        local success, err = pcall(initializeDefensiveCooldowns)
        if not success and print then
            print("HealIQ Error: Failed to initialize DefensiveCooldowns: " .. tostring(err))
        end
    end
end
-- HealIQ Tracker.lua
-- Tracks buffs, cooldowns, and relevant unit conditions

local addonName, HealIQ = ...

HealIQ.Tracker = {}
local Tracker = HealIQ.Tracker

-- API compatibility helper functions
local function GetSpellNameCompat(spellId)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    else
        return GetSpellInfo(spellId)
    end
end

local function GetAuraDataCompat(unit, spellName, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        return C_UnitAuras.GetAuraDataBySpellName(unit, spellName, filter)
    else
        -- Fallback: scan through auras manually
        local scanFunc = (filter == "HELPFUL") and UnitBuff or UnitDebuff
        for i = 1, 40 do
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, buffSpellId = scanFunc(unit, i)
            if not name then break end
            if name == spellName then
                return {
                    name = name,
                    icon = icon,
                    applications = count or 1,
                    duration = duration,
                    expirationTime = expirationTime,
                    sourceUnit = source
                }
            end
        end
        return nil
    end
end

-- Spell IDs for tracking
local SPELL_IDS = {
    -- Restoration Druid spells
    LIFEBLOOM = 33763,
    REJUVENATION = 774,
    REGROWTH = 8936,
    WILD_GROWTH = 48438,
    SWIFTMEND = 18562,
    CLEARCASTING = 16870,

    -- Major cooldowns
    IRONBARK = 102342,
    EFFLORESCENCE = 145205,
    TRANQUILITY = 740,
    INCARNATION_TREE = 33891,
    NATURES_SWIFTNESS = 132158,
    BARKSKIN = 22812,
    FLOURISH = 197721,

    -- New spells from strategy review
    GROVE_GUARDIANS = 102693,
    WRATH = 5176,

    -- Buffs
    CLEARCASTING_BUFF = 16870,
    IRONBARK_BUFF = 102342,
    BARKSKIN_BUFF = 22812,
    NATURES_SWIFTNESS_BUFF = 132158,
    INCARNATION_TREE_BUFF = 33891,
}

-- Track state
local trackedData = {
    cooldowns = {},
    buffs = {},
    lastCombatLogTime = 0,
    recentDamage = {},
    targetHots = {},
    playerBuffs = {},
    trinketCooldowns = {},
    efflorescenceActive = false,
    efflorescenceExpires = 0,
}

function Tracker:Initialize()
    HealIQ:SafeCall(function()
        self:RegisterEvents()
        HealIQ:Print("Tracker initialized")
    end)
end

function Tracker:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")

    frame:SetScript("OnEvent", function(self, event, ...)
        Tracker:OnEvent(event, ...)
    end)
end

function Tracker:OnEvent(event, ...)
    local args = {...}  -- Capture varargs for use in SafeCall
    HealIQ:SafeCall(function()
        if event == "SPELL_UPDATE_COOLDOWN" then
            self:UpdateCooldowns()
        elseif event == "UNIT_AURA" then
            local unit = args[1]
            self:UpdateUnitAuras(unit)
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            self:ParseCombatLog()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self:UpdateTargetHots()
        end
    end)
end

function Tracker:UpdateCooldowns()
    local currentTime = GetTime()

    -- Helper function to update cooldown data with enhanced error handling
    local function updateCooldown(spellId, spellName)
        HealIQ:SafeCall(function()
            local startTime, duration, isEnabled

            -- Use C_Spell API if available (newer WoW versions), fallback to older API
            if C_Spell and C_Spell.GetSpellCooldown then
                startTime, duration, isEnabled = C_Spell.GetSpellCooldown(spellId)
            else
                -- Fallback to older API for compatibility
                startTime, duration, isEnabled = GetSpellCooldown(spellId)
            end

            -- Defensive check: ensure we got valid values
            if startTime and duration and isEnabled then
                -- Handle different cooldown states
                if startTime > 0 and duration > 0 then
                    -- Spell is on cooldown
                    local remaining = math.max(0, (startTime + duration) - currentTime)
                    trackedData.cooldowns[spellName] = {
                        remaining = remaining,
                        ready = remaining <= 0.1,  -- Add small tolerance for timing issues
                        start = startTime,
                        duration = duration
                    }
                else
                    -- Spell is ready (not on cooldown)
                    trackedData.cooldowns[spellName] = {
                        remaining = 0,
                        ready = true,
                        start = 0,
                        duration = 0
                    }
                end
            else
                -- API call failed, assume spell is ready but log the issue
                HealIQ:DebugLog("Cooldown API call failed for " .. spellName)
                trackedData.cooldowns[spellName] = {
                    remaining = 0,
                    ready = true,
                    start = 0,
                    duration = 0
                }
            end
        end)
    end

    -- Track existing spells
    updateCooldown(SPELL_IDS.WILD_GROWTH, "wildGrowth")
    updateCooldown(SPELL_IDS.SWIFTMEND, "swiftmend")

    -- Track new major cooldowns
    updateCooldown(SPELL_IDS.IRONBARK, "ironbark")
    updateCooldown(SPELL_IDS.EFFLORESCENCE, "efflorescence")
    updateCooldown(SPELL_IDS.TRANQUILITY, "tranquility")
    updateCooldown(SPELL_IDS.INCARNATION_TREE, "incarnationTree")
    updateCooldown(SPELL_IDS.NATURES_SWIFTNESS, "naturesSwiftness")
    updateCooldown(SPELL_IDS.BARKSKIN, "barkskin")
    updateCooldown(SPELL_IDS.FLOURISH, "flourish")

    -- Track new spells from strategy review
    updateCooldown(SPELL_IDS.GROVE_GUARDIANS, "groveGuardians")
    updateCooldown(SPELL_IDS.WRATH, "wrath")

    -- Track trinket cooldowns (slot 13 and 14)
    for slot = 13, 14 do
        local itemId = GetInventoryItemID and GetInventoryItemID("player", slot)
        if itemId then
            -- Defensive API check for GetItemCooldown
            local startTime, duration, isEnabled
            if C_Item and C_Item.GetItemCooldown then
                startTime, duration, isEnabled = C_Item.GetItemCooldown(itemId)
            elseif GetItemCooldown then
                startTime, duration, isEnabled = GetItemCooldown(itemId)
            end

            -- Defensive check: ensure we got valid values and item is on cooldown
            if startTime and duration and isEnabled and startTime > 0 and duration > 0 then
                local remaining = (startTime + duration) - currentTime
                trackedData.trinketCooldowns[slot] = {
                    remaining = math.max(0, remaining),
                    ready = remaining <= 0,
                    start = startTime,
                    duration = duration,
                    itemId = itemId
                }
            else
                -- Clear trinket cooldown data when not on cooldown
                trackedData.trinketCooldowns[slot] = nil
            end
        end
    end
end

function Tracker:UpdateUnitAuras(unit)
    if unit == "player" then
        self:UpdatePlayerBuffs()
    elseif unit == "target" or unit == "focus" then
        self:UpdateTargetHots()
    end
end

function Tracker:UpdatePlayerBuffs()
    local currentTime = GetTime()

    -- Helper function to check for buff with enhanced API compatibility
    local function checkBuff(spellId, buffName)
        HealIQ:SafeCall(function()
            local spellName

            -- Use C_Spell API if available, fallback to GetSpellInfo
            if C_Spell and C_Spell.GetSpellName then
                spellName = C_Spell.GetSpellName(spellId)
            else
                spellName = GetSpellInfo(spellId)
            end

            if spellName then
                local auraData

                -- Use C_UnitAuras if available, fallback to UnitBuff
                if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
                    auraData = C_UnitAuras.GetAuraDataBySpellName("player", spellName, "HELPFUL")
                else
                    -- Fallback: scan through buffs manually
                    for i = 1, 40 do
                        local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, buffSpellId = UnitBuff("player", i)
                        if not name then break end
                        if buffSpellId == spellId then
                            auraData = {
                                name = name,
                                icon = icon,
                                applications = count or 1,
                                duration = duration,
                                expirationTime = expirationTime,
                                sourceUnit = source
                            }
                            break
                        end
                    end
                end
                if auraData then
                    trackedData.playerBuffs[buffName] = {
                        active = true,
                        remaining = auraData.expirationTime - currentTime,
                        stacks = auraData.applications or 1
                    }
                else
                    trackedData.playerBuffs[buffName] = {
                        active = false,
                        remaining = 0,
                        stacks = 0
                    }
                end
            else
                -- Spell name lookup failed
                trackedData.playerBuffs[buffName] = {
                    active = false,
                    remaining = 0,
                    stacks = 0
                }
            end
        end)
    end

    -- Check for existing buffs
    checkBuff(SPELL_IDS.CLEARCASTING_BUFF, "clearcasting")

    -- Check for new buffs
    checkBuff(SPELL_IDS.IRONBARK_BUFF, "ironbark")
    checkBuff(SPELL_IDS.BARKSKIN_BUFF, "barkskin")
    checkBuff(SPELL_IDS.NATURES_SWIFTNESS_BUFF, "naturesSwiftness")
    checkBuff(SPELL_IDS.INCARNATION_TREE_BUFF, "incarnationTree")

    -- Maintain backward compatibility
    trackedData.buffs.clearcasting = trackedData.playerBuffs.clearcasting
end

function Tracker:UpdateTargetHots()
    if not UnitExists("target") then
        trackedData.targetHots = {}
        return
    end

    HealIQ:SafeCall(function()
        local currentTime = GetTime()

        -- Check for Lifebloom on target
        local spellName = GetSpellNameCompat(SPELL_IDS.LIFEBLOOM)
        local auraData = spellName and GetAuraDataCompat("target", spellName, "HELPFUL")
        if auraData then
            trackedData.targetHots.lifebloom = {
                active = true,
                remaining = auraData.expirationTime - currentTime,
                stacks = auraData.applications or 1
            }
        else
            trackedData.targetHots.lifebloom = {
                active = false,
                remaining = 0,
                stacks = 0
            }
        end

        -- Check for Rejuvenation on target
        spellName = GetSpellNameCompat(SPELL_IDS.REJUVENATION)
        if auraData then
            trackedData.targetHots.rejuvenation = {
                active = true,
                remaining = auraData.expirationTime - currentTime,
                stacks = auraData.applications or 1
            }
        else
            trackedData.targetHots.rejuvenation = {
                active = false,
                remaining = 0,
                stacks = 0
            }
        end

        -- Check for Regrowth on target
        spellName = GetSpellNameCompat(SPELL_IDS.REGROWTH)
        auraData = spellName and GetAuraDataCompat("target", spellName, "HELPFUL")
        if auraData then
            trackedData.targetHots.regrowth = {
                active = true,
                remaining = auraData.expirationTime - currentTime,
                stacks = auraData.applications or 1
            }
        else
            trackedData.targetHots.regrowth = {
                active = false,
                remaining = 0,
                stacks = 0
            }
        end
    end)
end

function Tracker:ParseCombatLog()
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- Track recent damage for Wild Growth suggestions
    if subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
        if UnitInParty(destName) or UnitInRaid(destName) then
            local currentTime = GetTime()
            trackedData.recentDamage[destGUID] = currentTime

            -- Clean up old damage records (older than 5 seconds)
            -- Use separate cleanup pass to avoid performance issues
            local toRemove = {}
            for guid, time in pairs(trackedData.recentDamage) do
                if currentTime - time > 5 then
                    table.insert(toRemove, guid)
                end
            end

            for _, guid in ipairs(toRemove) do
                trackedData.recentDamage[guid] = nil
            end
        end
    end

    -- Track Efflorescence casting
    if subevent == "SPELL_CAST_SUCCESS" then
        local spellId = select(12, CombatLogGetCurrentEventInfo())
        if spellId == SPELL_IDS.EFFLORESCENCE and sourceGUID == UnitGUID("player") then
            trackedData.efflorescenceActive = true
            trackedData.efflorescenceExpires = GetTime() + 30 -- Efflorescence lasts 30 seconds
        end
    end

    -- Update efflorescence status
    if trackedData.efflorescenceActive and GetTime() > trackedData.efflorescenceExpires then
        trackedData.efflorescenceActive = false
    end
end

-- Public getter functions
function Tracker:GetCooldownInfo(spellName)
    local cooldown = trackedData.cooldowns[spellName]
    -- Defensive check: ensure we return either nil or a valid table
    if cooldown and type(cooldown) == "table" then
        return cooldown
    end
    return nil
end

function Tracker:GetBuffInfo(buffName)
    return trackedData.buffs[buffName]
end

function Tracker:GetTargetHotInfo(hotName)
    return trackedData.targetHots[hotName]
end

function Tracker:GetRecentDamageCount()
    local count = 0
    local currentTime = GetTime()

    -- Use configurable time window from strategy settings
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local timeWindow = strategy.recentDamageWindow or 3 -- default 3 seconds

    for guid, time in pairs(trackedData.recentDamage) do
        if currentTime - time <= timeWindow then
            count = count + 1
        end
    end

    return count
end

function Tracker:HasClearcasting()
    return trackedData.buffs.clearcasting and trackedData.buffs.clearcasting.active
end

function Tracker:IsSpellReady(spellName)
    local cooldown = trackedData.cooldowns[spellName]
    -- If no cooldown entry exists, assume the spell is ready
    -- If cooldown entry exists, check the ready flag
    if cooldown then
        return cooldown.ready
    else
        -- No cooldown data - assume ready, but this shouldn't happen after the fix
        HealIQ:DebugLog("No cooldown data for " .. spellName .. ", assuming ready")
        return true
    end
end

function Tracker:CanSwiftmend()
    local swiftmendReady = self:IsSpellReady("swiftmend")
    local hasRejuv = trackedData.targetHots.rejuvenation and trackedData.targetHots.rejuvenation.active
    local hasRegrowth = trackedData.targetHots.regrowth and trackedData.targetHots.regrowth.active

    return swiftmendReady and (hasRejuv or hasRegrowth)
end

-- New getter functions for additional spells
function Tracker:GetPlayerBuffInfo(buffName)
    return trackedData.playerBuffs[buffName]
end

function Tracker:HasPlayerBuff(buffName)
    local buff = trackedData.playerBuffs[buffName]
    return buff and buff.active
end

function Tracker:GetTrinketCooldown(slot)
    return trackedData.trinketCooldowns[slot]
end

function Tracker:IsEfflorescenceActive()
    return trackedData.efflorescenceActive
end

function Tracker:GetEfflorescenceTimeRemaining()
    if trackedData.efflorescenceActive then
        return math.max(0, trackedData.efflorescenceExpires - GetTime())
    end
    return 0
end


-- ========================================
-- Rule Functions - Delegates to Modular Rules
-- ========================================

function Tracker:ShouldUseIronbark()
    if HealIQ.Rules and HealIQ.Rules.DefensiveCooldowns then
        return HealIQ.Rules.DefensiveCooldowns:ShouldUseIronbark(self)
    end
    -- Fallback to original logic if rules not loaded
    local ironbarkReady = self:IsSpellReady("ironbark")
    local targetExists = UnitExists("target")
    local targetIsFriendly = targetExists and UnitIsFriend("player", "target")

    local hasIronbark = false
    if targetExists then
        local spellName = GetSpellNameCompat(SPELL_IDS.IRONBARK_BUFF)
        local auraData = spellName and GetAuraDataCompat("target", spellName, "HELPFUL")
        hasIronbark = auraData ~= nil
    end

    return ironbarkReady and targetIsFriendly and not hasIronbark
end

function Tracker:ShouldUseBarkskin()
    if HealIQ.Rules and HealIQ.Rules.DefensiveCooldowns then
        return HealIQ.Rules.DefensiveCooldowns:ShouldUseBarkskin(self)
    end
    -- Fallback to original logic
    local barkskinReady = self:IsSpellReady("barkskin")
    local inCombat = InCombatLockdown()
    local playerHealthPercent = UnitHealth("player") / UnitHealthMax("player")
    local lowHealthThreshold = (HealIQ.db and HealIQ.db.strategy and HealIQ.db.strategy.lowHealthThreshold) or 0.5

    return barkskinReady and inCombat and (playerHealthPercent <= lowHealthThreshold)
end

function Tracker:ShouldUseEfflorescence()
    if HealIQ.Rules and HealIQ.Rules.AoERules then
        return HealIQ.Rules.AoERules:ShouldUseEfflorescence(self)
    end
    -- Fallback logic
    local efflorescenceReady = self:IsSpellReady("efflorescence")
    local notActive = not trackedData.efflorescenceActive
    local recentDamageCount = self:GetRecentDamageCount()
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = strategy.efflorescenceMinTargets or 2

    return efflorescenceReady and notActive and recentDamageCount >= minTargets
end

function Tracker:ShouldUseTranquility()
    if HealIQ.Rules and HealIQ.Rules.HealingCooldowns then
        return HealIQ.Rules.HealingCooldowns:ShouldUseTranquility(self)
    end
    -- Fallback logic
    local tranquilityReady = self:IsSpellReady("tranquility")
    local recentDamageCount = self:GetRecentDamageCount()
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = strategy.tranquilityMinTargets or 4

    return tranquilityReady and recentDamageCount >= minTargets
end

function Tracker:ShouldUseFlourish()
    if HealIQ.Rules and HealIQ.Rules.UtilityRules then
        return HealIQ.Rules.UtilityRules:ShouldUseFlourish(self)
    end
    -- Fallback logic would go here but is complex, so return false
    return false
end

function Tracker:ShouldUseIncarnation()
    if HealIQ.Rules and HealIQ.Rules.HealingCooldowns then
        return HealIQ.Rules.HealingCooldowns:ShouldUseIncarnation(self)
    end
    -- Fallback logic
    local incarnationReady = self:IsSpellReady("incarnationTree")
    local recentDamageCount = self:GetRecentDamageCount()
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = math.max(2, strategy.wildGrowthMinTargets or 1)

    return incarnationReady and recentDamageCount >= minTargets
end

function Tracker:ShouldUseNaturesSwiftness()
    if HealIQ.Rules and HealIQ.Rules.HealingCooldowns then
        return HealIQ.Rules.HealingCooldowns:ShouldUseNaturesSwiftness(self)
    end
    -- Fallback logic would be complex, return false
    return false
end

function Tracker:ShouldUseGroveGuardians()
    if HealIQ.Rules and HealIQ.Rules.UtilityRules then
        return HealIQ.Rules.UtilityRules:ShouldUseGroveGuardians(self)
    end
    -- Fallback logic would be complex, return false
    return false
end

function Tracker:ShouldUseWrath()
    if HealIQ.Rules and HealIQ.Rules.OffensiveRules then
        return HealIQ.Rules.OffensiveRules:ShouldUseWrath(self)
    end
    -- Fallback logic would be complex, return false
    return false
end

HealIQ.Tracker = Tracker
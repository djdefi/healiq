-- HealIQ Tracker.lua
-- Tracks buffs, cooldowns, and relevant unit conditions

local addonName, HealIQ = ...

HealIQ.Tracker = {}
local Tracker = HealIQ.Tracker

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
    
    -- Helper function to update cooldown data
    local function updateCooldown(spellId, spellName)
        local startTime, duration, isEnabled = C_Spell.GetSpellCooldown(spellId)
        -- Defensive check: ensure we got valid values and spell is on cooldown
        if startTime and duration and isEnabled and startTime > 0 and duration > 0 then
            local remaining = (startTime + duration) - currentTime
            trackedData.cooldowns[spellName] = {
                remaining = math.max(0, remaining),
                ready = remaining <= 0,
                start = startTime,
                duration = duration
            }
        else
            -- Clear any existing data when spell is not on cooldown
            trackedData.cooldowns[spellName] = nil
        end
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
        local itemId = GetInventoryItemID("player", slot)
        if itemId then
            local startTime, duration, isEnabled = C_Item.GetItemCooldown(itemId)
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
    
    -- Helper function to check for buff
    local function checkBuff(spellId, buffName)
        local spellName = C_Spell.GetSpellName(spellId)
        if spellName then
            local auraData = C_UnitAuras.GetAuraDataBySpellName("player", spellName, "HELPFUL")
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
            trackedData.playerBuffs[buffName] = {
                active = false,
                remaining = 0,
                stacks = 0
            }
        end
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
    
    local currentTime = GetTime()
    
    -- Check for Lifebloom on target
    local spellName = C_Spell.GetSpellName(SPELL_IDS.LIFEBLOOM)
    local auraData = spellName and C_UnitAuras.GetAuraDataBySpellName("target", spellName, "HELPFUL")
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
    spellName = C_Spell.GetSpellName(SPELL_IDS.REJUVENATION)
    auraData = spellName and C_UnitAuras.GetAuraDataBySpellName("target", spellName, "HELPFUL")
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
    spellName = C_Spell.GetSpellName(SPELL_IDS.REGROWTH)
    auraData = spellName and C_UnitAuras.GetAuraDataBySpellName("target", spellName, "HELPFUL")
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
    -- If no cooldown entry exists, the spell is ready (not on cooldown)
    -- If cooldown entry exists, check if it's marked as ready
    return not cooldown or cooldown.ready
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

function Tracker:ShouldUseIronbark()
    -- Suggest Ironbark if available and target is taking damage
    local ironbarkReady = self:IsSpellReady("ironbark")
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

function Tracker:ShouldUseEfflorescence()
    -- Suggest Efflorescence if available, not currently active, and multiple people took damage
    local efflorescenceReady = self:IsSpellReady("efflorescence")
    local notActive = not trackedData.efflorescenceActive
    local recentDamageCount = self:GetRecentDamageCount()
    
    -- Use configurable threshold
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = strategy.efflorescenceMinTargets or 2
    
    return efflorescenceReady and notActive and recentDamageCount >= minTargets
end

function Tracker:ShouldUseTranquility()
    -- Suggest Tranquility if available and high group damage
    local tranquilityReady = self:IsSpellReady("tranquility")
    local recentDamageCount = self:GetRecentDamageCount()
    
    -- Use configurable threshold
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = strategy.tranquilityMinTargets or 4
    
    return tranquilityReady and recentDamageCount >= minTargets
end

function Tracker:ShouldUseFlourish()
    -- Suggest Flourish if available and multiple HoTs are about to expire
    local flourishReady = self:IsSpellReady("flourish")
    local expiringHots = 0
    
    -- Use configurable threshold for expiring HoTs
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minHots = strategy.flourishMinHots or 2
    local expirationWindow = 6 -- HoTs expiring in next 6 seconds
    
    -- Check for expiring HoTs on target
    if UnitExists("target") then
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

function Tracker:ShouldUseIncarnation()
    -- Suggest Incarnation during high damage phases
    local incarnationReady = self:IsSpellReady("incarnationTree")
    local recentDamageCount = self:GetRecentDamageCount()
    
    -- Use more aggressive threshold for major cooldown
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local minTargets = math.max(2, strategy.wildGrowthMinTargets or 1)
    
    return incarnationReady and recentDamageCount >= minTargets
end

function Tracker:ShouldUseNaturesSwiftness()
    -- Suggest Nature's Swiftness if available and healing is needed
    local naturesSwiftnessReady = self:IsSpellReady("naturesSwiftness")
    local targetExists = UnitExists("target")
    local targetIsFriendly = targetExists and UnitIsFriend("player", "target")
    
    -- Enhanced logic: suggest more proactively, not just in emergencies
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local shouldSuggest = false
    
    -- Emergency situations (low health targets)
    if targetExists and targetIsFriendly then
        local healthPercent = UnitHealth("target") / UnitHealthMax("target")
        local lowHealthThreshold = strategy.lowHealthThreshold or 0.3
        if healthPercent <= lowHealthThreshold then
            shouldSuggest = true
        end
    end
    
    -- Proactive use during combat with group damage
    if not shouldSuggest and InCombatLockdown() then
        local recentDamageCount = self:GetRecentDamageCount()
        local groupSize = GetNumGroupMembers()
        -- Suggest if significant group damage (25% of group or 2+ people)
        if recentDamageCount >= math.max(2, math.floor(groupSize * 0.25)) then
            shouldSuggest = true
        end
    end
    
    -- Allow manual override via strategy setting
    local emergencyOnly = strategy.emergencyNaturesSwiftness == true
    if emergencyOnly then
        -- Only suggest in emergency situations when this setting is true
        shouldSuggest = targetExists and targetIsFriendly and UnitHealth("target") / UnitHealthMax("target") <= (strategy.lowHealthThreshold or 0.3)
    end
    
    return naturesSwiftnessReady and shouldSuggest
end

function Tracker:ShouldUseBarkskin()
    -- Suggest Barkskin if available and player is taking damage
    local barkskinReady = self:IsSpellReady("barkskin")
    local inCombat = InCombatLockdown()
    
    -- Enhanced logic: consider player health and threat
    local playerHealthPercent = UnitHealth("player") / UnitHealthMax("player")
    local lowHealthThreshold = (HealIQ.db and HealIQ.db.strategy and HealIQ.db.strategy.lowHealthThreshold) or 0.5
    
    return barkskinReady and inCombat and (playerHealthPercent <= lowHealthThreshold)
end

function Tracker:ShouldUseGroveGuardians()
    -- Suggest Grove Guardians based on strategy - pool charges for big cooldowns
    local groveGuardiansReady = self:IsSpellReady("groveGuardians")
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local poolCharges = strategy.poolGroveGuardians ~= false -- default true
    
    if not groveGuardiansReady then
        return false
    end
    
    -- If pooling is disabled, suggest whenever ready
    if not poolCharges then
        return true
    end
    
    -- Enhanced pooling logic: suggest more frequently
    local recentDamageCount = self:GetRecentDamageCount()
    local minTargets = strategy.wildGrowthMinTargets or 1
    local hasOtherCooldowns = self:HasPlayerBuff("incarnationTree") or self:HasPlayerBuff("naturesSwiftness")
    local inCombat = InCombatLockdown()
    
    -- Suggest if:
    -- 1. High damage to group, OR
    -- 2. Other major cooldowns are active, OR  
    -- 3. In combat with any group damage
    return (recentDamageCount >= minTargets) or hasOtherCooldowns or (inCombat and recentDamageCount >= 1)
end

function Tracker:ShouldUseWrath()
    -- Suggest Wrath for mana restoration during downtime
    local wrathReady = not self:IsSpellReady("wrath") or true -- Wrath has no cooldown typically
    local strategy = HealIQ.db and HealIQ.db.strategy or {}
    local useForMana = strategy.useWrathForMana ~= false -- default true
    
    if not useForMana then
        return false
    end
    
    -- Only suggest Wrath during low activity periods
    local inCombat = InCombatLockdown()
    local recentDamageCount = self:GetRecentDamageCount()
    local hasTarget = UnitExists("target")
    local targetIsEnemy = hasTarget and UnitIsEnemy("player", "target")
    
    -- Suggest if:
    -- 1. Not in combat and have enemy target, OR
    -- 2. In combat but low damage activity and have enemy target, OR
    -- 3. No immediate healing needs
    local lowActivity = recentDamageCount == 0
    local noHealingNeeds = not self:HasImmediateHealingNeeds()
    
    return wrathReady and ((not inCombat and targetIsEnemy) or (inCombat and lowActivity and targetIsEnemy) or (inCombat and noHealingNeeds and targetIsEnemy))
end

function Tracker:HasImmediateHealingNeeds()
    -- Check if there are immediate healing needs
    local hasTarget = UnitExists("target")
    local targetIsFriendly = hasTarget and UnitIsFriend("player", "target")
    
    if targetIsFriendly then
        -- Check if target has low health
        local healthPercent = UnitHealth("target") / UnitHealthMax("target")
        local strategy = HealIQ.db and HealIQ.db.strategy or {}
        local lowHealthThreshold = strategy.lowHealthThreshold or 0.3
        
        if healthPercent <= lowHealthThreshold then
            return true
        end
        
        -- Check if target is missing important buffs
        local lifeboomInfo = self:GetTargetHotInfo("lifebloom")
        local rejuvInfo = self:GetTargetHotInfo("rejuvenation")
        local isTank = UnitGroupRolesAssigned("target") == "TANK"
        local isFocus = UnitIsUnit("target", "focus")
        
        -- Tank missing Lifebloom is high priority
        if (isTank or isFocus) and (not lifeboomInfo or not lifeboomInfo.active) then
            return true
        end
        
        -- Missing Rejuvenation during combat
        if InCombatLockdown() and (not rejuvInfo or not rejuvInfo.active) then
            return true
        end
    end
    
    -- Check for group damage
    local recentDamageCount = self:GetRecentDamageCount()
    return recentDamageCount >= 2
end

function Tracker:HasActiveTrinket()
    -- Check if any trinket is ready to use
    for slot = 13, 14 do
        local itemId = GetInventoryItemID("player", slot)
        if itemId then
            local startTime, duration, isEnabled = C_Item.GetItemCooldown(itemId)
            -- Check if trinket has a use effect and is not on cooldown
            if isEnabled and (not startTime or startTime == 0 or duration == 0) then
                -- Additional check to see if item has a use effect
                if type(itemId) == "number" and itemId > 0 then
                    local item = Item:CreateFromItemID(itemId)
                    if item and item:IsItemDataCached() then
                        local itemSpell = C_Item.GetItemSpell(itemId)
                        if itemSpell then
                            return true, slot
                        end
                    end
                end
            end
        end
    end
    return false, nil
end

HealIQ.Tracker = Tracker
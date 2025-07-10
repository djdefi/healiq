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
        local cooldownInfo = C_Spell.GetSpellCooldown(spellId)
        -- Defensive check: ensure we got valid values
        if cooldownInfo and cooldownInfo.isEnabled then
            local remaining = (cooldownInfo.startTime + cooldownInfo.duration) - currentTime
            trackedData.cooldowns[spellName] = {
                remaining = math.max(0, remaining),
                ready = remaining <= 0,
                start = cooldownInfo.startTime,
                duration = cooldownInfo.duration
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
    
    -- Track trinket cooldowns (slot 13 and 14)
    for slot = 13, 14 do
        local itemId = GetInventoryItemID("player", slot)
        if itemId then
            local cooldownInfo = C_Item.GetItemCooldown(itemId)
            -- Defensive check: ensure we got valid values
            if cooldownInfo and cooldownInfo.isEnabled then
                local remaining = (cooldownInfo.startTime + cooldownInfo.duration) - currentTime
                trackedData.trinketCooldowns[slot] = {
                    remaining = math.max(0, remaining),
                    ready = remaining <= 0,
                    start = cooldownInfo.startTime,
                    duration = cooldownInfo.duration,
                    itemId = itemId
                }
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
    
    for guid, time in pairs(trackedData.recentDamage) do
        if currentTime - time <= 3 then -- Count damage within last 3 seconds
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
    return cooldown and cooldown.ready
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
    
    return efflorescenceReady and notActive and recentDamageCount >= 2
end

function Tracker:ShouldUseTranquility()
    -- Suggest Tranquility if available and high group damage
    local tranquilityReady = self:IsSpellReady("tranquility")
    local recentDamageCount = self:GetRecentDamageCount()
    
    return tranquilityReady and recentDamageCount >= 4
end

function Tracker:ShouldUseFlourish()
    -- Suggest Flourish if available and multiple HoTs are about to expire
    local flourishReady = self:IsSpellReady("flourish")
    local expiringHots = 0
    
    -- Check for expiring HoTs on target
    if UnitExists("target") then
        local rejuv = trackedData.targetHots.rejuvenation
        local regrowth = trackedData.targetHots.regrowth
        local lifebloom = trackedData.targetHots.lifebloom
        
        if rejuv and rejuv.active and rejuv.remaining < 6 then
            expiringHots = expiringHots + 1
        end
        if regrowth and regrowth.active and regrowth.remaining < 6 then
            expiringHots = expiringHots + 1
        end
        if lifebloom and lifebloom.active and lifebloom.remaining < 6 then
            expiringHots = expiringHots + 1
        end
    end
    
    return flourishReady and expiringHots >= 2
end

function Tracker:ShouldUseIncarnation()
    -- Suggest Incarnation during high damage phases
    local incarnationReady = self:IsSpellReady("incarnationTree")
    local recentDamageCount = self:GetRecentDamageCount()
    
    return incarnationReady and recentDamageCount >= 3
end

function Tracker:ShouldUseNaturesSwiftness()
    -- Suggest Nature's Swiftness if available and target needs immediate healing
    local naturesSwiftnessReady = self:IsSpellReady("naturesSwiftness")
    local targetExists = UnitExists("target")
    local targetIsFriendly = targetExists and UnitIsFriend("player", "target")
    
    return naturesSwiftnessReady and targetIsFriendly
end

function Tracker:ShouldUseBarkskin()
    -- Suggest Barkskin if available and player is taking damage
    local barkskinReady = self:IsSpellReady("barkskin")
    local inCombat = InCombatLockdown()
    
    return barkskinReady and inCombat
end

function Tracker:HasActiveTrinket()
    -- Check if any trinket is ready to use
    for slot = 13, 14 do
        local trinket = trackedData.trinketCooldowns[slot]
        if trinket and trinket.ready then
            return true, slot
        end
    end
    return false, nil
end

HealIQ.Tracker = Tracker
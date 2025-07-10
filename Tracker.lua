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
    
    -- Buffs
    CLEARCASTING_BUFF = 16870,
}

-- Track state
local trackedData = {
    cooldowns = {},
    buffs = {},
    lastCombatLogTime = 0,
    recentDamage = {},
    targetHots = {},
}

function Tracker:Initialize()
    self:RegisterEvents()
    HealIQ:Print("Tracker initialized")
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
    if event == "SPELL_UPDATE_COOLDOWN" then
        self:UpdateCooldowns()
    elseif event == "UNIT_AURA" then
        local unit = ...
        self:UpdateUnitAuras(unit)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:ParseCombatLog()
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:UpdateTargetHots()
    end
end

function Tracker:UpdateCooldowns()
    local currentTime = GetTime()
    
    -- Track Wild Growth
    local start, duration, enabled = GetSpellCooldown(SPELL_IDS.WILD_GROWTH)
    if enabled == 1 then
        local remaining = (start + duration) - currentTime
        trackedData.cooldowns.wildGrowth = {
            remaining = math.max(0, remaining),
            ready = remaining <= 0,
            start = start,
            duration = duration
        }
    end
    
    -- Track Swiftmend
    start, duration, enabled = GetSpellCooldown(SPELL_IDS.SWIFTMEND)
    if enabled == 1 then
        local remaining = (start + duration) - currentTime
        trackedData.cooldowns.swiftmend = {
            remaining = math.max(0, remaining),
            ready = remaining <= 0,
            start = start,
            duration = duration
        }
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
    -- Check for Clearcasting
    local name, icon, count, debuffType, duration, expirationTime = AuraUtil.FindAuraBySpellID(SPELL_IDS.CLEARCASTING_BUFF, "player", "HELPFUL")
    
    if name then
        trackedData.buffs.clearcasting = {
            active = true,
            remaining = expirationTime - GetTime(),
            stacks = count or 1
        }
    else
        trackedData.buffs.clearcasting = {
            active = false,
            remaining = 0,
            stacks = 0
        }
    end
end

function Tracker:UpdateTargetHots()
    if not UnitExists("target") then
        trackedData.targetHots = {}
        return
    end
    
    local currentTime = GetTime()
    
    -- Check for Lifebloom on target
    local name, icon, count, debuffType, duration, expirationTime = AuraUtil.FindAuraBySpellID(SPELL_IDS.LIFEBLOOM, "target", "HELPFUL")
    if name then
        trackedData.targetHots.lifebloom = {
            active = true,
            remaining = expirationTime - currentTime,
            stacks = count or 1
        }
    else
        trackedData.targetHots.lifebloom = {
            active = false,
            remaining = 0,
            stacks = 0
        }
    end
    
    -- Check for Rejuvenation on target
    name, icon, count, debuffType, duration, expirationTime = AuraUtil.FindAuraBySpellID(SPELL_IDS.REJUVENATION, "target", "HELPFUL")
    if name then
        trackedData.targetHots.rejuvenation = {
            active = true,
            remaining = expirationTime - currentTime,
            stacks = count or 1
        }
    else
        trackedData.targetHots.rejuvenation = {
            active = false,
            remaining = 0,
            stacks = 0
        }
    end
    
    -- Check for Regrowth on target
    name, icon, count, debuffType, duration, expirationTime = AuraUtil.FindAuraBySpellID(SPELL_IDS.REGROWTH, "target", "HELPFUL")
    if name then
        trackedData.targetHots.regrowth = {
            active = true,
            remaining = expirationTime - currentTime,
            stacks = count or 1
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
            for guid, time in pairs(trackedData.recentDamage) do
                if currentTime - time > 5 then
                    trackedData.recentDamage[guid] = nil
                end
            end
        end
    end
end

-- Public getter functions
function Tracker:GetCooldownInfo(spellName)
    return trackedData.cooldowns[spellName]
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

HealIQ.Tracker = Tracker
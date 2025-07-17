-- HealIQ EncounterIntegration.lua
-- DBM/BigWigs integration for encounter-aware healing suggestions

local addonName, HealIQ = ...

HealIQ.EncounterIntegration = {}
local EncounterIntegration = HealIQ.EncounterIntegration

-- Integration state
local encounterData = {
    dbmLoaded = false,
    bigWigsLoaded = false,
    activeEncounter = nil,
    upcomingEvents = {},
    lastEventCheck = 0,
    encounterPhase = 0,
}

-- Event types that trigger healing preparation
local HEALING_RELEVANT_EVENTS = {
    "damage_aoe",
    "damage_tank", 
    "damage_raid",
    "heal_intensive",
    "cooldown_phase",
}

function EncounterIntegration:Initialize()
    HealIQ:SafeCall(function()
        self:DetectAddons()
        self:RegisterIntegrations()
        HealIQ:DebugLog("EncounterIntegration initialized - DBM: " .. tostring(encounterData.dbmLoaded) .. ", BigWigs: " .. tostring(encounterData.bigWigsLoaded))
    end)
end

function EncounterIntegration:DetectAddons()
    -- Check if DBM is loaded
    if IsAddOnLoaded("DBM-Core") then
        encounterData.dbmLoaded = true
        HealIQ:DebugLog("DBM detected and loaded")
    end
    
    -- Check if BigWigs is loaded  
    if IsAddOnLoaded("BigWigs_Core") or IsAddOnLoaded("BigWigs") then
        encounterData.bigWigsLoaded = true
        HealIQ:DebugLog("BigWigs detected and loaded")
    end
end

function EncounterIntegration:RegisterIntegrations()
    if encounterData.dbmLoaded then
        self:RegisterDBMIntegration()
    end
    
    if encounterData.bigWigsLoaded then
        self:RegisterBigWigsIntegration()
    end
    
    -- Register for addon loading events in case they load later
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "DBM-Core" then
            encounterData.dbmLoaded = true
            EncounterIntegration:RegisterDBMIntegration()
            HealIQ:DebugLog("DBM loaded after startup - registering integration")
        elseif addonName == "BigWigs_Core" or addonName == "BigWigs" then
            encounterData.bigWigsLoaded = true
            EncounterIntegration:RegisterBigWigsIntegration()
            HealIQ:DebugLog("BigWigs loaded after startup - registering integration")
        end
    end)
end

function EncounterIntegration:RegisterDBMIntegration()
    HealIQ:SafeCall(function()
        if not DBM then
            return
        end
        
        -- Register for DBM timer events
        DBM:RegisterCallback("timerStart", function(id, text, timer, icon, type, spellId, colorId)
            self:OnDBMTimer(id, text, timer, icon, type, spellId, colorId)
        end)
        
        -- Register for DBM combat events
        DBM:RegisterCallback("pull", function(delay, mod, sync)
            encounterData.activeEncounter = mod and mod.id or "unknown"
            encounterData.encounterPhase = 1
            HealIQ:DebugLog("DBM: Encounter started - " .. tostring(encounterData.activeEncounter))
        end)
        
        DBM:RegisterCallback("wipe", function(mod)
            self:ResetEncounterData()
            HealIQ:DebugLog("DBM: Encounter wiped")
        end)
        
        DBM:RegisterCallback("kill", function(mod)
            self:ResetEncounterData()
            HealIQ:DebugLog("DBM: Encounter completed")
        end)
        
        HealIQ:DebugLog("DBM integration callbacks registered")
    end)
end

function EncounterIntegration:RegisterBigWigsIntegration()
    HealIQ:SafeCall(function()
        if not BigWigs then
            return
        end
        
        -- Create frame to listen for BigWigs events
        local frame = CreateFrame("Frame")
        
        -- Register for BigWigs timer events
        frame:RegisterEvent("BIGWIGS_TIMER_START")
        frame:RegisterEvent("BIGWIGS_TIMER_STOP")
        frame:RegisterEvent("BIGWIGS_ENCOUNTER_START")
        frame:RegisterEvent("BIGWIGS_ENCOUNTER_END")
        
        frame:SetScript("OnEvent", function(self, event, ...)
            if event == "BIGWIGS_TIMER_START" then
                local text, duration, icon, isApprox = ...
                EncounterIntegration:OnBigWigsTimer(text, duration, icon, isApprox)
            elseif event == "BIGWIGS_ENCOUNTER_START" then
                local encounterId = ...
                encounterData.activeEncounter = encounterId
                encounterData.encounterPhase = 1
                HealIQ:DebugLog("BigWigs: Encounter started - " .. tostring(encounterId))
            elseif event == "BIGWIGS_ENCOUNTER_END" then
                EncounterIntegration:ResetEncounterData()
                HealIQ:DebugLog("BigWigs: Encounter ended")
            end
        end)
        
        HealIQ:DebugLog("BigWigs integration events registered")
    end)
end

function EncounterIntegration:OnDBMTimer(id, text, timer, icon, type, spellId, colorId)
    HealIQ:SafeCall(function()
        local eventData = {
            source = "DBM",
            id = id,
            text = text,
            duration = timer,
            icon = icon,
            type = type,
            spellId = spellId,
            timestamp = GetTime(),
            expiresAt = GetTime() + timer,
            healingRelevant = self:IsHealingRelevantEvent(text, spellId)
        }
        
        if eventData.healingRelevant then
            table.insert(encounterData.upcomingEvents, eventData)
            HealIQ:DebugLog("DBM healing-relevant timer added: " .. text .. " in " .. timer .. "s")
        end
        
        -- Clean up old events
        self:CleanupOldEvents()
    end)
end

function EncounterIntegration:OnBigWigsTimer(text, duration, icon, isApprox)
    HealIQ:SafeCall(function()
        local eventData = {
            source = "BigWigs",
            text = text,
            duration = duration,
            icon = icon,
            isApprox = isApprox,
            timestamp = GetTime(),
            expiresAt = GetTime() + duration,
            healingRelevant = self:IsHealingRelevantEvent(text, nil)
        }
        
        if eventData.healingRelevant then
            table.insert(encounterData.upcomingEvents, eventData)
            HealIQ:DebugLog("BigWigs healing-relevant timer added: " .. text .. " in " .. duration .. "s")
        end
        
        -- Clean up old events
        self:CleanupOldEvents()
    end)
end

function EncounterIntegration:IsHealingRelevantEvent(text, spellId)
    if not text then
        return false
    end
    
    local textLower = string.lower(text)
    
    -- Look for keywords that indicate healing-intensive phases
    local healingKeywords = {
        "aoe", "raid", "damage", "burn", "phase", "transition",
        "storm", "blast", "wave", "pulse", "explosion", "fire",
        "shadow", "void", "cleave", "spread", "dot", "debuff"
    }
    
    for _, keyword in ipairs(healingKeywords) do
        if string.find(textLower, keyword) then
            return true
        end
    end
    
    -- Check specific spell IDs that are known to require healing preparation
    if spellId then
        local healingSpells = {
            -- Add specific spell IDs that require healing preparation
            -- This would be populated based on encounter knowledge
        }
        
        for _, id in ipairs(healingSpells) do
            if spellId == id then
                return true
            end
        end
    end
    
    return false
end

function EncounterIntegration:CleanupOldEvents()
    local currentTime = GetTime()
    local newEvents = {}
    
    for _, event in ipairs(encounterData.upcomingEvents) do
        if event.expiresAt > currentTime then
            table.insert(newEvents, event)
        end
    end
    
    encounterData.upcomingEvents = newEvents
end

function EncounterIntegration:ResetEncounterData()
    encounterData.activeEncounter = nil
    encounterData.upcomingEvents = {}
    encounterData.encounterPhase = 0
end

-- Public API for Engine to query encounter state
function EncounterIntegration:IsInEncounter()
    return encounterData.activeEncounter ~= nil
end

function EncounterIntegration:GetUpcomingHealingEvents(timeWindow)
    timeWindow = timeWindow or 15 -- Default 15 second window
    local currentTime = GetTime()
    local upcomingEvents = {}
    
    for _, event in ipairs(encounterData.upcomingEvents) do
        local timeUntil = event.expiresAt - currentTime
        if timeUntil > 0 and timeUntil <= timeWindow and event.healingRelevant then
            table.insert(upcomingEvents, {
                text = event.text,
                timeUntil = timeUntil,
                source = event.source,
                priority = self:GetEventPriority(event)
            })
        end
    end
    
    -- Sort by time until event
    table.sort(upcomingEvents, function(a, b) return a.timeUntil < b.timeUntil end)
    
    return upcomingEvents
end

function EncounterIntegration:GetEventPriority(event)
    local textLower = string.lower(event.text or "")
    
    -- High priority events (require immediate preparation)
    if string.find(textLower, "raid") or string.find(textLower, "aoe") then
        return "high"
    end
    
    -- Medium priority events (suggest preparation)
    if string.find(textLower, "damage") or string.find(textLower, "phase") then
        return "medium"
    end
    
    return "low"
end

function EncounterIntegration:ShouldPrepareForAoE(timeWindow)
    timeWindow = timeWindow or 10
    local events = self:GetUpcomingHealingEvents(timeWindow)
    
    for _, event in ipairs(events) do
        if event.priority == "high" and event.timeUntil <= timeWindow then
            return true, event.timeUntil, event.text
        end
    end
    
    return false
end

function EncounterIntegration:GetEncounterPhase()
    return encounterData.encounterPhase
end

function EncounterIntegration:IsAddonActive()
    return encounterData.dbmLoaded or encounterData.bigWigsLoaded
end
-- HealIQ Engine.lua
-- Priority logic engine that determines the suggested spell

local addonName, HealIQ = ...

HealIQ.Engine = {}
local Engine = HealIQ.Engine

-- Spell information for suggestions
local SPELLS = {
    WILD_GROWTH = {
        id = 48438,
        name = "Wild Growth",
        icon = "Interface\\Icons\\Ability_Druid_WildGrowth",
        priority = 1,
    },
    REGROWTH = {
        id = 8936,
        name = "Regrowth",
        icon = "Interface\\Icons\\Spell_Nature_ResistNature",
        priority = 2,
    },
    LIFEBLOOM = {
        id = 33763,
        name = "Lifebloom",
        icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom",
        priority = 3,
    },
    SWIFTMEND = {
        id = 18562,
        name = "Swiftmend",
        icon = "Interface\\Icons\\INV_Relics_IdolofRejuvenation",
        priority = 4,
    },
    REJUVENATION = {
        id = 774,
        name = "Rejuvenation",
        icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        priority = 5,
    },
}

-- Current suggestion state
local currentSuggestion = nil
local lastUpdate = 0
local updateInterval = 0.1 -- Update every 100ms

function Engine:Initialize()
    self:StartUpdateLoop()
    HealIQ:Print("Engine initialized")
end

function Engine:StartUpdateLoop()
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(self, elapsed)
        Engine:OnUpdate(elapsed)
    end)
end

function Engine:OnUpdate(elapsed)
    local currentTime = GetTime()
    
    -- Throttle updates
    if currentTime - lastUpdate < updateInterval then
        return
    end
    
    lastUpdate = currentTime
    
    -- Only suggest spells if addon is enabled and player is in combat or has a target
    if not HealIQ.db.enabled then
        self:SetSuggestion(nil)
        return
    end
    
    -- Check if we should be suggesting anything
    if not self:ShouldSuggest() then
        self:SetSuggestion(nil)
        return
    end
    
    -- Evaluate priority rules
    local suggestion = self:EvaluateRules()
    self:SetSuggestion(suggestion)
end

function Engine:ShouldSuggest()
    -- Only suggest if player is a Restoration Druid
    local _, class = UnitClass("player")
    if class ~= "DRUID" then
        return false
    end
    
    local specIndex = GetSpecialization()
    if specIndex ~= 4 then -- Not Restoration
        return false
    end
    
    -- Suggest in combat or when having a friendly target
    local inCombat = InCombatLockdown()
    local hasTarget = UnitExists("target")
    local targetIsFriendly = hasTarget and UnitIsFriend("player", "target")
    
    return inCombat or (hasTarget and targetIsFriendly)
end

function Engine:EvaluateRules()
    local tracker = HealIQ.Tracker
    if not tracker then
        return nil
    end
    
    -- Rule 1: Wild Growth if off cooldown and 3+ allies recently damaged
    if HealIQ.db.rules.wildGrowth and tracker:IsSpellReady("wildGrowth") then
        local recentDamageCount = tracker:GetRecentDamageCount()
        if recentDamageCount >= 3 then
            return SPELLS.WILD_GROWTH
        end
    end
    
    -- Rule 2: Clearcasting active → Suggest Regrowth
    if HealIQ.db.rules.clearcasting and tracker:HasClearcasting() then
        return SPELLS.REGROWTH
    end
    
    -- Rule 3: Lifebloom on target < 4s → Suggest refresh
    if HealIQ.db.rules.lifebloom and UnitExists("target") and UnitIsFriend("player", "target") then
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        if lifeboomInfo and lifeboomInfo.active and lifeboomInfo.remaining < 4 then
            return SPELLS.LIFEBLOOM
        end
    end
    
    -- Rule 4: Swiftmend is usable and Rejuv+Regrowth are active → Suggest Swiftmend
    if HealIQ.db.rules.swiftmend and tracker:CanSwiftmend() then
        return SPELLS.SWIFTMEND
    end
    
    -- Rule 5: No Rejuvenation on current target → Suggest Rejuvenation
    if HealIQ.db.rules.rejuvenation and UnitExists("target") and UnitIsFriend("player", "target") then
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        if not rejuvInfo or not rejuvInfo.active then
            return SPELLS.REJUVENATION
        end
    end
    
    -- Rule 6: No Lifebloom on target at all → Suggest Lifebloom
    if HealIQ.db.rules.lifebloom and UnitExists("target") and UnitIsFriend("player", "target") then
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        if not lifeboomInfo or not lifeboomInfo.active then
            -- Check if target is a tank (simple heuristic)
            if UnitGroupRolesAssigned("target") == "TANK" then
                return SPELLS.LIFEBLOOM
            end
        end
    end
    
    -- No suggestion
    return nil
end

function Engine:SetSuggestion(suggestion)
    if suggestion ~= currentSuggestion then
        currentSuggestion = suggestion
        
        -- Notify UI of change
        if HealIQ.UI then
            HealIQ.UI:UpdateSuggestion(suggestion)
        end
        
        -- Debug output
        if suggestion then
            HealIQ:Print("Suggesting: " .. suggestion.name)
        else
            HealIQ:Print("No suggestion")
        end
    end
end

function Engine:GetCurrentSuggestion()
    return currentSuggestion
end

function Engine:ForceUpdate()
    lastUpdate = 0
    self:OnUpdate(0)
end

-- Public rule evaluation functions for testing
function Engine:TestRule(ruleName, ...)
    local tracker = HealIQ.Tracker
    if not tracker then
        return false
    end
    
    if ruleName == "wildGrowth" then
        return tracker:IsSpellReady("wildGrowth") and tracker:GetRecentDamageCount() >= 3
    elseif ruleName == "clearcasting" then
        return tracker:HasClearcasting()
    elseif ruleName == "lifebloom" then
        if not UnitExists("target") then return false end
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        return lifeboomInfo and lifeboomInfo.active and lifeboomInfo.remaining < 4
    elseif ruleName == "swiftmend" then
        return tracker:CanSwiftmend()
    elseif ruleName == "rejuvenation" then
        if not UnitExists("target") then return false end
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        return not rejuvInfo or not rejuvInfo.active
    end
    
    return false
end

HealIQ.Engine = Engine
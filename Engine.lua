-- HealIQ Engine.lua
-- Priority logic engine that determines the suggested spell

local addonName, HealIQ = ...

HealIQ.Engine = {}
local Engine = HealIQ.Engine

-- Spell information for suggestions
local SPELLS = {
    TRANQUILITY = {
        id = 740,
        name = "Tranquility",
        icon = "Interface\\Icons\\Spell_Nature_Tranquility",
        priority = 1,
    },
    INCARNATION_TREE = {
        id = 33891,
        name = "Incarnation",
        icon = "Interface\\Icons\\Spell_Druid_Incarnation",
        priority = 2,
    },
    IRONBARK = {
        id = 102342,
        name = "Ironbark",
        icon = "Interface\\Icons\\Spell_Druid_IronBark",
        priority = 3,
    },
    WILD_GROWTH = {
        id = 48438,
        name = "Wild Growth",
        icon = "Interface\\Icons\\Ability_Druid_WildGrowth",
        priority = 4,
    },
    EFFLORESCENCE = {
        id = 145205,
        name = "Efflorescence",
        icon = "Interface\\Icons\\Ability_Druid_Efflorescence",
        priority = 5,
    },
    FLOURISH = {
        id = 197721,
        name = "Flourish",
        icon = "Interface\\Icons\\Spell_Druid_WildGrowth",
        priority = 6,
    },
    NATURES_SWIFTNESS = {
        id = 132158,
        name = "Nature's Swiftness",
        icon = "Interface\\Icons\\Spell_Nature_RavenForm",
        priority = 7,
    },
    REGROWTH = {
        id = 8936,
        name = "Regrowth",
        icon = "Interface\\Icons\\Spell_Nature_ResistNature",
        priority = 8,
    },
    BARKSKIN = {
        id = 22812,
        name = "Barkskin",
        icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
        priority = 9,
    },
    LIFEBLOOM = {
        id = 33763,
        name = "Lifebloom",
        icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom",
        priority = 10,
    },
    SWIFTMEND = {
        id = 18562,
        name = "Swiftmend",
        icon = "Interface\\Icons\\INV_Relics_IdolofRejuvenation",
        priority = 11,
    },
    REJUVENATION = {
        id = 774,
        name = "Rejuvenation",
        icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        priority = 12,
    },
    TRINKET = {
        id = 0, -- Variable
        name = "Use Trinket",
        icon = "Interface\\Icons\\INV_Jewelry_Trinket_03",
        priority = 13,
    },
}

-- Current suggestion state
local currentSuggestion = nil
local currentQueue = {}
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
        self:SetQueue({})
        return
    end
    
    -- Check if we should be suggesting anything
    if not self:ShouldSuggest() then
        self:SetSuggestion(nil)
        self:SetQueue({})
        return
    end
    
    -- Evaluate priority rules
    local suggestion = self:EvaluateRules()
    local queue = self:EvaluateRulesQueue()
    
    self:SetSuggestion(suggestion)
    self:SetQueue(queue)
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
    
    local suggestions = {}
    
    -- Rule 1: Tranquility if off cooldown and 4+ allies recently damaged (highest priority)
    if HealIQ.db.rules.tranquility and tracker:ShouldUseTranquility() then
        table.insert(suggestions, SPELLS.TRANQUILITY)
    end
    
    -- Rule 2: Incarnation: Tree of Life for high damage phases
    if HealIQ.db.rules.incarnationTree and tracker:ShouldUseIncarnation() then
        table.insert(suggestions, SPELLS.INCARNATION_TREE)
    end
    
    -- Rule 3: Ironbark for damage reduction on target
    if HealIQ.db.rules.ironbark and tracker:ShouldUseIronbark() then
        table.insert(suggestions, SPELLS.IRONBARK)
    end
    
    -- Rule 4: Wild Growth if off cooldown and 3+ allies recently damaged
    if HealIQ.db.rules.wildGrowth and tracker:IsSpellReady("wildGrowth") then
        local recentDamageCount = tracker:GetRecentDamageCount()
        if recentDamageCount >= 3 then
            table.insert(suggestions, SPELLS.WILD_GROWTH)
        end
    end
    
    -- Rule 5: Efflorescence if available and not currently active
    if HealIQ.db.rules.efflorescence and tracker:ShouldUseEfflorescence() then
        table.insert(suggestions, SPELLS.EFFLORESCENCE)
    end
    
    -- Rule 6: Flourish if available and multiple HoTs are expiring
    if HealIQ.db.rules.flourish and tracker:ShouldUseFlourish() then
        table.insert(suggestions, SPELLS.FLOURISH)
    end
    
    -- Rule 7: Nature's Swiftness for instant cast
    if HealIQ.db.rules.naturesSwiftness and tracker:ShouldUseNaturesSwiftness() then
        table.insert(suggestions, SPELLS.NATURES_SWIFTNESS)
    end
    
    -- Rule 8: Clearcasting active → Suggest Regrowth
    if HealIQ.db.rules.clearcasting and tracker:HasClearcasting() then
        table.insert(suggestions, SPELLS.REGROWTH)
    end
    
    -- Rule 9: Barkskin for self-defense
    if HealIQ.db.rules.barkskin and tracker:ShouldUseBarkskin() then
        table.insert(suggestions, SPELLS.BARKSKIN)
    end
    
    -- Rule 10: Lifebloom on target < 4s → Suggest refresh
    if HealIQ.db.rules.lifebloom and UnitExists("target") and UnitIsFriend("player", "target") then
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        if lifeboomInfo and lifeboomInfo.active and lifeboomInfo.remaining < 4 then
            table.insert(suggestions, SPELLS.LIFEBLOOM)
        end
    end
    
    -- Rule 11: Swiftmend is usable and Rejuv+Regrowth are active → Suggest Swiftmend
    if HealIQ.db.rules.swiftmend and tracker:CanSwiftmend() then
        table.insert(suggestions, SPELLS.SWIFTMEND)
    end
    
    -- Rule 12: No Rejuvenation on current target → Suggest Rejuvenation
    if HealIQ.db.rules.rejuvenation and UnitExists("target") and UnitIsFriend("player", "target") then
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        if not rejuvInfo or not rejuvInfo.active then
            table.insert(suggestions, SPELLS.REJUVENATION)
        end
    end
    
    -- Rule 13: Trinket usage
    if HealIQ.db.rules.trinket then
        local hasTrinket, slot = tracker:HasActiveTrinket()
        if hasTrinket then
            table.insert(suggestions, SPELLS.TRINKET)
        end
    end
    
    -- Rule 14: No Lifebloom on target at all → Suggest Lifebloom
    if HealIQ.db.rules.lifebloom and UnitExists("target") and UnitIsFriend("player", "target") then
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        if not lifeboomInfo or not lifeboomInfo.active then
            -- Check if target is a tank (simple heuristic)
            if UnitGroupRolesAssigned("target") == "TANK" then
                table.insert(suggestions, SPELLS.LIFEBLOOM)
            end
        end
    end
    
    -- Return the top suggestion for backward compatibility
    return suggestions[1] or nil
end

-- New function to get multiple suggestions for queue display
function Engine:EvaluateRulesQueue()
    local tracker = HealIQ.Tracker
    if not tracker then
        return {}
    end
    
    local suggestions = {}
    
    -- Rule 1: Tranquility if off cooldown and 4+ allies recently damaged (highest priority)
    if HealIQ.db.rules.tranquility and tracker:ShouldUseTranquility() then
        table.insert(suggestions, SPELLS.TRANQUILITY)
    end
    
    -- Rule 2: Incarnation: Tree of Life for high damage phases
    if HealIQ.db.rules.incarnationTree and tracker:ShouldUseIncarnation() then
        table.insert(suggestions, SPELLS.INCARNATION_TREE)
    end
    
    -- Rule 3: Ironbark for damage reduction on target
    if HealIQ.db.rules.ironbark and tracker:ShouldUseIronbark() then
        table.insert(suggestions, SPELLS.IRONBARK)
    end
    
    -- Rule 4: Wild Growth if off cooldown and 3+ allies recently damaged
    if HealIQ.db.rules.wildGrowth and tracker:IsSpellReady("wildGrowth") then
        local recentDamageCount = tracker:GetRecentDamageCount()
        if recentDamageCount >= 3 then
            table.insert(suggestions, SPELLS.WILD_GROWTH)
        end
    end
    
    -- Rule 5: Efflorescence if available and not currently active
    if HealIQ.db.rules.efflorescence and tracker:ShouldUseEfflorescence() then
        table.insert(suggestions, SPELLS.EFFLORESCENCE)
    end
    
    -- Rule 6: Flourish if available and multiple HoTs are expiring
    if HealIQ.db.rules.flourish and tracker:ShouldUseFlourish() then
        table.insert(suggestions, SPELLS.FLOURISH)
    end
    
    -- Rule 7: Nature's Swiftness for instant cast
    if HealIQ.db.rules.naturesSwiftness and tracker:ShouldUseNaturesSwiftness() then
        table.insert(suggestions, SPELLS.NATURES_SWIFTNESS)
    end
    
    -- Rule 8: Clearcasting active → Suggest Regrowth
    if HealIQ.db.rules.clearcasting and tracker:HasClearcasting() then
        table.insert(suggestions, SPELLS.REGROWTH)
    end
    
    -- Rule 9: Barkskin for self-defense
    if HealIQ.db.rules.barkskin and tracker:ShouldUseBarkskin() then
        table.insert(suggestions, SPELLS.BARKSKIN)
    end
    
    -- Rule 10: Lifebloom on target < 4s → Suggest refresh
    if HealIQ.db.rules.lifebloom and UnitExists("target") and UnitIsFriend("player", "target") then
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        if lifeboomInfo and lifeboomInfo.active and lifeboomInfo.remaining < 4 then
            table.insert(suggestions, SPELLS.LIFEBLOOM)
        end
    end
    
    -- Rule 11: Swiftmend is usable and Rejuv+Regrowth are active → Suggest Swiftmend
    if HealIQ.db.rules.swiftmend and tracker:CanSwiftmend() then
        table.insert(suggestions, SPELLS.SWIFTMEND)
    end
    
    -- Rule 12: No Rejuvenation on current target → Suggest Rejuvenation
    if HealIQ.db.rules.rejuvenation and UnitExists("target") and UnitIsFriend("player", "target") then
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        if not rejuvInfo or not rejuvInfo.active then
            table.insert(suggestions, SPELLS.REJUVENATION)
        end
    end
    
    -- Rule 13: Trinket usage
    if HealIQ.db.rules.trinket then
        local hasTrinket, slot = tracker:HasActiveTrinket()
        if hasTrinket then
            table.insert(suggestions, SPELLS.TRINKET)
        end
    end
    
    -- Rule 14: No Lifebloom on target at all → Suggest Lifebloom
    if HealIQ.db.rules.lifebloom and UnitExists("target") and UnitIsFriend("player", "target") then
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        if not lifeboomInfo or not lifeboomInfo.active then
            -- Check if target is a tank (simple heuristic)
            if UnitGroupRolesAssigned("target") == "TANK" then
                table.insert(suggestions, SPELLS.LIFEBLOOM)
            end
        end
    end
    
    -- Return up to 3 suggestions for queue display
    local queue = {}
    for i = 1, math.min(3, #suggestions) do
        table.insert(queue, suggestions[i])
    end
    
    return queue
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

function Engine:SetQueue(queue)
    -- Compare queue arrays for changes
    local changed = false
    if #queue ~= #currentQueue then
        changed = true
    else
        for i, suggestion in ipairs(queue) do
            if not currentQueue[i] or suggestion.id ~= currentQueue[i].id then
                changed = true
                break
            end
        end
    end
    
    if changed then
        currentQueue = queue
        
        -- Notify UI of queue change
        if HealIQ.UI then
            HealIQ.UI:UpdateQueue(queue)
        end
        
        -- Debug output
        if #queue > 0 then
            local names = {}
            for i, suggestion in ipairs(queue) do
                table.insert(names, suggestion.name)
            end
            HealIQ:Print("Queue: " .. table.concat(names, " → "))
        else
            HealIQ:Print("Empty queue")
        end
    end
end

function Engine:GetCurrentSuggestion()
    return currentSuggestion
end

function Engine:GetCurrentQueue()
    return currentQueue
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
    elseif ruleName == "ironbark" then
        return tracker:ShouldUseIronbark()
    elseif ruleName == "efflorescence" then
        return tracker:ShouldUseEfflorescence()
    elseif ruleName == "tranquility" then
        return tracker:ShouldUseTranquility()
    elseif ruleName == "flourish" then
        return tracker:ShouldUseFlourish()
    elseif ruleName == "incarnationTree" then
        return tracker:ShouldUseIncarnation()
    elseif ruleName == "naturesSwiftness" then
        return tracker:ShouldUseNaturesSwiftness()
    elseif ruleName == "barkskin" then
        return tracker:ShouldUseBarkskin()
    elseif ruleName == "trinket" then
        local hasTrinket, slot = tracker:HasActiveTrinket()
        return hasTrinket
    end
    
    return false
end

HealIQ.Engine = Engine
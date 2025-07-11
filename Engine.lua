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
    HealIQ:SafeCall(function()
        self:StartUpdateLoop()
        HealIQ:Print("Engine initialized")
    end)
end

function Engine:StartUpdateLoop()
    local frame = CreateFrame("Frame", "HealIQUpdateFrame")
    frame:SetScript("OnUpdate", function(self, elapsed)
        Engine:OnUpdate(elapsed)
    end)
    self.updateFrame = frame
end

function Engine:StopUpdateLoop()
    if self.updateFrame then
        self.updateFrame:SetScript("OnUpdate", nil)
        self.updateFrame = nil
    end
end

function Engine:OnUpdate(elapsed)
    HealIQ:SafeCall(function()
        local currentTime = GetTime()
        
        -- Throttle updates
        if currentTime - lastUpdate < updateInterval then
            return
        end
        
        lastUpdate = currentTime
        
        -- Check for log buffer flush (do this periodically, regardless of other conditions)
        if HealIQ.db and HealIQ.db.logging and HealIQ.db.logging.enabled and HealIQ:ShouldFlushLogBuffer() then
            HealIQ:FlushLogBuffer()
        end
        
        -- Only suggest spells if addon is enabled and database is initialized
        if not HealIQ.db or not HealIQ.db.enabled then
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
    end)
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
    
    if not HealIQ.db or not HealIQ.db.rules then
        return nil
    end
    
    local suggestions = {}
    HealIQ:LogVerbose("Starting rule evaluation")
    
    -- Rule 1: Tranquility if off cooldown and 4+ allies recently damaged (highest priority)
    if HealIQ.db.rules.tranquility and tracker:ShouldUseTranquility() then
        table.insert(suggestions, SPELLS.TRANQUILITY)
        HealIQ:LogVerbose("Rule triggered: Tranquility")
        if HealIQ.sessionStats then
            HealIQ.sessionStats.rulesProcessed = HealIQ.sessionStats.rulesProcessed + 1
        end
    end
    
    -- Rule 2: Incarnation: Tree of Life for high damage phases
    if HealIQ.db.rules.incarnationTree and tracker:ShouldUseIncarnation() then
        table.insert(suggestions, SPELLS.INCARNATION_TREE)
        HealIQ:LogVerbose("Rule triggered: Incarnation Tree")
        if HealIQ.sessionStats then
            HealIQ.sessionStats.rulesProcessed = HealIQ.sessionStats.rulesProcessed + 1
        end
    end
    
    -- Rule 3: Ironbark for damage reduction on target
    if HealIQ.db.rules.ironbark and tracker:ShouldUseIronbark() then
        table.insert(suggestions, SPELLS.IRONBARK)
        HealIQ:LogVerbose("Rule triggered: Ironbark")
        if HealIQ.sessionStats then
            HealIQ.sessionStats.rulesProcessed = HealIQ.sessionStats.rulesProcessed + 1
        end
    end
    
    -- Rule 4: Wild Growth if off cooldown and 3+ allies recently damaged
    if HealIQ.db.rules.wildGrowth and tracker:IsSpellReady("wildGrowth") then
        local recentDamageCount = tracker:GetRecentDamageCount()
        if recentDamageCount >= 3 then
            table.insert(suggestions, SPELLS.WILD_GROWTH)
            HealIQ:LogVerbose("Rule triggered: Wild Growth (recent damage: " .. recentDamageCount .. ")")
            if HealIQ.sessionStats then
                HealIQ.sessionStats.rulesProcessed = HealIQ.sessionStats.rulesProcessed + 1
            end
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
    
    -- Priority rules for targets without basic heals - moved higher for better coverage
    if UnitExists("target") and UnitIsFriend("player", "target") then
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        local hasRejuv = rejuvInfo and rejuvInfo.active
        local hasLifebloom = lifeboomInfo and lifeboomInfo.active
        
        -- Rule 10: No Rejuvenation on current target → High priority Rejuvenation
        if HealIQ.db.rules.rejuvenation and not hasRejuv then
            table.insert(suggestions, SPELLS.REJUVENATION)
        end
        
        -- Rule 11: No Lifebloom on tank target → High priority Lifebloom
        if HealIQ.db.rules.lifebloom and not hasLifebloom then
            -- Check if target is a tank or important target
            local isTank = UnitGroupRolesAssigned("target") == "TANK"
            local isFocus = UnitIsUnit("target", "focus")
            if isTank or isFocus then
                table.insert(suggestions, SPELLS.LIFEBLOOM)
            end
        end
        
        -- Rule 12: Lifebloom on target < 4s → Suggest refresh
        if HealIQ.db.rules.lifebloom and hasLifebloom and lifeboomInfo.remaining < 4 then
            table.insert(suggestions, SPELLS.LIFEBLOOM)
        end
        
        -- Rule 13: Swiftmend is usable and HoTs are active → Suggest Swiftmend
        if HealIQ.db.rules.swiftmend and tracker:CanSwiftmend() then
            table.insert(suggestions, SPELLS.SWIFTMEND)
        end
    end
    
    -- Rule 14: Trinket usage
    if HealIQ.db.rules.trinket then
        local hasTrinket, slot = tracker:HasActiveTrinket()
        if hasTrinket then
            table.insert(suggestions, SPELLS.TRINKET)
        end
    end
    
    HealIQ:LogVerbose("Rule evaluation completed, " .. #suggestions .. " suggestions found")
    
    -- Return the top suggestion for backward compatibility
    return suggestions[1] or nil
end

-- New function to get multiple suggestions for queue display
function Engine:EvaluateRulesQueue()
    local tracker = HealIQ.Tracker
    if not tracker then
        return {}
    end
    
    if not HealIQ.db or not HealIQ.db.rules then
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
    
    -- Priority rules for targets without basic heals - moved higher for better coverage
    if UnitExists("target") and UnitIsFriend("player", "target") then
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
        local hasRejuv = rejuvInfo and rejuvInfo.active
        local hasLifebloom = lifeboomInfo and lifeboomInfo.active
        
        -- Rule 10: No Rejuvenation on current target → High priority Rejuvenation
        if HealIQ.db.rules.rejuvenation and not hasRejuv then
            table.insert(suggestions, SPELLS.REJUVENATION)
        end
        
        -- Rule 11: No Lifebloom on tank target → High priority Lifebloom
        if HealIQ.db.rules.lifebloom and not hasLifebloom then
            -- Check if target is a tank or important target
            local isTank = UnitGroupRolesAssigned("target") == "TANK"
            local isFocus = UnitIsUnit("target", "focus")
            if isTank or isFocus then
                table.insert(suggestions, SPELLS.LIFEBLOOM)
            end
        end
        
        -- Rule 12: Lifebloom on target < 4s → Suggest refresh
        if HealIQ.db.rules.lifebloom and hasLifebloom and lifeboomInfo.remaining < 4 then
            table.insert(suggestions, SPELLS.LIFEBLOOM)
        end
        
        -- Rule 13: Swiftmend is usable and HoTs are active → Suggest Swiftmend
        if HealIQ.db.rules.swiftmend and tracker:CanSwiftmend() then
            table.insert(suggestions, SPELLS.SWIFTMEND)
        end
    end
    
    -- Rule 14: Trinket usage
    if HealIQ.db.rules.trinket then
        local hasTrinket, slot = tracker:HasActiveTrinket()
        if hasTrinket then
            table.insert(suggestions, SPELLS.TRINKET)
        end
    end
    
    -- Return up to the configured queue size suggestions
    if HealIQ.db and HealIQ.db.ui then
        local queueSize = HealIQ.db.ui.queueSize or 3
        local queue = {}
        for i = 1, math.min(queueSize, #suggestions) do
            table.insert(queue, suggestions[i])
        end
        return queue
    else
        -- Fallback if UI config not available
        local queue = {}
        for i = 1, math.min(3, #suggestions) do
            table.insert(queue, suggestions[i])
        end
        return queue
    end
end

function Engine:SetSuggestion(suggestion)
    if suggestion ~= currentSuggestion then
        currentSuggestion = suggestion
        
        -- Notify UI of change
        if HealIQ.UI then
            HealIQ.UI:UpdateSuggestion(suggestion)
        end
        
        -- Debug output (only when debug mode is on)
        if HealIQ.debug then
            if suggestion then
                HealIQ:Print("Suggesting: " .. suggestion.name)
                HealIQ:LogVerbose("Generated suggestion: " .. suggestion.name .. " (priority: " .. suggestion.priority .. ")")
            else
                HealIQ:Print("No suggestion")
                HealIQ:LogVerbose("No suggestion generated")
            end
        end
        
        -- Track suggestion stats
        if suggestion and HealIQ.sessionStats then
            HealIQ.sessionStats.suggestions = HealIQ.sessionStats.suggestions + 1
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
        
        -- Debug output (only when debug mode is on)
        if HealIQ.debug then
            if #queue > 0 then
                local names = {}
                for i, suggestion in ipairs(queue) do
                    table.insert(names, suggestion.name)
                end
                HealIQ:Print("Queue updated: " .. table.concat(names, " → "))
                HealIQ:LogVerbose("Queue updated (" .. #queue .. " items): " .. table.concat(names, " → "))
            else
                HealIQ:Print("Queue cleared")
                HealIQ:LogVerbose("Queue cleared")
            end
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
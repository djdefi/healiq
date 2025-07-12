-- HealIQ Engine.lua
-- Priority logic engine that determines the suggested spell

local addonName, HealIQ = ...

HealIQ.Engine = {}
local Engine = HealIQ.Engine

-- Targeting types and their associated icons
-- Icon path constants
local ICON_SELF = "Interface\\Icons\\Ability_Warrior_BattleShout"
local ICON_TANK = "Interface\\Icons\\Ability_Warrior_DefensiveStance"
local ICON_CURRENT_TARGET = "Interface\\Icons\\Ability_Hunter_MarkedForDeath"
local ICON_FOCUS = "Interface\\Icons\\Spell_Shadow_Teleport"
local ICON_PARTY_MEMBER = "Interface\\Icons\\Achievement_Guildperk_EverybodysFriend"
local ICON_LOWEST_HEALTH = "Interface\\Icons\\Spell_ChargeNegative"
local ICON_TARGET_OF_TARGET = "Interface\\Icons\\Ability_Hunter_SniperShot"
local ICON_GROUND_TARGET = "Interface\\Icons\\Spell_Arcane_TeleportBoralus"

local TARGET_TYPES = {
    SELF = {
        name = "Self",
        icon = ICON_SELF,
        description = "Cast on yourself"
    },
    TANK = {
        name = "Tank",
        icon = ICON_TANK,
        description = "Cast on main tank"
    },
    CURRENT_TARGET = {
        name = "Current Target",
        icon = ICON_CURRENT_TARGET,
        description = "Cast on current target"
    },
    FOCUS = {
        name = "Focus",
        icon = ICON_FOCUS,
        description = "Cast on focus target"
    },
    PARTY_MEMBER = {
        name = "Party Member",
        icon = ICON_PARTY_MEMBER,
        description = "Cast on any party member"
    },
    LOWEST_HEALTH = {
        name = "Lowest Health",
        icon = ICON_LOWEST_HEALTH,
        description = "Target with lowest health"
    },
    TARGET_OF_TARGET = {
        name = "Target's Target",
        icon = ICON_TARGET_OF_TARGET,
        description = "Cast on target's target"
    },
    GROUND_TARGET = {
        name = "Ground Target",
        icon = ICON_GROUND_TARGET,
        description = "Place on ground"
    }
}

-- Spell information for suggestions with targeting recommendations
local SPELLS = {
    TRANQUILITY = {
        id = 740,
        name = "Tranquility",
        icon = "Interface\\Icons\\Spell_Nature_Tranquility",
        priority = 1,
        targets = {TARGET_TYPES.SELF}, -- Channel on self, affects all nearby allies
        targetingDescription = "Channel while positioned near injured allies"
    },
    INCARNATION_TREE = {
        id = 33891,
        name = "Incarnation",
        icon = "Interface\\Icons\\Spell_Druid_Incarnation",
        priority = 2,
        targets = {TARGET_TYPES.SELF}, -- Self-buff
        targetingDescription = "Activate when group healing is needed"
    },
    IRONBARK = {
        id = 102342,
        name = "Ironbark",
        icon = "Interface\\Icons\\Spell_Druid_IronBark",
        priority = 3,
        targets = {TARGET_TYPES.TANK, TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.FOCUS}, -- Damage reduction
        targetingDescription = "Prioritize tanks or targets taking heavy damage"
    },
    WILD_GROWTH = {
        id = 48438,
        name = "Wild Growth",
        icon = "Interface\\Icons\\Ability_Druid_WildGrowth",
        priority = 4,
        targets = {TARGET_TYPES.PARTY_MEMBER, TARGET_TYPES.CURRENT_TARGET}, -- Smart heal around target
        targetingDescription = "Target near damaged party members"
    },
    EFFLORESCENCE = {
        id = 145205,
        name = "Efflorescence",
        icon = "Interface\\Icons\\Ability_Druid_Efflorescence",
        priority = 5,
        targets = {TARGET_TYPES.GROUND_TARGET}, -- Ground-targeted spell
        targetingDescription = "Place where group will be standing"
    },
    FLOURISH = {
        id = 197721,
        name = "Flourish",
        icon = "Interface\\Icons\\Spell_Druid_WildGrowth",
        priority = 6,
        targets = {TARGET_TYPES.SELF}, -- Affects all your HoTs
        targetingDescription = "Use when multiple HoTs are active"
    },
    NATURES_SWIFTNESS = {
        id = 132158,
        name = "Nature's Swiftness",
        icon = "Interface\\Icons\\Spell_Nature_RavenForm",
        priority = 7,
        targets = {TARGET_TYPES.SELF}, -- Self-buff for next spell
        targetingDescription = "Use before emergency heal cast"
    },
    REGROWTH = {
        id = 8936,
        name = "Regrowth",
        icon = "Interface\\Icons\\Spell_Nature_ResistNature",
        priority = 8,
        targets = {TARGET_TYPES.LOWEST_HEALTH, TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.TANK}, -- Direct heal
        targetingDescription = "Target needs immediate healing"
    },
    BARKSKIN = {
        id = 22812,
        name = "Barkskin",
        icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
        priority = 9,
        targets = {TARGET_TYPES.SELF}, -- Self-defensive
        targetingDescription = "Use when taking damage"
    },
    LIFEBLOOM = {
        id = 33763,
        name = "Lifebloom",
        icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom",
        priority = 10,
        targets = {TARGET_TYPES.TANK, TARGET_TYPES.FOCUS, TARGET_TYPES.CURRENT_TARGET}, -- Tank maintenance
        targetingDescription = "Keep active on main tank or focus target"
    },
    SWIFTMEND = {
        id = 18562,
        name = "Swiftmend",
        icon = "Interface\\Icons\\INV_Relics_IdolofRejuvenation",
        priority = 11,
        targets = {TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.LOWEST_HEALTH}, -- Target with HoTs
        targetingDescription = "Target must have Rejuvenation or Regrowth"
    },
    REJUVENATION = {
        id = 774,
        name = "Rejuvenation",
        icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        priority = 12,
        targets = {TARGET_TYPES.PARTY_MEMBER, TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.TANK}, -- Basic HoT
        targetingDescription = "Apply to targets without HoT coverage"
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
    HealIQ:DebugLog("Starting rule evaluation")
    
    -- Rule 1: Tranquility if off cooldown and 4+ allies recently damaged (highest priority)
    if HealIQ.db.rules.tranquility and tracker:ShouldUseTranquility() then
        table.insert(suggestions, SPELLS.TRANQUILITY)
        HealIQ:DebugLog("Rule triggered: Tranquility")
        if HealIQ.sessionStats then
            HealIQ.sessionStats.rulesProcessed = HealIQ.sessionStats.rulesProcessed + 1
        end
    end
    
    -- Rule 2: Incarnation: Tree of Life for high damage phases
    if HealIQ.db.rules.incarnationTree and tracker:ShouldUseIncarnation() then
        table.insert(suggestions, SPELLS.INCARNATION_TREE)
        HealIQ:DebugLog("Rule triggered: Incarnation Tree")
        if HealIQ.sessionStats then
            HealIQ.sessionStats.rulesProcessed = HealIQ.sessionStats.rulesProcessed + 1
        end
    end
    
    -- Rule 3: Ironbark for damage reduction on target
    if HealIQ.db.rules.ironbark and tracker:ShouldUseIronbark() then
        table.insert(suggestions, SPELLS.IRONBARK)
        HealIQ:DebugLog("Rule triggered: Ironbark")
        if HealIQ.sessionStats then
            HealIQ.sessionStats.rulesProcessed = HealIQ.sessionStats.rulesProcessed + 1
        end
    end
    
    -- Rule 4: Wild Growth if off cooldown and 3+ allies recently damaged
    if HealIQ.db.rules.wildGrowth and tracker:IsSpellReady("wildGrowth") then
        local recentDamageCount = tracker:GetRecentDamageCount()
        if recentDamageCount >= 3 then
            table.insert(suggestions, SPELLS.WILD_GROWTH)
            HealIQ:DebugLog("Rule triggered: Wild Growth (recent damage: " .. recentDamageCount .. ")")
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
    
    HealIQ:DebugLog("Rule evaluation completed, " .. #suggestions .. " suggestions found")
    
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

-- Targeting evaluation functions
function Engine:EvaluateTargetingSuggestion(spell)
    if not spell or not spell.targets then
        return nil
    end
    
    local bestTarget = nil
    local targetingContext = {
        hasTarget = UnitExists("target"),
        targetIsFriendly = UnitExists("target") and UnitIsFriend("player", "target"),
        hasFocus = UnitExists("focus"),
        focusIsFriendly = UnitExists("focus") and UnitIsFriend("player", "focus"),
        inParty = IsInGroup(),
        inRaid = IsInRaid(),
        inCombat = InCombatLockdown()
    }
    
    -- Evaluate each potential target type for this spell
    for _, targetType in ipairs(spell.targets) do
        local targetPriority = self:EvaluateTargetPriority(targetType, spell, targetingContext)
        if targetPriority > 0 and (not bestTarget or targetPriority > bestTarget.priority) then
            bestTarget = {
                type = targetType,
                priority = targetPriority,
                available = true
            }
        end
    end
    
    return bestTarget
end

function Engine:EvaluateTargetPriority(targetType, spell, context)
    -- Return priority score (higher = better target choice)
    
    if targetType == TARGET_TYPES.SELF then
        return 100 -- Always available
    end
    
    if targetType == TARGET_TYPES.CURRENT_TARGET then
        if context.targetIsFriendly then
            return 90 -- High priority if we have a friendly target
        else
            return 0 -- Not available
        end
    end
    
    if targetType == TARGET_TYPES.FOCUS then
        if context.focusIsFriendly then
            return 85 -- Good priority for focus target
        else
            return 0 -- Not available
        end
    end
    
    if targetType == TARGET_TYPES.TANK then
        -- Check if current target or focus is a tank
        local targetIsTank = context.targetIsFriendly and UnitGroupRolesAssigned("target") == "TANK"
        local focusIsTank = context.focusIsFriendly and UnitGroupRolesAssigned("focus") == "TANK"
        
        if targetIsTank then
            return 95 -- Very high priority for tank targeting spells
        elseif focusIsTank then
            return 90 -- Also high priority if focus is tank
        elseif context.inParty or context.inRaid then
            return 70 -- Medium priority, assume tank exists in group
        else
            return 0 -- No tank available
        end
    end
    
    if targetType == TARGET_TYPES.PARTY_MEMBER then
        if context.inParty or context.inRaid then
            return 75 -- Good priority if in group
        else
            return 0 -- Not in party
        end
    end
    
    if targetType == TARGET_TYPES.LOWEST_HEALTH then
        -- We can't read health during combat, so this is contextual
        if context.targetIsFriendly then
            return 80 -- Assume current target needs healing
        elseif context.inParty or context.inRaid then
            return 60 -- Medium priority, would need to target manually
        else
            return 0 -- No one to heal
        end
    end
    
    if targetType == TARGET_TYPES.TARGET_OF_TARGET then
        if context.hasTarget and UnitExists("targettarget") and UnitIsFriend("player", "targettarget") then
            return 70 -- Available and useful for some situations
        else
            return 0 -- Not available
        end
    end
    
    if targetType == TARGET_TYPES.GROUND_TARGET then
        return 80 -- Always available for ground-targeted spells
    end
    
    return 0 -- Unknown target type
end

function Engine:GetTargetingSuggestionsText(suggestion)
    if not suggestion then
        return nil
    end
    
    local targetSuggestion = self:EvaluateTargetingSuggestion(suggestion)
    if targetSuggestion and targetSuggestion.type then
        return targetSuggestion.type.name
    end
    
    return nil
end

function Engine:GetTargetingSuggestionsIcon(suggestion)
    if not suggestion then
        return nil
    end
    
    local targetSuggestion = self:EvaluateTargetingSuggestion(suggestion)
    if targetSuggestion and targetSuggestion.type then
        return targetSuggestion.type.icon
    end
    
    return nil
end

function Engine:GetTargetingSuggestionsDescription(suggestion)
    if not suggestion then
        return nil
    end
    
    local targetSuggestion = self:EvaluateTargetingSuggestion(suggestion)
    if targetSuggestion and targetSuggestion.type then
        return targetSuggestion.type.description
    end
    
    return suggestion.targetingDescription or nil
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
                local targetText = self:GetTargetingSuggestionsText(suggestion)
                local suggestionText = suggestion.name
                if targetText then
                    suggestionText = suggestionText .. " → " .. targetText
                end
                HealIQ:Print("Suggesting: " .. suggestionText)
                HealIQ:DebugLog("Generated suggestion: " .. suggestion.name .. " (priority: " .. suggestion.priority .. ", target: " .. (targetText or "none") .. ")")
            else
                HealIQ:Print("No suggestion")
                HealIQ:DebugLog("No suggestion generated")
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
                HealIQ:DebugLog("Queue updated (" .. #queue .. " items): " .. table.concat(names, " → "))
            else
                HealIQ:Print("Queue cleared")
                HealIQ:DebugLog("Queue cleared")
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
    end
    
    return false
end

HealIQ.Engine = Engine
HealIQ.Engine.TARGET_TYPES = TARGET_TYPES
HealIQ.Engine.SPELLS = SPELLS
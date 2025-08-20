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
    },
    TANK_RELATIONSHIP = {
        name = "Tank Relationship",
        icon = ICON_TANK,
        description = "Establish beneficial relationship with tank"
    }
}

-- Spell information for suggestions with targeting recommendations
-- Updated priorities based on Wowhead Restoration Druid guide
local SPELLS = {
    -- Emergency/Major Cooldowns (Highest Priority)
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
    NATURES_SWIFTNESS = {
        id = 132158,
        name = "Nature's Swiftness",
        icon = "Interface\\Icons\\Spell_Nature_RavenForm",
        priority = 3,
        targets = {TARGET_TYPES.SELF}, -- Self-buff for next spell
        targetingDescription = "Use before emergency heal cast"
    },

    -- Core Maintenance (High Priority - keep these active)
    EFFLORESCENCE = {
        id = 145205,
        name = "Efflorescence",
        icon = "Interface\\Icons\\Ability_Druid_Efflorescence",
        priority = 4, -- Higher priority per guide: "keep active as frequently as possible"
        targets = {TARGET_TYPES.GROUND_TARGET}, -- Ground-targeted spell
        targetingDescription = "Place where group will be standing"
    },
    LIFEBLOOM = {
        id = 33763,
        name = "Lifebloom",
        icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom",
        priority = 5, -- Higher priority per guide: "keep active on tank"
        targets = {TARGET_TYPES.TANK, TARGET_TYPES.FOCUS, TARGET_TYPES.CURRENT_TARGET}, -- Tank maintenance
        targetingDescription = "Keep active on main tank or focus target"
    },

    -- Proc-based spells (High Priority when available)
    REGROWTH = {
        id = 8936,
        name = "Regrowth",
        icon = "Interface\\Icons\\Spell_Nature_ResistNature",
        priority = 6, -- Higher priority when used with Clearcasting
        targets = {TARGET_TYPES.LOWEST_HEALTH, TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.TANK}, -- Direct heal
        targetingDescription = "Target needs immediate healing"
    },

    -- AoE Healing Combo
    SWIFTMEND = {
        id = 18562,
        name = "Swiftmend",
        icon = "Interface\\Icons\\INV_Relics_IdolofRejuvenation",
        priority = 7, -- Higher priority as setup for Wild Growth
        targets = {TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.LOWEST_HEALTH}, -- Target with HoTs
        targetingDescription = "Target must have Rejuvenation or Regrowth"
    },
    WILD_GROWTH = {
        id = 48438,
        name = "Wild Growth",
        icon = "Interface\\Icons\\Ability_Druid_WildGrowth",
        priority = 8, -- Often paired with Swiftmend
        targets = {TARGET_TYPES.PARTY_MEMBER, TARGET_TYPES.CURRENT_TARGET}, -- Smart heal around target
        targetingDescription = "Target near damaged party members"
    },

    -- Cooldown Management
    GROVE_GUARDIANS = {
        id = 102693,
        name = "Grove Guardians",
        icon = "Interface\\Icons\\Spell_Druid_Treant",
        priority = 9,
        targets = {TARGET_TYPES.SELF}, -- Self-activated with charges
        targetingDescription = "Pool charges for big cooldowns"
    },
    FLOURISH = {
        id = 197721,
        name = "Flourish",
        icon = "Interface\\Icons\\Spell_Druid_WildGrowth",
        priority = 10,
        targets = {TARGET_TYPES.SELF}, -- Affects all your HoTs
        targetingDescription = "Use when multiple HoTs are active"
    },

    -- Defensive/Utility
    IRONBARK = {
        id = 102342,
        name = "Ironbark",
        icon = "Interface\\Icons\\Spell_Druid_IronBark",
        priority = 11,
        targets = {TARGET_TYPES.TANK, TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.FOCUS}, -- Damage reduction
        targetingDescription = "Prioritize tanks or targets taking heavy damage"
    },
    BARKSKIN = {
        id = 22812,
        name = "Barkskin",
        icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
        priority = 12,
        targets = {TARGET_TYPES.SELF}, -- Self-defensive
        targetingDescription = "Use when taking damage"
    },

    -- Ramping HoTs (Lower priority during maintenance, higher during damage phases)
    REJUVENATION = {
        id = 774,
        name = "Rejuvenation",
        icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        priority = 13,
        targets = {TARGET_TYPES.PARTY_MEMBER, TARGET_TYPES.CURRENT_TARGET, TARGET_TYPES.TANK}, -- Basic HoT
        targetingDescription = "Apply to targets without HoT coverage"
    },

    -- Filler/Mana Management
    WRATH = {
        id = 5176,
        name = "Wrath",
        icon = "Interface\\Icons\\Spell_Nature_AbolishMagic",
        priority = 14,
        targets = {TARGET_TYPES.CURRENT_TARGET}, -- Enemy target
        targetingDescription = "Use on enemies during downtime for mana restoration"
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

    -- Suggest in combat, when having a friendly target, or when in a group
    -- This allows single-target spells to be suggested even without a target selected
    -- for click-casting workflows, with targeting recommendations provided
    local inCombat = InCombatLockdown()
    local hasTarget = UnitExists("target")
    local targetIsFriendly = hasTarget and UnitIsFriend("player", "target")
    local inGroup = IsInGroup() or IsInRaid()

    return inCombat or (hasTarget and targetIsFriendly) or inGroup
end

-- Talent validation and detection system
function Engine:GetOptimalTalents()
    -- Define optimal Restoration Druid talents for the healing strategy
    -- These are key talents that support the implemented healing strategy
    local optimalTalents = {
        -- Class Talents (essential for the strategy)
        {
            name = "Wild Growth",
            spellId = 48438,
            description = "Essential AoE healing spell used in priority system",
            category = "Core Healing",
            required = true
        },
        {
            name = "Efflorescence",
            spellId = 145205,
            description = "Ground AoE healing - high priority in strategy",
            category = "Core Healing",
            required = true
        },
        {
            name = "Lifebloom",
            spellId = 33763,
            description = "Tank maintenance HoT with refresh timing logic",
            category = "Core Healing",
            required = true
        },
        {
            name = "Swiftmend",
            spellId = 18562,
            description = "Instant heal used for Wild Growth combo setup",
            category = "Core Healing",
            required = true
        },
        {
            name = "Nature's Swiftness",
            spellId = 132158,
            description = "Emergency instant cast enabler",
            category = "Emergency",
            required = true
        },

        -- Spec Talents (highly recommended for optimal performance)
        {
            name = "Flourish",
            spellId = 197721,
            description = "Extends multiple HoTs - part of priority system",
            category = "HoT Management",
            required = false
        },
        {
            name = "Grove Guardians",
            spellId = 102693,
            description = "Charge pooling for cooldown coordination",
            category = "Cooldown Management",
            required = false
        },
        {
            name = "Incarnation: Tree of Life",
            spellId = 33891,
            description = "Major healing cooldown in priority system",
            category = "Major Cooldowns",
            required = false
        },
        {
            name = "Tranquility",
            spellId = 740,
            description = "Raid healing cooldown - highest priority spell",
            category = "Major Cooldowns",
            required = false
        }
    }

    return optimalTalents
end

function Engine:CheckTalentAvailability(spellId)
    -- Check if a talent/spell is known by the player
    if not spellId then
        return false
    end

    -- Use IsSpellKnown for passive talents and active abilities
    local isKnown = IsSpellKnown(spellId)
    if isKnown then
        return true
    end

    -- For some talents, check if they're learned via C_Spell.GetSpellName
    local spellName = C_Spell.GetSpellName(spellId)
    if spellName then
        return IsSpellKnown(spellId) or IsPlayerSpell(spellId)
    end

    return false
end

function Engine:GetTalentStatus()
    local talentStatus = {
        missing = {},
        present = {},
        categories = {}
    }

    local optimalTalents = self:GetOptimalTalents()

    for _, talent in ipairs(optimalTalents) do
        local isAvailable = self:CheckTalentAvailability(talent.spellId)

        if isAvailable then
            table.insert(talentStatus.present, talent)
        else
            table.insert(talentStatus.missing, talent)
        end

        -- Organize by category
        if not talentStatus.categories[talent.category] then
            talentStatus.categories[talent.category] = {missing = {}, present = {}}
        end

        if isAvailable then
            table.insert(talentStatus.categories[talent.category].present, talent)
        else
            table.insert(talentStatus.categories[talent.category].missing, talent)
        end
    end

    return talentStatus
end

function Engine:GetTalentRecommendations()
    local talentStatus = self:GetTalentStatus()
    local recommendations = {
        critical = {},
        suggested = {},
        summary = ""
    }

    -- Separate critical missing talents from suggested ones
    for _, talent in ipairs(talentStatus.missing) do
        if talent.required then
            table.insert(recommendations.critical, talent)
        else
            table.insert(recommendations.suggested, talent)
        end
    end

    -- Generate summary text
    local criticalCount = #recommendations.critical
    local suggestedCount = #recommendations.suggested

    if criticalCount > 0 then
        recommendations.summary = string.format("Missing %d critical talents for optimal healing", criticalCount)
    elseif suggestedCount > 0 then
        recommendations.summary = string.format("Missing %d recommended talents for enhanced healing", suggestedCount)
    else
        recommendations.summary = "All optimal talents are available!"
    end

    return recommendations
end

-- Helper method for emergency/major cooldown evaluation
function Engine:EvaluateEmergencyCooldowns(suggestions, tracker, strategy)
    -- Rule 1: Emergency/Major Cooldowns (Highest Priority)

    -- Tranquility if off cooldown and enough allies recently damaged
    if HealIQ.db.rules.tranquility and tracker:ShouldUseTranquility() then
        table.insert(suggestions, SPELLS.TRANQUILITY)
        HealIQ:DebugLog("Rule triggered: Tranquility")
        HealIQ:LogRuleTrigger("Tranquility")
    end

    -- Incarnation: Tree of Life for high damage phases
    if HealIQ.db.rules.incarnationTree and tracker:ShouldUseIncarnation() then
        table.insert(suggestions, SPELLS.INCARNATION_TREE)
        HealIQ:DebugLog("Rule triggered: Incarnation Tree")
        HealIQ:LogRuleTrigger("Incarnation Tree")
    end

    -- Nature's Swiftness for emergency situations (low health targets)
    if HealIQ.db.rules.naturesSwiftness and tracker:ShouldUseNaturesSwiftness() then
        table.insert(suggestions, SPELLS.NATURES_SWIFTNESS)
        HealIQ:DebugLog("Rule triggered: Nature's Swiftness")
        HealIQ:LogRuleTrigger("Nature's Swiftness")
    end
end

-- Helper method for core maintenance rules
function Engine:EvaluateCoreMaintenanceRules(suggestions, tracker, strategy)
    -- Rule 2: Core Maintenance (High Priority - keep these active)

    -- Efflorescence - "keep active as frequently as possible"
    if HealIQ.db.rules.efflorescence and strategy.prioritizeEfflorescence and tracker:ShouldUseEfflorescence() then
        table.insert(suggestions, SPELLS.EFFLORESCENCE)
        HealIQ:DebugLog("Rule triggered: Efflorescence (prioritized)")
        HealIQ:LogRuleTrigger("Efflorescence")
    end

    -- Lifebloom maintenance on tank - higher priority
    if HealIQ.db.rules.lifebloom and strategy.maintainLifebloomOnTank then
        local shouldSuggestLifebloom = false
        local suggestReason = ""

        if UnitExists("target") and UnitIsFriend("player", "target") then
            local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
            local hasLifebloom = lifeboomInfo and lifeboomInfo.active
            local refreshWindow = strategy.lifebloomRefreshWindow or 4.5

            -- Check if target is a tank or important target
            local isTank = UnitGroupRolesAssigned("target") == "TANK"
            local isFocus = UnitIsUnit("target", "focus")

            if isTank or isFocus then
                -- Suggest if no Lifebloom or needs refresh
                if not hasLifebloom then
                    shouldSuggestLifebloom = true
                    suggestReason = "missing on tank"
                elseif hasLifebloom and lifeboomInfo.remaining < refreshWindow then
                    shouldSuggestLifebloom = true
                    suggestReason = "refresh for bloom"
                end
            end
        elseif InCombatLockdown() or (IsInGroup() or IsInRaid()) then
            -- Suggest Lifebloom even without target as a reminder for tank maintenance
            shouldSuggestLifebloom = true
            suggestReason = "tank maintenance needed"
        end

        if shouldSuggestLifebloom then
            table.insert(suggestions, SPELLS.LIFEBLOOM)
            HealIQ:DebugLog("Rule triggered: Lifebloom (" .. suggestReason .. ")")
            HealIQ:LogRuleTrigger("Lifebloom")
        end
    end
end

-- Helper method for symbiotic tank relationship rules
function Engine:EvaluateSymbioticTankRules(suggestions, tracker, strategy)
    -- Rule 2b: Symbiotic Tank Relationships - Suggest establishing beneficial relationships
    if strategy.suggestTankRelationships ~= false then -- Default enabled, can be disabled
        local inGroup = IsInGroup() or IsInRaid()
        local inCombat = InCombatLockdown()
        
        if (inGroup or inCombat) and not UnitExists("target") then
            -- When no target is selected in group/combat, suggest tank relationship
            table.insert(suggestions, {
                spellId = SPELLS.LIFEBLOOM.spellId,
                name = SPELLS.LIFEBLOOM.name,
                icon = SPELLS.LIFEBLOOM.icon,
                priority = 8,
                targetType = "TANK_RELATIONSHIP",
                reason = "No target selected - consider targeting tank for beneficial relationship"
            })
            HealIQ:DebugLog("Rule triggered: Symbiotic Tank Relationship (no target in group)")
            HealIQ:LogRuleTrigger("SymbioticTankRelationship")
        elseif inGroup and UnitExists("target") and not UnitIsFriend("player", "target") then
            -- When targeting enemy in group, suggest switching to tank for support
            table.insert(suggestions, {
                spellId = SPELLS.LIFEBLOOM.spellId,
                name = SPELLS.LIFEBLOOM.name,
                icon = SPELLS.LIFEBLOOM.icon,
                priority = 6,
                targetType = "TANK_RELATIONSHIP",
                reason = "Consider targeting friendly tank for beneficial relationship"
            })
            HealIQ:DebugLog("Rule triggered: Symbiotic Tank Relationship (enemy target)")
            HealIQ:LogRuleTrigger("SymbioticTankRelationship")
        end
    end
end

-- Helper method for proc-based spell evaluation
function Engine:EvaluateProcBasedRules(suggestions, tracker, strategy)
    -- Rule 3: Proc-based spells (High Priority when available)

    -- Clearcasting active → Prioritize Regrowth
    if HealIQ.db.rules.clearcasting and strategy.preferClearcastingRegrowth and tracker:HasClearcasting() then
        table.insert(suggestions, SPELLS.REGROWTH)
        HealIQ:DebugLog("Rule triggered: Regrowth (Clearcasting proc)")
        HealIQ:LogRuleTrigger("Regrowth")
    end
end

-- Helper method for AoE healing combo evaluation
function Engine:EvaluateAoEHealingRules(suggestions, tracker, strategy)
    -- Rule 4: AoE Healing Combo (Swiftmend → Wild Growth)

    -- Swiftmend for immediate healing (enhanced logic)
    if HealIQ.db.rules.swiftmend and tracker:CanSwiftmend() then
        local recentDamageCount = tracker:GetRecentDamageCount()
        local wildGrowthReady = tracker:IsSpellReady("wildGrowth")
        local minTargets = strategy.wildGrowthMinTargets or 1

        -- Suggest Swiftmend if:
        -- 1. Part of Wild Growth combo (when enabled), OR
        -- 2. Target needs immediate healing, OR
        -- 3. Recent damage to group, OR
        -- 4. In combat/group without target as a reminder
        local comboCondition = strategy.swiftmendWildGrowthCombo and wildGrowthReady and recentDamageCount >= minTargets
        local healingCondition = UnitExists("target") and UnitIsFriend("player", "target")
        local emergencyCondition = recentDamageCount >= 1
        local reminderCondition = not UnitExists("target") and (InCombatLockdown() or (IsInGroup() or IsInRaid()))

        if comboCondition or healingCondition or emergencyCondition or reminderCondition then
            table.insert(suggestions, SPELLS.SWIFTMEND)
            HealIQ:DebugLog("Rule triggered: Swiftmend (immediate healing)")
            HealIQ:LogRuleTrigger("Swiftmend")
        end
    end

    -- Wild Growth if off cooldown and targets need healing
    if HealIQ.db.rules.wildGrowth and tracker:IsSpellReady("wildGrowth") then
        local recentDamageCount = tracker:GetRecentDamageCount()
        local minTargets = strategy.wildGrowthMinTargets or 1
        if recentDamageCount >= minTargets then
            table.insert(suggestions, SPELLS.WILD_GROWTH)
            HealIQ:DebugLog("Rule triggered: Wild Growth (recent damage: " .. recentDamageCount .. ")")
            HealIQ:LogRuleTrigger("Wild Growth")
        end
    end
end

-- Helper method for cooldown management evaluation
function Engine:EvaluateCooldownManagement(suggestions, tracker, strategy)
    -- Rule 5: Cooldown Management

    -- Grove Guardians - pool charges for big cooldowns
    if HealIQ.db.rules.groveGuardians and tracker:ShouldUseGroveGuardians() then
        table.insert(suggestions, SPELLS.GROVE_GUARDIANS)
        HealIQ:DebugLog("Rule triggered: Grove Guardians")
        HealIQ:LogRuleTrigger("Grove Guardians")
    end

    -- Flourish if available and multiple HoTs are expiring
    if HealIQ.db.rules.flourish and tracker:ShouldUseFlourish() then
        table.insert(suggestions, SPELLS.FLOURISH)
        HealIQ:DebugLog("Rule triggered: Flourish")
        HealIQ:LogRuleTrigger("Flourish")
    end
end

-- Helper method for defensive/utility rules
function Engine:EvaluateDefensiveUtilityRules(suggestions, tracker, strategy)
    -- Rule 6: Defensive/Utility

    -- Ironbark for damage reduction on target
    if HealIQ.db.rules.ironbark and tracker:ShouldUseIronbark() then
        table.insert(suggestions, SPELLS.IRONBARK)
        HealIQ:DebugLog("Rule triggered: Ironbark")
        HealIQ:LogRuleTrigger("Ironbark")
    end

    -- Barkskin for self-defense
    if HealIQ.db.rules.barkskin and tracker:ShouldUseBarkskin() then
        table.insert(suggestions, SPELLS.BARKSKIN)
        HealIQ:DebugLog("Rule triggered: Barkskin")
        HealIQ:LogRuleTrigger("Barkskin")
    end
end

-- Helper method for ramping HoT evaluation
function Engine:EvaluateRampingHotRules(suggestions, tracker, strategy)
    -- Rule 7: Ramping HoTs (Context-dependent priority)

    -- Rejuvenation logic - avoid random casts during downtime
    local shouldSuggestRejuvenation = false
    local rejuvReason = ""

    if UnitExists("target") and UnitIsFriend("player", "target") then
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        local hasRejuv = rejuvInfo and rejuvInfo.active

        if HealIQ.db.rules.rejuvenation and not hasRejuv then
            local inCombat = InCombatLockdown()
            local recentDamageCount = tracker:GetRecentDamageCount()

            -- Only suggest Rejuvenation if in combat or damage is expected
            if inCombat or recentDamageCount > 0 or not strategy.avoidRandomRejuvenationDowntime then
                shouldSuggestRejuvenation = true
                rejuvReason = "target missing"
            end
        end
    elseif HealIQ.db.rules.rejuvenation then
        local inCombat = InCombatLockdown()
        local recentDamageCount = tracker:GetRecentDamageCount()
        local inGroup = IsInGroup() or IsInRaid()

        -- Suggest Rejuvenation without target as reminder when in combat or damage occurring
        if (inCombat and inGroup) or recentDamageCount > 0 then
            shouldSuggestRejuvenation = true
            rejuvReason = "group needs HoT coverage"
        end
    end

    if shouldSuggestRejuvenation then
        table.insert(suggestions, SPELLS.REJUVENATION)
        HealIQ:DebugLog("Rule triggered: Rejuvenation (" .. rejuvReason .. ")")
        HealIQ:LogRuleTrigger("Rejuvenation")
    end
end

-- Helper method for filler/mana management evaluation
function Engine:EvaluateFillerManaRules(suggestions, tracker, strategy)
    -- Rule 8: Filler/Mana Management

    -- Wrath for mana restoration during downtime
    if HealIQ.db.rules.wrath and strategy.useWrathForMana and tracker:ShouldUseWrath() then
        table.insert(suggestions, SPELLS.WRATH)
        HealIQ:DebugLog("Rule triggered: Wrath (mana filler)")
        HealIQ:LogRuleTrigger("Wrath")
    end
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
    local strategy = HealIQ.db.strategy or {}
    HealIQ:DebugLog("Starting rule evaluation with enhanced strategy")

    -- Evaluate all rule categories using helper methods
    self:EvaluateEmergencyCooldowns(suggestions, tracker, strategy)
    self:EvaluateCoreMaintenanceRules(suggestions, tracker, strategy)
    self:EvaluateSymbioticTankRules(suggestions, tracker, strategy)
    self:EvaluateProcBasedRules(suggestions, tracker, strategy)
    self:EvaluateAoEHealingRules(suggestions, tracker, strategy)
    self:EvaluateCooldownManagement(suggestions, tracker, strategy)
    self:EvaluateDefensiveUtilityRules(suggestions, tracker, strategy)
    self:EvaluateRampingHotRules(suggestions, tracker, strategy)
    self:EvaluateFillerManaRules(suggestions, tracker, strategy)

    HealIQ:DebugLog("Rule evaluation completed, " .. #suggestions .. " suggestions found")

    -- Return the top suggestion for backward compatibility, log if suggestion made
    local topSuggestion = suggestions[1] or nil
    if topSuggestion then
        HealIQ:LogSuggestionMade()
    end
    return topSuggestion
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
    local strategy = HealIQ.db.strategy or {}

    -- Use the same rule evaluation logic as the main function for consistency
    -- This ensures the queue shows the same priority order as the main suggestion

    -- Rule 1: Emergency/Major Cooldowns
    if HealIQ.db.rules.tranquility and tracker:ShouldUseTranquility() then
        table.insert(suggestions, SPELLS.TRANQUILITY)
    end

    if HealIQ.db.rules.incarnationTree and tracker:ShouldUseIncarnation() then
        table.insert(suggestions, SPELLS.INCARNATION_TREE)
    end

    if HealIQ.db.rules.naturesSwiftness and tracker:ShouldUseNaturesSwiftness() then
        table.insert(suggestions, SPELLS.NATURES_SWIFTNESS)
    end

    -- Rule 2: Core Maintenance
    if HealIQ.db.rules.efflorescence and strategy.prioritizeEfflorescence and tracker:ShouldUseEfflorescence() then
        table.insert(suggestions, SPELLS.EFFLORESCENCE)
    end

    -- Lifebloom maintenance logic
    if HealIQ.db.rules.lifebloom and strategy.maintainLifebloomOnTank then
        local shouldSuggestLifebloom = false

        if UnitExists("target") and UnitIsFriend("player", "target") then
            local lifeboomInfo = tracker:GetTargetHotInfo("lifebloom")
            local hasLifebloom = lifeboomInfo and lifeboomInfo.active
            local refreshWindow = strategy.lifebloomRefreshWindow or 4.5
            local isTank = UnitGroupRolesAssigned("target") == "TANK"
            local isFocus = UnitIsUnit("target", "focus")

            if (isTank or isFocus) and (not hasLifebloom or (hasLifebloom and lifeboomInfo.remaining < refreshWindow)) then
                shouldSuggestLifebloom = true
            end
        elseif InCombatLockdown() or (IsInGroup() or IsInRaid()) then
            shouldSuggestLifebloom = true
        end

        if shouldSuggestLifebloom then
            table.insert(suggestions, SPELLS.LIFEBLOOM)
        end
    end

    -- Rule 3: Proc-based spells
    if HealIQ.db.rules.clearcasting and strategy.preferClearcastingRegrowth and tracker:HasClearcasting() then
        table.insert(suggestions, SPELLS.REGROWTH)
    end

    -- Rule 4: AoE Healing Combo
    if HealIQ.db.rules.swiftmend and tracker:CanSwiftmend() then
        local recentDamageCount = tracker:GetRecentDamageCount()
        local wildGrowthReady = tracker:IsSpellReady("wildGrowth")
        local minTargets = strategy.wildGrowthMinTargets or 1

        local comboCondition = strategy.swiftmendWildGrowthCombo and wildGrowthReady and recentDamageCount >= minTargets
        local healingCondition = UnitExists("target") and UnitIsFriend("player", "target")
        local emergencyCondition = recentDamageCount >= 1
        local reminderCondition = not UnitExists("target") and (InCombatLockdown() or (IsInGroup() or IsInRaid()))

        if comboCondition or healingCondition or emergencyCondition or reminderCondition then
            table.insert(suggestions, SPELLS.SWIFTMEND)
        end
    end

    if HealIQ.db.rules.wildGrowth and tracker:IsSpellReady("wildGrowth") then
        local recentDamageCount = tracker:GetRecentDamageCount()
        local minTargets = strategy.wildGrowthMinTargets or 1
        if recentDamageCount >= minTargets then
            table.insert(suggestions, SPELLS.WILD_GROWTH)
        end
    end

    -- Rule 5: Cooldown Management
    if HealIQ.db.rules.groveGuardians and tracker:ShouldUseGroveGuardians() then
        table.insert(suggestions, SPELLS.GROVE_GUARDIANS)
    end

    if HealIQ.db.rules.flourish and tracker:ShouldUseFlourish() then
        table.insert(suggestions, SPELLS.FLOURISH)
    end

    -- Rule 6: Defensive/Utility
    if HealIQ.db.rules.ironbark and tracker:ShouldUseIronbark() then
        table.insert(suggestions, SPELLS.IRONBARK)
    end

    if HealIQ.db.rules.barkskin and tracker:ShouldUseBarkskin() then
        table.insert(suggestions, SPELLS.BARKSKIN)
    end

    -- Rule 7: Ramping HoTs
    local shouldSuggestRejuvenation = false

    if UnitExists("target") and UnitIsFriend("player", "target") then
        local rejuvInfo = tracker:GetTargetHotInfo("rejuvenation")
        local hasRejuv = rejuvInfo and rejuvInfo.active

        if HealIQ.db.rules.rejuvenation and not hasRejuv then
            local inCombat = InCombatLockdown()
            local recentDamageCount = tracker:GetRecentDamageCount()

            if inCombat or recentDamageCount > 0 or not strategy.avoidRandomRejuvenationDowntime then
                shouldSuggestRejuvenation = true
            end
        end
    elseif HealIQ.db.rules.rejuvenation then
        local inCombat = InCombatLockdown()
        local recentDamageCount = tracker:GetRecentDamageCount()
        local inGroup = IsInGroup() or IsInRaid()

        if (inCombat and inGroup) or recentDamageCount > 0 then
            shouldSuggestRejuvenation = true
        end
    end

    if shouldSuggestRejuvenation then
        table.insert(suggestions, SPELLS.REJUVENATION)
    end

    -- Rule 8: Filler/Mana Management
    if HealIQ.db.rules.wrath and strategy.useWrathForMana and tracker:ShouldUseWrath() then
        table.insert(suggestions, SPELLS.WRATH)
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

-- Target priority evaluation lookup table for better performance
local TARGET_PRIORITY_EVALUATORS = {
    [TARGET_TYPES.SELF] = function(context)
        return 100 -- Always available
    end,

    [TARGET_TYPES.CURRENT_TARGET] = function(context)
        if context.targetIsFriendly then
            return 90 -- High priority if we have a friendly target
        else
            return 0 -- Not available
        end
    end,

    [TARGET_TYPES.FOCUS] = function(context)
        if context.focusIsFriendly then
            return 85 -- Good priority for focus target
        else
            return 0 -- Not available
        end
    end,

    [TARGET_TYPES.TANK] = function(context)
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
    end,

    [TARGET_TYPES.PARTY_MEMBER] = function(context)
        if context.inParty or context.inRaid then
            return 75 -- Good priority if in group
        else
            return 0 -- Not in party
        end
    end,

    [TARGET_TYPES.LOWEST_HEALTH] = function(context)
        -- We can't read health during combat due to WoW API limitations.
        -- As a fallback, we prioritize the current target if it is friendly,
        -- assuming it needs healing. If in a party or raid, we assign medium
        -- priority, as manual targeting may be required. If neither condition
        -- is met, we return 0, indicating no one is available to heal.
        if context.targetIsFriendly then
            return 80 -- Assume current target needs healing
        elseif context.inParty or context.inRaid then
            return 60 -- Medium priority, would need to target manually
        else
            return 0 -- No one to heal
        end
    end,

    [TARGET_TYPES.TARGET_OF_TARGET] = function(context)
        if context.hasTarget and UnitExists("targettarget") and UnitIsFriend("player", "targettarget") then
            return 70 -- Available and useful for some situations
        else
            return 0 -- Not available
        end
    end,

    [TARGET_TYPES.GROUND_TARGET] = function(context)
        return 80 -- Always available for ground-targeted spells
    end
}

function Engine:EvaluateTargetPriority(targetType, spell, context)
    --[[
        Evaluate the priority score for a given target type based on the spell and context.

        Scoring System:
        - Priority scores range from 0 to 100, where higher values indicate better target choices.
        - A score of 0 means the target type is not available or applicable.
        - Scores are assigned based on contextual factors such as whether the target is friendly,
          whether the player is in a group, and the type of spell being cast.

        Parameters:
        - targetType: The type of target being evaluated (e.g., SELF, CURRENT_TARGET, FOCUS).
        - spell: The spell being considered for casting, which includes its target types.
        - context: A table containing contextual information (e.g., whether the player is in combat,
          whether a target exists, and whether the target is friendly).

        Returns:
        - A numerical priority score (0-100) indicating the suitability of the target type.
    ]]

    local evaluator = TARGET_PRIORITY_EVALUATORS[targetType]
    if evaluator then
        return evaluator(context)
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
    elseif ruleName == "groveGuardians" then
        return tracker:ShouldUseGroveGuardians()
    elseif ruleName == "wrath" then
        return tracker:ShouldUseWrath()
    end

    return false
end

HealIQ.Engine = Engine
HealIQ.Engine.TARGET_TYPES = TARGET_TYPES
HealIQ.Engine.SPELLS = SPELLS
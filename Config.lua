-- HealIQ Config.lua
-- Handles slash commands and user options

local addonName, HealIQ = ...

HealIQ.Config = {}
local Config = HealIQ.Config

-- Helper function for table contains check
local function tContains(table, item)
    for _, v in ipairs(table) do
        if v == item then
            return true
        end
    end
    return false
end



-- Command handlers
local commands = {}

function Config:Initialize()
    HealIQ:SafeCall(function()
        self:RegisterSlashCommands()
        HealIQ:Print("Config initialized")
    end)
end

function Config:RegisterSlashCommands()
    SLASH_HEALIQ1 = "/healiq"
    SLASH_HEALIQ2 = "/hiq"

    SlashCmdList["HEALIQ"] = function(msg)
        Config:HandleSlashCommand(msg)
    end
end

function Config:HandleSlashCommand(msg)
    HealIQ:SafeCall(function()
        local args = {}
        for word in msg:gmatch("%S+") do
            table.insert(args, word:lower())
        end

        local command = args[1] or "help"

        if commands[command] then
            commands[command](unpack(args, 2))
        else
            self:ShowHelp()
        end
    end)
end

-- Command implementations
commands.help = function()
    print("|cFF00FF00HealIQ v" .. HealIQ.version .. " Commands:|r")
    print("|cFFFFFF00/healiq|r - Show this help")
    print("|cFFFFFF00/healiq version|r - Show version information")
    print("|cFFFFFF00/healiq config|r - Open options window")
    print("|cFFFFFF00/healiq toggle|r - Toggle addon on/off")
    print("|cFFFFFF00/healiq enable|r - Enable addon")
    print("|cFFFFFF00/healiq disable|r - Disable addon")
    print("|cFFFFFF00/healiq profile|r - Show profile commands")
    print("|cFFFFFF00/healiq plugins|r - Show plugin commands")
    print("|cFFFFFF00/healiq spec|r - Show specialization commands")
    print("|cFFFFFF00/healiq ui|r - Show UI commands")
    print("|cFFFFFF00/healiq rules|r - Show rule commands")
    print("|cFFFFFF00/healiq strategy|r - Show strategy commands")
    print("|cFFFFFF00/healiq test|r - Test suggestion display")
    print("|cFFFFFF00/healiq test queue|r - Test queue display")
    print("|cFFFFFF00/healiq test ui|r - Test UI with sample queue")
    print("|cFFFFFF00/healiq test targeting|r - Test targeting suggestions")
    print("|cFFFFFF00/healiq debug|r - Toggle debug mode")
    print("|cFFFFFF00/healiq dump|r - Generate diagnostic dump")
    print("|cFFFFFF00/healiq health|r - Run comprehensive health check")
    print("|cFFFFFF00/healiq performance|r - Show performance report")
    print("|cFFFFFF00/healiq memory|r - Show memory usage information")
    print("|cFFFFFF00/healiq reset|r - Reset all settings")
    print("|cFFFFFF00/healiq reload|r - Reload addon configuration")
    print("|cFFFFFF00/healiq status|r - Show current status")
end

commands.version = function()
    print("|cFF00FF00HealIQ|r Version " .. HealIQ.version)
    print("  Interface: 110107 (The War Within)")
    print("  Author: djdefi")
    print("  Description: Smart healing spell suggestion addon for Restoration Druids")
    print("  GitHub: https://github.com/djdefi/healiq")
end

commands.toggle = function()
    if not HealIQ.db or not HealIQ.db.profile then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    HealIQ.db.profile.enabled = not HealIQ.db.profile.enabled
    local status = HealIQ.db.profile.enabled and "enabled" or "disabled"
    print("|cFF00FF00HealIQ|r " .. status)

    if HealIQ.UI then
        HealIQ.UI:SetEnabled(HealIQ.db.profile.enabled)
    end
end

commands.config = function()
    if HealIQ.UI then
        HealIQ.UI:ToggleOptionsFrame()
    end
end

commands.enable = function()
    if not HealIQ.db or not HealIQ.db.profile then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    HealIQ.db.profile.enabled = true
    print("|cFF00FF00HealIQ|r enabled")

    if HealIQ.UI then
        HealIQ.UI:SetEnabled(true)
    end
end

commands.disable = function()
    if not HealIQ.db or not HealIQ.db.profile then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    HealIQ.db.profile.enabled = false
    print("|cFF00FF00HealIQ|r disabled")

    if HealIQ.UI then
        HealIQ.UI:SetEnabled(false)
    end
end

commands.ui = function(subcommand, ...)
    local profileData = HealIQ:GetCurrentProfile()
    if not profileData or not profileData.ui then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    if subcommand == "lock" then
        profileData.ui.locked = true
        print("|cFF00FF00HealIQ|r UI locked")
    elseif subcommand == "unlock" then
        profileData.ui.locked = false
        print("|cFF00FF00HealIQ|r UI unlocked")
    elseif subcommand == "scale" then
        local scale = tonumber((...))
        if scale and HealIQ.UI then
            HealIQ.UI:SetScale(scale)
        else
            print("|cFF00FF00HealIQ|r Usage: /healiq ui scale <0.5-2.0>")
        end
    elseif subcommand == "reset" then
        if HealIQ.UI then
            HealIQ.UI:ResetPosition()
        end
    elseif subcommand == "name" then
        local show = ... == "show"
        if HealIQ.UI then
            HealIQ.UI:SetShowSpellName(show)
        end
        print("|cFF00FF00HealIQ|r Spell name display " .. (show and "enabled" or "disabled"))
    elseif subcommand == "cooldown" then
        local show = ... == "show"
        if HealIQ.UI then
            HealIQ.UI:SetShowCooldown(show)
        end
        print("|cFF00FF00HealIQ|r Cooldown display " .. (show and "enabled" or "disabled"))
    elseif subcommand == "queue" then
        local show = ... == "show"
        profileData.ui.showQueue = show
        if HealIQ.UI then
            HealIQ.UI:RecreateFrames()
        end
        print("|cFF00FF00HealIQ|r Queue display " .. (show and "enabled" or "disabled"))
    elseif subcommand == "queuesize" then
        local size = tonumber((...))
        if size and size >= 2 and size <= 5 then
            profileData.ui.queueSize = size
            if HealIQ.UI then
                HealIQ.UI:RecreateFrames()
            end
            print("|cFF00FF00HealIQ|r Queue size set to " .. size)
        else
            print("|cFF00FF00HealIQ|r Usage: /healiq ui queuesize <2-5>")
        end
    elseif subcommand == "layout" then
        local layout = ... or "horizontal"
        if layout == "horizontal" or layout == "vertical" then
            profileData.ui.queueLayout = layout
            if HealIQ.UI then
                HealIQ.UI:RecreateFrames()
            end
            print("|cFF00FF00HealIQ|r Queue layout set to " .. layout)
        else
            print("|cFF00FF00HealIQ|r Usage: /healiq ui layout <horizontal|vertical>")
        end
    elseif subcommand == "targeting" then
        local show = ... == "show"
        profileData.ui.showTargeting = show
        if HealIQ.Engine then
            HealIQ.Engine:ForceUpdate()
        end
        print("|cFF00FF00HealIQ|r Targeting suggestions " .. (show and "enabled" or "disabled"))
    elseif subcommand == "targetingicon" then
        local show = ... == "show"
        HealIQ.db.ui.showTargetingIcon = show
        if HealIQ.Engine then
            HealIQ.Engine:ForceUpdate()
        end
        print("|cFF00FF00HealIQ|r Targeting icons " .. (show and "enabled" or "disabled"))
    else
        print("|cFF00FF00HealIQ UI Commands:|r")
        print("|cFFFFFF00/healiq ui lock|r - Lock UI position")
        print("|cFFFFFF00/healiq ui unlock|r - Unlock UI position")
        print("|cFFFFFF00/healiq ui scale <number>|r - Set UI scale (0.5-2.0)")
        print("|cFFFFFF00/healiq ui reset|r - Reset UI position")
        print("|cFFFFFF00/healiq ui name show/hide|r - Show/hide spell names")
        print("|cFFFFFF00/healiq ui cooldown show/hide|r - Show/hide cooldowns")
        print("|cFFFFFF00/healiq ui queue show/hide|r - Show/hide queue display")
        print("|cFFFFFF00/healiq ui queuesize <2-5>|r - Set queue size")
        print("|cFFFFFF00/healiq ui layout horizontal/vertical|r - Set queue layout")
        print("|cFFFFFF00/healiq ui targeting show/hide|r - Show/hide targeting suggestions")
        print("|cFFFFFF00/healiq ui targetingicon show/hide|r - Show/hide targeting icons")
    end
end

commands.rules = function(subcommand, ...)
    if not HealIQ.db or not HealIQ.db.rules then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    if subcommand == "list" then
        print("|cFF00FF00HealIQ Rules:|r")
        for rule, enabled in pairs(HealIQ.db.rules) do
            local status = enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
            print("  " .. rule .. ": " .. status)
        end
    elseif subcommand == "enable" then
        local rule = ...
        if rule and HealIQ.db.rules[rule] ~= nil then
            HealIQ.db.rules[rule] = true
            print("|cFF00FF00HealIQ|r Rule '" .. rule .. "' enabled")
        else
            print("|cFF00FF00HealIQ|r Unknown rule: " .. tostring(rule))
        end
    elseif subcommand == "disable" then
        local rule = ...
        if rule and HealIQ.db.rules[rule] ~= nil then
            HealIQ.db.rules[rule] = false
            print("|cFF00FF00HealIQ|r Rule '" .. rule .. "' disabled")
        else
            print("|cFF00FF00HealIQ|r Unknown rule: " .. tostring(rule))
        end
    else
        print("|cFF00FF00HealIQ Rule Commands:|r")
        print("|cFFFFFF00/healiq rules list|r - List all rules and their status")
        print("|cFFFFFF00/healiq rules enable <rule>|r - Enable a specific rule")
        print("|cFFFFFF00/healiq rules disable <rule>|r - Disable a specific rule")
        print("|cFFFFFF00Rules:|r wildGrowth, clearcasting, lifebloom, swiftmend, rejuvenation,")
        print("  ironbark, efflorescence, tranquility, incarnationTree, naturesSwiftness,")
        print("  barkskin, flourish, groveGuardians, wrath")
        print("|cFFFFFF00/healiq strategy|r - Show strategy commands")
    end
end

commands.strategy = function(subcommand, ...)
    if not HealIQ.db or not HealIQ.db.strategy then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    if subcommand == "list" then
        print("|cFF00FF00HealIQ Strategy Settings:|r")
        for setting, value in pairs(HealIQ.db.strategy) do
            local valueStr = tostring(value)
            if type(value) == "boolean" then
                valueStr = value and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
            else
                valueStr = "|cFFFFFF00" .. valueStr .. "|r"
            end
            print("  " .. setting .. ": " .. valueStr)
        end
    elseif subcommand == "set" then
        local setting = (...)
        local value = select(2, ...)
        if setting and value and HealIQ.db.strategy[setting] ~= nil then
            local oldValue = HealIQ.db.strategy[setting]

            -- Convert value based on current type
            if type(oldValue) == "boolean" then
                if value == "true" or value == "1" or value == "on" then
                    HealIQ.db.strategy[setting] = true
                elseif value == "false" or value == "0" or value == "off" then
                    HealIQ.db.strategy[setting] = false
                else
                    print("|cFFFF0000HealIQ|r Invalid boolean value. Use true/false, 1/0, or on/off")
                    return
                end
            elseif type(oldValue) == "number" then
                local numValue = tonumber(value)
                if numValue then
                    HealIQ.db.strategy[setting] = numValue
                else
                    print("|cFFFF0000HealIQ|r Invalid number value: " .. value)
                    return
                end
            else
                print("|cFFFF0000HealIQ|r Cannot set setting of type: " .. type(oldValue))
                return
            end

            print("|cFF00FF00HealIQ|r Strategy setting '" .. setting .. "' set to " .. tostring(HealIQ.db.strategy[setting]))

            -- Force engine update to apply changes
            if HealIQ.Engine then
                HealIQ.Engine:ForceUpdate()
            end
        else
            print("|cFFFF0000HealIQ|r Unknown strategy setting: " .. tostring(setting))
        end
    elseif subcommand == "reset" then
        -- Reset strategy settings to defaults
        if HealIQ.db and HealIQ.db.strategy then
            -- Get defaults from Core.lua
            local defaults = {
                prioritizeEfflorescence = true,
                maintainLifebloomOnTank = true,
                lifebloomRefreshWindow = 4.5,
                preferClearcastingRegrowth = true,
                swiftmendWildGrowthCombo = true,
                rejuvenationRampThreshold = 15,
                avoidRandomRejuvenationDowntime = true,
                useWrathForMana = true,
                poolGroveGuardians = true,
                emergencyNaturesSwiftness = true,
                wildGrowthMinTargets = 3,
                tranquilityMinTargets = 4,
                efflorescenceMinTargets = 2,
                flourishMinHots = 2,
                recentDamageWindow = 3,
                lowHealthThreshold = 0.3,
            }

            for setting, defaultValue in pairs(defaults) do
                HealIQ.db.strategy[setting] = defaultValue
            end

            print("|cFF00FF00HealIQ|r Strategy settings reset to defaults")

            if HealIQ.Engine then
                HealIQ.Engine:ForceUpdate()
            end
        end
    else
        print("|cFF00FF00HealIQ Strategy Commands:|r")
        print("|cFFFFFF00/healiq strategy list|r - List all strategy settings")
        print("|cFFFFFF00/healiq strategy set <setting> <value>|r - Set a strategy setting")
        print("|cFFFFFF00/healiq strategy reset|r - Reset all strategy settings to defaults")
        print("|cFFFFFF00Settings:|r prioritizeEfflorescence, maintainLifebloomOnTank,")
        print("  preferClearcastingRegrowth, swiftmendWildGrowthCombo, useWrathForMana,")
        print("  poolGroveGuardians, emergencyNaturesSwiftness, wildGrowthMinTargets,")
        print("  tranquilityMinTargets, efflorescenceMinTargets, flourishMinHots,")
        print("  recentDamageWindow, lowHealthThreshold, lifebloomRefreshWindow")
    end
end

commands.test = function(subcommand)
    if not HealIQ.db then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    if subcommand == "engine" then
        if HealIQ.Engine and HealIQ.db.rules then
            print("|cFF00FF00HealIQ|r Testing engine rules...")
            for rule in pairs(HealIQ.db.rules) do
                local result = HealIQ.Engine:TestRule(rule)
                local status = result and "|cFF00FF00PASS|r" or "|cFFFF0000FAIL|r"
                print("  " .. rule .. ": " .. status)
            end
        else
            print("|cFFFF0000HealIQ|r Engine or rules not yet initialized")
        end
    elseif subcommand == "queue" then
        if HealIQ.Engine then
            print("|cFF00FF00HealIQ|r Testing queue display...")
            local queue = HealIQ.Engine:EvaluateRulesQueue()
            if #queue > 0 then
                print("  Queue contains " .. #queue .. " suggestions:")
                for i, suggestion in ipairs(queue) do
                    print("    " .. i .. ". " .. suggestion.name)
                end
            else
                print("  Queue is empty")
            end

            -- Force UI update
            if HealIQ.UI then
                HealIQ.UI:UpdateQueue(queue)
            end
        else
            print("|cFFFF0000HealIQ|r Engine not yet initialized")
        end
    elseif subcommand == "ui" then
        if HealIQ.UI then
            HealIQ.UI:TestQueue()
        else
            print("|cFFFF0000HealIQ|r UI not yet initialized")
        end
    elseif subcommand == "targeting" then
        if HealIQ.Engine and HealIQ.UI then
            print("|cFF00FF00HealIQ|r Testing targeting suggestions...")

            -- Test each spell's targeting suggestions
            for spellName, spellData in pairs(HealIQ.Engine.SPELLS) do
                local targetText = HealIQ.Engine:GetTargetingSuggestionsText(spellData)
                local targetDesc = HealIQ.Engine:GetTargetingSuggestionsDescription(spellData)

                print("  " .. spellData.name .. ":")
                if targetText then
                    print("    → " .. targetText)
                    if targetDesc then
                        print("    " .. targetDesc)
                    end
                else
                    print("    → No targeting suggestion")
                end
            end

            -- Show a test suggestion with targeting
            local testSuggestion = HealIQ.Engine.SPELLS.REJUVENATION
            HealIQ.UI:UpdateSuggestion(testSuggestion)
            print("Test targeting display activated with Rejuvenation")
        else
            print("|cFFFF0000HealIQ|r Engine or UI not yet initialized")
        end
    else
        if HealIQ.UI then
            HealIQ.UI:TestDisplay()
        else
            print("|cFFFF0000HealIQ|r UI not yet initialized")
        end
    end
end

commands.debug = function()
    HealIQ.debug = not HealIQ.debug
    -- Save debug state to database so it persists across sessions
    if HealIQ.db then
        HealIQ.db.debug = HealIQ.debug
    end
    local status = HealIQ.debug and "enabled" or "disabled"
    print("|cFF00FF00HealIQ|r Debug mode " .. status)
end

commands.dump = function()
    local dump = HealIQ:GenerateDiagnosticDump()

    -- Print dump to chat (this would normally be saved to file)
    print("|cFF00FF00HealIQ|r Diagnostic dump generated:")
    print("|cFF888888" .. string.rep("-", 50) .. "|r")

    -- Split dump into lines and print each
    for line in dump:gmatch("[^\n]+") do
        print("|cFF888888" .. line .. "|r")
    end

    print("|cFF888888" .. string.rep("-", 50) .. "|r")
    print("|cFF00FF00HealIQ|r Diagnostic dump complete")
end

commands.reset = function()
    if not HealIQ.db then
        print("|cFFFF0000HealIQ|r Database not yet initialized")
        return
    end

    print("|cFF00FF00HealIQ|r Resetting all settings...")

    -- Reset to defaults
    HealIQ.db.enabled = true
    HealIQ.db.debug = false

    if HealIQ.db.ui then
        HealIQ.db.ui.scale = 1.0
        HealIQ.db.ui.x = 0
        HealIQ.db.ui.y = 0
        HealIQ.db.ui.locked = false
        HealIQ.db.ui.showIcon = true
        HealIQ.db.ui.showSpellName = true
        HealIQ.db.ui.showCooldown = true
        HealIQ.db.ui.showQueue = true
        HealIQ.db.ui.queueSize = 3
        HealIQ.db.ui.queueLayout = "horizontal"
        HealIQ.db.ui.queueSpacing = 8
        HealIQ.db.ui.queueScale = 0.75
        HealIQ.db.ui.minimapAngle = -math.pi/4
        HealIQ.db.ui.showPositionBorder = false
    end

    if HealIQ.db.rules then
        for rule in pairs(HealIQ.db.rules) do
            HealIQ.db.rules[rule] = true
        end
    end

    if HealIQ.UI then
        HealIQ.UI:RecreateFrames()
    end

    print("|cFF00FF00HealIQ|r Settings reset to defaults")
end

commands.reload = function()
    print("|cFF00FF00HealIQ|r Reloading addon configuration...")

    -- Reinitialize all modules
    if HealIQ.Tracker then
        HealIQ.Tracker:Initialize()
    end

    if HealIQ.Engine then
        HealIQ.Engine:Initialize()
    end

    if HealIQ.UI then
        HealIQ.UI:RecreateFrames()
    end

    -- Force an update
    if HealIQ.Engine then
        HealIQ.Engine:ForceUpdate()
    end

    print("|cFF00FF00HealIQ|r Addon reloaded successfully")
end

commands.status = function()
    print("|cFF00FF00HealIQ v" .. HealIQ.version .. " Status:|r")

    if not HealIQ.db then
        print("  |cFFFF0000Database not yet initialized|r")
        return
    end

    print("  Enabled: " .. (HealIQ.db.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Debug: " .. (HealIQ.debug and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))

    if HealIQ.db.ui then
        print("  UI Scale: " .. HealIQ.db.ui.scale)
        print("  UI Position: " .. HealIQ.db.ui.x .. ", " .. HealIQ.db.ui.y)
        print("  UI Locked: " .. (HealIQ.db.ui.locked and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("  Queue Display: " .. (HealIQ.db.ui.showQueue and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        print("  Queue Size: " .. (HealIQ.db.ui.queueSize or 3))
        print("  Queue Layout: " .. (HealIQ.db.ui.queueLayout or "horizontal"))
    else
        print("  UI: |cFFFF0000Not yet initialized|r")
    end

    -- Show current suggestion
    if HealIQ.Engine then
        local suggestion = HealIQ.Engine:GetCurrentSuggestion()
        if suggestion then
            print("  Current Suggestion: |cFF00FF00" .. suggestion.name .. "|r")
        else
            print("  Current Suggestion: |cFFFF0000None|r")
        end

        -- Show current queue
        local queue = HealIQ.Engine:GetCurrentQueue()
        if queue and #queue > 0 then
            local names = {}
            for i, queueSuggestion in ipairs(queue) do
                table.insert(names, queueSuggestion.name)
            end
            print("  Current Queue: |cFF00FF00" .. table.concat(names, " → ") .. "|r")
        else
            print("  Current Queue: |cFFFF0000Empty|r")
        end
    else
        print("  Engine: |cFFFF0000Not yet initialized|r")
    end

    -- Show active rules
    if HealIQ.db.rules then
        local activeRules = {}
        for rule, enabled in pairs(HealIQ.db.rules) do
            if enabled then
                table.insert(activeRules, rule)
            end
        end
        print("  Active Rules: " .. (#activeRules > 0 and "|cFF00FF00" .. table.concat(activeRules, ", ") .. "|r" or "|cFFFF0000None|r"))
    else
        print("  Rules: |cFFFF0000Not yet initialized|r")
    end

    -- Show spec info
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    local specName = specIndex and GetSpecializationInfo(specIndex) or "Unknown"
    print("  Class: |cFF00FF00" .. class .. "|r")
    print("  Spec: |cFF00FF00" .. specName .. "|r")
    print("  In Combat: " .. (InCombatLockdown() and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))

    -- Show session statistics
    if HealIQ.sessionStats and HealIQ.sessionStats.startTime then
        print("  |cFF00FF00Session Statistics:|r")
        local duration = time() - HealIQ.sessionStats.startTime
        print("    Duration: " .. HealIQ:FormatDuration(duration))
        print("    Suggestions: " .. HealIQ.sessionStats.suggestions)
        print("    Rules Processed: " .. HealIQ.sessionStats.rulesProcessed)
        print("    Events Handled: " .. HealIQ.sessionStats.eventsHandled)
        print("    Errors Logged: " .. HealIQ.sessionStats.errorsLogged)
    end

    -- Show addon status
    local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata("HealIQ", "Version") or GetAddOnMetadata("HealIQ", "Version") or "Unknown"
    print("  Addon Version: |cFF00FF00" .. addonVersion .. "|r")
end

-- Comprehensive health check command
commands.health = function()
    print("|cFF00FF00HealIQ Health Check:|r")

    if HealIQ.Validation then
        local healthCheck = HealIQ.Validation:HealthCheck()

        -- Show overall status
        local statusColor = "|cFF00FF00" -- Green
        if healthCheck.overall_status == "WARNING" then
            statusColor = "|cFFFFFF00" -- Yellow
        elseif healthCheck.overall_status == "CRITICAL" then
            statusColor = "|cFFFF0000" -- Red
        end

        print("  Overall Status: " .. statusColor .. healthCheck.overall_status .. "|r")
        print("  Success Rate: " .. string.format("%.1f%%", healthCheck.success_rate * 100) .. " (" .. healthCheck.checks_passed .. "/" .. healthCheck.total_checks .. ")")

        -- Show failed checks
        local failedChecks = {}
        for _, check in ipairs(healthCheck.checks) do
            if check.status == "FAIL" then
                table.insert(failedChecks, check.name .. ": " .. check.message)
            end
        end

        if #failedChecks > 0 then
            print("  |cFFFF0000Failed Checks:|r")
            for _, failure in ipairs(failedChecks) do
                print("    - " .. failure)
            end
        else
            print("  |cFF00FF00All checks passed!|r")
        end
    else
        print("  |cFFFF0000Health check system not available|r")
    end
end

-- Profile management commands
commands.profile = function(subcommand, ...)
    if subcommand == "list" then
        local profiles = HealIQ:GetProfiles()
        local currentProfile = HealIQ.db.global and HealIQ.db.global.currentProfile or "Default"
        
        print("|cFF00FF00HealIQ Profiles:|r")
        for _, name in ipairs(profiles) do
            local marker = (name == currentProfile) and " |cFF00FF00(current)|r" or ""
            print("  " .. name .. marker)
        end
    elseif subcommand == "switch" then
        local profileName = select(1, ...)
        if not profileName then
            print("|cFF00FF00Usage:|r /healiq profile switch <name>")
            return
        end
        
        HealIQ:SetProfile(profileName)
    elseif subcommand == "create" then
        local profileName = select(1, ...)
        if not profileName then
            print("|cFF00FF00Usage:|r /healiq profile create <name>")
            return
        end
        
        HealIQ:SetProfile(profileName) -- This creates it if it doesn't exist
    elseif subcommand == "delete" then
        local profileName = select(1, ...)
        if not profileName then
            print("|cFF00FF00Usage:|r /healiq profile delete <name>")
            return
        end
        
        HealIQ:DeleteProfile(profileName)
    elseif subcommand == "export" then
        local profileName = select(1, ...)
        local exportString = HealIQ:ExportProfile(profileName)
        if exportString then
            print("|cFF00FF00Profile Export Data:|r")
            print(exportString)
        end
    else
        print("|cFF00FF00HealIQ Profile Commands:|r")
        print("|cFFFFFF00/healiq profile list|r - List all profiles")
        print("|cFFFFFF00/healiq profile switch <name>|r - Switch to profile")
        print("|cFFFFFF00/healiq profile create <name>|r - Create new profile")
        print("|cFFFFFF00/healiq profile delete <name>|r - Delete profile")
        print("|cFFFFFF00/healiq profile export [name]|r - Export profile")
    end
end

-- Plugin management commands
commands.plugins = function(subcommand, ...)
    if subcommand == "list" then
        print("|cFF00FF00HealIQ Registered Plugins:|r")
        local hasPlugins = false
        for name, plugin in pairs(HealIQ.Plugins.registered) do
            hasPlugins = true
            local status = HealIQ.Plugins.enabled[name] and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"
            print("  " .. name .. " v" .. plugin.version .. " (" .. status .. ")")
            if plugin.description and plugin.description ~= "" then
                print("    " .. plugin.description)
            end
        end
        
        if not hasPlugins then
            print("  No plugins registered")
        end
    elseif subcommand == "enable" then
        local pluginName = select(1, ...)
        if not pluginName then
            print("|cFF00FF00Usage:|r /healiq plugins enable <name>")
            return
        end
        
        HealIQ:EnablePlugin(pluginName)
    elseif subcommand == "disable" then
        local pluginName = select(1, ...)
        if not pluginName then
            print("|cFF00FF00Usage:|r /healiq plugins disable <name>")
            return
        end
        
        HealIQ:DisablePlugin(pluginName)
    else
        print("|cFF00FF00HealIQ Plugin Commands:|r")
        print("|cFFFFFF00/healiq plugins list|r - List all plugins")
        print("|cFFFFFF00/healiq plugins enable <name>|r - Enable plugin")
        print("|cFFFFFF00/healiq plugins disable <name>|r - Disable plugin")
    end
end

-- Specialization management commands
commands.spec = function(subcommand, ...)
    if subcommand == "detect" then
        local detected = HealIQ:DetectSpecialization()
        local active = HealIQ:GetActiveSpecialization()
        
        print("|cFF00FF00HealIQ Specialization:|r")
        print("  Detected: " .. detected)
        print("  Active: " .. active)
        
        local profileData = HealIQ:GetCurrentProfile()
        if profileData then
            print("  Mode: " .. (profileData.specialization or "auto"))
        end
    elseif subcommand == "set" then
        local spec = select(1, ...)
        local validSpecs = {"auto", "restoration", "guardian", "feral", "balance"}
        
        if not spec or not tContains(validSpecs, spec) then
            print("|cFF00FF00Usage:|r /healiq spec set <auto|restoration|guardian|feral|balance>")
            return
        end
        
        local profileData = HealIQ:GetCurrentProfile()
        if profileData then
            profileData.specialization = spec
            print("|cFF00FF00HealIQ|r Specialization set to: " .. spec)
            
            if spec ~= "auto" then
                -- Update rules immediately for manual setting
                if HealIQ.Engine then
                    HealIQ.Engine:UpdateRulesForSpecialization(spec)
                end
            else
                -- Trigger detection and update
                HealIQ:OnSpecializationChanged()
            end
        else
            print("|cFFFF0000HealIQ|r Profile not available")
        end
    else
        print("|cFF00FF00HealIQ Specialization Commands:|r")
        print("|cFFFFFF00/healiq spec detect|r - Show current specialization")
        print("|cFFFFFF00/healiq spec set <spec>|r - Set specialization override")
        print("  Valid specs: auto, restoration, guardian, feral, balance")
    end
end

-- Performance diagnostics command
commands.performance = function()
    print("|cFF00FF00HealIQ Performance Report:|r")

    if HealIQ.Performance then
        print(HealIQ.Performance:GeneratePerformanceReport())
    else
        print("  |cFFFF0000Performance monitoring not available|r")
    end
end

-- Memory usage command
commands.memory = function()
    print("|cFF00FF00HealIQ Memory Usage:|r")

    local beforeGC = collectgarbage("count")
    collectgarbage("collect")
    local afterGC = collectgarbage("count")

    print("  Memory before GC: " .. string.format("%.2f KB", beforeGC))
    print("  Memory after GC: " .. string.format("%.2f KB", afterGC))
    print("  Memory freed: " .. string.format("%.2f KB", beforeGC - afterGC))

    if HealIQ.Performance then
        local performanceData = HealIQ.Performance:ExportData()
        if performanceData.memory then
            local totalTracked = 0
            for _, memUsage in pairs(performanceData.memory) do
                totalTracked = totalTracked + memUsage
            end
            print("  Tracked allocations: " .. string.format("%.2f KB", totalTracked))
        end
    end
end

-- Enhanced configuration methods with validation
-- @param category Configuration category (ui, rules, general)
-- @param option Configuration option name
-- @param value New value to set
-- @return boolean, string Success status and error message
function Config:SetOption(category, option, value)
    local profileData = HealIQ:GetCurrentProfile()
    if not profileData then
        return false, "Database not initialized"
    end

    -- Use validation if available
    if HealIQ.Validation then
        local success, error, sanitizedValue = HealIQ.Validation:ValidateConfigValue(category, option, value)
        if not success then
            return false, error
        end
        value = sanitizedValue
    end

    -- Apply the validated value
    if category == "ui" and profileData.ui and profileData.ui[option] ~= nil then
        local oldValue = profileData.ui[option]
        profileData.ui[option] = value

        -- Trigger UI updates if necessary
        if HealIQ.UI then
            if option == "scale" and HealIQ.UI.SetScale then
                HealIQ.UI:SetScale(value)
            elseif option == "locked" and HealIQ.UI.SetLocked then
                HealIQ.UI:SetLocked(value)
            elseif option == "queueSize" and HealIQ.UI.RecreateFrames then
                HealIQ.UI:RecreateFrames()
            end
        end

        HealIQ:DebugLog(string.format("UI setting changed: %s = %s (was %s)", option, tostring(value), tostring(oldValue)), "INFO")
        return true, "Setting updated"
    elseif category == "rules" and profileData.rules and profileData.rules[option] ~= nil then
        local oldValue = profileData.rules[option]
        profileData.rules[option] = value
        HealIQ:DebugLog(string.format("Rule setting changed: %s = %s (was %s)", option, tostring(value), tostring(oldValue)), "INFO")
        return true, "Rule updated"
    elseif category == "general" and profileData[option] ~= nil then
        local oldValue = profileData[option]
        profileData[option] = value

        -- Special handling for general settings
        if option == "debug" then
            HealIQ.debug = value
        elseif option == "enabled" and HealIQ.UI then
            HealIQ.UI:SetEnabled(value)
        end

        HealIQ:DebugLog(string.format("General setting changed: %s = %s (was %s)", option, tostring(value), tostring(oldValue)), "INFO")
        return true, "General setting updated"
    end
    return false, "Unknown configuration option: " .. tostring(category) .. "." .. tostring(option)
end

-- Get configuration option with fallback handling
-- @param category Configuration category (ui, rules, general)
-- @param option Configuration option name
-- @return any The configuration value or nil if not found
function Config:GetOption(category, option)
    local profileData = HealIQ:GetCurrentProfile()
    if not profileData then
        return nil
    end

    if category == "ui" and profileData.ui then
        return profileData.ui[option]
    elseif category == "rules" and profileData.rules then
        return profileData.rules[option]
    elseif category == "general" then
        return profileData[option]
    end
    return nil
end

function Config:ShowHelp()
    commands.help()
end

-- Expose commands for testing
Config.commands = commands

HealIQ.Config = Config
-- HealIQ Config.lua
-- Handles slash commands and user options

local addonName, HealIQ = ...

HealIQ.Config = {}
local Config = HealIQ.Config

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
    print("|cFFFFFF00/healiq ui|r - Show UI commands")
    print("|cFFFFFF00/healiq rules|r - Show rule commands")
    print("|cFFFFFF00/healiq test|r - Test suggestion display")
    print("|cFFFFFF00/healiq test queue|r - Test queue display")
    print("|cFFFFFF00/healiq test ui|r - Test UI with sample queue")
    print("|cFFFFFF00/healiq debug|r - Toggle debug mode")
    print("|cFFFFFF00/healiq reset|r - Reset all settings")
    print("|cFFFFFF00/healiq reload|r - Reload addon configuration")
    print("|cFFFFFF00/healiq backup|r - Create settings backup")
    print("|cFFFFFF00/healiq restore|r - Restore settings from backup")
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
    HealIQ.db.enabled = not HealIQ.db.enabled
    local status = HealIQ.db.enabled and "enabled" or "disabled"
    print("|cFF00FF00HealIQ|r " .. status)
    
    if HealIQ.UI then
        HealIQ.UI:SetEnabled(HealIQ.db.enabled)
    end
end

commands.config = function()
    if HealIQ.UI then
        HealIQ.UI:ToggleOptionsFrame()
    end
end

commands.enable = function()
    HealIQ.db.enabled = true
    print("|cFF00FF00HealIQ|r enabled")
    
    if HealIQ.UI then
        HealIQ.UI:SetEnabled(true)
    end
end

commands.disable = function()
    HealIQ.db.enabled = false
    print("|cFF00FF00HealIQ|r disabled")
    
    if HealIQ.UI then
        HealIQ.UI:SetEnabled(false)
    end
end

commands.ui = function(subcommand, ...)
    if subcommand == "lock" then
        HealIQ.db.ui.locked = true
        print("|cFF00FF00HealIQ|r UI locked")
    elseif subcommand == "unlock" then
        HealIQ.db.ui.locked = false
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
        HealIQ.db.ui.showQueue = show
        if HealIQ.UI then
            HealIQ.UI:RecreateFrames()
        end
        print("|cFF00FF00HealIQ|r Queue display " .. (show and "enabled" or "disabled"))
    elseif subcommand == "queuesize" then
        local size = tonumber((...))
        if size and size >= 2 and size <= 5 then
            HealIQ.db.ui.queueSize = size
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
            HealIQ.db.ui.queueLayout = layout
            if HealIQ.UI then
                HealIQ.UI:RecreateFrames()
            end
            print("|cFF00FF00HealIQ|r Queue layout set to " .. layout)
        else
            print("|cFF00FF00HealIQ|r Usage: /healiq ui layout <horizontal|vertical>")
        end
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
    end
end

commands.rules = function(subcommand, ...)
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
        print("  barkskin, flourish, trinket")
    end
end

commands.test = function(subcommand)
    if subcommand == "engine" then
        if HealIQ.Engine then
            print("|cFF00FF00HealIQ|r Testing engine rules...")
            for rule in pairs(HealIQ.db.rules) do
                local result = HealIQ.Engine:TestRule(rule)
                local status = result and "|cFF00FF00PASS|r" or "|cFFFF0000FAIL|r"
                print("  " .. rule .. ": " .. status)
            end
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
        end
    elseif subcommand == "ui" then
        if HealIQ.UI then
            HealIQ.UI:TestQueue()
        end
    else
        if HealIQ.UI then
            HealIQ.UI:TestDisplay()
        end
    end
end

commands.debug = function()
    HealIQ.debug = not HealIQ.debug
    local status = HealIQ.debug and "enabled" or "disabled"
    print("|cFF00FF00HealIQ|r Debug mode " .. status)
end

commands.reset = function()
    print("|cFF00FF00HealIQ|r Resetting all settings...")
    
    -- Reset to defaults
    HealIQ.db.enabled = true
    HealIQ.db.debug = false
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
    
    for rule in pairs(HealIQ.db.rules) do
        HealIQ.db.rules[rule] = true
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

commands.backup = function()
    -- Create a backup of current settings
    if not HealIQDB.backups then
        HealIQDB.backups = {}
    end
    
    local backupKey = "backup_" .. date("%Y%m%d_%H%M%S")
    HealIQDB.backups[backupKey] = {
        enabled = HealIQ.db.enabled,
        ui = {},
        rules = {}
    }
    
    -- Copy UI settings
    for key, value in pairs(HealIQ.db.ui) do
        HealIQDB.backups[backupKey].ui[key] = value
    end
    
    -- Copy rule settings
    for key, value in pairs(HealIQ.db.rules) do
        HealIQDB.backups[backupKey].rules[key] = value
    end
    
    print("|cFF00FF00HealIQ|r Settings backed up as: " .. backupKey)
end

commands.restore = function()
    if not HealIQDB.backups then
        print("|cFF00FF00HealIQ|r No backups found")
        return
    end
    
    -- Find the most recent backup
    local mostRecent = nil
    local mostRecentKey = nil
    
    for key, backup in pairs(HealIQDB.backups) do
        if not mostRecent or key > mostRecentKey then
            mostRecent = backup
            mostRecentKey = key
        end
    end
    
    if mostRecent then
        -- Restore settings
        HealIQ.db.enabled = mostRecent.enabled
        
        for key, value in pairs(mostRecent.ui) do
            HealIQ.db.ui[key] = value
        end
        
        for key, value in pairs(mostRecent.rules) do
            HealIQ.db.rules[key] = value
        end
        
        -- Recreate UI with restored settings
        if HealIQ.UI then
            HealIQ.UI:RecreateFrames()
        end
        
        print("|cFF00FF00HealIQ|r Settings restored from: " .. mostRecentKey)
    else
        print("|cFF00FF00HealIQ|r No valid backups found")
    end
end

commands.status = function()
    print("|cFF00FF00HealIQ v" .. HealIQ.version .. " Status:|r")
    print("  Enabled: " .. (HealIQ.db.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Debug: " .. (HealIQ.debug and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  UI Scale: " .. HealIQ.db.ui.scale)
    print("  UI Position: " .. HealIQ.db.ui.x .. ", " .. HealIQ.db.ui.y)
    print("  UI Locked: " .. (HealIQ.db.ui.locked and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Queue Display: " .. (HealIQ.db.ui.showQueue and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
    print("  Queue Size: " .. (HealIQ.db.ui.queueSize or 3))
    print("  Queue Layout: " .. (HealIQ.db.ui.queueLayout or "horizontal"))
    
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
    end
    
    -- Show active rules
    local activeRules = {}
    for rule, enabled in pairs(HealIQ.db.rules) do
        if enabled then
            table.insert(activeRules, rule)
        end
    end
    print("  Active Rules: " .. (#activeRules > 0 and "|cFF00FF00" .. table.concat(activeRules, ", ") .. "|r" or "|cFFFF0000None|r"))
    
    -- Show spec info
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    local specName = specIndex and GetSpecializationInfo(specIndex) or "Unknown"
    print("  Class: |cFF00FF00" .. class .. "|r")
    print("  Spec: |cFF00FF00" .. specName .. "|r")
    print("  In Combat: " .. (InCombatLockdown() and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    
    -- Show addon status
    local addonVersion = GetAddOnMetadata("HealIQ", "Version")
    print("  Addon Version: |cFF00FF00" .. addonVersion .. "|r")
    print("  Memory Usage: |cFF00FF00" .. GetAddOnMemoryUsage("HealIQ") .. " KB|r")
end

-- Public configuration methods
function Config:SetOption(category, option, value)
    if category == "ui" and HealIQ.db.ui[option] ~= nil then
        HealIQ.db.ui[option] = value
        return true
    elseif category == "rules" and HealIQ.db.rules[option] ~= nil then
        HealIQ.db.rules[option] = value
        return true
    elseif category == "general" and HealIQ.db[option] ~= nil then
        HealIQ.db[option] = value
        return true
    end
    return false
end

function Config:GetOption(category, option)
    if category == "ui" then
        return HealIQ.db.ui[option]
    elseif category == "rules" then
        return HealIQ.db.rules[option]
    elseif category == "general" then
        return HealIQ.db[option]
    end
    return nil
end

function Config:ShowHelp()
    commands.help()
end

HealIQ.Config = Config
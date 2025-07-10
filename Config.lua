-- HealIQ Config.lua
-- Handles slash commands and user options

local addonName, HealIQ = ...

HealIQ.Config = {}
local Config = HealIQ.Config

-- Command handlers
local commands = {}

function Config:Initialize()
    self:RegisterSlashCommands()
    HealIQ:Print("Config initialized")
end

function Config:RegisterSlashCommands()
    SLASH_HEALIQ1 = "/healiq"
    SLASH_HEALIQ2 = "/hiq"
    
    SlashCmdList["HEALIQ"] = function(msg)
        Config:HandleSlashCommand(msg)
    end
end

function Config:HandleSlashCommand(msg)
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
end

-- Command implementations
commands.help = function()
    print("|cFF00FF00HealIQ v" .. HealIQ.version .. " Commands:|r")
    print("|cFFFFFF00/healiq|r - Show this help")
    print("|cFFFFFF00/healiq config|r - Open options window")
    print("|cFFFFFF00/healiq toggle|r - Toggle addon on/off")
    print("|cFFFFFF00/healiq enable|r - Enable addon")
    print("|cFFFFFF00/healiq disable|r - Disable addon")
    print("|cFFFFFF00/healiq ui|r - Show UI commands")
    print("|cFFFFFF00/healiq rules|r - Show rule commands")
    print("|cFFFFFF00/healiq test|r - Test suggestion display")
    print("|cFFFFFF00/healiq debug|r - Toggle debug mode")
    print("|cFFFFFF00/healiq reset|r - Reset all settings")
    print("|cFFFFFF00/healiq status|r - Show current status")
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
    else
        print("|cFF00FF00HealIQ UI Commands:|r")
        print("|cFFFFFF00/healiq ui lock|r - Lock UI position")
        print("|cFFFFFF00/healiq ui unlock|r - Unlock UI position")
        print("|cFFFFFF00/healiq ui scale <number>|r - Set UI scale (0.5-2.0)")
        print("|cFFFFFF00/healiq ui reset|r - Reset UI position")
        print("|cFFFFFF00/healiq ui name show/hide|r - Show/hide spell names")
        print("|cFFFFFF00/healiq ui cooldown show/hide|r - Show/hide cooldowns")
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
    HealIQ.db.ui.scale = 1.0
    HealIQ.db.ui.x = 0
    HealIQ.db.ui.y = 0
    HealIQ.db.ui.locked = false
    HealIQ.db.ui.showIcon = true
    HealIQ.db.ui.showSpellName = true
    HealIQ.db.ui.showCooldown = true
    
    for rule in pairs(HealIQ.db.rules) do
        HealIQ.db.rules[rule] = true
    end
    
    if HealIQ.UI then
        HealIQ.UI:UpdateScale()
        HealIQ.UI:UpdatePosition()
    end
    
    print("|cFF00FF00HealIQ|r Settings reset to defaults")
end

commands.status = function()
    print("|cFF00FF00HealIQ v" .. HealIQ.version .. " Status:|r")
    print("  Enabled: " .. (HealIQ.db.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Debug: " .. (HealIQ.debug and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  UI Scale: " .. HealIQ.db.ui.scale)
    print("  UI Position: " .. HealIQ.db.ui.x .. ", " .. HealIQ.db.ui.y)
    print("  UI Locked: " .. (HealIQ.db.ui.locked and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    
    -- Show current suggestion
    if HealIQ.Engine then
        local suggestion = HealIQ.Engine:GetCurrentSuggestion()
        if suggestion then
            print("  Current Suggestion: " .. suggestion.name)
        else
            print("  Current Suggestion: None")
        end
    end
    
    -- Show active rules
    local activeRules = {}
    for rule, enabled in pairs(HealIQ.db.rules) do
        if enabled then
            table.insert(activeRules, rule)
        end
    end
    print("  Active Rules: " .. (#activeRules > 0 and table.concat(activeRules, ", ") or "None"))
    
    -- Show spec info
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    local specName = specIndex and GetSpecializationInfo(specIndex) or "Unknown"
    print("  Class: " .. class)
    print("  Spec: " .. specName)
    print("  In Combat: " .. (InCombatLockdown() and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
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
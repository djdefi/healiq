-- HealIQ Core.lua
-- Main addon initialization, event registration, and saved variables management
--
-- This module handles:
-- * Addon initialization and database setup
-- * Event registration and handling
-- * Session statistics tracking
-- * Error handling and logging
-- * Version upgrade management
-- * Player class/spec validation

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    error("HealIQ Core.lua: Init system not loaded - check TOC loading order")
end

-- Ensure version is set for packaging validation
HealIQ.version = "0.2.3"

-- Best Practice: Prepare for LibStub integration (optional library support)
HealIQ.LibStub = _G.LibStub -- Will be nil if LibStub not available, won't break anything

-- Ace3 Integration - Modern addon framework
local LibStub = _G.LibStub
if LibStub then
    -- Try to load Ace3 libraries (optional - addon works without them)
    local AceAddon = LibStub("AceAddon-3.0", true)
    local AceDB = LibStub("AceDB-3.0", true)
    local AceConfig = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    
    if AceAddon then
        HealIQ.AceAddon = AceAddon:NewAddon("HealIQ", "AceEvent-3.0", "AceConsole-3.0")
        HealIQ.ace = HealIQ.AceAddon -- Alias for easier access
    end
    
    HealIQ.AceDB = AceDB
    HealIQ.AceConfig = AceConfig
    HealIQ.AceConfigDialog = AceConfigDialog
end

-- Best Practice: Enhanced addon metadata for better debugging
HealIQ.addonName = HealIQ.addonName or "HealIQ"
HealIQ.buildInfo = {
    tocVersion = "110107",
    author = "djdefi",
    category = "Healing",
    license = "MIT",
    website = "https://github.com/djdefi/healiq"
}

-- Default settings with profile support
local defaults = {
    -- Global account settings
    global = {
        profiles = {},
        currentProfile = "Default"
    },
    
    -- Profile-specific settings (this is the Default profile)
    profile = {
        enabled = true,
        debug = false, -- Debug mode setting
        specialization = "auto", -- auto, restoration, guardian, feral, balance
        ui = {
            scale = 1.0,
            x = 0,
            y = 0,
            locked = false,
            showIcon = true,
            showSpellName = true,
            showCooldown = true,
            showQueue = true,
            showTargeting = true, -- Show targeting suggestions
            showTargetingIcon = true, -- Show targeting icon overlay
            queueSize = 3,
            queueLayout = "horizontal", -- horizontal or vertical
            queueSpacing = 8,
            queueScale = 0.75, -- Scale of queue icons relative to main icon
            minimapX = 10,
            minimapY = -10,
            minimapAngle = -math.pi/4, -- Default angle for minimap positioning
            showPositionBorder = false, -- Show frame positioning border
        },
        rules = {
            -- Existing rules
            wildGrowth = true,
            clearcasting = true,
            lifebloom = true,
            swiftmend = true,
            rejuvenation = true,

            -- Enhanced rules
            ironbark = true,
            efflorescence = true,
            tranquility = true,
            incarnationTree = true,
            naturesSwiftness = true,
            barkskin = true,
            flourish = true,

            -- New spells from strategy review
            groveGuardians = true,
            wrath = true,
        },
        strategy = {
            -- Healing strategy settings based on Wowhead guide
            prioritizeEfflorescence = true,          -- Keep Efflorescence active frequently
            maintainLifebloomOnTank = true,          -- Always keep Lifebloom on tank
            lifebloomRefreshWindow = 4.5,            -- Refresh Lifebloom in last 4.5s for bloom
            preferClearcastingRegrowth = true,       -- Prioritize Regrowth with Clearcasting
            swiftmendWildGrowthCombo = true,         -- Link Swiftmend and Wild Growth usage
            rejuvenationRampThreshold = 15,          -- Start ramping Rejuv when damage expected in 15s
            avoidRandomRejuvenationDowntime = true,  -- Don't cast random Rejuvs during downtime
            useWrathForMana = true,                  -- Fill downtime with Wrath for mana
            poolGroveGuardians = true,               -- Pool Grove Guardian charges for cooldowns
            emergencyNaturesSwiftness = true,       -- Use Nature's Swiftness for emergency heals

            -- Tunable thresholds
            wildGrowthMinTargets = 1,                -- Minimum targets damaged to suggest Wild Growth (solo-friendly)
            tranquilityMinTargets = 4,               -- Minimum targets damaged to suggest Tranquility
            efflorescenceMinTargets = 2,             -- Minimum targets damaged to suggest Efflorescence
            flourishMinHots = 2,                     -- Minimum expiring HoTs to suggest Flourish
            recentDamageWindow = 3,                  -- Time window to consider "recent damage" (seconds)
            lowHealthThreshold = 0.3,                -- Health percentage to consider "emergency"
            suggestTankRelationships = true,         -- Suggest establishing tank support relationships
        }
    }
}

-- Initialize saved variables with intelligent defaults merging and profile support
-- This function ensures database integrity and handles corruption gracefully
-- @return void
function HealIQ:InitializeDB()
    -- Ensure HealIQDB exists
    if not HealIQDB then
        HealIQDB = {}
    end

    -- Validate HealIQDB structure and handle corruption
    if type(HealIQDB) ~= "table" then
        HealIQDB = {}
        self:Message("HealIQ database was corrupted (type: " .. type(HealIQDB) .. "), resetting to defaults", true)
    end

    -- Initialize profile system with AceDB if available, fallback to manual implementation
    if self.AceDB then
        self.db = self.AceDB:New("HealIQDB", defaults, true)
        self:Print("Profile system initialized using AceDB")
    else
        -- Manual profile implementation
        self:InitializeProfileSystem()
        self:Print("Profile system initialized using fallback implementation")
    end
    
    -- Check for version upgrade and migrate settings if needed
    local currentVersion = self.db and self.db.global and self.db.global.version or HealIQDB.version
    if currentVersion ~= self.version then
        self:OnVersionUpgrade(currentVersion, self.version)
        if self.db and self.db.global then
            self.db.global.version = self.version
        else
            HealIQDB.version = self.version
        end
    end
    
    -- Restore debug state from current profile
    local profileData = self:GetCurrentProfile()
    if profileData and profileData.debug ~= nil then
        self.debug = profileData.debug
    end
    
    self:Print("Database initialized with " .. self:CountSettings() .. " settings")
end

-- Manual profile system implementation (fallback when AceDB not available)
function HealIQ:InitializeProfileSystem()
    -- Ensure global structure exists
    if not HealIQDB.global then
        HealIQDB.global = {
            profiles = {
                Default = {}
            },
            currentProfile = "Default"
        }
    end
    
    -- Ensure profiles table exists
    if not HealIQDB.global.profiles then
        HealIQDB.global.profiles = {
            Default = {}
        }
    end
    
    -- Ensure current profile exists
    local currentProfile = HealIQDB.global.currentProfile or "Default"
    if not HealIQDB.global.profiles[currentProfile] then
        HealIQDB.global.profiles[currentProfile] = {}
    end
    
    -- Merge defaults into current profile
    local profileData = HealIQDB.global.profiles[currentProfile]
    self:MergeDefaults(profileData, defaults.profile)
    
    -- Create db interface that mimics AceDB structure
    self.db = {
        global = HealIQDB.global,
        profile = profileData,
        -- Profile management methods
        GetCurrentProfile = function() return currentProfile end,
        SetProfile = function(name) self:SetProfile(name) end,
        GetProfiles = function() return HealIQDB.global.profiles end
    }
end

-- Merge defaults into existing data
function HealIQ:MergeDefaults(target, defaultValues)
    for key, value in pairs(defaultValues) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                self:MergeDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            self:MergeDefaults(target[key], value)
        end
    end
end

-- Profile Management System
function HealIQ:GetCurrentProfile()
    if self.db and self.db.profile then
        return self.db.profile
    end
    return nil
end

function HealIQ:SetProfile(profileName)
    if not HealIQDB.global or not HealIQDB.global.profiles then
        self:Print("Profile system not initialized")
        return false
    end
    
    if not HealIQDB.global.profiles[profileName] then
        -- Create new profile from defaults
        HealIQDB.global.profiles[profileName] = {}
        self:MergeDefaults(HealIQDB.global.profiles[profileName], defaults.profile)
        self:Print("Created new profile: " .. profileName)
    end
    
    HealIQDB.global.currentProfile = profileName
    
    -- Reinitialize db interface
    if not self.AceDB then
        self:InitializeProfileSystem()
    else
        self.db = self.AceDB:New("HealIQDB", defaults, true)
    end
    
    self:Print("Switched to profile: " .. profileName)
    return true
end

function HealIQ:GetProfiles()
    if HealIQDB.global and HealIQDB.global.profiles then
        local profiles = {}
        for name in pairs(HealIQDB.global.profiles) do
            table.insert(profiles, name)
        end
        return profiles
    end
    return {"Default"}
end

function HealIQ:DeleteProfile(profileName)
    if profileName == "Default" then
        self:Print("Cannot delete Default profile")
        return false
    end
    
    if not HealIQDB.global or not HealIQDB.global.profiles then
        self:Print("Profile system not initialized")
        return false
    end
    
    if not HealIQDB.global.profiles[profileName] then
        self:Print("Profile not found: " .. profileName)
        return false
    end
    
    -- If deleting current profile, switch to Default
    if HealIQDB.global.currentProfile == profileName then
        self:SetProfile("Default")
    end
    
    HealIQDB.global.profiles[profileName] = nil
    self:Print("Deleted profile: " .. profileName)
    return true
end

function HealIQ:ExportProfile(profileName)
    profileName = profileName or HealIQDB.global.currentProfile
    
    if not HealIQDB.global or not HealIQDB.global.profiles[profileName] then
        self:Print("Profile not found: " .. profileName)
        return nil
    end
    
    local profileData = HealIQDB.global.profiles[profileName]
    local exportData = {
        version = self.version,
        profile = profileName,
        data = profileData,
        timestamp = time()
    }
    
    -- Convert to string representation for sharing
    local exportString = self:SerializeTable(exportData)
    self:Print("Profile exported: " .. profileName)
    return exportString
end

function HealIQ:ImportProfile(importString, newProfileName)
    local importData = self:DeserializeTable(importString)
    if not importData or not importData.data then
        self:Print("Invalid profile import data")
        return false
    end
    
    newProfileName = newProfileName or importData.profile or "Imported"
    
    -- Create profile
    if not HealIQDB.global.profiles then
        HealIQDB.global.profiles = {}
    end
    
    HealIQDB.global.profiles[newProfileName] = importData.data
    self:Print("Profile imported: " .. newProfileName)
    return true
end

-- Specialization Detection System
function HealIQ:DetectSpecialization()
    -- Check if WoW API is available
    if not GetSpecialization then
        return "unknown"
    end
    
    local specIndex = GetSpecialization()
    if not specIndex then
        return "unknown"
    end
    
    -- Druid specializations:
    -- 1 = Balance, 2 = Feral, 3 = Guardian, 4 = Restoration
    local specNames = {
        [1] = "balance",
        [2] = "feral",
        [3] = "guardian",
        [4] = "restoration"
    }
    
    return specNames[specIndex] or "unknown"
end

function HealIQ:GetActiveSpecialization()
    local profileData = self:GetCurrentProfile()
    if not profileData then
        return "restoration" -- Safe default
    end
    
    if profileData.specialization == "auto" then
        return self:DetectSpecialization()
    else
        return profileData.specialization
    end
end

function HealIQ:OnSpecializationChanged()
    local newSpec = self:DetectSpecialization()
    local profileData = self:GetCurrentProfile()
    
    if profileData and profileData.specialization == "auto" then
        self:Print("Specialization changed to: " .. newSpec)
        
        -- Update rules based on specialization
        if self.Engine then
            self.Engine:UpdateRulesForSpecialization(newSpec)
        end
        
        -- Update UI visibility if needed
        if newSpec == "restoration" then
            if self.UI and profileData.enabled then
                self.UI:SetEnabled(true)
            end
        else
            -- For non-resto specs, consider hiding UI or showing different suggestions
            if self.UI then
                self.UI:SetEnabled(false)
            end
        end
    end
end

-- Plugin API System
HealIQ.Plugins = {
    registered = {},
    hooks = {},
    enabled = {}
}

function HealIQ:RegisterPlugin(pluginName, pluginData)
    if not pluginName or not pluginData then
        self:Print("Invalid plugin registration")
        return false
    end
    
    if self.Plugins.registered[pluginName] then
        self:Print("Plugin already registered: " .. pluginName)
        return false
    end
    
    -- Validate plugin structure
    if type(pluginData.Initialize) ~= "function" then
        self:Print("Plugin missing Initialize function: " .. pluginName)
        return false
    end
    
    self.Plugins.registered[pluginName] = {
        name = pluginName,
        version = pluginData.version or "1.0.0",
        author = pluginData.author or "Unknown",
        description = pluginData.description or "",
        Initialize = pluginData.Initialize,
        OnEnable = pluginData.OnEnable,
        OnDisable = pluginData.OnDisable,
        GetSuggestions = pluginData.GetSuggestions, -- For rule plugins
        OnEvent = pluginData.OnEvent -- For event handling plugins
    }
    
    self:Print("Plugin registered: " .. pluginName .. " v" .. (pluginData.version or "1.0.0"))
    return true
end

function HealIQ:EnablePlugin(pluginName)
    local plugin = self.Plugins.registered[pluginName]
    if not plugin then
        self:Print("Plugin not found: " .. pluginName)
        return false
    end
    
    if self.Plugins.enabled[pluginName] then
        return true -- Already enabled
    end
    
    local success, err = self:SafeCall(plugin.Initialize, plugin)
    if not success then
        self:Print("Failed to initialize plugin " .. pluginName .. ": " .. (err or "unknown error"))
        return false
    end
    
    if plugin.OnEnable then
        success, err = self:SafeCall(plugin.OnEnable, plugin)
        if not success then
            self:Print("Failed to enable plugin " .. pluginName .. ": " .. (err or "unknown error"))
            return false
        end
    end
    
    self.Plugins.enabled[pluginName] = true
    self:Print("Plugin enabled: " .. pluginName)
    return true
end

function HealIQ:DisablePlugin(pluginName)
    local plugin = self.Plugins.registered[pluginName]
    if not plugin then
        return false
    end
    
    if not self.Plugins.enabled[pluginName] then
        return true -- Already disabled
    end
    
    if plugin.OnDisable then
        self:SafeCall(plugin.OnDisable, plugin)
    end
    
    self.Plugins.enabled[pluginName] = false
    self:Print("Plugin disabled: " .. pluginName)
    return true
end

function HealIQ:GetPluginSuggestions()
    local suggestions = {}
    
    for pluginName, enabled in pairs(self.Plugins.enabled) do
        if enabled then
            local plugin = self.Plugins.registered[pluginName]
            if plugin and plugin.GetSuggestions then
                local success, pluginSuggestions = self:SafeCall(plugin.GetSuggestions, plugin)
                if success and pluginSuggestions then
                    for _, suggestion in ipairs(pluginSuggestions) do
                        table.insert(suggestions, suggestion)
                    end
                end
            end
        end
    end
    
    return suggestions
end

function HealIQ:TriggerPluginHook(hookName, ...)
    if not self.Plugins.hooks[hookName] then
        return
    end
    
    for _, callback in ipairs(self.Plugins.hooks[hookName]) do
        self:SafeCall(callback, ...)
    end
end

function HealIQ:RegisterHook(hookName, callback, pluginName)
    if not self.Plugins.hooks[hookName] then
        self.Plugins.hooks[hookName] = {}
    end
    
    table.insert(self.Plugins.hooks[hookName], callback)
end

-- Serialization helpers for profile import/export
function HealIQ:SerializeTable(tbl)
    -- Simple table serialization for configuration data
    local function serialize(obj, level)
        level = level or 0
        if level > 10 then return "..." end -- Prevent infinite recursion
        
        if type(obj) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(obj) do
                if not first then result = result .. "," end
                first = false
                
                result = result .. "["
                if type(k) == "string" then
                    result = result .. '"' .. k:gsub('"', '\\"') .. '"'
                else
                    result = result .. tostring(k)
                end
                result = result .. "]=" .. serialize(v, level + 1)
            end
            return result .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj:gsub('"', '\\"') .. '"'
        else
            return tostring(obj)
        end
    end
    
    return serialize(tbl)
end

function HealIQ:DeserializeTable(str)
    -- Simple deserialization (security note: only use with trusted data)
    if not str or str == "" then
        return nil
    end
    
    local success, result = pcall(loadstring("return " .. str))
    if success and type(result) == "table" then
        return result
    end
    
    return nil
end

-- Handle version upgrades
function HealIQ:OnVersionUpgrade(oldVersion, newVersion)
    if oldVersion then
        self:Message("HealIQ upgraded from v" .. oldVersion .. " to v" .. newVersion)
    else
        self:Message("HealIQ v" .. newVersion .. " - First time installation")
    end
end

-- Count settings for diagnostics
function HealIQ:CountSettings()
    local count = 0
    local function countTable(t)
        local c = 0
        for k, v in pairs(t) do
            c = c + 1
            if type(v) == "table" then
                c = c + countTable(v)
            end
        end
        return c
    end

    if self.db then
        count = countTable(self.db)
    end

    return count
end

-- Initialize session statistics
function HealIQ:InitializeSessionStats()
    self.sessionStats = {
        startTime = time(),
        suggestions = 0,
        rulesProcessed = 0,
        errorsLogged = 0,
        eventsHandled = 0,
    }
end

-- Debug print function
function HealIQ:Print(message)
    if self.debug then
        print("|cFF00FF00HealIQ:|r " .. tostring(message))
    end
end












function HealIQ:FormatDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, secs)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Enhanced error handling wrapper with comprehensive logging
-- Safely executes functions with detailed error reporting and debugging
-- @param func The function to execute safely
-- @param ... Arguments to pass to the function
-- @return success (boolean), result (any) - success status and function result
function HealIQ:SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        local errorMsg = tostring(result)
        print("|cFFFF0000HealIQ Error:|r " .. errorMsg)
        self:LogError("SafeCall Error: " .. errorMsg)

        -- Enhanced debugging information when debug mode is enabled
        if self.debug then
            print("|cFFFF0000Stack trace:|r " .. debugstack())
            self:DebugLog("Stack trace: " .. debugstack(), "ERROR")
        end

        -- Report to WoW's error system for copyable errors
        -- This ensures errors appear in the default error frame for user reporting
        if self.debug then
            -- Construct a complete error message with context and stack trace
            local completeError = "HealIQ SafeCall Error: " .. errorMsg .. "\n" .. debugstack()
            geterrorhandler()(completeError)
        end

        return false, result
    end
    return true, result
end

-- User message function
function HealIQ:Message(message, isError)
    local prefix = isError and "|cFFFF0000HealIQ Error:|r " or "|cFF00FF00HealIQ:|r "
    print(prefix .. tostring(message))
end

-- Main addon initialization
-- Register Core module with the initialization system
local function initializeCore()
    HealIQ:InitializeDB()
    HealIQ:Message("HealIQ " .. HealIQ.version .. " loaded")

    -- Initialize session statistics
    if HealIQ.Logging then
        HealIQ.Logging:InitializeVariables()
    end
    HealIQ:InitializeSessionStats()

    -- Register for specialization change events
    if HealIQ.ace then
        -- Use Ace3 event system if available
        HealIQ.ace:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
            HealIQ:OnSpecializationChanged()
        end)
    else
        -- Fallback to direct WoW event registration
        local frame = CreateFrame("Frame", "HealIQSpecFrame")
        frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        frame:SetScript("OnEvent", function()
            HealIQ:OnSpecializationChanged()
        end)
    end

    -- Register other core components that depend on Core
    if HealIQ.InitRegistry then
        -- Register core modules
        HealIQ.InitRegistry:RegisterComponent("Performance", function()
            if HealIQ.Performance and HealIQ.Performance.Initialize then
                HealIQ.Performance:Initialize()
                HealIQ:DebugLog("Performance monitoring initialized")
            end
        end, {"Core"})

        HealIQ.InitRegistry:RegisterComponent("Validation", function()
            if HealIQ.Validation and HealIQ.Validation.Initialize then
                HealIQ.Validation:Initialize()
                HealIQ:DebugLog("Validation system initialized")
            end
        end, {"Core"})

        HealIQ.InitRegistry:RegisterComponent("Tracker", function()
            if HealIQ.Tracker and HealIQ.Tracker.Initialize then
                HealIQ.Tracker:Initialize()
                HealIQ:DebugLog("Tracker module initialized")
            end
        end, {"Core"})

        HealIQ.InitRegistry:RegisterComponent("Engine", function()
            if HealIQ.Engine and HealIQ.Engine.Initialize then
                HealIQ.Engine:Initialize()
                HealIQ:DebugLog("Engine module initialized")
            end
        end, {"Core"})

        -- UI module initialization moved to ADDON_LOADED event
        -- This ensures minimap button and options frame are created after WoW UI is ready

        -- Config module initialization moved to ADDON_LOADED event
        -- This ensures slash commands are registered when WoW's system is ready
    end

    HealIQ:Message("HealIQ Core " .. HealIQ.version .. " initialized successfully")
    HealIQ:DebugLog("HealIQ Core initialization completed successfully", "INFO")
end

-- Register with initialization system
if HealIQ.InitRegistry then
    HealIQ.InitRegistry:RegisterComponent("Core", initializeCore, {})
else
    -- Fallback if Init.lua didn't load properly
    HealIQ:DebugLog("Init system not available, using fallback initialization", "WARN")
    HealIQ:SafeCall(initializeCore)
end

-- Event handling for game events (not initialization events)
function HealIQ:OnEvent(event, ...)
    local args = {...}  -- Capture varargs for use in SafeCall
    self:SafeCall(function()
        if self.sessionStats then
            self.sessionStats.eventsHandled = self.sessionStats.eventsHandled + 1
        end
        self:DebugLog("Event received: " .. event)

        if event == "ADDON_LOADED" then
            self:OnAddonLoaded(args[1])  -- args[1] is addonName
        elseif event == "PLAYER_LOGIN" then
            self:OnPlayerLogin()
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:OnPlayerEnteringWorld()
        end
    end)
end

function HealIQ:OnAddonLoaded(addonName)
    self:SafeCall(function()
        -- Only handle our own addon loaded event
        if addonName ~= "HealIQ" then
            return
        end
        
        self:DebugLog("HealIQ addon loaded, initializing slash commands and UI", "INFO")
        
        -- Now it's safe to initialize Config module (slash commands)
        if self.Config and self.Config.Initialize then
            self.Config:Initialize()
            self:DebugLog("Config module initialized on ADDON_LOADED", "INFO")
        end
        
        -- Initialize UI after WoW UI system is ready
        if self.UI and self.UI.Initialize then
            self.UI:Initialize()
            self:DebugLog("UI module initialized on ADDON_LOADED", "INFO")
        end
    end)
end

function HealIQ:OnPlayerLogin()
    self:SafeCall(function()
        self:Print("Player logged in")
        self:DebugLog("Player logged in", "INFO")
    end)
end

-- Validate player class and spec, enable/disable addon accordingly
-- Only enables for Restoration Druids to ensure relevant suggestions
-- @return void
function HealIQ:OnPlayerEnteringWorld()
    self:SafeCall(function()
        self:Print("Player entering world")
        self:DebugLog("Player entering world", "INFO")

        if not self.db then
            self:DebugLog("Database not yet initialized during OnPlayerEnteringWorld", "WARN")
            return
        end

        -- Check if player is a Restoration Druid
        local _, class = UnitClass("player")
        if class == "DRUID" then
            local specIndex = GetSpecialization()
            if specIndex == 4 then -- Restoration spec (index 4 for druids)
                self:Print("Restoration Druid detected")
                self:DebugLog("Restoration Druid detected - enabling addon", "INFO")
                self.db.enabled = true
                self:Message("HealIQ enabled for Restoration Druid")
            else
                self:Print("Not Restoration spec, addon disabled")
                self:DebugLog("Not Restoration spec (spec: " .. (specIndex or "unknown") .. ") - disabling addon", "INFO")
                self.db.enabled = false
                self:Message("HealIQ disabled (not Restoration spec)")
            end
        else
            self:Print("Not a Druid, addon disabled")
            self:DebugLog("Not a Druid (class: " .. (class or "unknown") .. ") - disabling addon", "INFO")
            self.db.enabled = false
            self:Message("HealIQ disabled (not a Druid)")
        end
    end)
end

-- Create event frame for game events (not initialization events)
local function setupEventHandling()
    if not CreateFrame then
        HealIQ:DebugLog("CreateFrame not available, deferring event setup", "WARN")
        return
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        HealIQ:OnEvent(event, ...)
    end)
    
    HealIQ:DebugLog("Event handling setup complete", "INFO")
end

-- Register event setup as a component
if HealIQ.InitRegistry then
    HealIQ.InitRegistry:RegisterComponent("EventHandling", setupEventHandling, {"Core"})
else
    HealIQ:SafeCall(setupEventHandling)
end

-- HealIQ is already globally accessible via Init.lua

-- Cleanup function for addon disable/reload
function HealIQ:Cleanup()
    self:SafeCall(function()
        if self.UI then
            self.UI:Hide()
        end

        if self.Engine then
            -- Stop update loop
            self.Engine:StopUpdateLoop()
        end

        self:Print("HealIQ cleanup completed")
    end)
end
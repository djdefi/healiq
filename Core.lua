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

local addonName, HealIQ = ...

-- Create the main addon object
HealIQ = HealIQ or {}
HealIQ.version = "0.1.14"
HealIQ.debug = false

-- Initialize namespace for rule modules
HealIQ.Rules = HealIQ.Rules or {}

-- Best Practice: Prepare for LibStub integration (optional library support)
HealIQ.LibStub = _G.LibStub -- Will be nil if LibStub not available, won't break anything

-- Best Practice: Enhanced addon metadata for better debugging
HealIQ.addonName = addonName
HealIQ.buildInfo = {
    tocVersion = "110107",
    author = "djdefi",
    category = "Healing",
    license = "MIT",
    website = "https://github.com/djdefi/healiq"
}

-- Default settings
local defaults = {
    enabled = true,
    debug = false, -- Debug mode setting
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

-- Initialize saved variables with intelligent defaults merging
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

    -- Check for version upgrade and migrate settings if needed
    if HealIQDB.version ~= self.version then
        self:OnVersionUpgrade(HealIQDB.version, self.version)
        HealIQDB.version = self.version
    end

    -- Intelligently merge defaults with saved settings
    -- This preserves user customizations while adding new features
    for key, value in pairs(defaults) do
        if HealIQDB[key] == nil then
            if type(value) == "table" then
                HealIQDB[key] = {}
                for subkey, subvalue in pairs(value) do
                    HealIQDB[key][subkey] = subvalue
                end
            else
                HealIQDB[key] = value
            end
        elseif type(value) == "table" and type(HealIQDB[key]) == "table" then
            -- Merge nested tables to preserve existing settings while adding new ones
            for subkey, subvalue in pairs(value) do
                if HealIQDB[key][subkey] == nil then
                    HealIQDB[key][subkey] = subvalue
                end
            end
        end
    end

    self.db = HealIQDB
    
    -- Restore debug state from saved settings
    if self.db.debug ~= nil then
        self.debug = self.db.debug
    end
    
    self:Print("Database initialized with " .. self:CountSettings() .. " settings")
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
-- Initialize rule system after all files have been loaded
-- This ensures rules are properly initialized regardless of file loading order
function HealIQ:InitializeRules()
    self:SafeCall(function()
        self:DebugLog("Initializing rule system...")
        
        -- Verify that rule files loaded successfully
        local ruleFiles = {
            "BaseRule",
            "DefensiveCooldowns",
            "HealingCooldowns",
            "UtilityRules",
            "AoERules",
            "OffensiveRules"
        }
        
        local loadedRules = 0
        local failedRules = {}
        
        for _, ruleName in ipairs(ruleFiles) do
            if self.Rules and self.Rules[ruleName] then
                loadedRules = loadedRules + 1
                self:DebugLog("✓ Rule loaded: " .. ruleName)
            else
                table.insert(failedRules, ruleName)
                self:DebugLog("✗ Rule missing: " .. ruleName, "WARN")
            end
        end
        
        if #failedRules > 0 then
            self:Print("Warning: Some rule files failed to load: " .. table.concat(failedRules, ", "))
            self:DebugLog("Failed rules may cause reduced functionality", "WARN")
        else
            self:DebugLog("All " .. loadedRules .. " rule files loaded successfully")
        end
        
        -- Verify BaseRule is available for other rules
        if self.Rules.BaseRule then
            self:DebugLog("BaseRule methods available for other rules")
        else
            self:Print("Error: BaseRule failed to load - rule functionality may be limited")
        end
    end)
end

function HealIQ:OnInitialize()
    self:SafeCall(function()
        self:InitializeDB()
        self:Print("HealIQ " .. self.version .. " loaded")

        -- Initialize session statistics
        if self.Logging then
            self.Logging:InitializeVariables()
        end
        self:InitializeSessionStats()

        -- Initialize rule system after all files are loaded
        self:InitializeRules()

        -- Initialize new quality modules
        if self.Performance then
            self.Performance:Initialize()
            self:DebugLog("Performance monitoring initialized")
        end

        if self.Validation then
            self.Validation:Initialize()
            self:DebugLog("Validation system initialized")
        end

        -- Initialize modules
        if self.Tracker then
            self.Tracker:Initialize()
            self:DebugLog("Tracker module initialized")
        end

        if self.Engine then
            self.Engine:Initialize()
            self:DebugLog("Engine module initialized")
        end

        if self.UI then
            self.UI:Initialize()
            self:DebugLog("UI module initialized")
        end

        if self.Config then
            self.Config:Initialize()
            self:DebugLog("Config module initialized")
        end

        self:Message("HealIQ " .. self.version .. " initialized successfully")
        self:DebugLog("HealIQ initialization completed successfully", "INFO")
    end)
end

-- Event handling
function HealIQ:OnEvent(event, ...)
    local args = {...}  -- Capture varargs for use in SafeCall
    self:SafeCall(function()
        if self.sessionStats then
            self.sessionStats.eventsHandled = self.sessionStats.eventsHandled + 1
        end
        self:DebugLog("Event received: " .. event)

        if event == "ADDON_LOADED" then
            local loadedAddon = args[1]
            if loadedAddon == addonName then
                self:OnInitialize()
            end
        elseif event == "PLAYER_LOGIN" then
            self:OnPlayerLogin()
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:OnPlayerEnteringWorld()
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

-- Create event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    HealIQ:OnEvent(event, ...)
end)

-- Make HealIQ globally accessible
_G[addonName] = HealIQ

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
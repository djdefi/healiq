-- HealIQ Core.lua
-- Addon initialization, event registration, and saved variables

local addonName, HealIQ = ...

-- Create the main addon object
HealIQ = HealIQ or {}
HealIQ.version = "0.0.9"
HealIQ.debug = false

-- File logging variables
HealIQ.logFile = nil
HealIQ.logPath = nil
HealIQ.logBuffer = nil
HealIQ.logBufferSize = 0 -- Track actual memory usage in bytes
HealIQ.lastFlushTime = 0 -- Track last flush time for interval-based flushing
HealIQ.sessionStats = {
    startTime = nil,
    suggestions = 0,
    rulesProcessed = 0,
    errorsLogged = 0,
    eventsHandled = 0,
}

-- Default settings
local defaults = {
    enabled = true,
    debug = false, -- Debug mode setting
    logging = {
        enabled = false, -- File logging enabled
        verbose = false, -- Verbose file logging
        sessionStats = true, -- Track session statistics
        maxLogSize = 1024, -- Maximum log buffer size in KB
        maxLogFiles = 5, -- Maximum number of log files to keep
        flushInterval = 300, -- Flush to storage every 5 minutes (in seconds)
        flushThreshold = 512, -- Flush when buffer reaches this size in KB
    },
    ui = {
        scale = 1.0,
        x = 0,
        y = 0,
        locked = false,
        showIcon = true,
        showSpellName = true,
        showCooldown = true,
        showQueue = true,
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
        
        -- New rules
        ironbark = true,
        efflorescence = true,
        tranquility = true,
        incarnationTree = true,
        naturesSwiftness = true,
        barkskin = true,
        flourish = true,
        trinket = true,
    }
}

-- Initialize saved variables
function HealIQ:InitializeDB()
    -- Ensure HealIQDB exists
    if not HealIQDB then
        HealIQDB = {}
    end
    
    -- Validate HealIQDB structure
    if type(HealIQDB) ~= "table" then
        HealIQDB = {}
        self:Message("HealIQ database was corrupted (type: " .. type(HealIQDB) .. "), resetting to defaults", true)
    end
    
    -- Check for version upgrade
    if HealIQDB.version ~= self.version then
        self:OnVersionUpgrade(HealIQDB.version, self.version)
        HealIQDB.version = self.version
    end
    
    -- Merge defaults with saved settings
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
            -- Merge nested tables
            for subkey, subvalue in pairs(value) do
                if HealIQDB[key][subkey] == nil then
                    HealIQDB[key][subkey] = subvalue
                end
            end
        end
    end
    
    self.db = HealIQDB
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

-- Debug print function
function HealIQ:Print(message)
    if self.debug then
        print("|cFF00FF00HealIQ:|r " .. tostring(message))
    end
end

-- File logging functions
function HealIQ:InitializeLogging()
    if not self.db.logging.enabled then
        return
    end
    
    -- Create logs directory path
    local logsDir = "Interface\\AddOns\\HealIQ\\logs"
    self.logPath = logsDir .. "\\healiq-debug.log"
    
    -- Initialize log buffer and tracking
    self.logBuffer = {}
    self.logBufferSize = 0
    self.lastFlushTime = time()
    
    -- Initialize session stats
    self.sessionStats.startTime = time()
    self.sessionStats.suggestions = 0
    self.sessionStats.rulesProcessed = 0
    self.sessionStats.errorsLogged = 0
    self.sessionStats.eventsHandled = 0
    
    self:LogToFile("=== HealIQ Debug Session Started ===")
    self:LogToFile("Version: " .. self.version)
    self:LogToFile("Session Start Time: " .. date("%Y-%m-%d %H:%M:%S", self.sessionStats.startTime))
    self:LogToFile("Debug Mode: " .. (self.debug and "Enabled" or "Disabled"))
    self:LogToFile("Verbose Logging: " .. (self.db.logging.verbose and "Enabled" or "Disabled"))
    self:LogToFile("Max Buffer Size: " .. self.db.logging.maxLogSize .. " KB")
    self:LogToFile("Flush Interval: " .. self.db.logging.flushInterval .. " seconds")
    self:LogToFile("Flush Threshold: " .. self.db.logging.flushThreshold .. " KB")
end

function HealIQ:GetLogBufferSizeKB()
    return math.floor(self.logBufferSize / 1024 * 100) / 100 -- Round to 2 decimal places
end

function HealIQ:ShouldFlushLogBuffer()
    local currentTime = time()
    local timeSinceFlush = currentTime - self.lastFlushTime
    local bufferSizeKB = self:GetLogBufferSizeKB()
    
    -- Flush if interval exceeded or size threshold reached
    return timeSinceFlush >= self.db.logging.flushInterval or bufferSizeKB >= self.db.logging.flushThreshold
end

function HealIQ:FlushLogBuffer()
    if not self.logBuffer or #self.logBuffer == 0 then
        return
    end
    
    local bufferSizeKB = self:GetLogBufferSizeKB()
    local entryCount = #self.logBuffer
    
    -- In WoW environment, we simulate flushing by creating a summary
    -- Real implementation would write to actual files here
    local flushSummary = string.format("LOG FLUSH: %d entries, %.2f KB flushed at %s",
        entryCount, bufferSizeKB, date("%H:%M:%S"))
    
    if self.debug then
        print("|cFF888888[FLUSH]|r " .. flushSummary)
    end
    
    -- Clear the buffer after flush
    self.logBuffer = {}
    self.logBufferSize = 0
    self.lastFlushTime = time()
    
    -- Log the flush event itself (this starts a new buffer)
    self:LogToFile("Buffer flushed: " .. entryCount .. " entries, " .. bufferSizeKB .. " KB", "INFO")
end

function HealIQ:TrimLogBuffer()
    if not self.logBuffer then
        return
    end
    
    local maxSizeBytes = self.db.logging.maxLogSize * 1024
    
    -- Remove oldest entries until we're under the size limit
    while self.logBufferSize > maxSizeBytes and #self.logBuffer > 1 do
        local removedEntry = table.remove(self.logBuffer, 1)
        self.logBufferSize = self.logBufferSize - string.len(removedEntry)
    end
    
    -- Ensure we don't go negative due to estimation errors
    if self.logBufferSize < 0 then
        self.logBufferSize = 0
    end
end

function HealIQ:LogToFile(message, level)
    if not self.db.logging.enabled then
        return
    end
    
    level = level or "INFO"
    local timestamp = date("%H:%M:%S")
    local logEntry = string.format("[%s] [%s] %s", timestamp, level, tostring(message))
    
    -- For now, we'll use a simple print with special formatting that can be redirected
    -- In WoW environment, actual file I/O would require different implementation
    if self.debug or self.db.logging.verbose then
        print("|cFF888888[LOG]|r " .. logEntry)
    end
    
    -- Store log entries in memory for diagnostic dump
    if not self.logBuffer then
        self.logBuffer = {}
        self.logBufferSize = 0
    end
    
    table.insert(self.logBuffer, logEntry)
    self.logBufferSize = self.logBufferSize + string.len(logEntry)
    
    -- Check if we should flush the buffer
    if self:ShouldFlushLogBuffer() then
        self:FlushLogBuffer()
    end
    
    -- Trim buffer if it exceeds maximum size
    self:TrimLogBuffer()
end

function HealIQ:LogVerbose(message)
    if self.db.logging.enabled and self.db.logging.verbose then
        self:LogToFile(message, "VERBOSE")
    end
end

function HealIQ:LogError(message)
    self:LogToFile(message, "ERROR")
    self.sessionStats.errorsLogged = self.sessionStats.errorsLogged + 1
end

function HealIQ:GenerateDiagnosticDump()
    local dump = {}
    
    -- Header
    table.insert(dump, "=== HealIQ Diagnostic Dump ===")
    table.insert(dump, "Generated: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(dump, "Version: " .. self.version)
    table.insert(dump, "")
    
    -- Session Statistics
    table.insert(dump, "=== Session Statistics ===")
    if self.sessionStats.startTime then
        local sessionDuration = time() - self.sessionStats.startTime
        table.insert(dump, "Session Duration: " .. self:FormatDuration(sessionDuration))
    end
    table.insert(dump, "Suggestions Generated: " .. self.sessionStats.suggestions)
    table.insert(dump, "Rules Processed: " .. self.sessionStats.rulesProcessed)
    table.insert(dump, "Errors Logged: " .. self.sessionStats.errorsLogged)
    table.insert(dump, "Events Handled: " .. self.sessionStats.eventsHandled)
    table.insert(dump, "")
    
    -- Logging Statistics
    table.insert(dump, "=== Logging Statistics ===")
    table.insert(dump, "Log Buffer Entries: " .. (self.logBuffer and #self.logBuffer or 0))
    table.insert(dump, "Log Buffer Size: " .. self:GetLogBufferSizeKB() .. " KB")
    table.insert(dump, "Max Buffer Size: " .. self.db.logging.maxLogSize .. " KB")
    table.insert(dump, "Flush Threshold: " .. self.db.logging.flushThreshold .. " KB")
    table.insert(dump, "Flush Interval: " .. self.db.logging.flushInterval .. " seconds")
    if self.lastFlushTime and self.lastFlushTime > 0 then
        local timeSinceFlush = time() - self.lastFlushTime
        table.insert(dump, "Last Flush: " .. self:FormatDuration(timeSinceFlush) .. " ago")
    end
    table.insert(dump, "")
    
    -- Configuration
    table.insert(dump, "=== Configuration ===")
    table.insert(dump, "Enabled: " .. tostring(self.db.enabled))
    table.insert(dump, "Debug Mode: " .. tostring(self.debug))
    table.insert(dump, "File Logging: " .. tostring(self.db.logging.enabled))
    table.insert(dump, "Verbose Logging: " .. tostring(self.db.logging.verbose))
    table.insert(dump, "Session Stats: " .. tostring(self.db.logging.sessionStats))
    table.insert(dump, "")
    
    -- UI Configuration
    table.insert(dump, "=== UI Configuration ===")
    table.insert(dump, "Scale: " .. tostring(self.db.ui.scale))
    table.insert(dump, "Position: " .. self.db.ui.x .. ", " .. self.db.ui.y)
    table.insert(dump, "Locked: " .. tostring(self.db.ui.locked))
    table.insert(dump, "Show Queue: " .. tostring(self.db.ui.showQueue))
    table.insert(dump, "Queue Size: " .. tostring(self.db.ui.queueSize))
    table.insert(dump, "Queue Layout: " .. tostring(self.db.ui.queueLayout))
    table.insert(dump, "")
    
    -- Rules Configuration
    table.insert(dump, "=== Rules Configuration ===")
    for rule, enabled in pairs(self.db.rules) do
        table.insert(dump, rule .. ": " .. tostring(enabled))
    end
    table.insert(dump, "")
    
    -- Current State
    table.insert(dump, "=== Current State ===")
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    table.insert(dump, "Class: " .. (class or "Unknown"))
    table.insert(dump, "Specialization: " .. (spec or "Unknown"))
    table.insert(dump, "In Combat: " .. tostring(InCombatLockdown()))
    table.insert(dump, "Memory Usage: " .. string.format("%.2f KB", GetAddOnMemoryUsage("HealIQ")))
    table.insert(dump, "")
    
    -- Recent Log Entries
    if self.logBuffer and #self.logBuffer > 0 then
        table.insert(dump, "=== Recent Log Entries (last " .. math.min(50, #self.logBuffer) .. ") ===")
        local startIdx = math.max(1, #self.logBuffer - 49)
        for i = startIdx, #self.logBuffer do
            table.insert(dump, self.logBuffer[i])
        end
        table.insert(dump, "")
    end
    
    return table.concat(dump, "\n")
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

-- Error handling wrapper
function HealIQ:SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        local errorMsg = tostring(result)
        print("|cFFFF0000HealIQ Error:|r " .. errorMsg)
        self:LogError("SafeCall Error: " .. errorMsg)
        
        if self.debug then
            print("|cFFFF0000Stack trace:|r " .. debugstack())
            self:LogToFile("Stack trace: " .. debugstack(), "ERROR")
        end
        
        -- Also report to WoW's error system for copyable errors
        -- This ensures errors appear in the default error frame
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
function HealIQ:OnInitialize()
    self:SafeCall(function()
        self:InitializeDB()
        self:Print("HealIQ " .. self.version .. " loaded")
        
        -- Initialize logging
        self:InitializeLogging()
        self:LogToFile("HealIQ initialization started", "INFO")
        
        -- Initialize modules
        if self.Tracker then
            self.Tracker:Initialize()
            self:LogVerbose("Tracker module initialized")
        end
        
        if self.Engine then
            self.Engine:Initialize()
            self:LogVerbose("Engine module initialized")
        end
        
        if self.UI then
            self.UI:Initialize()
            self:LogVerbose("UI module initialized")
        end
        
        if self.Config then
            self.Config:Initialize()
            self:LogVerbose("Config module initialized")
        end
        
        self:Message("HealIQ " .. self.version .. " initialized successfully")
        self:LogToFile("HealIQ initialization completed successfully", "INFO")
    end)
end

-- Event handling
function HealIQ:OnEvent(event, ...)
    local args = {...}  -- Capture varargs for use in SafeCall
    self:SafeCall(function()
        self.sessionStats.eventsHandled = self.sessionStats.eventsHandled + 1
        self:LogVerbose("Event received: " .. event)
        
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
        self:LogToFile("Player logged in", "INFO")
    end)
end

function HealIQ:OnPlayerEnteringWorld()
    self:SafeCall(function()
        self:Print("Player entering world")
        self:LogToFile("Player entering world", "INFO")
        
        -- Check if player is a Restoration Druid
        local _, class = UnitClass("player")
        if class == "DRUID" then
            local specIndex = GetSpecialization()
            if specIndex == 4 then -- Restoration spec
                self:Print("Restoration Druid detected")
                self:LogToFile("Restoration Druid detected - enabling addon", "INFO")
                self.db.enabled = true
                self:Message("HealIQ enabled for Restoration Druid")
            else
                self:Print("Not Restoration spec, addon disabled")
                self:LogToFile("Not Restoration spec (spec: " .. (specIndex or "unknown") .. ") - disabling addon", "INFO")
                self.db.enabled = false
                self:Message("HealIQ disabled (not Restoration spec)")
            end
        else
            self:Print("Not a Druid, addon disabled")
            self:LogToFile("Not a Druid (class: " .. (class or "unknown") .. ") - disabling addon", "INFO")
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
        -- Flush any remaining log entries before cleanup
        if self.db and self.db.logging and self.db.logging.enabled then
            self:FlushLogBuffer()
        end
        
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
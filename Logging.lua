-- HealIQ Logging.lua
-- File logging, session statistics, and diagnostic functionality

local addonName, HealIQ = ...

-- Create the Logging module
HealIQ.Logging = {}
local Logging = HealIQ.Logging

-- Initialize logging-related variables on HealIQ object
function Logging:InitializeVariables()
    -- Initialize logging variables if they don't exist
    HealIQ.logFile = HealIQ.logFile or nil
    HealIQ.logPath = HealIQ.logPath or nil
    HealIQ.logBuffer = HealIQ.logBuffer or nil
    HealIQ.logBufferSize = HealIQ.logBufferSize or 0
    HealIQ.lastFlushTime = HealIQ.lastFlushTime or 0
    
    -- Initialize session stats if they don't exist
    HealIQ.sessionStats = HealIQ.sessionStats or {
        startTime = nil,
        suggestions = 0,
        rulesProcessed = 0,
        errorsLogged = 0,
        eventsHandled = 0,
    }
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
    if self.db.logging.sessionStats then
        self.sessionStats.startTime = time()
    end
    
    -- Log session initialization
    self:LogToFile("=== HealIQ Session Started ===", "INFO")
    self:LogToFile("Version: " .. self.version, "INFO")
    self:LogToFile("File Logging: " .. (self.db.logging.enabled and "Enabled" or "Disabled"), "INFO")
    self:LogToFile("Verbose Logging: " .. (self.db.logging.verbose and "Enabled" or "Disabled"))
    self:LogToFile("Max Buffer Size: " .. self.db.logging.maxLogSize .. " KB")
    self:LogToFile("Flush Interval: " .. self.db.logging.flushInterval .. " seconds")
    self:LogToFile("Flush Threshold: " .. self.db.logging.flushThreshold .. " KB")
end

function HealIQ:GetLogBufferSizeKB()
    return math.floor(self.logBufferSize / 1024 * 100) / 100 -- Round to 2 decimal places
end

function HealIQ:ShouldFlushLogBuffer()
    if not self.logBuffer or #self.logBuffer == 0 then
        return false
    end
    local timeSinceFlush = time() - self.lastFlushTime
    local bufferSizeKB = self:GetLogBufferSizeKB()
    return timeSinceFlush >= self.db.logging.flushInterval or bufferSizeKB >= self.db.logging.flushThreshold
end

function HealIQ:FlushLogBuffer()
    if not self.logBuffer or #self.logBuffer == 0 then
        return
    end
    
    local entryCount = #self.logBuffer
    local bufferSizeKB = self:GetLogBufferSizeKB()
    
    -- In WoW environment, we simulate flushing by creating a summary
    -- Real implementation would write to actual files here
    local flushSummary = string.format("LOG FLUSH: %d entries, %.2f KB flushed at %s",
        entryCount, bufferSizeKB, date("%H:%M:%S"))
    
    if self.debug then
        print("|cFF888888[FLUSH]|r " .. flushSummary)
    end
    
    -- Reset buffer and tracking
    self.logBuffer = {}
    self.logBufferSize = 0
    self.lastFlushTime = time()
    
    -- Log the flush operation
    self:LogToFile(flushSummary, "INFO")
end

function HealIQ:TrimLogBuffer()
    if not self.logBuffer then
        return
    end
    
    local maxSizeBytes = self.db.logging.maxLogSize * 1024
    
    -- Remove oldest entries until we're under the limit
    while self.logBufferSize > maxSizeBytes and #self.logBuffer > 0 do
        local removedEntry = table.remove(self.logBuffer, 1)
        self.logBufferSize = self.logBufferSize - string.len(removedEntry)
    end
    
    -- Additional size validation for single oversized entry
    if self.logBufferSize > maxSizeBytes and #self.logBuffer == 1 then
        self.logBuffer = {}
        self.logBufferSize = 0
    end
    
    -- Safety check to prevent negative buffer size
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
    
    -- Print to chat if debug mode or verbose logging is enabled
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
    
    -- Trim buffer if it's getting too large
    self:TrimLogBuffer()
    
    -- Check if we should flush the buffer
    if self:ShouldFlushLogBuffer() then
        self:FlushLogBuffer()
    end
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
    
    -- Recent log entries
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


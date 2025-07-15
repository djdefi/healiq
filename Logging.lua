-- HealIQ Logging.lua
-- Session statistics and diagnostic functionality

local addonName, HealIQ = ...

-- Create the Logging module
HealIQ.Logging = {}
local Logging = HealIQ.Logging

-- Initialize logging-related variables on HealIQ object
function Logging:InitializeVariables()
    -- Initialize session stats if they don't exist
    HealIQ.sessionStats = HealIQ.sessionStats or {
        startTime = nil,
        suggestions = 0,
        rulesProcessed = 0,
        errorsLogged = 0,
        eventsHandled = 0,
        ruleTriggers = {}, -- Track individual rule trigger counts
    }
end

-- Initialize session statistics
function HealIQ:InitializeSessionStats()
    if self.sessionStats then
        self.sessionStats.startTime = time()
    end
end

-- Debug logging function - prints to chat in real-time when debug mode is enabled
function HealIQ:DebugLog(message, level)
    if not self.debug then
        return
    end
    
    level = level or "DEBUG"
    local timestamp = date("%H:%M:%S")
    local logEntry = string.format("[%s] [%s] %s", timestamp, level, tostring(message))
    
    -- Print to chat with color coding
    local color = "|cFF888888"
    if level == "ERROR" then
        color = "|cFFFF0000"
    elseif level == "WARN" then
        color = "|cFFFFFF00"
    elseif level == "INFO" then
        color = "|cFF00FF00"
    end
    
    print(color .. "[HealIQ] " .. logEntry .. "|r")
end

function HealIQ:LogError(message)
    self:DebugLog(message, "ERROR")
    if self.sessionStats then
        self.sessionStats.errorsLogged = self.sessionStats.errorsLogged + 1
    end
end

-- Track rule triggers
function HealIQ:LogRuleTrigger(ruleName)
    if self.sessionStats and self.sessionStats.ruleTriggers then
        self.sessionStats.ruleTriggers[ruleName] = (self.sessionStats.ruleTriggers[ruleName] or 0) + 1
        self.sessionStats.rulesProcessed = self.sessionStats.rulesProcessed + 1
    end
end

-- Track suggestions made
function HealIQ:LogSuggestionMade()
    if self.sessionStats then
        self.sessionStats.suggestions = self.sessionStats.suggestions + 1
    end
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
    if self.sessionStats then
        if self.sessionStats.startTime then
            local sessionDuration = time() - self.sessionStats.startTime
            table.insert(dump, "Session Duration: " .. self:FormatDuration(sessionDuration))
        end
        table.insert(dump, "Suggestions Generated: " .. self.sessionStats.suggestions)
        table.insert(dump, "Rules Processed: " .. self.sessionStats.rulesProcessed)
        table.insert(dump, "Errors Logged: " .. self.sessionStats.errorsLogged)
        table.insert(dump, "Events Handled: " .. self.sessionStats.eventsHandled)
        
        -- Rule trigger counts
        if self.sessionStats.ruleTriggers and next(self.sessionStats.ruleTriggers) then
            table.insert(dump, "")
            table.insert(dump, "Rule Trigger Counts:")
            local sortedRules = {}
            for ruleName, count in pairs(self.sessionStats.ruleTriggers) do
                table.insert(sortedRules, {name = ruleName, count = count})
            end
            table.sort(sortedRules, function(a, b) return a.count > b.count end)
            for _, rule in ipairs(sortedRules) do
                table.insert(dump, "  " .. rule.name .. ": " .. rule.count)
            end
        else
            table.insert(dump, "")
            table.insert(dump, "Rule Trigger Counts: None yet")
        end
    else
        table.insert(dump, "Session statistics not yet initialized")
    end
    table.insert(dump, "")
    
    -- Configuration
    table.insert(dump, "=== Configuration ===")
    if self.db then
        table.insert(dump, "Enabled: " .. tostring(self.db.enabled))
        table.insert(dump, "Debug Mode: " .. tostring(self.debug))
    else
        table.insert(dump, "Database not yet initialized")
    end
    table.insert(dump, "")
    
    -- UI Configuration
    table.insert(dump, "=== UI Configuration ===")
    if self.db and self.db.ui then
        table.insert(dump, "Scale: " .. tostring(self.db.ui.scale))
        table.insert(dump, "Position: " .. self.db.ui.x .. ", " .. self.db.ui.y)
        table.insert(dump, "Locked: " .. tostring(self.db.ui.locked))
        table.insert(dump, "Show Queue: " .. tostring(self.db.ui.showQueue))
        table.insert(dump, "Queue Size: " .. tostring(self.db.ui.queueSize))
        table.insert(dump, "Queue Layout: " .. tostring(self.db.ui.queueLayout))
    else
        table.insert(dump, "UI configuration not yet initialized")
    end
    table.insert(dump, "")
    
    -- Rules Configuration
    table.insert(dump, "=== Rules Configuration ===")
    if self.db and self.db.rules then
        for rule, enabled in pairs(self.db.rules) do
            table.insert(dump, rule .. ": " .. tostring(enabled))
        end
    else
        table.insert(dump, "Rules configuration not yet initialized")
    end
    table.insert(dump, "")
    
    -- Current State
    table.insert(dump, "=== Current State ===")
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    table.insert(dump, "Class: " .. (class or "Unknown"))
    table.insert(dump, "Specialization: " .. (spec or "Unknown"))
    table.insert(dump, "In Combat: " .. tostring(InCombatLockdown()))
    table.insert(dump, "")
    
    return table.concat(dump, "\n")
end


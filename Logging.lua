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
        self.sessionStats.rulesProcessed = (self.sessionStats.rulesProcessed or 0) + 1
    end
end

-- Track suggestions made
function HealIQ:LogSuggestionMade()
    if self.sessionStats then
        self.sessionStats.suggestions = (self.sessionStats.suggestions or 0) + 1
    end
end

function HealIQ:GenerateDiagnosticDump()
    local dump = {}

    -- Header
    table.insert(dump, "=== HealIQ Diagnostic Dump ===")
    table.insert(dump, "Generated: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(dump, "Version: " .. self.version)
    table.insert(dump, "")

    -- Session Statistics with Enhanced Analysis
    table.insert(dump, "=== Session Statistics ===")
    if self.sessionStats then
        local sessionDuration = 0
        if self.sessionStats.startTime then
            sessionDuration = time() - self.sessionStats.startTime
            table.insert(dump, "Session Duration: " .. self:FormatDuration(sessionDuration))
        end
        table.insert(dump, "Suggestions Generated: " .. (self.sessionStats.suggestions or 0))
        table.insert(dump, "Rules Processed: " .. (self.sessionStats.rulesProcessed or 0))
        table.insert(dump, "Errors Logged: " .. (self.sessionStats.errorsLogged or 0))
        table.insert(dump, "Events Handled: " .. (self.sessionStats.eventsHandled or 0))

        -- Performance Analysis
        if sessionDuration > 0 and self.sessionStats.suggestions then
            local suggestionsPerMinute = (self.sessionStats.suggestions * 60) / sessionDuration
            local rulesPerMinute = (self.sessionStats.rulesProcessed * 60) / sessionDuration
            table.insert(dump, "")
            table.insert(dump, "=== Performance Analysis ===")
            table.insert(dump, "Suggestions per Minute: " .. string.format("%.1f", suggestionsPerMinute))
            table.insert(dump, "Rules Processed per Minute: " .. string.format("%.1f", rulesPerMinute))
            if self.sessionStats.rulesProcessed > 0 then
                local efficiency = (self.sessionStats.suggestions / self.sessionStats.rulesProcessed) * 100
                table.insert(dump, "Suggestion Efficiency: " .. string.format("%.1f%%", efficiency))
            end
        end

        -- Rule trigger counts with analysis
        if self.sessionStats.ruleTriggers and next(self.sessionStats.ruleTriggers) then
            table.insert(dump, "")
            table.insert(dump, "=== Rule Trigger Analysis ===")
            local sortedRules = {}
            local totalTriggers = 0
            for ruleName, count in pairs(self.sessionStats.ruleTriggers) do
                table.insert(sortedRules, {name = ruleName, count = count})
                totalTriggers = totalTriggers + count
            end
            table.sort(sortedRules, function(a, b) return a.count > b.count end)

            table.insert(dump, "Most Active Rules:")
            for i, rule in ipairs(sortedRules) do
                local percentage = (rule.count / totalTriggers) * 100
                table.insert(dump, string.format("  %d. %s: %d (%.1f%%)", i, rule.name, rule.count, percentage))
                if i >= 5 then break end -- Top 5 only
            end

            -- Rule frequency recommendations
            table.insert(dump, "")
            table.insert(dump, "=== Strategy Recommendations ===")
            for _, rule in ipairs(sortedRules) do
                local percentage = (rule.count / totalTriggers) * 100
                if percentage > 50 then
                    table.insert(dump, "• " .. rule.name .. " is very active (" .. string.format("%.1f%%", percentage) .. ") - consider if this is optimal")
                elseif percentage < 5 and rule.count > 0 then
                    table.insert(dump, "• " .. rule.name .. " rarely triggers (" .. string.format("%.1f%%", percentage) .. ") - consider rule adjustments")
                end
            end
        else
            table.insert(dump, "")
            table.insert(dump, "Rule Trigger Counts: None yet")
        end
    else
        table.insert(dump, "Session statistics not yet initialized")
    end
    table.insert(dump, "")

    -- Configuration with Strategy Analysis
    table.insert(dump, "=== Configuration ===")
    if self.db then
        table.insert(dump, "Enabled: " .. tostring(self.db.enabled))
        table.insert(dump, "Debug Mode: " .. tostring(self.debug))
    else
        table.insert(dump, "Database not yet initialized")
    end
    table.insert(dump, "")

    -- Enhanced Strategy Configuration Analysis
    table.insert(dump, "=== Strategy Configuration Analysis ===")
    if self.db and self.db.strategy then
        -- Group analysis settings
        local groupType = "Unknown"
        local groupSize = GetNumGroupMembers()
        if groupSize <= 1 then
            groupType = "Solo"
        elseif groupSize <= 5 then
            groupType = "Small Group (5-man)"
        elseif groupSize <= 10 then
            groupType = "Medium Group (10-man)"
        else
            groupType = "Large Group (Raid)"
        end

        table.insert(dump, "Detected Group Type: " .. groupType .. " (" .. groupSize .. " members)")
        table.insert(dump, "")

        -- Key thresholds with recommendations
        table.insert(dump, "Key Thresholds:")
        local wildGrowthMin = self.db.strategy.wildGrowthMinTargets or 1
        table.insert(dump, "  Wild Growth Min Targets: " .. wildGrowthMin)
        if groupType == "Solo" and wildGrowthMin > 0 then
            table.insert(dump, "    → Recommendation: Set to 0 for solo content")
        elseif groupType == "Small Group (5-man)" and wildGrowthMin > 2 then
            table.insert(dump, "    → Recommendation: Consider 1-2 for 5-man content")
        elseif groupType == "Large Group (Raid)" and wildGrowthMin < 3 then
            table.insert(dump, "    → Recommendation: Consider 3+ for raid content")
        end

        local tranqMin = self.db.strategy.tranquilityMinTargets or 4
        table.insert(dump, "  Tranquility Min Targets: " .. tranqMin)
        if groupType == "Small Group (5-man)" and tranqMin > 3 then
            table.insert(dump, "    → Recommendation: Consider 2-3 for 5-man content")
        end

        local effloMin = self.db.strategy.efflorescenceMinTargets or 2
        table.insert(dump, "  Efflorescence Min Targets: " .. effloMin)

        local lowHealthThresh = self.db.strategy.lowHealthThreshold or 0.3
        table.insert(dump, "  Low Health Threshold: " .. string.format("%.0f%%", lowHealthThresh * 100))

        table.insert(dump, "")
        table.insert(dump, "Strategy Toggles:")
        local strategies = {
            {"prioritizeEfflorescence", "Prioritize Efflorescence"},
            {"maintainLifebloomOnTank", "Maintain Lifebloom on Tank"},
            {"preferClearcastingRegrowth", "Prefer Clearcasting Regrowth"},
            {"swiftmendWildGrowthCombo", "Swiftmend + Wild Growth Combo"},
            {"useWrathForMana", "Use Wrath for Mana"},
            {"poolGroveGuardians", "Pool Grove Guardians"},
            {"emergencyNaturesSwiftness", "Emergency Nature's Swiftness"}
        }

        for _, strategy in ipairs(strategies) do
            local key, name = strategy[1], strategy[2]
            local enabled = self.db.strategy[key]
            if enabled ~= nil then
                table.insert(dump, "  " .. name .. ": " .. tostring(enabled))
            end
        end
    else
        table.insert(dump, "Strategy configuration not yet initialized")
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
        local enabledRules = {}
        local disabledRules = {}
        for rule, enabled in pairs(self.db.rules) do
            if enabled then
                table.insert(enabledRules, rule)
            else
                table.insert(disabledRules, rule)
            end
        end

        table.sort(enabledRules)
        table.sort(disabledRules)

        table.insert(dump, "Enabled Rules (" .. #enabledRules .. "):")
        for _, rule in ipairs(enabledRules) do
            table.insert(dump, "  " .. rule)
        end

        if #disabledRules > 0 then
            table.insert(dump, "")
            table.insert(dump, "Disabled Rules (" .. #disabledRules .. "):")
            for _, rule in ipairs(disabledRules) do
                table.insert(dump, "  " .. rule)
            end
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

    -- Debugging Tips
    table.insert(dump, "=== Debugging Tips ===")
    table.insert(dump, "• Use '/healiq debug' to toggle real-time debug output")
    table.insert(dump, "• Use '/healiq test' to generate sample suggestions")
    table.insert(dump, "• Monitor rule trigger frequencies to optimize strategy")
    table.insert(dump, "• Adjust min target thresholds based on group size")
    table.insert(dump, "• Check suggestion efficiency for performance insights")
    table.insert(dump, "")

    -- Export Instructions
    table.insert(dump, "=== Export Instructions ===")
    table.insert(dump, "• Click in this text area to select all content")
    table.insert(dump, "• Use Ctrl+C (Cmd+C on Mac) to copy to clipboard")
    table.insert(dump, "• Paste into any text editor, spreadsheet, or document")
    table.insert(dump, "• Data includes all session metrics and configuration")
    table.insert(dump, "• Use the Refresh button above to get latest data")
    table.insert(dump, "")

    return table.concat(dump, "\n")
end


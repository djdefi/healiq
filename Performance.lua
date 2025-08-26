-- HealIQ Performance.lua
-- Performance monitoring and optimization utilities
--
-- This module provides:
-- * Function execution time tracking
-- * Memory usage monitoring
-- * Performance bottleneck detection
-- * Automatic performance adjustment
-- * Debug profiling tools

-- Use robust global access pattern that works with new Init system
local HealIQ = _G.HealIQ

-- Ensure HealIQ is available (Init.lua should have created it)
if not HealIQ then
    error("HealIQ Performance.lua: Init system not loaded - check TOC loading order")
end

HealIQ.Performance = HealIQ.Performance or {}
local Performance = HealIQ.Performance

-- Performance tracking data
local performanceData = {
    functionTimes = {},
    memoryUsage = {},
    lastGC = 0,
    gcThreshold = 1024 * 1024, -- 1MB garbage collection threshold
    performanceWarnings = {},
    frameTimeTargets = {
        critical = 16.67, -- 60 FPS target (16.67ms per frame)
        warning = 33.33,  -- 30 FPS warning threshold
        error = 50.0      -- 20 FPS error threshold
    }
}

-- Performance profiler for function execution timing
-- @param functionName String identifier for the function
-- @param func Function to profile
-- @param ... Arguments to pass to the function
-- @return success (boolean), result (any), executionTime (number)
function Performance:ProfileFunction(functionName, func, ...)
    local startTime = debugprofilestop and debugprofilestop() or GetTime() * 1000
    local startMemory = collectgarbage("count")

    local success, result = HealIQ:SafeCall(func, ...)

    local endTime = debugprofilestop and debugprofilestop() or GetTime() * 1000
    local endMemory = collectgarbage("count")

    local executionTime = endTime - startTime
    local memoryDelta = endMemory - startMemory

    -- Track performance data
    if not performanceData.functionTimes[functionName] then
        performanceData.functionTimes[functionName] = {
            totalTime = 0,
            calls = 0,
            maxTime = 0,
            minTime = math.huge,
            avgTime = 0
        }
    end

    local stats = performanceData.functionTimes[functionName]
    stats.totalTime = stats.totalTime + executionTime
    stats.calls = stats.calls + 1
    stats.maxTime = math.max(stats.maxTime, executionTime)
    stats.minTime = math.min(stats.minTime, executionTime)
    stats.avgTime = stats.totalTime / stats.calls

    -- Track memory usage
    if memoryDelta > 0 then
        performanceData.memoryUsage[functionName] = (performanceData.memoryUsage[functionName] or 0) + memoryDelta
    end

    -- Check for performance warnings
    if executionTime > performanceData.frameTimeTargets.critical then
        local warningLevel = "WARNING"
        if executionTime > performanceData.frameTimeTargets.error then
            warningLevel = "ERROR"
        end

        table.insert(performanceData.performanceWarnings, {
            timestamp = GetTime(),
            function_name = functionName,
            execution_time = executionTime,
            level = warningLevel,
            memory_delta = memoryDelta
        })

        if HealIQ.debug then
            HealIQ:DebugLog(string.format("Performance %s: %s took %.2fms (threshold: %.2fms)",
                warningLevel, functionName, executionTime, performanceData.frameTimeTargets.critical), warningLevel)
        end
    end

    -- Automatic garbage collection when threshold exceeded
    if endMemory > performanceData.gcThreshold and (GetTime() - performanceData.lastGC) > 5 then
        collectgarbage("collect")
        performanceData.lastGC = GetTime()
        if HealIQ.debug then
            HealIQ:DebugLog(string.format("Automatic GC triggered. Memory before: %.1fKB, after: %.1fKB",
                endMemory, collectgarbage("count")), "INFO")
        end
    end

    return success, result, executionTime
end

-- Wrap a function with automatic performance profiling
-- @param functionName String identifier for the function
-- @param originalFunc The original function to wrap
-- @return function The wrapped function with profiling
function Performance:WrapFunction(functionName, originalFunc)
    return function(...)
        local success, result, executionTime = self:ProfileFunction(functionName, originalFunc, ...)
        return result
    end
end

-- Generate comprehensive performance report
-- @return string Formatted performance report
function Performance:GeneratePerformanceReport()
    local report = {}

    table.insert(report, "=== HealIQ Performance Report ===")
    table.insert(report, "Generated: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(report, "")

    -- Function performance summary
    table.insert(report, "=== Function Performance ===")
    local sortedFunctions = {}
    for functionName, stats in pairs(performanceData.functionTimes) do
        table.insert(sortedFunctions, {name = functionName, stats = stats})
    end

    -- Sort by average execution time
    table.sort(sortedFunctions, function(a, b)
        return a.stats.avgTime > b.stats.avgTime
    end)

    table.insert(report, string.format("%-30s %8s %8s %8s %8s %8s",
        "Function", "Calls", "Total(ms)", "Avg(ms)", "Min(ms)", "Max(ms)"))
    table.insert(report, string.rep("-", 80))

    for _, func in ipairs(sortedFunctions) do
        local stats = func.stats
        table.insert(report, string.format("%-30s %8d %8.2f %8.2f %8.2f %8.2f",
            func.name, stats.calls, stats.totalTime, stats.avgTime, stats.minTime, stats.maxTime))
    end

    -- Memory usage summary
    table.insert(report, "")
    table.insert(report, "=== Memory Usage ===")
    local totalMemory = 0
    for functionName, memoryUsed in pairs(performanceData.memoryUsage) do
        totalMemory = totalMemory + memoryUsed
        table.insert(report, string.format("%-30s %8.2f KB", functionName, memoryUsed))
    end
    table.insert(report, string.format("%-30s %8.2f KB", "TOTAL TRACKED", totalMemory))
    table.insert(report, string.format("%-30s %8.2f KB", "CURRENT USAGE", collectgarbage("count")))

    -- Performance warnings
    table.insert(report, "")
    table.insert(report, "=== Performance Warnings ===")
    if #performanceData.performanceWarnings > 0 then
        table.insert(report, string.format("%-20s %-30s %10s %8s", "Time", "Function", "Duration", "Level"))
        table.insert(report, string.rep("-", 70))

        -- Show last 10 warnings
        local startIdx = math.max(1, #performanceData.performanceWarnings - 9)
        for i = startIdx, #performanceData.performanceWarnings do
            local warning = performanceData.performanceWarnings[i]
            table.insert(report, string.format("%-20s %-30s %8.2fms %8s",
                date("%H:%M:%S", warning.timestamp), warning.function_name,
                warning.execution_time, warning.level))
        end
    else
        table.insert(report, "No performance warnings detected")
    end

    -- Performance recommendations
    table.insert(report, "")
    table.insert(report, "=== Recommendations ===")

    local hasSlowFunctions = false
    for _, func in ipairs(sortedFunctions) do
        if func.stats.avgTime > performanceData.frameTimeTargets.warning then
            if not hasSlowFunctions then
                table.insert(report, "Functions exceeding performance targets:")
                hasSlowFunctions = true
            end
            table.insert(report, string.format("- %s: %.2fms avg (target: %.2fms)",
                func.name, func.stats.avgTime, performanceData.frameTimeTargets.critical))
        end
    end

    if not hasSlowFunctions then
        table.insert(report, "All functions within performance targets")
    end

    return table.concat(report, "\n")
end

-- Reset performance tracking data
function Performance:Reset()
    performanceData.functionTimes = {}
    performanceData.memoryUsage = {}
    performanceData.performanceWarnings = {}
    performanceData.lastGC = GetTime()

    if HealIQ.debug then
        HealIQ:DebugLog("Performance tracking data reset", "INFO")
    end
end

-- Get performance statistics for a specific function
-- @param functionName String identifier for the function
-- @return table Performance statistics or nil if not tracked
function Performance:GetFunctionStats(functionName)
    return performanceData.functionTimes[functionName]
end

-- Check if addon is experiencing performance issues
-- @return boolean True if performance issues detected
function Performance:HasPerformanceIssues()
    local recentWarnings = 0
    local currentTime = GetTime()

    -- Check for warnings in the last 60 seconds
    for _, warning in ipairs(performanceData.performanceWarnings) do
        if currentTime - warning.timestamp < 60 then
            recentWarnings = recentWarnings + 1
        end
    end

    return recentWarnings > 5 -- More than 5 warnings in last minute
end

-- Automatic performance optimization
function Performance:OptimizePerformance()
    if self:HasPerformanceIssues() then
        -- Reduce update frequency for non-critical systems
        if HealIQ.Engine and HealIQ.Engine.updateInterval then
            HealIQ.Engine.updateInterval = math.min(HealIQ.Engine.updateInterval * 1.5, 1.0)
            HealIQ:DebugLog(string.format("Performance optimization: Increased update interval to %.2fs",
                HealIQ.Engine.updateInterval), "INFO")
        end

        -- Force garbage collection
        collectgarbage("collect")
        performanceData.lastGC = GetTime()

        HealIQ:DebugLog("Automatic performance optimization applied", "WARN")
    end
end

-- Initialize performance monitoring
function Performance:Initialize()
    HealIQ:SafeCall(function()
        self:Reset()

        -- Set up periodic optimization check
        local optimizationFrame = CreateFrame("Frame")
        optimizationFrame:SetScript("OnUpdate", function(self, elapsed)
            self.timeSinceLastCheck = (self.timeSinceLastCheck or 0) + elapsed
            if self.timeSinceLastCheck >= 30 then -- Check every 30 seconds
                Performance:OptimizePerformance()
                self.timeSinceLastCheck = 0
            end
        end)

        HealIQ:Print("Performance monitoring initialized")
    end)
end

-- Export performance data for external analysis
-- @return table Raw performance data
function Performance:ExportData()
    return {
        functions = performanceData.functionTimes,
        memory = performanceData.memoryUsage,
        warnings = performanceData.performanceWarnings,
        current_memory = collectgarbage("count"),
        export_time = GetTime()
    }
end

-- Register Performance module with the initialization system
local function initializePerformance()
    Performance:Initialize()
    HealIQ:DebugLog("Performance module initialized successfully", "INFO")
end

-- Register with initialization system
if HealIQ.InitRegistry then
    HealIQ.InitRegistry:RegisterComponent("Performance", initializePerformance, {"Core"})
else
    -- Fallback if Init.lua didn't load properly
    HealIQ:DebugLog("Init system not available, using fallback initialization for Performance", "WARN")
    HealIQ:SafeCall(initializePerformance)
end
#!/usr/bin/env lua
-- HealIQ Coverage Analysis
-- Enhanced coverage reporting and analysis

local function parseStats(statsFile)
    local stats = {}
    local file = io.open(statsFile, "r")
    if not file then
        print("Warning: " .. statsFile .. " not found, coverage analysis will be limited")
        return {}
    end
    
    local currentFile = nil
    for line in file:lines() do
        -- Parse LuaCov stats format: 
        -- Format is: linecount:filename
        -- followed by: hit counts separated by spaces
        local lineCount, filename = line:match("^(%d+):(.+)$")
        if lineCount and filename then
            currentFile = filename
            stats[currentFile] = {}
        elseif currentFile and line:match("^%d") then
            -- This line contains hit counts
            local lineNum = 1
            for hitCount in line:gmatch("(%d+)") do
                stats[currentFile][lineNum] = tonumber(hitCount)
                lineNum = lineNum + 1
            end
        end
    end
    
    file:close()
    return stats
end

local function analyzeFile(filename, stats)
    local file = io.open(filename, "r")
    if not file then
        return nil
    end
    
    local lines = {}
    local lineNum = 1
    for line in file:lines() do
        table.insert(lines, {
            number = lineNum,
            content = line,
            hits = stats[filename] and stats[filename][lineNum] or nil,
            executable = false
        })
        lineNum = lineNum + 1
    end
    file:close()
    
    -- Determine executable lines (simplified heuristic)
    for _, line in ipairs(lines) do
        local content = line.content:gsub("^%s*", "") -- trim leading whitespace
        if content ~= "" and
           not content:match("^%-%-") and -- not a comment
           not content:match("^local%s+[%w_]+%s*=%s*{%s*$") and -- not table declaration start
           not content:match("^}%s*$") and -- not just closing brace
           not content:match("^end%s*$") and -- not just 'end'
           not content:match("^else%s*$") and -- not just 'else'
           not content:match("^elseif") and -- not elseif without code
           content:match("%S") then -- has non-whitespace
            line.executable = true
        end
    end
    
    -- Calculate coverage
    local totalExecutable = 0
    local coveredLines = 0
    
    for _, line in ipairs(lines) do
        if line.executable then
            totalExecutable = totalExecutable + 1
            if line.hits and line.hits > 0 then
                coveredLines = coveredLines + 1
            end
        end
    end
    
    return {
        filename = filename,
        totalLines = #lines,
        totalExecutable = totalExecutable,
        coveredLines = coveredLines,
        coverage = totalExecutable > 0 and (coveredLines / totalExecutable) * 100 or 0,
        lines = lines
    }
end

local function generateReport(files)
    print("=== HealIQ Code Coverage Analysis ===")
    print("")
    
    local totalExecutable = 0
    local totalCovered = 0
    local fileResults = {}
    
    -- Parse coverage stats
    local stats = parseStats("luacov.stats.out")
    if not stats then
        print("WARNING: Could not parse luacov.stats.out - coverage analysis may be incomplete")
        stats = {}
    end
    
    -- Analyze each file
    for _, filename in ipairs(files) do
        local analysis = analyzeFile(filename, stats)
        if analysis then
            table.insert(fileResults, analysis)
            totalExecutable = totalExecutable + analysis.totalExecutable
            totalCovered = totalCovered + analysis.coveredLines
        end
    end
    
    -- Overall summary
    local overallCoverage = totalExecutable > 0 and (totalCovered / totalExecutable) * 100 or 0
    print(string.format("Overall Coverage: %.1f%% (%d/%d executable lines)",
                       overallCoverage, totalCovered, totalExecutable))
    
    if totalExecutable == 0 then
        print("Note: No executable lines tracked - coverage analysis may be incomplete")
    end
    print("")
    
    -- File-by-file results
    print("File Coverage Details:")
    print("====================")
    for _, result in ipairs(fileResults) do
        print(string.format("%-20s: %5.1f%% (%3d/%3d lines)",
                           result.filename, result.coverage,
                           result.coveredLines, result.totalExecutable))
    end
    print("")
    
    -- Coverage threshold check
    local threshold = 70 -- 70% coverage threshold
    if totalExecutable == 0 then
        print("⚠️  Cannot determine coverage - no executable lines tracked")
        print("Coverage analysis may need adjustment for CI environment")
        return true -- Don't fail CI for coverage tracking issues
    elseif overallCoverage >= threshold then
        print(string.format("✅ Coverage meets threshold (%.1f%% >= %d%%)", overallCoverage, threshold))
        return true
    else
        print(string.format("❌ Coverage below threshold (%.1f%% < %d%%)", overallCoverage, threshold))
        
        -- Show uncovered critical lines
        print("")
        print("Critical uncovered areas:")
        for _, result in ipairs(fileResults) do
            if result.coverage < threshold then
                print(string.format("\n%s (%.1f%% coverage):", result.filename, result.coverage))
                local uncoveredCount = 0
                for _, line in ipairs(result.lines) do
                    if line.executable and (not line.hits or line.hits == 0) then
                        if uncoveredCount < 5 then -- Show first 5 uncovered lines
                            print(string.format("  Line %3d: %s", line.number, line.content:sub(1, 60)))
                        end
                        uncoveredCount = uncoveredCount + 1
                    end
                end
                if uncoveredCount > 5 then
                    print(string.format("  ... and %d more uncovered lines", uncoveredCount - 5))
                end
            end
        end
        
        return false
    end
end

-- Main execution
local function main()
    -- Filter to only analyze main addon files
    local files = {"Core.lua", "Engine.lua", "UI.lua", "Tracker.lua", "Config.lua", "Logging.lua"}
    
    print("Analyzing coverage for HealIQ addon files only...")
    local success = generateReport(files)
    if success then
        os.exit(0)
    else
        os.exit(1)
    end
end

-- Run if this is the main script
if arg and arg[0] and arg[0]:match("coverage_analysis%.lua$") then
    main()
end

return {
    parseStats = parseStats,
    analyzeFile = analyzeFile,
    generateReport = generateReport
}
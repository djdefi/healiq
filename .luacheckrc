-- Luacheck configuration for HealIQ
-- This file defines linting rules to catch common issues early

-- Standard setup for WoW addons
std = "none"

-- Global variables that are OK to use
globals = {
    "_G",
}

-- Ignore specific warning codes that are common in WoW addon development
ignore = {
    "11",   -- Unreachable code
    "21",   -- Invalid escape sequence
    "131",  -- Unused global variable
    "143",  -- Accessing undefined variable
    "213",  -- Unused loop variable
    "311",  -- Value assigned to a local variable is unused
    "312",  -- Value of a local variable is unused
    "631",  -- Line is too long
    "611",  -- Line contains only whitespace
    "432",  -- Shadowing definition of variable
    "212",  -- Unused argument
    "211",  -- Unused local variable
    "231",  -- Local variable is set but never accessed
    "111",  -- Setting non-standard global variable
    "112",  -- Mutating non-standard global variable
    "113",  -- Accessing undefined variable
}

-- Files to exclude from linting
exclude_files = {
    -- Exclude auto-generated or third-party files if any
}

-- Configure specific warning types
max_line_length = 120
max_cyclomatic_complexity = 80  -- Set higher for existing complex WoW addon functions

-- WoW-specific globals that should be allowed
read_globals = {
    -- Common WoW API globals would go here when testing in actual WoW environment
    -- For now, we allow undefined access via ignore rules
}
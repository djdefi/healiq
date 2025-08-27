-- Example HealIQ Plugin
-- This demonstrates how to create a plugin for HealIQ
-- This file is not loaded by the addon - it's just for reference

-- Example plugin that adds a simple spell suggestion
local ExamplePlugin = {
    name = "ExamplePlugin",
    version = "1.0.0",
    author = "Example Author",
    description = "Demonstrates HealIQ plugin API usage"
}

-- Plugin initialization function (required)
function ExamplePlugin:Initialize()
    print("Example Plugin initialized!")
    return true
end

-- Called when plugin is enabled (optional)
function ExamplePlugin:OnEnable()
    print("Example Plugin enabled!")
end

-- Called when plugin is disabled (optional)
function ExamplePlugin:OnDisable()
    print("Example Plugin disabled!")
end

-- Provide spell suggestions (optional - for rule plugins)
function ExamplePlugin:GetSuggestions()
    -- Example: suggest a custom spell
    local suggestions = {}
    
    -- Only suggest if player is in combat and health is low
    if InCombatLockdown() and UnitHealth("player") < UnitHealthMax("player") * 0.5 then
        table.insert(suggestions, {
            spellId = 8936, -- Regrowth
            priority = 50,
            reason = "Example Plugin: Emergency heal needed",
            targetType = "SELF"
        })
    end
    
    return suggestions
end

-- Handle addon events (optional - for event handling plugins)
function ExamplePlugin:OnEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        print("Example Plugin: Entered combat!")
    elseif event == "PLAYER_REGEN_ENABLED" then
        print("Example Plugin: Left combat!")
    end
end

-- Register the plugin with HealIQ
-- This would typically be done when the plugin file is loaded
if HealIQ and HealIQ.RegisterPlugin then
    HealIQ:RegisterPlugin(ExamplePlugin.name, ExamplePlugin)
    
    -- Register for events if needed
    if HealIQ.RegisterHook then
        HealIQ:RegisterHook("COMBAT_CHANGED", function(inCombat)
            if inCombat then
                print("Example Plugin: Combat started via hook!")
            else
                print("Example Plugin: Combat ended via hook!")
            end
        end, ExamplePlugin.name)
    end
end

--[[
Usage:
1. Load your plugin after HealIQ is initialized
2. Register it using HealIQ:RegisterPlugin(name, pluginData)
3. Enable it using /healiq plugins enable <name> or HealIQ:EnablePlugin(name)
4. Your GetSuggestions function will be called during rule evaluation
5. Your OnEvent function will receive events if registered
6. Use hooks for additional integration points

Available hooks:
- SPECIALIZATION_CHANGED: Called when player changes spec
- COMBAT_CHANGED: Called when entering/leaving combat
- SUGGESTION_UPDATED: Called when spell suggestions change
]]
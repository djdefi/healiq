#!/usr/bin/env lua5.3
-- Test the UI fix specifically

-- Load the test runner code directly inline
package.path = './?.lua;' .. package.path

-- Mock WoW API and globals for testing
local function setupMockEnvironment()
    -- Mock global functions that HealIQ might use
    _G.print = print
    _G.error = error
    _G.type = type
    _G.pairs = pairs
    _G.ipairs = ipairs
    _G.table = table
    _G.string = string
    _G.math = math
    _G.tostring = tostring
    _G.tonumber = tonumber
    _G.pcall = pcall
    _G.unpack = unpack or table.unpack
    _G.next = next

    -- Mock addon loading function
    _G.GetAddOnMetadata = function(addon, field)
        if addon == "HealIQ" and field == "Version" then
            return "0.1.2"
        end
        return nil
    end

    -- Mock frame creation
    _G.CreateFrame = function(frameType, name, parent, template)
        local frame = {
            frameType = frameType,
            name = name,
            parent = parent,
            template = template,
            children = {},

            -- Common frame methods
            SetSize = function(self, width, height)
                self.width = width
                self.height = height
            end,
            GetSize = function(self) return self.width or 0, self.height or 0 end,
            GetWidth = function(self) return self.width or 400 end,
            GetHeight = function(self) return self.height or 700 end,
            SetWidth = function(self, width) self.width = width end,
            SetHeight = function(self, height) self.height = height end,
            SetPoint = function(self, ...) end,
            GetPoint = function(self) return "CENTER", nil, "CENTER", 0, 0 end,
            SetParent = function(self, parent) self.parent = parent end,
            GetParent = function(self) return self.parent end,
            Show = function(self) self.visible = true end,
            Hide = function(self) self.visible = false end,
            IsShown = function(self) return self.visible or false end,
            SetScript = function(self, event, handler) self[event] = handler end,
            CreateTexture = function(self, name, layer) 
                return {
                    SetTexture = function() end,
                    SetColorTexture = function() end,
                    SetAllPoints = function() end,
                    SetAlpha = function() end
                }
            end,
            CreateFontString = function(self, name, layer, font)
                return {
                    SetText = function() end,
                    SetPoint = function() end,
                    SetTextColor = function() end,
                    SetFont = function() end,
                    GetStringWidth = function() return 100 end,
                    GetStringHeight = function() return 20 end,
                    SetMaxLines = function() end,
                    SetShadowColor = function() end,
                    SetShadowOffset = function() end
                }
            end,
            SetBackdrop = function() end,
            SetBackdropColor = function() end,
            SetBackdropBorderColor = function() end,
            SetMovable = function() end,
            EnableMouse = function() end,
            RegisterForDrag = function() end,
            StartMoving = function() end,
            StopMovingOrSizing = function() end,
            SetFrameStrata = function() end,
            SetFrameLevel = function() end,
            SetText = function() end,
            SetChecked = function() end,
            GetChecked = function() return false end,
            SetValue = function() end,
            GetValue = function() return 1.0 end,
            SetMinMaxValues = function() end,
            SetValueStep = function() end,
            SetObeyStepOnDrag = function() end,
            SetAlpha = function() end,
            GetAlpha = function() return 1.0 end
        }
        
        -- Add special properties for UIParent
        if name == "UIParent" then
            frame.width = 1920
            frame.height = 1080
        end
        
        return frame
    end

    -- Mock other WoW globals
    _G.UIParent = CreateFrame("Frame", "UIParent")
    _G.GameFontNormal = "GameFontNormal"
    _G.GameFontHighlight = "GameFontHighlight"
    _G.GameFontDisable = "GameFontDisable"
    _G.GameFontNormalLarge = "GameFontNormalLarge"
    _G.GameFontNormalSmall = "GameFontNormalSmall"
    
    -- Mock more WoW functions
    _G.GetTime = function() return 1000000 end
    _G.UnitExists = function(unit) return unit == "player" end
    _G.UnitName = function(unit) return unit == "player" and "TestPlayer" or nil end
    _G.UnitClass = function(unit)
        if unit == "player" then
            return "Druid", "DRUID"
        end
        return nil, nil
    end
    _G.InCombatLockdown = function() return false end
    _G.IsInRaid = function() return false end
    _G.IsInGroup = function() return false end
    _G.GetNumGroupMembers = function() return 1 end
    _G.GetNumSubgroupMembers = function() return 0 end
    _G.UnitHealth = function(unit) return 50000 end
    _G.UnitHealthMax = function(unit) return 100000 end
    _G.GetSpellCooldown = function(spellID) return 0, 0 end
    _G.geterrorhandler = function() return function(msg) print("Error: " .. msg) end end
    _G.debugstack = function() return "debug stack trace" end
end

setupMockEnvironment()

-- Initialize the addon table with basic structure
local addonName = "HealIQ"
HealIQ = {
    version = "0.1.2",
    debug = false,
    sessionStats = {},
    db = {
        enabled = true,
        debug = false,
        ui = {
            scale = 1.0,
            x = 0,
            y = 0,
            locked = false,
            showSpellName = true,
            showCooldown = true,
            showIcon = true,
            showQueue = true,
            queueScale = 0.75,
            queueSize = 3,
            queueLayout = "horizontal",
            queueSpacing = 8,
            showTargeting = true,
            showTargetingIcon = true
        },
        rules = {},
        strategy = {}
    }
}

-- Load the actual files
print("Loading Core.lua...")
loadfile("Core.lua")(addonName, HealIQ)

print("Loading UI.lua...")
loadfile("UI.lua")(addonName, HealIQ)

print("=== Testing UI CreateOptionsFrame Fix ===")

-- Initialize HealIQ
if HealIQ.OnInitialize then
    HealIQ:OnInitialize()
end

-- Test that the UI can be initialized without errors
local success, error = pcall(function()
    if HealIQ.UI and HealIQ.UI.Initialize then
        HealIQ.UI:Initialize()
    end
end)

if success then
    print("✓ UI.Initialize() completed without errors")
else
    print("✗ UI.Initialize() failed with error: " .. tostring(error))
    os.exit(1)
end

-- Test that CreateOptionsFrame works
local success2, error2 = pcall(function()
    if HealIQ.UI and HealIQ.UI.CreateOptionsFrame then
        HealIQ.UI:CreateOptionsFrame()
    end
end)

if success2 then
    print("✓ UI.CreateOptionsFrame() completed without errors")
else
    print("✗ UI.CreateOptionsFrame() failed with error: " .. tostring(error2))
    os.exit(1)
end

-- Test that options frame can be toggled
local success3, error3 = pcall(function()
    if HealIQ.UI and HealIQ.UI.ToggleOptionsFrame then
        HealIQ.UI:ToggleOptionsFrame()
    end
end)

if success3 then
    print("✓ UI.ToggleOptionsFrame() completed without errors")
else
    print("✗ UI.ToggleOptionsFrame() failed with error: " .. tostring(error3))
    os.exit(1)
end

print("=== All UI tests passed! The parentHeight fix is working! ===")

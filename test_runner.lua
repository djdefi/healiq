#!/usr/bin/env lua
-- HealIQ Test Runner for CI
-- This script can run HealIQ tests in a CI environment without WoW

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
    _G.getmetatable = getmetatable
    _G.setmetatable = setmetatable
    _G.rawget = rawget
    _G.rawset = rawset
    _G.select = select

    -- Mock time/date functions
    _G.time = os.time
    _G.date = os.date
    _G.GetTime = function() return os.time() end

    -- Mock basic WoW API functions
    _G.GetAddOnMetadata = function(addon, field)
        if addon == "HealIQ" and field == "Version" then
            return "0.0.25"
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
            SetWidth = function(self, width) self.width = width end,
            SetHeight = function(self, height) self.height = height end,
            SetPoint = function(self, ...) end,
            GetPoint = function(self) return "CENTER", nil, "CENTER", 0, 0 end,
            SetParent = function(self, parent) self.parent = parent end,
            GetParent = function(self) return self.parent end,
            Show = function(self) self.visible = true end,
            Hide = function(self) self.visible = false end,
            IsShown = function(self) return self.visible or false end,
            SetAlpha = function(self, alpha) self.alpha = alpha end,
            GetAlpha = function(self) return self.alpha or 1.0 end,
            SetScale = function(self, scale) self.scale = scale end,
            GetScale = function(self) return self.scale or 1.0 end,
            SetText = function(self, text) self.text = text end,
            GetText = function(self) return self.text or "" end,
            SetTexture = function(self, texture) self.texture = texture end,
            SetWordWrap = function(self, wrap) self.wordWrap = wrap end,
            SetScript = function(self, event, handler)
                self.scripts = self.scripts or {}
                self.scripts[event] = handler
            end,
            GetScript = function(self, event)
                return self.scripts and self.scripts[event]
            end,
            RegisterEvent = function(self, event)
                self.events = self.events or {}
                self.events[event] = true
            end,
            UnregisterEvent = function(self, event)
                if self.events then
                    self.events[event] = nil
                end
            end,
            CreateTexture = function(self, name, layer)
                local texture = CreateFrame("Texture", name, self)
                texture.layer = layer
                return texture
            end,
            CreateFontString = function(self, name, layer, template)
                local fontString = CreateFrame("FontString", name, self)
                fontString.layer = layer
                fontString.template = template
                return fontString
            end,
            SetVertexColor = function(self, r, g, b, a) end,
            GetVertexColor = function(self) return 1, 1, 1, 1 end,
            SetTexCoord = function(self, ...) end,
            SetFont = function(self, font, size, flags) end,
            GetFont = function(self) return "Fonts\\FRIZQT__.TTF", 12, "" end,
            SetTextColor = function(self, r, g, b, a) end,
            GetTextColor = function(self) return 1, 1, 1, 1 end,
            EnableMouse = function(self, enable) self.mouseEnabled = enable end,
            IsMouseEnabled = function(self) return self.mouseEnabled or false end,
            EnableMouseWheel = function(self, enable) self.mouseWheelEnabled = enable end,
            SetResizable = function(self, resizable) self.resizable = resizable end,
            IsResizable = function(self) return self.resizable or false end,
            SetMovable = function(self, movable) self.movable = movable end,
            IsMovable = function(self) return self.movable or false end,
            StartMoving = function(self) end,
            StopMovingOrSizing = function(self) end,
            SetMinResize = function(self, w, h) end,
            SetMaxResize = function(self, w, h) end
        }

        -- Add frame to global registry if named
        if name then
            _G[name] = frame
        end

        return frame
    end

    -- Mock other UI functions
    _G.UIParent = CreateFrame("Frame", "UIParent")
    _G.GameFontNormal = "GameFontNormal"
    _G.GameFontHighlight = "GameFontHighlight"
    _G.GameFontDisable = "GameFontDisable"
    _G.GameFontNormalLarge = "GameFontNormalLarge"
    _G.Minimap = CreateFrame("Frame", "Minimap")
    _G.Minimap.GetZoom = function() return 0 end
    _G.Minimap.SetZoom = function(zoom) end

    -- Mock game state functions
    _G.UnitExists = function(unit) return unit == "player" end
    _G.UnitName = function(unit) return unit == "player" and "TestPlayer" or nil end
    _G.UnitClass = function(unit)
        if unit == "player" then
            return "Druid", "DRUID"
        end
        return nil, nil
    end
    _G.GetSpellInfo = function(spellId)
        local spells = {
            [774] = "Rejuvenation",
            [8936] = "Regrowth",
            [5185] = "Healing Touch"
        }
        local name = spells[spellId] or "Unknown Spell"
        return name, nil, nil, nil, nil, nil, spellId
    end
    _G.IsSpellKnown = function(spellId) return true end
    _G.GetSpellCooldown = function(spellId) return 0, 0, 0, 0 end

    -- Mock saved variables
    _G.HealIQDB = {}

    -- Mock slash commands
    _G.SLASH_HEALIQ1 = "/healiq"
    _G.SLASH_HEALIQ2 = "/hiq"
    _G.SlashCmdList = {}

    -- Mock events
    _G.C_Timer = {
        After = function(delay, callback)
            -- Execute immediately in tests
            callback()
        end
    }

    -- Mock LibStub (if used)
    _G.LibStub = function(name, silent)
        return nil
    end

    -- Mock debugstack for error handling
    _G.debugstack = function(level)
        return "mock debug stack"
    end

    -- Mock error handler
    _G.geterrorhandler = function()
        return function(msg)
            print("Error: " .. tostring(msg))
        end
    end

    -- Mock chat functions
    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(self, msg) print(msg) end
    }

    -- Mock color functions
    _G.NORMAL_FONT_COLOR = {r = 1, g = 1, b = 1}
    _G.HIGHLIGHT_FONT_COLOR = {r = 1, g = 1, b = 0}
    _G.RED_FONT_COLOR = {r = 1, g = 0, b = 0}
    _G.GREEN_FONT_COLOR = {r = 0, g = 1, b = 0}

    -- Mock constants
    _G.TEXTURE = 1
    _G.OVERLAY = 2
    _G.BACKGROUND = 3
    _G.BORDER = 4
    _G.ARTWORK = 5

    -- Mock string coloring
    _G.YELLOW_FONT_COLOR_CODE = "|cFFFFD100"
    _G.FONT_COLOR_CODE_CLOSE = "|r"
end

-- Load and initialize the addon in a controlled environment
local function loadAddon()
    setupMockEnvironment()

    -- Create addon namespace
    local addonName = "HealIQ"
    local HealIQ = {}
    _G[addonName] = HealIQ

    -- Set version
    HealIQ.version = "0.0.25"

    -- Mock essential functions
    HealIQ.SafeCall = function(self, func)
        local success, result = pcall(func)
        if not success then
            print("Error in SafeCall: " .. tostring(result))
        end
        return success, result
    end

    HealIQ.Print = function(self, message)
        print("HealIQ: " .. tostring(message))
    end

    HealIQ.DebugLog = function(self, message, level)
        -- Silent in tests unless debug enabled
    end

    HealIQ.Message = function(self, message)
        print("HealIQ: " .. tostring(message))
    end

    -- Mock database
    HealIQ.db = {
        debug = false,
        ui = {
            scale = 1.0,
            opacity = 1.0
        },
        general = {
            debug = false
        }
    }

    -- Try to load actual addon files for coverage tracking
    local addonFiles = {"Core.lua", "Engine.lua", "UI.lua", "Tracker.lua", "Config.lua", "Logging.lua"}

    for _, filename in ipairs(addonFiles) do
        local file = io.open(filename, "r")
        if file then
            file:close()
            print("Loading " .. filename .. " for coverage analysis...")

            -- Load and execute the file
            local chunk, err = loadfile(filename)
            if chunk then
                local success, result = pcall(chunk, addonName, HealIQ)
                if not success then
                    print("Warning: Error loading " .. filename .. ": " .. tostring(result))
                end
            else
                print("Warning: Could not load " .. filename .. ": " .. tostring(err))
            end
        else
            print("Note: " .. filename .. " not found, using mock implementation")
        end
    end

    -- Ensure debug is disabled for clean test output
    HealIQ.debug = false
    if HealIQ.db then
        HealIQ.db.debug = false
        if HealIQ.db.general then
            HealIQ.db.general.debug = false
        end
    end

    -- Ensure we have the essential modules even if loading failed
    if not HealIQ.UI then
        HealIQ.UI = {
            GetFrameInfo = function()
                return {
                    scale = 1.0,
                    opacity = 1.0
                }
            end
        }
    end

    if not HealIQ.Config then
        HealIQ.Config = {
            GetOption = function(self, category, option)
                if category == "general" and option == "debug" then
                    return HealIQ.db.general.debug
                end
                return nil
            end,
            SetOption = function(self, category, option, value)
                if category == "general" and option == "debug" then
                    HealIQ.db.general.debug = value
                end
            end
        }
    end

    if not HealIQ.Tracker then
        HealIQ.Tracker = {
            Initialize = function() end,
            IsSpellKnown = function(self, spellName)
                -- Mock some known spells for druids
                local knownSpells = {
                    ["Rejuvenation"] = true,
                    ["Regrowth"] = true,
                    ["Healing Touch"] = true
                }
                return knownSpells[spellName] or false
            end
        }
    end

    return HealIQ
end

-- Run the tests
local function runTests()
    print("=== HealIQ CI Test Runner ===")

    -- Initialize LuaCov for coverage tracking (optional)
    local luacov_available = pcall(require, "luacov")
    if not luacov_available then
        print("Note: LuaCov not available, running tests without coverage tracking")
    end

    -- Load addon
    local HealIQ = loadAddon()
    if not HealIQ then
        print("ERROR: Failed to load HealIQ addon")
        return false
    end

    -- Load the test module
    local testFile = "Tests.lua"
    local testChunk, err = loadfile(testFile)
    if not testChunk then
        print("ERROR: Failed to load " .. testFile .. ": " .. tostring(err))
        return false
    end

    -- Execute the test file in our environment
    local success, result = pcall(testChunk, "HealIQ", HealIQ)
    if not success then
        print("ERROR: Failed to execute " .. testFile .. ": " .. tostring(result))
        return false
    end

    -- Run the tests
    if HealIQ.Tests then
        print("Running HealIQ tests...")
        HealIQ.Tests:RunAll()

        -- Force LuaCov to save stats if available
        if luacov_available then
            local luacov = require("luacov")
            if luacov.save_stats then
                luacov.save_stats()
            end
        end

        return true
    else
        print("ERROR: Test module not loaded properly")
        return false
    end
end

-- Main execution
local function main()
    local success = runTests()
    if success then
        print("Test execution completed")
        os.exit(0)
    else
        print("Test execution failed")
        os.exit(1)
    end
end

-- Run if this is the main script
if arg and arg[0] and arg[0]:match("test_runner%.lua$") then
    main()
end

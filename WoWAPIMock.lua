-- WoWAPIMock.lua
-- Mock WoW API functions for external testing
-- This allows testing WoW-dependent code outside the game client

local WoWAPIMock = {}

-- Mock frame system
local mockFrames = {}
local frameCounter = 0

-- Mock game state
local mockGameState = {
    time = 1000,
    inCombat = false,
    playerName = "TestPlayer",
    playerClass = "DRUID",
    targetExists = true,
    targetHealth = 0.8,
    targetMaxHealth = 10000,
    focusExists = true,
    focusHealth = 0.6,
    unitBuffs = {},
    spellCooldowns = {},
    combatLogEvents = {}
}

-- Mock Frame class
local MockFrame = {}
MockFrame.__index = MockFrame

function MockFrame:new(frameType, name, parent)
    local frame = {
        frameType = frameType or "Frame",
        name = name,
        parent = parent,
        children = {},
        scripts = {},
        size = {width = 100, height = 100},
        position = {x = 0, y = 0},
        visible = true,
        enabled = true,
        texture = nil,
        text = "",
        fontString = nil
    }
    setmetatable(frame, self)
    frameCounter = frameCounter + 1
    frame.id = frameCounter
    mockFrames[frame.id] = frame
    return frame
end

function MockFrame:SetSize(width, height)
    self.size.width = width
    self.size.height = height
end

function MockFrame:SetPoint(point, relativeTo, relativePoint, x, y)
    self.position.x = x or 0
    self.position.y = y or 0
end

function MockFrame:SetScript(event, handler)
    self.scripts[event] = handler
end

function MockFrame:RegisterEvent(event)
    -- Mock event registration
    if not self.events then
        self.events = {}
    end
    self.events[event] = true
end

function MockFrame:UnregisterEvent(event)
    if self.events then
        self.events[event] = nil
    end
end

function MockFrame:UnregisterAllEvents()
    self.events = {}
end

function MockFrame:Show()
    self.visible = true
end

function MockFrame:Hide()
    self.visible = false
end

function MockFrame:SetTexture(texture)
    self.texture = texture
end

function MockFrame:SetText(text)
    self.text = text or ""
end

function MockFrame:CreateFontString(name, layer, template)
    local fontString = MockFrame:new("FontString", name, self)
    self.fontString = fontString
    return fontString
end

function MockFrame:SetWidth(width)
    self.size.width = width
end

function MockFrame:SetWordWrap(wrap)
    self.wordWrap = wrap
end

-- Mock WoW API Functions
function WoWAPIMock.CreateFrame(frameType, name, parent, template)
    return MockFrame:new(frameType, name, parent)
end

function WoWAPIMock.GetTime()
    return mockGameState.time
end

function WoWAPIMock.InCombatLockdown()
    return mockGameState.inCombat
end

function WoWAPIMock.UnitExists(unit)
    if unit == "player" then return true end
    if unit == "target" then return mockGameState.targetExists end
    if unit == "focus" then return mockGameState.focusExists end
    return false
end

function WoWAPIMock.UnitHealth(unit)
    if unit == "target" then
        return math.floor(mockGameState.targetHealth * mockGameState.targetMaxHealth)
    end
    return 8000 -- Default health
end

function WoWAPIMock.UnitHealthMax(unit)
    if unit == "target" then
        return mockGameState.targetMaxHealth
    end
    return 10000 -- Default max health
end

function WoWAPIMock.UnitName(unit)
    if unit == "player" then return mockGameState.playerName end
    if unit == "target" then return "TestTarget" end
    if unit == "focus" then return "TestFocus" end
    return "UnknownUnit"
end

function WoWAPIMock.UnitClass(unit)
    if unit == "player" then return "Druid", mockGameState.playerClass end
    return "Warrior", "WARRIOR"
end

function WoWAPIMock.GetSpellCooldown(spellID)
    local cooldown = mockGameState.spellCooldowns[spellID] or {start = 0, duration = 0}
    return cooldown.start, cooldown.duration, 1
end

function WoWAPIMock.GetSpellInfo(spellID)
    local spellNames = {
        [774] = "Rejuvenation",
        [33763] = "Lifebloom", 
        [8936] = "Regrowth",
        [2061] = "Flash Heal",
        [139] = "Renew"
    }
    return spellNames[spellID] or "Unknown Spell"
end

function WoWAPIMock.UnitBuff(unit, index, filter)
    local buffs = mockGameState.unitBuffs[unit] or {}
    local buff = buffs[index]
    if buff then
        return buff.name, buff.icon, buff.count, buff.debuffType, 
               buff.duration, buff.expirationTime, buff.source, 
               buff.isStealable, buff.nameplateShowPersonal, buff.spellId
    end
    return nil
end

function WoWAPIMock.CombatLogGetCurrentEventInfo()
    local events = mockGameState.combatLogEvents
    if #events > 0 then
        return unpack(table.remove(events, 1))
    end
    return nil
end

-- Additional WoW API functions
function WoWAPIMock.GetPlayerInfoByGUID(guid)
    return nil, "DRUID", "Tauren", "Male", 1, "TestPlayer"
end

function WoWAPIMock.IsInInstance()
    return false, "none"
end

function WoWAPIMock.GetRealmName()
    return "TestRealm"
end

function WoWAPIMock.UnitLevel(unit)
    return 80
end

function WoWAPIMock.UnitPowerType(unit)
    return 0 -- Mana
end

function WoWAPIMock.UnitPower(unit, powerType)
    return 8000
end

function WoWAPIMock.UnitPowerMax(unit, powerType)
    return 10000
end

function WoWAPIMock.GetAddOnMetadata(addon, field)
    if addon == "HealIQ" and field == "Version" then
        return "0.0.25"
    end
    return nil
end

-- Mock utility functions
function WoWAPIMock.SetGameState(state)
    for key, value in pairs(state) do
        mockGameState[key] = value
    end
end

function WoWAPIMock.AddCombatLogEvent(...)
    table.insert(mockGameState.combatLogEvents, {...})
end

function WoWAPIMock.SetSpellCooldown(spellID, start, duration)
    mockGameState.spellCooldowns[spellID] = {start = start, duration = duration}
end

function WoWAPIMock.SetUnitBuff(unit, index, buffData)
    if not mockGameState.unitBuffs[unit] then
        mockGameState.unitBuffs[unit] = {}
    end
    mockGameState.unitBuffs[unit][index] = buffData
end

function WoWAPIMock.Reset()
    mockFrames = {}
    frameCounter = 0
    mockGameState = {
        time = 1000,
        inCombat = false,
        playerName = "TestPlayer",
        playerClass = "DRUID",
        targetExists = true,
        targetHealth = 0.8,
        targetMaxHealth = 10000,
        focusExists = true,
        focusHealth = 0.6,
        unitBuffs = {},
        spellCooldowns = {},
        combatLogEvents = {}
    }
end

-- Install mock functions into global namespace for testing
function WoWAPIMock.Install()
    -- Frame creation
    _G.CreateFrame = WoWAPIMock.CreateFrame
    
    -- Time and combat
    _G.GetTime = WoWAPIMock.GetTime
    _G.InCombatLockdown = WoWAPIMock.InCombatLockdown
    
    -- Unit functions
    _G.UnitExists = WoWAPIMock.UnitExists
    _G.UnitHealth = WoWAPIMock.UnitHealth
    _G.UnitHealthMax = WoWAPIMock.UnitHealthMax
    _G.UnitName = WoWAPIMock.UnitName
    _G.UnitClass = WoWAPIMock.UnitClass
    _G.UnitBuff = WoWAPIMock.UnitBuff
    
    -- Spell functions
    _G.GetSpellCooldown = WoWAPIMock.GetSpellCooldown
    _G.GetSpellInfo = WoWAPIMock.GetSpellInfo
    
    -- Combat log
    _G.CombatLogGetCurrentEventInfo = WoWAPIMock.CombatLogGetCurrentEventInfo
    
    -- Additional API functions
    _G.GetPlayerInfoByGUID = WoWAPIMock.GetPlayerInfoByGUID
    _G.IsInInstance = WoWAPIMock.IsInInstance
    _G.GetRealmName = WoWAPIMock.GetRealmName
    _G.UnitLevel = WoWAPIMock.UnitLevel
    _G.UnitPowerType = WoWAPIMock.UnitPowerType
    _G.UnitPower = WoWAPIMock.UnitPower
    _G.UnitPowerMax = WoWAPIMock.UnitPowerMax
    _G.GetAddOnMetadata = WoWAPIMock.GetAddOnMetadata
    
    -- Mock additional globals that might be needed
    _G.print = _G.print or function(...) print(...) end
end

return WoWAPIMock
-- HealIQ Core.lua
-- Addon initialization, event registration, and saved variables

local addonName, HealIQ = ...

-- Create the main addon object
HealIQ = HealIQ or {}
HealIQ.version = "0.0.3"
HealIQ.debug = false

-- Default settings
local defaults = {
    enabled = true,
    ui = {
        scale = 1.0,
        x = 0,
        y = 0,
        locked = false,
        showIcon = true,
        showSpellName = true,
        showCooldown = true,
        showQueue = true,
        queueSize = 3,
        queueLayout = "horizontal", -- horizontal or vertical
        queueSpacing = 8,
    },
    rules = {
        -- Existing rules
        wildGrowth = true,
        clearcasting = true,
        lifebloom = true,
        swiftmend = true,
        rejuvenation = true,
        
        -- New rules
        ironbark = true,
        efflorescence = true,
        tranquility = true,
        incarnationTree = true,
        naturesSwiftness = true,
        barkskin = true,
        flourish = true,
        trinket = true,
    }
}

-- Initialize saved variables
function HealIQ:InitializeDB()
    if not HealIQDB then
        HealIQDB = {}
    end
    
    -- Merge defaults with saved settings
    for key, value in pairs(defaults) do
        if HealIQDB[key] == nil then
            if type(value) == "table" then
                HealIQDB[key] = {}
                for subkey, subvalue in pairs(value) do
                    HealIQDB[key][subkey] = subvalue
                end
            else
                HealIQDB[key] = value
            end
        end
    end
    
    self.db = HealIQDB
end

-- Debug print function
function HealIQ:Print(message)
    if self.debug then
        print("|cFF00FF00HealIQ:|r " .. tostring(message))
    end
end

-- Main addon initialization
function HealIQ:OnInitialize()
    self:InitializeDB()
    self:Print("HealIQ " .. self.version .. " loaded")
    
    -- Initialize modules
    if self.Tracker then
        self.Tracker:Initialize()
    end
    
    if self.Engine then
        self.Engine:Initialize()
    end
    
    if self.UI then
        self.UI:Initialize()
    end
    
    if self.Config then
        self.Config:Initialize()
    end
end

-- Event handling
function HealIQ:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            self:OnInitialize()
        end
    elseif event == "PLAYER_LOGIN" then
        self:OnPlayerLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:OnPlayerEnteringWorld()
    end
end

function HealIQ:OnPlayerLogin()
    self:Print("Player logged in")
end

function HealIQ:OnPlayerEnteringWorld()
    self:Print("Player entering world")
    
    -- Check if player is a Restoration Druid
    local _, class = UnitClass("player")
    if class == "DRUID" then
        local specIndex = GetSpecialization()
        if specIndex == 4 then -- Restoration spec
            self:Print("Restoration Druid detected")
            self.db.enabled = true
        else
            self:Print("Not Restoration spec, addon disabled")
            self.db.enabled = false
        end
    else
        self:Print("Not a Druid, addon disabled")
        self.db.enabled = false
    end
end

-- Create event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    HealIQ:OnEvent(event, ...)
end)

-- Make HealIQ globally accessible
_G[addonName] = HealIQ
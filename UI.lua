-- HealIQ UI.lua
-- Renders suggestion icons and manages configuration display

local addonName, HealIQ = ...

HealIQ.UI = {}
local UI = HealIQ.UI

-- UI Frame references
local mainFrame = nil
local iconFrame = nil
local spellNameText = nil
local cooldownFrame = nil
local isDragging = false

-- Constants
local FRAME_SIZE = 64
local ICON_SIZE = 48

function UI:Initialize()
    self:CreateMainFrame()
    self:SetupEventHandlers()
    HealIQ:Print("UI initialized")
end

function UI:CreateMainFrame()
    -- Create main container frame
    mainFrame = CreateFrame("Frame", "HealIQMainFrame", UIParent)
    mainFrame:SetSize(FRAME_SIZE, FRAME_SIZE)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", HealIQ.db.ui.x, HealIQ.db.ui.y)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    
    -- Create background
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)
    bg:SetAlpha(0.5)
    
    -- Create spell icon frame
    iconFrame = CreateFrame("Frame", "HealIQIconFrame", mainFrame)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("CENTER")
    
    -- Create spell icon texture
    local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop edges for cleaner look
    iconFrame.icon = iconTexture
    
    -- Create spell name text
    spellNameText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellNameText:SetPoint("TOP", iconFrame, "BOTTOM", 0, -2)
    spellNameText:SetTextColor(1, 1, 1, 1)
    
    -- Create cooldown frame
    cooldownFrame = CreateFrame("Cooldown", "HealIQCooldownFrame", iconFrame, "CooldownFrameTemplate")
    cooldownFrame:SetAllPoints()
    cooldownFrame:SetDrawEdge(false)
    cooldownFrame:SetDrawSwipe(true)
    cooldownFrame:SetReverse(true)
    
    -- Make frame draggable
    self:MakeFrameDraggable()
    
    -- Initially hide the frame
    mainFrame:Hide()
end

function UI:MakeFrameDraggable()
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    
    mainFrame:SetScript("OnDragStart", function(self)
        if not HealIQ.db.ui.locked then
            self:StartMoving()
            isDragging = true
        end
    end)
    
    mainFrame:SetScript("OnDragStop", function(self)
        if isDragging then
            self:StopMovingOrSizing()
            isDragging = false
            
            -- Save position
            local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
            HealIQ.db.ui.x = xOfs
            HealIQ.db.ui.y = yOfs
            
            HealIQ:Print("UI position saved")
        end
    end)
    
    -- Right-click to toggle lock
    mainFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            UI:ToggleLock()
        end
    end)
end

function UI:SetupEventHandlers()
    -- Scale with UI changes
    local scaleFrame = CreateFrame("Frame")
    scaleFrame:RegisterEvent("UI_SCALE_CHANGED")
    scaleFrame:SetScript("OnEvent", function()
        UI:UpdateScale()
    end)
end

function UI:UpdateSuggestion(suggestion)
    if not mainFrame then
        return
    end
    
    if not suggestion then
        mainFrame:Hide()
        return
    end
    
    -- Show the frame
    mainFrame:Show()
    
    -- Update icon
    if iconFrame and iconFrame.icon then
        iconFrame.icon:SetTexture(suggestion.icon)
        iconFrame.icon:SetDesaturated(false)
    end
    
    -- Update spell name
    if spellNameText and HealIQ.db.ui.showSpellName then
        spellNameText:SetText(suggestion.name)
        spellNameText:Show()
    else
        spellNameText:Hide()
    end
    
    -- Update cooldown display
    if cooldownFrame and HealIQ.db.ui.showCooldown then
        self:UpdateCooldownDisplay(suggestion)
    end
end

function UI:UpdateCooldownDisplay(suggestion)
    if not cooldownFrame then
        return
    end
    
    -- Get cooldown info from tracker
    local tracker = HealIQ.Tracker
    if not tracker then
        return
    end
    
    local spellName = suggestion.name:lower():gsub(" ", "")
    local cooldownInfo = tracker:GetCooldownInfo(spellName)
    
    if cooldownInfo and cooldownInfo.remaining > 0 then
        cooldownFrame:SetCooldown(cooldownInfo.start, cooldownInfo.duration)
        cooldownFrame:Show()
    else
        cooldownFrame:Hide()
    end
end

function UI:UpdateScale()
    if mainFrame then
        mainFrame:SetScale(HealIQ.db.ui.scale)
    end
end

function UI:UpdatePosition()
    if mainFrame then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", HealIQ.db.ui.x, HealIQ.db.ui.y)
    end
end

function UI:ToggleLock()
    HealIQ.db.ui.locked = not HealIQ.db.ui.locked
    
    if HealIQ.db.ui.locked then
        HealIQ:Print("UI locked")
        mainFrame:SetBackdropBorderColor(1, 0, 0, 0.5) -- Red border when locked
    else
        HealIQ:Print("UI unlocked (drag to move, right-click to lock)")
        mainFrame:SetBackdropBorderColor(0, 1, 0, 0.5) -- Green border when unlocked
    end
end

function UI:Show()
    if mainFrame then
        mainFrame:Show()
    end
end

function UI:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function UI:Toggle()
    if mainFrame then
        if mainFrame:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
end

function UI:SetEnabled(enabled)
    if enabled then
        self:Show()
    else
        self:Hide()
    end
end

-- Configuration methods
function UI:SetScale(scale)
    if scale and scale > 0.5 and scale <= 2.0 then
        HealIQ.db.ui.scale = scale
        self:UpdateScale()
        HealIQ:Print("UI scale set to " .. scale)
    end
end

function UI:SetShowSpellName(show)
    HealIQ.db.ui.showSpellName = show
    if spellNameText then
        if show then
            spellNameText:Show()
        else
            spellNameText:Hide()
        end
    end
end

function UI:SetShowCooldown(show)
    HealIQ.db.ui.showCooldown = show
    if cooldownFrame then
        if show then
            cooldownFrame:Show()
        else
            cooldownFrame:Hide()
        end
    end
end

function UI:ResetPosition()
    HealIQ.db.ui.x = 0
    HealIQ.db.ui.y = 0
    self:UpdatePosition()
    HealIQ:Print("UI position reset to center")
end

-- Debug/testing functions
function UI:TestDisplay()
    local testSuggestion = {
        id = 774,
        name = "Rejuvenation",
        icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        priority = 5,
    }
    
    self:UpdateSuggestion(testSuggestion)
    HealIQ:Print("Test display activated")
end

function UI:GetFrameInfo()
    if mainFrame then
        local point, relativeTo, relativePoint, xOfs, yOfs = mainFrame:GetPoint()
        return {
            point = point,
            relativeTo = relativeTo and relativeTo:GetName() or "nil",
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs,
            scale = mainFrame:GetScale(),
            shown = mainFrame:IsShown(),
            locked = HealIQ.db.ui.locked
        }
    end
    return nil
end

HealIQ.UI = UI
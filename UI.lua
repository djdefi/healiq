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
local minimapButton = nil
local optionsFrame = nil

-- Constants
local FRAME_SIZE = 64
local ICON_SIZE = 48

function UI:Initialize()
    self:CreateMainFrame()
    self:CreateMinimapButton()
    self:CreateOptionsFrame()
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

function UI:CreateMinimapButton()
    -- Create minimap button
    minimapButton = CreateFrame("Button", "HealIQMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    
    -- Create button background
    local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")
    bg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Create button icon
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Nature_Rejuvenation")
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    minimapButton.icon = icon
    
    -- Position on minimap
    minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 10, -10)
    
    -- Make it draggable around minimap
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    
    minimapButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Keep button on minimap edge
        local x, y = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        local angle = math.atan2(y - my, x - mx)
        local radius = 80
        local newX = mx + radius * math.cos(angle)
        local newY = my + radius * math.sin(angle)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", newX, newY)
    end)
    
    -- Click handler
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            UI:ToggleOptionsFrame()
        elseif button == "RightButton" then
            UI:Toggle()
        end
    end)
    
    -- Tooltip
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("HealIQ", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Open Options", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Toggle Display", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag: Move Button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

function UI:CreateOptionsFrame()
    -- Create main options frame
    optionsFrame = CreateFrame("Frame", "HealIQOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optionsFrame:SetSize(400, 500)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    
    -- Title
    optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    optionsFrame.title:SetPoint("LEFT", optionsFrame.TitleBg, "LEFT", 5, 0)
    optionsFrame.title:SetText("HealIQ Options")
    
    -- Content area
    local content = optionsFrame.Inset
    
    -- Enable/Disable checkbox
    local enableCheck = CreateFrame("CheckButton", "HealIQEnableCheck", content, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
    enableCheck.text:SetText("Enable HealIQ")
    enableCheck:SetScript("OnClick", function(self)
        HealIQ.db.enabled = self:GetChecked()
        if HealIQ.UI then
            HealIQ.UI:SetEnabled(HealIQ.db.enabled)
        end
    end)
    optionsFrame.enableCheck = enableCheck
    
    -- UI Scale slider
    local scaleSlider = CreateFrame("Slider", "HealIQScaleSlider", content, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -30)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider.tooltipText = "Adjust the scale of the suggestion display"
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[scaleSlider:GetName() .. "High"]:SetText("2.0")
    _G[scaleSlider:GetName() .. "Text"]:SetText("UI Scale")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        if HealIQ.UI then
            HealIQ.UI:SetScale(value)
        end
    end)
    optionsFrame.scaleSlider = scaleSlider
    
    -- UI Position buttons
    local positionLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    positionLabel:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -30)
    positionLabel:SetText("UI Position:")
    
    local resetPosButton = CreateFrame("Button", "HealIQResetPosButton", content, "UIPanelButtonTemplate")
    resetPosButton:SetSize(100, 22)
    resetPosButton:SetPoint("LEFT", positionLabel, "RIGHT", 10, 0)
    resetPosButton:SetText("Reset Position")
    resetPosButton:SetScript("OnClick", function()
        if HealIQ.UI then
            HealIQ.UI:ResetPosition()
        end
    end)
    
    local lockButton = CreateFrame("Button", "HealIQLockButton", content, "UIPanelButtonTemplate")
    lockButton:SetSize(80, 22)
    lockButton:SetPoint("LEFT", resetPosButton, "RIGHT", 5, 0)
    lockButton:SetText("Lock UI")
    lockButton:SetScript("OnClick", function()
        if HealIQ.UI then
            HealIQ.UI:ToggleLock()
            UI:UpdateOptionsFrame()
        end
    end)
    optionsFrame.lockButton = lockButton
    
    -- Rules section
    local rulesLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rulesLabel:SetPoint("TOPLEFT", positionLabel, "BOTTOMLEFT", 0, -40)
    rulesLabel:SetText("Suggestion Rules:")
    
    -- Rule checkboxes
    local rules = {
        {key = "wildGrowth", name = "Wild Growth (AoE healing)"},
        {key = "clearcasting", name = "Clearcasting (Regrowth proc)"},
        {key = "lifebloom", name = "Lifebloom (refresh)"},
        {key = "swiftmend", name = "Swiftmend (combo)"},
        {key = "rejuvenation", name = "Rejuvenation (coverage)"}
    }
    
    optionsFrame.ruleChecks = {}
    for i, rule in ipairs(rules) do
        local check = CreateFrame("CheckButton", "HealIQRule" .. rule.key, content, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", rulesLabel, "BOTTOMLEFT", 0, -10 - ((i-1) * 25))
        check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        check.text:SetPoint("LEFT", check, "RIGHT", 5, 0)
        check.text:SetText(rule.name)
        check:SetScript("OnClick", function(self)
            HealIQ.db.rules[rule.key] = self:GetChecked()
        end)
        optionsFrame.ruleChecks[rule.key] = check
    end
    
    -- Display options
    local displayLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayLabel:SetPoint("TOPLEFT", rulesLabel, "BOTTOMLEFT", 0, -160)
    displayLabel:SetText("Display Options:")
    
    local showNameCheck = CreateFrame("CheckButton", "HealIQShowNameCheck", content, "UICheckButtonTemplate")
    showNameCheck:SetPoint("TOPLEFT", displayLabel, "BOTTOMLEFT", 0, -10)
    showNameCheck.text = showNameCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showNameCheck.text:SetPoint("LEFT", showNameCheck, "RIGHT", 5, 0)
    showNameCheck.text:SetText("Show spell names")
    showNameCheck:SetScript("OnClick", function(self)
        HealIQ.db.ui.showSpellName = self:GetChecked()
        if HealIQ.UI then
            HealIQ.UI:SetShowSpellName(self:GetChecked())
        end
    end)
    optionsFrame.showNameCheck = showNameCheck
    
    local showCooldownCheck = CreateFrame("CheckButton", "HealIQShowCooldownCheck", content, "UICheckButtonTemplate")
    showCooldownCheck:SetPoint("TOPLEFT", showNameCheck, "BOTTOMLEFT", 0, -5)
    showCooldownCheck.text = showCooldownCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showCooldownCheck.text:SetPoint("LEFT", showCooldownCheck, "RIGHT", 5, 0)
    showCooldownCheck.text:SetText("Show cooldown spirals")
    showCooldownCheck:SetScript("OnClick", function(self)
        HealIQ.db.ui.showCooldown = self:GetChecked()
        if HealIQ.UI then
            HealIQ.UI:SetShowCooldown(self:GetChecked())
        end
    end)
    optionsFrame.showCooldownCheck = showCooldownCheck
    
    -- Close button
    local closeButton = CreateFrame("Button", "HealIQCloseButton", content, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 22)
    closeButton:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        optionsFrame:Hide()
    end)
    
    -- Initially hide
    optionsFrame:Hide()
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

function UI:ToggleOptionsFrame()
    if optionsFrame then
        if optionsFrame:IsShown() then
            optionsFrame:Hide()
        else
            self:UpdateOptionsFrame()
            optionsFrame:Show()
        end
    end
end

function UI:UpdateOptionsFrame()
    if not optionsFrame then
        return
    end
    
    -- Update enable checkbox
    if optionsFrame.enableCheck then
        optionsFrame.enableCheck:SetChecked(HealIQ.db.enabled)
    end
    
    -- Update scale slider
    if optionsFrame.scaleSlider then
        optionsFrame.scaleSlider:SetValue(HealIQ.db.ui.scale)
    end
    
    -- Update lock button text
    if optionsFrame.lockButton then
        optionsFrame.lockButton:SetText(HealIQ.db.ui.locked and "Unlock UI" or "Lock UI")
    end
    
    -- Update rule checkboxes
    if optionsFrame.ruleChecks then
        for rule, checkbox in pairs(optionsFrame.ruleChecks) do
            checkbox:SetChecked(HealIQ.db.rules[rule])
        end
    end
    
    -- Update display option checkboxes
    if optionsFrame.showNameCheck then
        optionsFrame.showNameCheck:SetChecked(HealIQ.db.ui.showSpellName)
    end
    
    if optionsFrame.showCooldownCheck then
        optionsFrame.showCooldownCheck:SetChecked(HealIQ.db.ui.showCooldown)
    end
end

HealIQ.UI = UI
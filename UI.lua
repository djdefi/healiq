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
local queueFrame = nil
local queueIcons = {}
local isDragging = false
local minimapButton = nil
local optionsFrame = nil

-- Constants
local FRAME_SIZE = 64
local ICON_SIZE = 48

function UI:Initialize()
    HealIQ:SafeCall(function()
        self:CreateMainFrame()
        self:CreateMinimapButton()
        self:CreateOptionsFrame()
        self:SetupEventHandlers()
        HealIQ:Print("UI initialized")
    end)
end

function UI:CreateMainFrame()
    -- Determine total frame size based on queue settings
    local queueSize = HealIQ.db.ui.queueSize or 3
    local queueLayout = HealIQ.db.ui.queueLayout or "horizontal"
    local queueSpacing = HealIQ.db.ui.queueSpacing or 8
    
    local frameWidth = FRAME_SIZE
    local frameHeight = FRAME_SIZE
    
    if HealIQ.db.ui.showQueue then
        if queueLayout == "horizontal" then
            frameWidth = frameWidth + (queueSize - 1) * (ICON_SIZE + queueSpacing)
        else
            frameHeight = frameHeight + (queueSize - 1) * (ICON_SIZE + queueSpacing)
        end
    end
    
    -- Create main container frame
    mainFrame = CreateFrame("Frame", "HealIQMainFrame", UIParent)
    mainFrame:SetSize(frameWidth, frameHeight)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", HealIQ.db.ui.x, HealIQ.db.ui.y)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    
    -- Create background with improved styling
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)
    bg:SetAlpha(0.6)
    
    -- Create border for better visual definition
    local border = mainFrame:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    border:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 1, -1)
    border:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -1, 1)
    
    -- Store border reference for ToggleLock function
    mainFrame.border = border
    
    -- Create primary spell icon frame (current suggestion)
    iconFrame = CreateFrame("Frame", "HealIQIconFrame", mainFrame)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("LEFT", mainFrame, "LEFT", (FRAME_SIZE - ICON_SIZE) / 2, 0)
    
    -- Create spell icon texture with improved styling
    local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop edges for cleaner look
    iconFrame.icon = iconTexture
    
    -- Create glow effect for primary icon
    local glow = iconFrame:CreateTexture(nil, "OVERLAY")
    glow:SetSize(ICON_SIZE + 8, ICON_SIZE + 8)
    glow:SetPoint("CENTER")
    glow:SetColorTexture(1, 1, 0, 0.4) -- Yellow glow
    glow:SetBlendMode("ADD")
    iconFrame.glow = glow
    
    -- Create pulsing animation for the glow
    local glowAnimation = glow:CreateAnimationGroup()
    glowAnimation:SetLooping("BOUNCE")
    
    local fadeIn = glowAnimation:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.2)
    fadeIn:SetToAlpha(0.6)
    fadeIn:SetDuration(1.0)
    fadeIn:SetSmoothing("IN_OUT")
    
    local fadeOut = glowAnimation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.6)
    fadeOut:SetToAlpha(0.2)
    fadeOut:SetDuration(1.0)
    fadeOut:SetSmoothing("IN_OUT")
    
    glowAnimation:Play()
    iconFrame.glowAnimation = glowAnimation
    
    -- Create spell name text
    spellNameText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellNameText:SetPoint("TOP", iconFrame, "BOTTOM", 0, -2)
    spellNameText:SetTextColor(1, 1, 1, 1)
    spellNameText:SetShadowColor(0, 0, 0, 1)
    spellNameText:SetShadowOffset(1, -1)
    
    -- Create cooldown frame
    cooldownFrame = CreateFrame("Cooldown", "HealIQCooldownFrame", iconFrame, "CooldownFrameTemplate")
    cooldownFrame:SetAllPoints()
    cooldownFrame:SetDrawEdge(false)
    cooldownFrame:SetDrawSwipe(true)
    cooldownFrame:SetReverse(true)
    
    -- Create queue frame
    self:CreateQueueFrame()
    
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
    
    -- Create button background with circular masking
    local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")
    bg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Create circular mask for the background
    local mask = minimapButton:CreateMaskTexture()
    mask:SetAllPoints(bg)
    mask:SetTexture("Interface\\MINIMAP\\UI-Minimap-Background", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bg:AddMaskTexture(mask)
    
    -- Create button icon with circular masking
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Nature_Rejuvenation")
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- Apply circular mask to the icon as well
    local iconMask = minimapButton:CreateMaskTexture()
    iconMask:SetAllPoints(icon)
    iconMask:SetTexture("Interface\\MINIMAP\\UI-Minimap-Background", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(iconMask)
    
    minimapButton.icon = icon
    
    -- Position on minimap using angle-based positioning
    local savedAngle = HealIQ.db.ui.minimapAngle or -math.pi/4 -- Default to top-right
    local mx, my = Minimap:GetCenter()
    local minimapRadius = Minimap:GetWidth() / 2
    local buttonRadius = minimapButton:GetWidth() / 2
    local radius = minimapRadius - buttonRadius - 2
    
    local x = mx + radius * math.cos(savedAngle)
    local y = my + radius * math.sin(savedAngle)
    minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    
    -- Make it draggable around minimap
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    
    minimapButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Keep button on minimap edge and save position
        local dragX, dragY = self:GetCenter()
        local mapX, mapY = Minimap:GetCenter()
        local angle = math.atan2(dragY - mapY, dragX - mapX)
        
        -- Calculate proper radius based on minimap size
        local mapRadius = Minimap:GetWidth() / 2
        local btnRadius = self:GetWidth() / 2
        local finalRadius = mapRadius - btnRadius - 2 -- 2 pixel buffer
        
        local newX = mapX + finalRadius * math.cos(angle)
        local newY = mapY + finalRadius * math.sin(angle)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", newX, newY)
        
        -- Save minimap button position as angle for consistency
        HealIQ.db.ui.minimapAngle = angle
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
        GameTooltip:AddLine("HealIQ v" .. HealIQ.version, 1, 1, 1)
        GameTooltip:AddLine("Smart healing suggestions for Restoration Druids", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: Open Options", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Toggle Display", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag: Move Button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

function UI:CreateQueueFrame()
    if not HealIQ.db.ui.showQueue then
        return
    end
    
    local queueSize = HealIQ.db.ui.queueSize or 3
    local queueLayout = HealIQ.db.ui.queueLayout or "horizontal"
    local queueSpacing = HealIQ.db.ui.queueSpacing or 8
    local queueIconSize = math.floor(ICON_SIZE * (HealIQ.db.ui.queueScale or 0.75)) -- Configurable queue icon size
    
    -- Create queue container frame
    queueFrame = CreateFrame("Frame", "HealIQQueueFrame", mainFrame)
    
    if queueLayout == "horizontal" then
        queueFrame:SetSize((queueSize - 1) * (queueIconSize + queueSpacing), queueIconSize)
        queueFrame:SetPoint("LEFT", iconFrame, "RIGHT", queueSpacing, 0)
    else
        queueFrame:SetSize(queueIconSize, (queueSize - 1) * (queueIconSize + queueSpacing))
        queueFrame:SetPoint("TOP", iconFrame, "BOTTOM", 0, -queueSpacing - 20) -- Account for spell name
    end
    
    -- Create queue icons
    queueIcons = {}
    for i = 1, queueSize - 1 do -- -1 because primary icon is separate
        local queueIcon = CreateFrame("Frame", "HealIQQueueIcon" .. i, queueFrame)
        queueIcon:SetSize(queueIconSize, queueIconSize)
        
        if queueLayout == "horizontal" then
            queueIcon:SetPoint("LEFT", queueFrame, "LEFT", (i - 1) * (queueIconSize + queueSpacing), 0)
        else
            queueIcon:SetPoint("TOP", queueFrame, "TOP", 0, -(i - 1) * (queueIconSize + queueSpacing))
        end
        
        -- Create icon texture
        local texture = queueIcon:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        texture:SetAlpha(0.7) -- Slightly transparent for queue items
        queueIcon.icon = texture
        
        -- Create border for queue items
        local border = queueIcon:CreateTexture(nil, "BORDER")
        border:SetSize(queueIconSize + 2, queueIconSize + 2)
        border:SetPoint("CENTER")
        border:SetColorTexture(0.3, 0.6, 1, 0.8) -- Blue border for queue items
        queueIcon.border = border
        
        -- Add subtle shadow effect
        local shadow = queueIcon:CreateTexture(nil, "BACKGROUND")
        shadow:SetSize(queueIconSize + 4, queueIconSize + 4)
        shadow:SetPoint("CENTER", queueIcon, "CENTER", 2, -2)
        shadow:SetColorTexture(0, 0, 0, 0.5)
        queueIcon.shadow = shadow
        
        -- Add position number overlay
        local positionText = queueIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        positionText:SetPoint("BOTTOMRIGHT", queueIcon, "BOTTOMRIGHT", -2, 2)
        positionText:SetTextColor(1, 1, 1, 0.9)
        positionText:SetText(tostring(i + 1)) -- +1 because primary is position 1
        positionText:SetShadowColor(0, 0, 0, 1)
        positionText:SetShadowOffset(1, -1)
        queueIcon.positionText = positionText
        
        -- Initially hide queue icons
        queueIcon:Hide()
        
        table.insert(queueIcons, queueIcon)
    end
end

function UI:CreateOptionsFrame()
    -- Create main options frame
    optionsFrame = CreateFrame("Frame", "HealIQOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optionsFrame:SetSize(400, 750) -- Increased height for new elements and tooltips
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    
    -- Add icon to title bar
    local titleIcon = optionsFrame:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(16, 16)
    titleIcon:SetPoint("LEFT", optionsFrame.TitleBg, "LEFT", 8, 0)
    titleIcon:SetTexture("Interface\\Icons\\Spell_Nature_Rejuvenation")
    titleIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- Title
    optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    optionsFrame.title:SetPoint("LEFT", titleIcon, "RIGHT", 5, 0)
    optionsFrame.title:SetText("HealIQ Options")
    
    -- Version display
    optionsFrame.version = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    optionsFrame.version:SetPoint("RIGHT", optionsFrame.TitleBg, "RIGHT", -5, 0)
    optionsFrame.version:SetText("v" .. HealIQ.version)
    optionsFrame.version:SetTextColor(0.7, 0.7, 0.7, 1)
    
    -- Content area
    local content = optionsFrame.Inset or optionsFrame
    
    -- General Settings Section
    local generalHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    generalHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    generalHeader:SetText("General Settings")
    generalHeader:SetTextColor(1, 0.8, 0, 1) -- Gold color for headers
    
    -- Enable/Disable checkbox
    local enableCheck = CreateFrame("CheckButton", "HealIQEnableCheck", content, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", generalHeader, "BOTTOMLEFT", 0, -10)
    enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
    enableCheck.text:SetText("Enable HealIQ")
    enableCheck:SetScript("OnClick", function(self)
        HealIQ.db.enabled = self:GetChecked()
        if HealIQ.UI then
            HealIQ.UI:SetEnabled(HealIQ.db.enabled)
        end
    end)
    enableCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Enable HealIQ", 1, 1, 1)
        GameTooltip:AddLine("Enable or disable the entire HealIQ addon.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("When disabled, no suggestions will be shown.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    enableCheck:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.enableCheck = enableCheck
    
    -- Debug mode checkbox
    local debugCheck = CreateFrame("CheckButton", "HealIQDebugCheck", content, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -5)
    debugCheck.text = debugCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugCheck.text:SetPoint("LEFT", debugCheck, "RIGHT", 5, 0)
    debugCheck.text:SetText("Enable Debug Mode")
    debugCheck:SetScript("OnClick", function(self)
        HealIQ.db.debug = self:GetChecked()
        HealIQ.debug = HealIQ.db.debug
        if HealIQ.debug then
            HealIQ:Print("Debug mode enabled")
        else
            HealIQ:Print("Debug mode disabled")
        end
    end)
    debugCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Enable Debug Mode", 1, 1, 1)
        GameTooltip:AddLine("Enable additional debug output and test features.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Useful for troubleshooting issues.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    debugCheck:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.debugCheck = debugCheck
    
    -- UI Settings Section
    local uiHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    uiHeader:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 0, -20)
    uiHeader:SetText("UI Settings")
    uiHeader:SetTextColor(1, 0.8, 0, 1) -- Gold color for headers
    
    -- UI Scale slider (Main UI)
    local scaleSlider = CreateFrame("Slider", "HealIQScaleSlider", content, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", uiHeader, "BOTTOMLEFT", 0, -10)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider.tooltipText = "Adjust the scale of the main suggestion display"
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[scaleSlider:GetName() .. "High"]:SetText("2.0")
    _G[scaleSlider:GetName() .. "Text"]:SetText("Main UI Scale")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        HealIQ.db.ui.scale = value
        if HealIQ.UI then
            HealIQ.UI:SetScale(value)
        end
    end)
    scaleSlider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Main UI Scale", 1, 1, 1)
        GameTooltip:AddLine("Adjust the scale of the main HealIQ display (0.5-2.0).", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    scaleSlider:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.scaleSlider = scaleSlider
    
    -- Queue Scale slider
    local queueScaleSlider = CreateFrame("Slider", "HealIQQueueScaleSlider", content, "OptionsSliderTemplate")
    queueScaleSlider:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -30)
    queueScaleSlider:SetMinMaxValues(0.5, 1.5)
    queueScaleSlider:SetValueStep(0.1)
    queueScaleSlider:SetObeyStepOnDrag(true)
    queueScaleSlider.tooltipText = "Adjust the scale of the queue icons relative to main icon"
    _G[queueScaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[queueScaleSlider:GetName() .. "High"]:SetText("1.5")
    _G[queueScaleSlider:GetName() .. "Text"]:SetText("Queue Scale")
    queueScaleSlider:SetScript("OnValueChanged", function(self, value)
        HealIQ.db.ui.queueScale = value
        if HealIQ.UI then
            HealIQ.UI:RecreateFrames()
        end
    end)
    queueScaleSlider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Queue Scale", 1, 1, 1)
        GameTooltip:AddLine("Adjust the scale of queue icons relative to the main icon (0.5-1.5).", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    queueScaleSlider:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.queueScaleSlider = queueScaleSlider
    
    -- UI Position buttons
    local positionLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    positionLabel:SetPoint("TOPLEFT", queueScaleSlider, "BOTTOMLEFT", 0, -30)
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
    resetPosButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Reset UI Position", 1, 1, 1)
        GameTooltip:AddLine("Moves the main HealIQ display back to the center of the screen.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    resetPosButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
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
    lockButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Lock/Unlock UI Position", 1, 1, 1)
        GameTooltip:AddLine("When unlocked, you can drag the main UI to move it.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click the main UI to toggle lock state.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    lockButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.lockButton = lockButton
    
    -- Frame positioning indicator checkbox
    local showFrameCheck = CreateFrame("CheckButton", "HealIQShowFrameCheck", content, "UICheckButtonTemplate")
    showFrameCheck:SetPoint("TOPLEFT", resetPosButton, "BOTTOMLEFT", 0, -25)
    showFrameCheck.text = showFrameCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showFrameCheck.text:SetPoint("LEFT", showFrameCheck, "RIGHT", 5, 0)
    showFrameCheck.text:SetText("Show frame positioning border")
    showFrameCheck:SetScript("OnClick", function(self)
        HealIQ.db.ui.showPositionBorder = self:GetChecked()
        if HealIQ.UI then
            HealIQ.UI:UpdatePositionBorder()
        end
    end)
    showFrameCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Frame Position Border", 1, 1, 1)
        GameTooltip:AddLine("Shows a visible border around the main frame for easier positioning.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Helpful when arranging the UI layout.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    showFrameCheck:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.showFrameCheck = showFrameCheck
    
    -- Minimap button reset
    local minimapResetButton = CreateFrame("Button", "HealIQMinimapResetButton", content, "UIPanelButtonTemplate")
    minimapResetButton:SetSize(120, 22)
    minimapResetButton:SetPoint("TOPLEFT", showFrameCheck, "BOTTOMLEFT", 0, -5)
    minimapResetButton:SetText("Reset Minimap Icon")
    minimapResetButton:SetScript("OnClick", function()
        if HealIQ.UI then
            HealIQ.UI:ResetMinimapPosition()
        end
    end)
    minimapResetButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Reset Minimap Icon Position", 1, 1, 1)
        GameTooltip:AddLine("Moves the minimap icon back to its default position.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    minimapResetButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Rules section
    local rulesLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rulesLabel:SetPoint("TOPLEFT", minimapResetButton, "BOTTOMLEFT", 0, -20)
    rulesLabel:SetText("Suggestion Rules:")
    rulesLabel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Suggestion Rules", 1, 1, 1)
        GameTooltip:AddLine("Enable or disable specific healing suggestions.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Disabled rules will not appear in the suggestion queue.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    rulesLabel:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Rule checkboxes
    local rules = {
        -- Existing rules
        {key = "wildGrowth", name = "Wild Growth (AoE healing)"},
        {key = "clearcasting", name = "Clearcasting (Regrowth proc)"},
        {key = "lifebloom", name = "Lifebloom (refresh)"},
        {key = "swiftmend", name = "Swiftmend (combo)"},
        {key = "rejuvenation", name = "Rejuvenation (coverage)"},
        
        -- New rules
        {key = "ironbark", name = "Ironbark (damage reduction)"},
        {key = "efflorescence", name = "Efflorescence (ground AoE)"},
        {key = "tranquility", name = "Tranquility (major cooldown)"},
        {key = "incarnationTree", name = "Incarnation (transformation)"},
        {key = "naturesSwiftness", name = "Nature's Swiftness (instant)"},
        {key = "barkskin", name = "Barkskin (self-defense)"},
        {key = "flourish", name = "Flourish (extend HoTs)"},
        {key = "trinket", name = "Trinket usage"},
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
        
        -- Add tooltip for each rule
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(rule.name, 1, 1, 1)
            local tooltip = self:GetTooltipText()
            if tooltip then
                GameTooltip:AddLine(tooltip, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        -- Add custom tooltip text for each rule
        if rule.key == "wildGrowth" then
            check.GetTooltipText = function() return "Suggests Wild Growth when multiple party members have taken recent damage." end
        elseif rule.key == "clearcasting" then
            check.GetTooltipText = function() return "Suggests using Regrowth when you have a Clearcasting proc." end
        elseif rule.key == "lifebloom" then
            check.GetTooltipText = function() return "Suggests refreshing Lifebloom on your target when it's about to expire." end
        elseif rule.key == "swiftmend" then
            check.GetTooltipText = function() return "Suggests Swiftmend when target has HoTs and needs immediate healing." end
        elseif rule.key == "rejuvenation" then
            check.GetTooltipText = function() return "Suggests applying Rejuvenation for basic HoT coverage." end
        elseif rule.key == "ironbark" then
            check.GetTooltipText = function() return "Suggests Ironbark for damage reduction on targets taking heavy damage." end
        elseif rule.key == "efflorescence" then
            check.GetTooltipText = function() return "Suggests Efflorescence for AoE ground healing when group is stacked." end
        elseif rule.key == "tranquility" then
            check.GetTooltipText = function() return "Suggests Tranquility during high group-wide damage situations." end
        elseif rule.key == "incarnationTree" then
            check.GetTooltipText = function() return "Suggests Incarnation for enhanced healing during intensive phases." end
        elseif rule.key == "naturesSwiftness" then
            check.GetTooltipText = function() return "Suggests Nature's Swiftness for instant cast emergency healing." end
        elseif rule.key == "barkskin" then
            check.GetTooltipText = function() return "Suggests Barkskin for personal damage reduction in combat." end
        elseif rule.key == "flourish" then
            check.GetTooltipText = function() return "Suggests Flourish to extend multiple expiring HoTs." end
        elseif rule.key == "trinket" then
            check.GetTooltipText = function() return "Suggests using available healing trinkets." end
        end
        
        optionsFrame.ruleChecks[rule.key] = check
    end
    
    -- Display options
    local displayLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayLabel:SetPoint("TOPLEFT", rulesLabel, "BOTTOMLEFT", 0, -365) -- Adjusted for more rules
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
    showNameCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Spell Names", 1, 1, 1)
        GameTooltip:AddLine("Display the name of the suggested spell below the icon.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    showNameCheck:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
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
    showCooldownCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Cooldown Spirals", 1, 1, 1)
        GameTooltip:AddLine("Display cooldown sweep animations on suggestion icons.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    showCooldownCheck:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.showCooldownCheck = showCooldownCheck
    
    -- Queue options
    local queueLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    queueLabel:SetPoint("TOPLEFT", showCooldownCheck, "BOTTOMLEFT", 0, -20)
    queueLabel:SetText("Queue Display:")
    
    local showQueueCheck = CreateFrame("CheckButton", "HealIQShowQueueCheck", content, "UICheckButtonTemplate")
    showQueueCheck:SetPoint("TOPLEFT", queueLabel, "BOTTOMLEFT", 0, -10)
    showQueueCheck.text = showQueueCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showQueueCheck.text:SetPoint("LEFT", showQueueCheck, "RIGHT", 5, 0)
    showQueueCheck.text:SetText("Show suggestion queue")
    showQueueCheck:SetScript("OnClick", function(self)
        HealIQ.db.ui.showQueue = self:GetChecked()
        if HealIQ.UI then
            HealIQ.UI:RecreateFrames()
        end
    end)
    showQueueCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Suggestion Queue", 1, 1, 1)
        GameTooltip:AddLine("Display upcoming spell suggestions in a queue next to the main icon.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    showQueueCheck:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.showQueueCheck = showQueueCheck
    
    -- Queue size slider
    local queueSizeSlider = CreateFrame("Slider", "HealIQQueueSizeSlider", content, "OptionsSliderTemplate")
    queueSizeSlider:SetPoint("TOPLEFT", showQueueCheck, "BOTTOMLEFT", 0, -20)
    queueSizeSlider:SetMinMaxValues(2, 5)
    queueSizeSlider:SetValueStep(1)
    queueSizeSlider:SetObeyStepOnDrag(true)
    queueSizeSlider.tooltipText = "Number of suggestions to show in queue"
    _G[queueSizeSlider:GetName() .. "Low"]:SetText("2")
    _G[queueSizeSlider:GetName() .. "High"]:SetText("5")
    _G[queueSizeSlider:GetName() .. "Text"]:SetText("Queue Size")
    queueSizeSlider:SetScript("OnValueChanged", function(self, value)
        HealIQ.db.ui.queueSize = math.floor(value)
        if HealIQ.UI then
            HealIQ.UI:RecreateFrames()
        end
    end)
    queueSizeSlider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Queue Size", 1, 1, 1)
        GameTooltip:AddLine("Number of spell suggestions to show in the queue (2-5).", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    queueSizeSlider:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.queueSizeSlider = queueSizeSlider
    
    -- Queue layout dropdown
    local queueLayoutLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    queueLayoutLabel:SetPoint("TOPLEFT", queueSizeSlider, "BOTTOMLEFT", 0, -20)
    queueLayoutLabel:SetText("Queue Layout:")
    
    local queueLayoutButton = CreateFrame("Button", "HealIQQueueLayoutButton", content, "UIPanelButtonTemplate")
    queueLayoutButton:SetSize(100, 22)
    queueLayoutButton:SetPoint("LEFT", queueLayoutLabel, "RIGHT", 10, 0)
    queueLayoutButton:SetText("Horizontal")
    queueLayoutButton:SetScript("OnClick", function(self)
        local newLayout = HealIQ.db.ui.queueLayout == "horizontal" and "vertical" or "horizontal"
        HealIQ.db.ui.queueLayout = newLayout
        self:SetText(newLayout:sub(1,1):upper() .. newLayout:sub(2))
        if HealIQ.UI then
            HealIQ.UI:RecreateFrames()
        end
    end)
    queueLayoutButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Queue Layout", 1, 1, 1)
        GameTooltip:AddLine("Choose whether to display the queue horizontally or vertically.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    queueLayoutButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    optionsFrame.queueLayoutButton = queueLayoutButton
    
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
    HealIQ:SafeCall(function()
        if not mainFrame then
            return
        end
        
        if not suggestion then
            mainFrame:Hide()
            return
        end
        
        -- Show the frame
        mainFrame:Show()
        
        -- Update primary icon
        if iconFrame and iconFrame.icon then
            iconFrame.icon:SetTexture(suggestion.icon)
            iconFrame.icon:SetDesaturated(false)
            
            -- Show glow effect for primary suggestion
            if iconFrame.glow then
                iconFrame.glow:Show()
                if iconFrame.glowAnimation then
                    iconFrame.glowAnimation:Play()
                end
            end
        end
        
        -- Update spell name
        if spellNameText and HealIQ.db.ui.showSpellName then
            spellNameText:SetText(suggestion.name)
            spellNameText:Show()
        else
            if spellNameText then
                spellNameText:Hide()
            end
        end
        
        -- Update cooldown display
        if cooldownFrame and HealIQ.db.ui.showCooldown then
            self:UpdateCooldownDisplay(suggestion)
        end
    end)
end

function UI:UpdateQueue(queue)
    if not HealIQ.db.ui.showQueue or not queueIcons then
        return
    end
    
    -- Hide all queue icons first
    for _, queueIcon in ipairs(queueIcons) do
        queueIcon:Hide()
    end
    
    -- Update queue icons with new suggestions
    for i, suggestion in ipairs(queue) do
        if i > 1 and i <= #queueIcons + 1 then -- Skip first suggestion (it's the primary)
            local queueIcon = queueIcons[i - 1]
            if queueIcon then
                queueIcon.icon:SetTexture(suggestion.icon)
                queueIcon:Show()
                
                -- Add enhanced tooltip for queue items
                queueIcon:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(suggestion.name, 1, 1, 1)
                    GameTooltip:AddLine("Position " .. (i) .. " in queue", 0.7, 0.7, 0.7)
                    GameTooltip:AddLine("Priority: " .. suggestion.priority, 0.5, 0.8, 1)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("This suggestion will appear when higher", 0.6, 0.6, 0.6)
                    GameTooltip:AddLine("priority spells become unavailable.", 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                end)
                
                queueIcon:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            end
        end
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
    else
        HealIQ:Print("UI unlocked (drag to move, right-click to lock)")
    end
    
    -- Update border based on new state
    self:UpdatePositionBorder()
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

function UI:ResetMinimapPosition()
    HealIQ.db.ui.minimapAngle = -math.pi/4 -- Reset to default angle (top-right)
    if minimapButton then
        local mx, my = Minimap:GetCenter()
        local minimapRadius = Minimap:GetWidth() / 2
        local buttonRadius = minimapButton:GetWidth() / 2
        local radius = minimapRadius - buttonRadius - 2
        
        local x = mx + radius * math.cos(HealIQ.db.ui.minimapAngle)
        local y = my + radius * math.sin(HealIQ.db.ui.minimapAngle)
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end
    HealIQ:Print("Minimap icon position reset")
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

function UI:RecreateFrames()
    -- Hide and remove existing frames
    if mainFrame then
        mainFrame:Hide()
        mainFrame = nil
    end
    
    -- Clear references
    iconFrame = nil
    spellNameText = nil
    cooldownFrame = nil
    queueFrame = nil
    queueIcons = {}
    
    -- Recreate the main frame with new settings
    self:CreateMainFrame()
    
    -- Update position and scale
    self:UpdatePosition()
    self:UpdateScale()
    
    HealIQ:Print("UI frames recreated with new settings")
end

function UI:UpdatePositionBorder()
    if mainFrame and mainFrame.border then
        if HealIQ.db.ui.showPositionBorder then
            mainFrame.border:SetColorTexture(0, 1, 1, 0.8) -- Cyan border for positioning
            mainFrame.border:Show()
        else
            -- Hide border or show normal border based on lock state
            if HealIQ.db.ui.locked then
                mainFrame.border:SetColorTexture(1, 0, 0, 0.5) -- Red border when locked
            else
                mainFrame.border:SetColorTexture(0, 1, 0, 0.5) -- Green border when unlocked
            end
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
    
    -- Update debug checkbox
    if optionsFrame.debugCheck then
        optionsFrame.debugCheck:SetChecked(HealIQ.db.debug)
    end
    
    -- Update scale slider
    if optionsFrame.scaleSlider then
        optionsFrame.scaleSlider:SetValue(HealIQ.db.ui.scale)
    end
    
    -- Update queue scale slider
    if optionsFrame.queueScaleSlider then
        optionsFrame.queueScaleSlider:SetValue(HealIQ.db.ui.queueScale or 0.75)
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
    
    -- Update frame positioning checkbox
    if optionsFrame.showFrameCheck then
        optionsFrame.showFrameCheck:SetChecked(HealIQ.db.ui.showPositionBorder)
    end
    
    -- Update queue options
    if optionsFrame.showQueueCheck then
        optionsFrame.showQueueCheck:SetChecked(HealIQ.db.ui.showQueue)
    end
    
    if optionsFrame.queueSizeSlider then
        optionsFrame.queueSizeSlider:SetValue(HealIQ.db.ui.queueSize or 3)
    end
    
    if optionsFrame.queueLayoutButton then
        local layout = HealIQ.db.ui.queueLayout or "horizontal"
        optionsFrame.queueLayoutButton:SetText(layout:sub(1,1):upper() .. layout:sub(2))
    end
end

HealIQ.UI = UI
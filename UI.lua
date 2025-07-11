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
local OPTIONS_FRAME_HEIGHT = 600
local TOOLTIP_LINE_LENGTH = 45

-- Minimap button positioning
local MINIMAP_BUTTON_PIXEL_BUFFER = 2

-- UI Border colors (configurable for accessibility)
local BORDER_COLORS = {
    positioning = {0, 1, 1, 0.8},     -- Cyan for positioning aid
    locked = {1, 0, 0, 0.5},          -- Red when UI is locked
    unlocked = {0, 1, 0, 0.5}         -- Green when UI is unlocked
}

-- Texture paths
local MINIMAP_BACKGROUND_TEXTURE = "Interface\\MINIMAP\\UI-Minimap-Background"

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
    -- Check if database is initialized before accessing UI settings
    if not HealIQ.db or not HealIQ.db.ui then
        HealIQ:LogError("UI:CreateMainFrame called before database initialization")
        return
    end
    
    -- Determine total frame size based on queue settings
    local queueSize = HealIQ.db.ui.queueSize or 3
    local queueLayout = HealIQ.db.ui.queueLayout or "horizontal"
    local queueSpacing = HealIQ.db.ui.queueSpacing or 8
    local padding = 8 -- Consistent padding for all elements
    
    local frameWidth = FRAME_SIZE + (padding * 2)
    local frameHeight = FRAME_SIZE + (padding * 2)
    
    if HealIQ.db.ui.showQueue then
        if queueLayout == "horizontal" then
            frameWidth = frameWidth + (queueSize - 1) * (ICON_SIZE + queueSpacing)
        else
            -- Account for spell name text in vertical layout
            local spellNameHeight = HealIQ.db.ui.showSpellName and 20 or 0
            frameHeight = frameHeight + (queueSize - 1) * (ICON_SIZE + queueSpacing) + spellNameHeight
        end
    end
    
    -- Create main container frame
    mainFrame = CreateFrame("Frame", "HealIQMainFrame", UIParent)
    mainFrame:SetSize(frameWidth, frameHeight)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", HealIQ.db.ui.x, HealIQ.db.ui.y)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    
    -- Create background with improved styling and consistent padding
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", padding, -padding)
    bg:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -padding, padding)
    bg:SetColorTexture(0, 0, 0, 0.4)
    bg:SetAlpha(0.6)
    
    -- Create border for better visual definition with consistent padding
    local border = mainFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", padding - 1, -(padding - 1))
    border:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -(padding - 1), padding - 1)
    border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    
    -- Store border reference for ToggleLock function
    mainFrame.border = border
    
    -- Create primary spell icon frame (current suggestion) with consistent padding
    iconFrame = CreateFrame("Frame", "HealIQIconFrame", mainFrame)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("LEFT", mainFrame, "LEFT", padding + (FRAME_SIZE - ICON_SIZE) / 2, 0)
    
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
    
    -- Create spell name text with consistent spacing
    spellNameText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellNameText:SetPoint("TOP", iconFrame, "BOTTOM", 0, -4) -- Consistent spacing
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

-- Helper function for minimap button positioning
function UI:CalculateMinimapButtonRadius()
    if not minimapButton then
        return 1
    end
    
    local minimapRadius = Minimap:GetWidth() / 2
    local buttonRadius = minimapButton:GetWidth() / 2
    -- Fixed: Use minimapRadius + MINIMAP_BUTTON_PIXEL_BUFFER to place button ON the edge
    local radius = minimapRadius + MINIMAP_BUTTON_PIXEL_BUFFER
    
    if radius <= 0 then
        radius = 1 -- Ensure a minimum positive radius
    end
    
    return radius
end

function UI:CreateMinimapButton()
    if not HealIQ.db or not HealIQ.db.ui then
        HealIQ:LogError("UI:CreateMinimapButton called before database initialization")
        return
    end
    
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
    mask:SetTexture(MINIMAP_BACKGROUND_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
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
    iconMask:SetTexture(MINIMAP_BACKGROUND_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(iconMask)
    
    minimapButton.icon = icon
    
    -- Position on minimap using angle-based positioning
    local savedAngle = HealIQ.db.ui.minimapAngle or -math.pi/4 -- Default to top-right
    local mx, my = Minimap:GetCenter()
    local radius = self:CalculateMinimapButtonRadius()
    
    local x = mx + radius * math.cos(savedAngle)
    local y = my + radius * math.sin(savedAngle)
    minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    
    -- Make it draggable around minimap
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    
    minimapButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
        -- Store original border visibility
        if self.icon then
            self.originalAlpha = self.icon:GetAlpha()
        end
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Keep button on minimap edge and save position
        local dragX, dragY = self:GetCenter()
        local mapX, mapY = Minimap:GetCenter()
        local angle = math.atan2(dragY - mapY, dragX - mapX)
        
        -- Use helper method for radius calculation
        local finalRadius = UI:CalculateMinimapButtonRadius()
        
        local newX = mapX + finalRadius * math.cos(angle)
        local newY = mapY + finalRadius * math.sin(angle)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", newX, newY)
        
        -- Restore icon visibility if it was affected
        if self.icon and self.originalAlpha then
            self.icon:SetAlpha(self.originalAlpha)
        end
        
        -- Save minimap button position as angle for consistency
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.minimapAngle = angle
        end
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
    if not HealIQ.db or not HealIQ.db.ui then
        HealIQ:LogError("UI:CreateQueueFrame called before database initialization")
        return
    end
    
    local queueSize = HealIQ.db.ui.queueSize or 3
    local queueLayout = HealIQ.db.ui.queueLayout or "horizontal"
    local queueSpacing = HealIQ.db.ui.queueSpacing or 8
    local queueIconSize = math.floor(ICON_SIZE * (HealIQ.db.ui.queueScale or 0.75)) -- Configurable queue icon size
    local padding = 8 -- Consistent with main frame padding
    
    -- Create queue container frame (always create, but conditionally show)
    queueFrame = CreateFrame("Frame", "HealIQQueueFrame", mainFrame)
    
    if queueLayout == "horizontal" then
        queueFrame:SetSize((queueSize - 1) * (queueIconSize + queueSpacing), queueIconSize)
        queueFrame:SetPoint("LEFT", iconFrame, "RIGHT", queueSpacing + padding, 0)
    else
        queueFrame:SetSize(queueIconSize, (queueSize - 1) * (queueIconSize + queueSpacing))
        -- Fixed: Better vertical positioning that accounts for spell name text and padding
        local verticalOffset = HealIQ.db.ui.showSpellName and -(queueSpacing + 25) or -(queueSpacing + padding)
        queueFrame:SetPoint("TOP", iconFrame, "BOTTOM", 0, verticalOffset)
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
        
        -- Create border for queue items with improved visibility
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
        
        -- Add position number overlay with better positioning for vertical layout
        local positionText = queueIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if queueLayout == "vertical" then
            positionText:SetPoint("LEFT", queueIcon, "RIGHT", 6, 0) -- Consistent spacing
        else
            positionText:SetPoint("BOTTOMRIGHT", queueIcon, "BOTTOMRIGHT", -2, 2)
        end
        positionText:SetTextColor(1, 1, 1, 0.9)
        positionText:SetText(tostring(i + 1)) -- +1 because primary is position 1
        positionText:SetShadowColor(0, 0, 0, 1)
        positionText:SetShadowOffset(1, -1)
        queueIcon.positionText = positionText
        
        -- Initially hide queue icons
        queueIcon:Hide()
        
        table.insert(queueIcons, queueIcon)
    end
    
    -- Show/hide queue frame based on settings
    if HealIQ.db.ui.showQueue then
        queueFrame:Show()
    else
        queueFrame:Hide()
    end
end

function UI:CreateOptionsFrame()
    -- Create main options frame with reduced height
    optionsFrame = CreateFrame("Frame", "HealIQOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optionsFrame:SetSize(400, OPTIONS_FRAME_HEIGHT) -- Reduced height, content will be organized in tabs
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
    
    -- Create tab system
    self:CreateOptionsTabs(content)
    
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

function UI:CreateOptionsTabs(parent)
    -- Create tab buttons
    local tabHeight = 25
    local tabWidth = 95
    local tabs = {
        {name = "General", id = "general"},
        {name = "Display", id = "display"},
        {name = "Rules", id = "rules"},
        {name = "Queue", id = "queue"}
    }
    
    optionsFrame.tabs = {}
    optionsFrame.tabPanels = {}
    
    for i, tab in ipairs(tabs) do
        -- Create tab button
        local tabButton = CreateFrame("Button", "HealIQTab" .. tab.id, parent, "TabButtonTemplate")
        tabButton:SetSize(tabWidth, tabHeight)
        tabButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 10 + (i-1) * (tabWidth - 10), -5)
        tabButton:SetText(tab.name)
        tabButton.tabId = tab.id
        
        tabButton:SetScript("OnClick", function(self)
            UI:ShowOptionsTab(self.tabId)
        end)
        
        optionsFrame.tabs[tab.id] = tabButton
        
        -- Create tab panel
        local panel = CreateFrame("Frame", "HealIQPanel" .. tab.id, parent)
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -35)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 40)
        panel:Hide()
        
        optionsFrame.tabPanels[tab.id] = panel
    end
    
    -- Create content for each tab
    self:CreateGeneralTab(optionsFrame.tabPanels.general)
    self:CreateDisplayTab(optionsFrame.tabPanels.display)
    self:CreateRulesTab(optionsFrame.tabPanels.rules)
    self:CreateQueueTab(optionsFrame.tabPanels.queue)
    
    -- Show first tab by default
    self:ShowOptionsTab("general")
end
function UI:ShowOptionsTab(tabId)
    -- Hide all panels and reset tab states
    for id, panel in pairs(optionsFrame.tabPanels) do
        panel:Hide()
        optionsFrame.tabs[id]:SetNormalTexture("")
        optionsFrame.tabs[id]:SetPushedTexture("")
    end
    
    -- Show selected panel and mark tab as active
    if optionsFrame.tabPanels[tabId] then
        optionsFrame.tabPanels[tabId]:Show()
        optionsFrame.tabs[tabId]:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab-ActiveLeft")
        optionsFrame.tabs[tabId]:SetPushedTexture("Interface\\ChatFrame\\ChatFrameTab-ActiveLeft")
    end
end

function UI:CreateGeneralTab(panel)
    local yOffset = -10
    
    -- General Settings Section
    local generalHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    generalHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    generalHeader:SetText("General Settings")
    generalHeader:SetTextColor(1, 0.8, 0, 1)
    yOffset = yOffset - 30
    
    -- Enable/Disable checkbox
    local enableCheck = CreateFrame("CheckButton", "HealIQEnableCheck", panel, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
    enableCheck.text:SetText("Enable HealIQ")
    enableCheck:SetScript("OnClick", function(self)
        if HealIQ.db then
            HealIQ.db.enabled = self:GetChecked()
            if HealIQ.UI then
                HealIQ.UI:SetEnabled(HealIQ.db.enabled)
            end
        end
    end)
    self:AddTooltip(enableCheck, "Enable HealIQ", "Enable or disable the entire HealIQ addon.\nWhen disabled, no suggestions will be shown.")
    optionsFrame.enableCheck = enableCheck
    yOffset = yOffset - 30
    
    -- Debug mode checkbox
    local debugCheck = CreateFrame("CheckButton", "HealIQDebugCheck", panel, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    debugCheck.text = debugCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugCheck.text:SetPoint("LEFT", debugCheck, "RIGHT", 5, 0)
    debugCheck.text:SetText("Enable Debug Mode")
    debugCheck:SetScript("OnClick", function(self)
        if HealIQ.db then
            HealIQ.db.debug = self:GetChecked()
            HealIQ.debug = HealIQ.db.debug
            if HealIQ.debug then
                HealIQ:Print("Debug mode enabled")
            else
                HealIQ:Print("Debug mode disabled")
            end
        end
    end)
    self:AddTooltip(debugCheck, "Enable Debug Mode", "Enable additional debug output and test features.\nUseful for troubleshooting issues.")
    optionsFrame.debugCheck = debugCheck
    yOffset = yOffset - 30
    
    -- File logging checkbox
    local loggingCheck = CreateFrame("CheckButton", "HealIQLoggingCheck", panel, "UICheckButtonTemplate")
    loggingCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    loggingCheck.text = loggingCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loggingCheck.text:SetPoint("LEFT", loggingCheck, "RIGHT", 5, 0)
    loggingCheck.text:SetText("Enable File Logging")
    loggingCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.logging then
            HealIQ.db.logging.enabled = self:GetChecked()
            if HealIQ.db.logging.enabled then
                HealIQ:InitializeLogging()
                HealIQ:Message("File logging enabled")
            else
                HealIQ:Message("File logging disabled")
            end
        end
    end)
    self:AddTooltip(loggingCheck, "Enable File Logging", "Enable logging debug information to file for troubleshooting.\nLogs are stored in memory and can be exported via /healiq dump.")
    optionsFrame.loggingCheck = loggingCheck
    yOffset = yOffset - 30
    
    -- Verbose logging checkbox
    local verboseCheck = CreateFrame("CheckButton", "HealIQVerboseCheck", panel, "UICheckButtonTemplate")
    verboseCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    verboseCheck.text = verboseCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    verboseCheck.text:SetPoint("LEFT", verboseCheck, "RIGHT", 5, 0)
    verboseCheck.text:SetText("Verbose Logging")
    verboseCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.logging then
            HealIQ.db.logging.verbose = self:GetChecked()
            local status = HealIQ.db.logging.verbose and "enabled" or "disabled"
            HealIQ:Message("Verbose logging " .. status)
        end
    end)
    self:AddTooltip(verboseCheck, "Verbose Logging", "Enable detailed logging of rule processing and suggestions.\nRequires File Logging to be enabled.")
    optionsFrame.verboseCheck = verboseCheck
    yOffset = yOffset - 30
    
    -- Session stats checkbox
    local statsCheck = CreateFrame("CheckButton", "HealIQStatsCheck", panel, "UICheckButtonTemplate")
    statsCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    statsCheck.text = statsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsCheck.text:SetPoint("LEFT", statsCheck, "RIGHT", 5, 0)
    statsCheck.text:SetText("Session Statistics")
    statsCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.logging then
            HealIQ.db.logging.sessionStats = self:GetChecked()
            local status = HealIQ.db.logging.sessionStats and "enabled" or "disabled"
            HealIQ:Message("Session statistics " .. status)
        end
    end)
    self:AddTooltip(statsCheck, "Session Statistics", "Track session statistics like suggestions generated, rules processed, etc.\nView statistics with /healiq status or /healiq dump.")
    optionsFrame.statsCheck = statsCheck
    yOffset = yOffset - 50
    
    -- UI Position Section
    local positionHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    positionHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    positionHeader:SetText("Position Settings")
    positionHeader:SetTextColor(1, 0.8, 0, 1)
    yOffset = yOffset - 30
    
    -- UI Position buttons
    local resetPosButton = CreateFrame("Button", "HealIQResetPosButton", panel, "UIPanelButtonTemplate")
    resetPosButton:SetSize(120, 22)
    resetPosButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    resetPosButton:SetText("Reset UI Position")
    resetPosButton:SetScript("OnClick", function()
        if HealIQ.UI then
            HealIQ.UI:ResetPosition()
        end
    end)
    self:AddTooltip(resetPosButton, "Reset UI Position", "Moves the main HealIQ display back to the center of the screen.")
    yOffset = yOffset - 30
    
    local lockButton = CreateFrame("Button", "HealIQLockButton", panel, "UIPanelButtonTemplate")
    lockButton:SetSize(100, 22)
    lockButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    lockButton:SetText("Lock UI")
    lockButton:SetScript("OnClick", function()
        if HealIQ.UI then
            HealIQ.UI:ToggleLock()
            UI:UpdateOptionsFrame()
        end
    end)
    self:AddTooltip(lockButton, "Lock/Unlock UI Position", "When unlocked, you can drag the main UI to move it.\nRight-click the main UI to toggle lock state.")
    optionsFrame.lockButton = lockButton
    yOffset = yOffset - 30
    
    -- Frame positioning indicator checkbox
    local showFrameCheck = CreateFrame("CheckButton", "HealIQShowFrameCheck", panel, "UICheckButtonTemplate")
    showFrameCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    showFrameCheck.text = showFrameCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showFrameCheck.text:SetPoint("LEFT", showFrameCheck, "RIGHT", 5, 0)
    showFrameCheck.text:SetText("Show frame positioning border")
    showFrameCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.showPositionBorder = self:GetChecked()
            if HealIQ.UI then
                HealIQ.UI:UpdatePositionBorder()
            end
        end
    end)
    self:AddTooltip(showFrameCheck, "Show Frame Position Border", "Shows a visible border around the main frame for easier positioning.\nHelpful when arranging the UI layout.")
    optionsFrame.showFrameCheck = showFrameCheck
    yOffset = yOffset - 30
    
    -- Minimap button reset
    local minimapResetButton = CreateFrame("Button", "HealIQMinimapResetButton", panel, "UIPanelButtonTemplate")
    minimapResetButton:SetSize(140, 22)
    minimapResetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    minimapResetButton:SetText("Reset Minimap Icon")
    minimapResetButton:SetScript("OnClick", function()
        if HealIQ.UI then
            HealIQ.UI:ResetMinimapPosition()
        end
    end)
    self:AddTooltip(minimapResetButton, "Reset Minimap Icon Position", "Moves the minimap icon back to its default position.")
end
function UI:CreateDisplayTab(panel)
    local yOffset = -10
    
    -- Display Settings Section
    local displayHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    displayHeader:SetText("Display Settings")
    displayHeader:SetTextColor(1, 0.8, 0, 1)
    yOffset = yOffset - 30
    
    -- UI Scale slider (Main UI)
    local scaleSlider = CreateFrame("Slider", "HealIQScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider.tooltipText = "Adjust the scale of the main suggestion display"
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[scaleSlider:GetName() .. "High"]:SetText("2.0")
    _G[scaleSlider:GetName() .. "Text"]:SetText("Main UI Scale")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        if HealIQ.UI then
            HealIQ.UI:SetScale(value)
        end
    end)
    self:AddTooltip(scaleSlider, "Main UI Scale", "Adjust the scale of the main HealIQ display (0.5-2.0).")
    optionsFrame.scaleSlider = scaleSlider
    yOffset = yOffset - 40
    
    -- Display options
    local showNameCheck = CreateFrame("CheckButton", "HealIQShowNameCheck", panel, "UICheckButtonTemplate")
    showNameCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    showNameCheck.text = showNameCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showNameCheck.text:SetPoint("LEFT", showNameCheck, "RIGHT", 5, 0)
    showNameCheck.text:SetText("Show spell names")
    showNameCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.showSpellName = self:GetChecked()
            if HealIQ.UI then
                HealIQ.UI:SetShowSpellName(self:GetChecked())
            end
        end
    end)
    self:AddTooltip(showNameCheck, "Show Spell Names", "Display the name of the suggested spell below the icon.")
    optionsFrame.showNameCheck = showNameCheck
    yOffset = yOffset - 30
    
    local showCooldownCheck = CreateFrame("CheckButton", "HealIQShowCooldownCheck", panel, "UICheckButtonTemplate")
    showCooldownCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    showCooldownCheck.text = showCooldownCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showCooldownCheck.text:SetPoint("LEFT", showCooldownCheck, "RIGHT", 5, 0)
    showCooldownCheck.text:SetText("Show cooldown spirals")
    showCooldownCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.showCooldown = self:GetChecked()
            if HealIQ.UI then
                HealIQ.UI:SetShowCooldown(self:GetChecked())
            end
        end
    end)
    self:AddTooltip(showCooldownCheck, "Show Cooldown Spirals", "Display cooldown sweep animations on suggestion icons.")
    optionsFrame.showCooldownCheck = showCooldownCheck
end

function UI:CreateQueueTab(panel)
    local yOffset = -10
    
    -- Queue Settings Section
    local queueHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    queueHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    queueHeader:SetText("Queue Display Settings")
    queueHeader:SetTextColor(1, 0.8, 0, 1)
    yOffset = yOffset - 30
    
    -- Queue options
    local showQueueCheck = CreateFrame("CheckButton", "HealIQShowQueueCheck", panel, "UICheckButtonTemplate")
    showQueueCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    showQueueCheck.text = showQueueCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showQueueCheck.text:SetPoint("LEFT", showQueueCheck, "RIGHT", 5, 0)
    showQueueCheck.text:SetText("Show suggestion queue")
    showQueueCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.showQueue = self:GetChecked()
            if HealIQ.UI then
                HealIQ.UI:RecreateFrames()
            end
        end
    end)
    self:AddTooltip(showQueueCheck, "Show Suggestion Queue", "Display upcoming spell suggestions in a queue next to the main icon.")
    optionsFrame.showQueueCheck = showQueueCheck
    yOffset = yOffset - 40
    
    -- Queue Scale slider
    local queueScaleSlider = CreateFrame("Slider", "HealIQQueueScaleSlider", panel, "OptionsSliderTemplate")
    queueScaleSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    queueScaleSlider:SetMinMaxValues(0.5, 1.5)
    queueScaleSlider:SetValueStep(0.1)
    queueScaleSlider:SetObeyStepOnDrag(true)
    queueScaleSlider.tooltipText = "Adjust the scale of the queue icons relative to main icon"
    _G[queueScaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[queueScaleSlider:GetName() .. "High"]:SetText("1.5")
    _G[queueScaleSlider:GetName() .. "Text"]:SetText("Queue Scale")
    queueScaleSlider:SetScript("OnValueChanged", function(self, value)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.queueScale = value
            if HealIQ.UI then
                HealIQ.UI:RecreateFrames()
            end
        end
    end)
    self:AddTooltip(queueScaleSlider, "Queue Scale", "Adjust the scale of queue icons relative to the main icon (0.5-1.5).")
    optionsFrame.queueScaleSlider = queueScaleSlider
    yOffset = yOffset - 50
    
    -- Queue size slider
    local queueSizeSlider = CreateFrame("Slider", "HealIQQueueSizeSlider", panel, "OptionsSliderTemplate")
    queueSizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    queueSizeSlider:SetMinMaxValues(2, 5)
    queueSizeSlider:SetValueStep(1)
    queueSizeSlider:SetObeyStepOnDrag(true)
    queueSizeSlider.tooltipText = "Number of suggestions to show in queue"
    _G[queueSizeSlider:GetName() .. "Low"]:SetText("2")
    _G[queueSizeSlider:GetName() .. "High"]:SetText("5")
    _G[queueSizeSlider:GetName() .. "Text"]:SetText("Queue Size")
    queueSizeSlider:SetScript("OnValueChanged", function(self, value)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.queueSize = math.floor(value)
            if HealIQ.UI then
                HealIQ.UI:RecreateFrames()
            end
        end
    end)
    self:AddTooltip(queueSizeSlider, "Queue Size", "Number of spell suggestions to show in the queue (2-5).")
    optionsFrame.queueSizeSlider = queueSizeSlider
    yOffset = yOffset - 50
    
    -- Queue layout dropdown
    local queueLayoutLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    queueLayoutLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    queueLayoutLabel:SetText("Queue Layout:")
    
    local queueLayoutButton = CreateFrame("Button", "HealIQQueueLayoutButton", panel, "UIPanelButtonTemplate")
    queueLayoutButton:SetSize(100, 22)
    queueLayoutButton:SetPoint("LEFT", queueLayoutLabel, "RIGHT", 10, 0)
    queueLayoutButton:SetText("Horizontal")
    queueLayoutButton:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            local newLayout = HealIQ.db.ui.queueLayout == "horizontal" and "vertical" or "horizontal"
            HealIQ.db.ui.queueLayout = newLayout
            self:SetText(newLayout:sub(1,1):upper() .. newLayout:sub(2))
            if HealIQ.UI then
                HealIQ.UI:RecreateFrames()
            end
        end
    end)
    self:AddTooltip(queueLayoutButton, "Queue Layout", "Choose whether to display the queue horizontally or vertically.")
    optionsFrame.queueLayoutButton = queueLayoutButton
end
function UI:CreateRulesTab(panel)
    local yOffset = -10
    
    -- Rules section
    local rulesHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rulesHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    rulesHeader:SetText("Suggestion Rules")
    rulesHeader:SetTextColor(1, 0.8, 0, 1)
    yOffset = yOffset - 30
    
    local rulesDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rulesDesc:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    rulesDesc:SetText("Enable or disable specific healing suggestions")
    rulesDesc:SetTextColor(0.8, 0.8, 0.8, 1)
    yOffset = yOffset - 25
    
    -- Rule checkboxes organized into categories
    local rules = {
        -- Emergency spells
        {key = "tranquility", name = "Tranquility (major AoE cooldown)", category = "Emergency"},
        {key = "incarnationTree", name = "Incarnation (transformation)", category = "Emergency"},
        {key = "naturesSwiftness", name = "Nature's Swiftness (instant cast)", category = "Emergency"},
        
        -- Core healing
        {key = "wildGrowth", name = "Wild Growth (AoE healing)", category = "Core"},
        {key = "efflorescence", name = "Efflorescence (ground AoE)", category = "Core"},
        {key = "swiftmend", name = "Swiftmend (combo)", category = "Core"},
        {key = "clearcasting", name = "Clearcasting (Regrowth proc)", category = "Core"},
        
        -- HoT management
        {key = "lifebloom", name = "Lifebloom (refresh)", category = "HoTs"},
        {key = "rejuvenation", name = "Rejuvenation (coverage)", category = "HoTs"},
        {key = "flourish", name = "Flourish (extend HoTs)", category = "HoTs"},
        
        -- Utility
        {key = "ironbark", name = "Ironbark (damage reduction)", category = "Utility"},
        {key = "barkskin", name = "Barkskin (self-defense)", category = "Utility"},
        {key = "trinket", name = "Trinket usage", category = "Utility"},
    }
    
    optionsFrame.ruleChecks = {}
    local currentCategory = nil
    local categoryYOffset = 0
    
    for i, rule in ipairs(rules) do
        -- Add category header if needed
        if rule.category ~= currentCategory then
            currentCategory = rule.category
            categoryYOffset = yOffset - 10
            
            local categoryHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            categoryHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, categoryYOffset)
            categoryHeader:SetText(rule.category .. " Spells:")
            categoryHeader:SetTextColor(0.8, 1, 0.8, 1)
            yOffset = categoryYOffset - 25
        end
        
        local check = CreateFrame("CheckButton", "HealIQRule" .. rule.key, panel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, yOffset)
        check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        check.text:SetPoint("LEFT", check, "RIGHT", 5, 0)
        check.text:SetText(rule.name)
        check:SetScript("OnClick", function(self)
            if HealIQ.db and HealIQ.db.rules then
                HealIQ.db.rules[rule.key] = self:GetChecked()
            end
        end)
        
        -- Add tooltip for each rule
        local tooltipText = self:GetRuleTooltip(rule.key)
        if tooltipText then
            self:AddTooltip(check, rule.name, tooltipText)
        end
        
        optionsFrame.ruleChecks[rule.key] = check
        yOffset = yOffset - 25
    end
end

function UI:GetRuleTooltip(ruleKey)
    local tooltips = {
        wildGrowth = "Suggests Wild Growth when multiple party members have taken recent damage.",
        clearcasting = "Suggests using Regrowth when you have a Clearcasting proc.",
        lifebloom = "Suggests refreshing Lifebloom on your target when it's about to expire.",
        swiftmend = "Suggests Swiftmend when target has HoTs and needs immediate healing.",
        rejuvenation = "Suggests applying Rejuvenation for basic HoT coverage.",
        ironbark = "Suggests Ironbark for damage reduction on targets taking heavy damage.",
        efflorescence = "Suggests Efflorescence for AoE ground healing when group is stacked.",
        tranquility = "Suggests Tranquility during high group-wide damage situations.",
        incarnationTree = "Suggests Incarnation for enhanced healing during intensive phases.",
        naturesSwiftness = "Suggests Nature's Swiftness for instant cast emergency healing.",
        barkskin = "Suggests Barkskin for personal damage reduction in combat.",
        flourish = "Suggests Flourish to extend multiple expiring HoTs.",
        trinket = "Suggests using available healing trinkets.",
    }
    return tooltips[ruleKey]
end

function UI:AddTooltip(frame, title, description)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        if description then
            -- Split long descriptions into multiple lines
            local words = {}
            for word in description:gmatch("%S+") do
                table.insert(words, word)
            end
            
            local lines = {}
            local currentLine = ""
            for i, word in ipairs(words) do
                if #currentLine + #word + 1 <= TOOLTIP_LINE_LENGTH then
                    currentLine = currentLine .. (currentLine == "" and "" or " ") .. word
                else
                    table.insert(lines, currentLine)
                    currentLine = word
                end
            end
            if currentLine ~= "" then
                table.insert(lines, currentLine)
            end
            
            for _, line in ipairs(lines) do
                GameTooltip:AddLine(line, 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

function UI:MakeFrameDraggable()
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    
    mainFrame:SetScript("OnDragStart", function(self)
        if HealIQ.db and HealIQ.db.ui and not HealIQ.db.ui.locked then
            self:StartMoving()
            isDragging = true
        end
    end)
    
    mainFrame:SetScript("OnDragStop", function(self)
        if isDragging then
            self:StopMovingOrSizing()
            isDragging = false
            
            -- Save position if database is available
            if HealIQ.db and HealIQ.db.ui then
                local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
                HealIQ.db.ui.x = xOfs
                HealIQ.db.ui.y = yOfs
                HealIQ:Print("UI position saved")
            end
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
        if spellNameText and HealIQ.db and HealIQ.db.ui and HealIQ.db.ui.showSpellName then
            spellNameText:SetText(suggestion.name)
            spellNameText:Show()
        else
            if spellNameText then
                spellNameText:Hide()
            end
        end
        
        -- Update cooldown display
        if cooldownFrame and HealIQ.db and HealIQ.db.ui and HealIQ.db.ui.showCooldown then
            self:UpdateCooldownDisplay(suggestion)
        end
    end)
end

function UI:UpdateQueue(queue)
    if not queueIcons then
        return
    end
    
    -- Show/hide queue frame based on settings
    if queueFrame then
        if HealIQ.db and HealIQ.db.ui and HealIQ.db.ui.showQueue then
            queueFrame:Show()
        else
            queueFrame:Hide()
            return
        end
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
                
                -- Update position text to show queue order more clearly
                if queueIcon.positionText then
                    queueIcon.positionText:SetText(tostring(i)) -- Show actual queue position
                end
                
                -- Add enhanced tooltip for queue items with better information
                queueIcon:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(suggestion.name, 1, 1, 1)
                    GameTooltip:AddLine("Queue Position: " .. i, 0.7, 0.7, 0.7)
                    GameTooltip:AddLine("Priority: " .. (suggestion.priority or "Normal"), 0.5, 0.8, 1)
                    GameTooltip:AddLine(" ")
                    
                    -- Add contextual information about why this spell is suggested
                    local context = self:GetSpellContext(suggestion)
                    if context then
                        GameTooltip:AddLine(context, 0.6, 0.6, 0.6)
                    end
                    
                    GameTooltip:AddLine("This suggestion will appear when higher", 0.6, 0.6, 0.6)
                    GameTooltip:AddLine("priority spells become unavailable.", 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                end)
                
                queueIcon:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
                
                -- Store suggestion data for tooltip context
                queueIcon.suggestion = suggestion
            end
        end
    end
end

-- Helper function to provide contextual information about spells
function UI:GetSpellContext(suggestion)
    if not suggestion then return nil end
    
    local contexts = {
        ["Rejuvenation"] = "Basic HoT coverage for targets without heals",
        ["Lifebloom"] = "Essential HoT for tank targets",
        ["Wild Growth"] = "AoE healing when multiple allies take damage",
        ["Regrowth"] = "Strong direct heal, especially with Clearcasting",
        ["Swiftmend"] = "Instant heal when HoTs are active on target",
        ["Efflorescence"] = "Ground-based AoE healing effect",
        ["Ironbark"] = "Damage reduction for targets under heavy fire",
        ["Tranquility"] = "Emergency raid-wide healing cooldown",
        ["Incarnation"] = "Enhanced healing form for intensive phases",
        ["Nature's Swiftness"] = "Makes next spell instant cast",
        ["Barkskin"] = "Personal damage reduction",
        ["Flourish"] = "Extends duration of active HoTs",
        ["Use Trinket"] = "Activate healing trinket effect"
    }
    
    return contexts[suggestion.name]
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
    if mainFrame and HealIQ.db and HealIQ.db.ui then
        mainFrame:SetScale(HealIQ.db.ui.scale)
    end
end

function UI:UpdatePosition()
    if mainFrame and HealIQ.db and HealIQ.db.ui then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", HealIQ.db.ui.x, HealIQ.db.ui.y)
    end
end

function UI:ToggleLock()
    if not HealIQ.db or not HealIQ.db.ui then
        HealIQ:Print("UI database not yet initialized")
        return
    end
    
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
    if scale and scale > 0.5 and scale <= 2.0 and HealIQ.db and HealIQ.db.ui then
        HealIQ.db.ui.scale = scale
        self:UpdateScale()
        HealIQ:Print("UI scale set to " .. scale)
    end
end

function UI:SetShowSpellName(show)
    if HealIQ.db and HealIQ.db.ui then
        HealIQ.db.ui.showSpellName = show
        if spellNameText then
            if show then
                spellNameText:Show()
            else
                spellNameText:Hide()
            end
        end
    end
end

function UI:SetShowCooldown(show)
    if HealIQ.db and HealIQ.db.ui then
        HealIQ.db.ui.showCooldown = show
        if cooldownFrame then
            if show then
                cooldownFrame:Show()
            else
                cooldownFrame:Hide()
            end
        end
    end
end

function UI:ResetPosition()
    if HealIQ.db and HealIQ.db.ui then
        HealIQ.db.ui.x = 0
        HealIQ.db.ui.y = 0
        self:UpdatePosition()
        HealIQ:Print("UI position reset to center")
    end
end

function UI:ResetMinimapPosition()
    if HealIQ.db and HealIQ.db.ui then
        HealIQ.db.ui.minimapAngle = -math.pi/4 -- Reset to default angle (top-right)
        if minimapButton then
            local mx, my = Minimap:GetCenter()
            local radius = self:CalculateMinimapButtonRadius()
            
            local x = mx + radius * math.cos(HealIQ.db.ui.minimapAngle)
            local y = my + radius * math.sin(HealIQ.db.ui.minimapAngle)
            minimapButton:ClearAllPoints()
            minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
        HealIQ:Print("Minimap icon position reset")
    end
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

function UI:TestQueue()
    local testQueue = {
        {
            id = 774,
            name = "Rejuvenation",
            icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
            priority = 5,
        },
        {
            id = 48438,
            name = "Wild Growth",
            icon = "Interface\\Icons\\Ability_Druid_WildGrowth",
            priority = 4,
        },
        {
            id = 18562,
            name = "Swiftmend",
            icon = "Interface\\Icons\\INV_Relics_IdolofRejuvenation",
            priority = 6,
        },
        {
            id = 8936,
            name = "Regrowth",
            icon = "Interface\\Icons\\Spell_Nature_ResistNature",
            priority = 7,
        }
    }
    
    self:UpdateSuggestion(testQueue[1])
    self:UpdateQueue(testQueue)
    HealIQ:Print("Test queue display activated with " .. #testQueue .. " queue items")
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
            locked = HealIQ.db and HealIQ.db.ui and HealIQ.db.ui.locked or false
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
    -- Check for UI frame existence first (original function logic)
    if not mainFrame or not mainFrame.border then
        return
    end
    
    -- If database isn't ready, hide border and return (graceful degradation)
    if not HealIQ.db or not HealIQ.db.ui then
        mainFrame.border:Hide()
        return
    end
    
    -- Determine border color and visibility
    local borderColor
    local showBorder = false
    
    if HealIQ.db.ui.showPositionBorder then
        -- Show positioning aid border (cyan)
        borderColor = BORDER_COLORS.positioning
        showBorder = true
    elseif HealIQ.db.ui.locked then
        -- Show locked state border (red)
        borderColor = BORDER_COLORS.locked
        showBorder = true
    else
        -- Show unlocked state border (green)
        borderColor = BORDER_COLORS.unlocked
        showBorder = true
    end
    
    if showBorder then
        mainFrame.border:SetColorTexture(unpack(borderColor))
        mainFrame.border:Show()
    else
        mainFrame.border:Hide()
    end
end

function UI:UpdateOptionsFrame()
    if not optionsFrame then
        return
    end
    
    -- Only update if database is available
    if not HealIQ.db then
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
    
    -- Update logging checkboxes
    if HealIQ.db.logging then
        if optionsFrame.loggingCheck then
            optionsFrame.loggingCheck:SetChecked(HealIQ.db.logging.enabled)
        end
        
        if optionsFrame.verboseCheck then
            optionsFrame.verboseCheck:SetChecked(HealIQ.db.logging.verbose)
        end
        
        if optionsFrame.statsCheck then
            optionsFrame.statsCheck:SetChecked(HealIQ.db.logging.sessionStats)
        end
    end
    
    -- Update UI options
    if HealIQ.db.ui then
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
    
    -- Update rule checkboxes
    if optionsFrame.ruleChecks and HealIQ.db.rules then
        for rule, checkbox in pairs(optionsFrame.ruleChecks) do
            checkbox:SetChecked(HealIQ.db.rules[rule])
        end
    end
end

HealIQ.UI = UI
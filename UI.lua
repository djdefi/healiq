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
    unlocked = {0, 1, 0, 0.5},        -- Green when UI is unlocked
    targeting = {0, 0, 0, 0.8}        -- Dark border for targeting indicators
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
    local queueScale = HealIQ.db.ui.queueScale or 0.75
    local queueIconSize = math.floor(ICON_SIZE * queueScale) -- Use same calculation as CreateQueueFrame
    local padding = 8 -- Consistent padding for all elements
    
    local frameWidth = FRAME_SIZE + (padding * 2)
    local frameHeight = FRAME_SIZE + (padding * 2)
    
    if HealIQ.db.ui.showQueue then
        if queueLayout == "horizontal" then
            -- Fix: Add spacing between icon and queue, plus queue width
            local queueWidth = (queueSize - 1) * queueIconSize + math.max(0, queueSize - 2) * queueSpacing
            frameWidth = frameWidth + queueSpacing + queueWidth
        else
            -- Account for spell name text in vertical layout
            local spellNameHeight = HealIQ.db.ui.showSpellName and 25 or 0  -- Match CreateQueueFrame offset
            -- Fix: Add spacing between icon and queue, plus queue height
            local queueHeight = (queueSize - 1) * queueIconSize + math.max(0, queueSize - 2) * queueSpacing
            frameHeight = frameHeight + queueSpacing + spellNameHeight + queueHeight
        end
    end
    
    -- Create main container frame
    mainFrame = CreateFrame("Frame", "HealIQMainFrame", UIParent)
    mainFrame:SetSize(frameWidth, frameHeight)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", HealIQ.db.ui.x, HealIQ.db.ui.y)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    
    -- Create background with improved styling that covers the entire frame for mouse events
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(mainFrame)  -- Cover the entire frame area
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
    iconFrame = CreateFrame("Button", "HealIQIconFrame", mainFrame)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("LEFT", mainFrame, "LEFT", padding + (FRAME_SIZE - ICON_SIZE) / 2, 0)
    
    -- Store current suggestion for tooltip display
    iconFrame.currentSuggestion = nil
    
    -- Create spell icon texture with improved styling
    local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop edges for cleaner look
    iconFrame.icon = iconTexture
    
    -- Create targeting indicator (small icon in corner)
    local targetingIcon = CreateFrame("Frame", "HealIQTargetingIcon", iconFrame)
    targetingIcon:SetSize(16, 16)
    targetingIcon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
    
    local targetingTexture = targetingIcon:CreateTexture(nil, "OVERLAY")
    targetingTexture:SetAllPoints()
    targetingTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    targetingIcon.icon = targetingTexture
    
    -- Create targeting indicator border
    local targetingBorder = targetingIcon:CreateTexture(nil, "BORDER")
    targetingBorder:SetSize(18, 18)
    targetingBorder:SetPoint("CENTER")
    targetingBorder:SetColorTexture(unpack(BORDER_COLORS.targeting))
    targetingIcon.border = targetingBorder
    
    iconFrame.targetingIcon = targetingIcon
    
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
    
    -- Add click handler for viewing spell information (removed casting functionality)
    iconFrame:SetScript("OnClick", function(self, button)
        -- Spell casting removed due to Blizzard restrictions
        if self.currentSuggestion then
            HealIQ:Print("Suggested: " .. self.currentSuggestion.name)
        end
    end)
    
    -- Add tooltip functionality for the main icon
    iconFrame:SetScript("OnEnter", function(self)
        if self.currentSuggestion then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.currentSuggestion.name, 1, 1, 1)
            GameTooltip:AddLine("Suggested spell for current situation", 0.7, 0.7, 0.7)
            
            if self.currentSuggestion.priority then
                GameTooltip:AddLine("Priority: " .. self.currentSuggestion.priority, 0.5, 0.8, 1)
            end
            
            -- Add targeting suggestions
            if HealIQ.Engine then
                local targetText = HealIQ.Engine:GetTargetingSuggestionsText(self.currentSuggestion)
                local targetDesc = HealIQ.Engine:GetTargetingSuggestionsDescription(self.currentSuggestion)
                
                if targetText then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Suggested Target: " .. targetText, 1, 0.8, 0)
                    if targetDesc then
                        GameTooltip:AddLine(targetDesc, 0.8, 0.8, 0.8)
                    end
                end
            end
            
            GameTooltip:Show()
        end
    end)
    
    iconFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Create spell name text with consistent spacing
    spellNameText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellNameText:SetPoint("TOP", iconFrame, "BOTTOM", 0, -4) -- Consistent spacing
    spellNameText:SetTextColor(1, 1, 1, 1)
    spellNameText:SetShadowColor(0, 0, 0, 1)
    spellNameText:SetShadowOffset(1, -1)
    spellNameText:SetJustifyH("CENTER") -- Center-align the text
    spellNameText:SetJustifyV("TOP") -- Top-align for multi-line support
    spellNameText:SetWidth(120) -- Set a max width to prevent overflow
    
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
    
    -- Update position border based on current settings
    -- This call is necessary here because the frame border needs to be initialized
    -- after all frame components are created and the database is available
    self:UpdatePositionBorder()
    
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
    local radius = self:CalculateMinimapButtonRadius()
    
    -- Fixed: Position relative to Minimap center, not UIParent
    local x = radius * math.cos(savedAngle)
    local y = radius * math.sin(savedAngle)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
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
        
        -- Fixed: Position relative to Minimap center, not UIParent
        local newX = finalRadius * math.cos(angle)
        local newY = finalRadius * math.sin(angle)
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", newX, newY)
        
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
    
    -- Set initial visibility based on showIcon setting
    self:UpdateMinimapButtonVisibility()
end

function UI:UpdateMinimapButtonVisibility()
    if minimapButton and HealIQ.db and HealIQ.db.ui then
        if HealIQ.db.ui.showIcon then
            minimapButton:Show()
        else
            minimapButton:Hide()
        end
    end
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
        -- Fix: Adjust frame size calculation to account for proper spacing
        local totalWidth = (queueSize - 1) * queueIconSize + math.max(0, queueSize - 2) * queueSpacing
        queueFrame:SetSize(totalWidth, queueIconSize)
        queueFrame:SetPoint("LEFT", iconFrame, "RIGHT", queueSpacing, 0)
    else
        -- Fix: Adjust frame size calculation for vertical layout
        local totalHeight = (queueSize - 1) * queueIconSize + math.max(0, queueSize - 2) * queueSpacing
        queueFrame:SetSize(queueIconSize, totalHeight)
        -- Better vertical positioning that accounts for spell name text and padding
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
    
    -- Update options with current values once frame is created
    self:UpdateOptionsFrame()
end

function UI:CreateOptionsTabs(parent)
    -- Create tab buttons
    local tabHeight = 25
    local tabWidth = 95
    local tabs = {
        {name = "General", id = "general"},
        {name = "Display", id = "display"},
        {name = "Rules", id = "rules"},
        {name = "Strategy", id = "strategy"},
        {name = "Queue", id = "queue"}
    }
    
    optionsFrame.tabs = {}
    optionsFrame.tabPanels = {}
    optionsFrame.activeTab = nil  -- Initialize activeTab to avoid nil reference issues
    
    for i, tab in ipairs(tabs) do
        -- Create tab button using UIPanelButtonTemplate which is known to work
        local tabButton = CreateFrame("Button", "HealIQTab" .. tab.id, parent, "UIPanelButtonTemplate")
        tabButton:SetSize(tabWidth, tabHeight)
        -- Fix: Increase y-offset to prevent overlap with header (was -5, now -35)
        tabButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 10 + (i-1) * (tabWidth - 10), -35)
        tabButton:SetText(tab.name)
        tabButton.tabId = tab.id
        
        -- Style the button to look like a tab with better visual feedback
        tabButton:SetNormalFontObject("GameFontNormal")
        tabButton:SetHighlightFontObject("GameFontHighlight")
        tabButton:SetDisabledFontObject("GameFontDisable")
        
        -- Set initial inactive appearance
        tabButton:SetAlpha(0.7)
        
        -- Add hover effects for better user experience
        tabButton:SetScript("OnEnter", function(self)
            if not optionsFrame.activeTab or self.tabId ~= optionsFrame.activeTab then
                self:SetAlpha(0.85)
            end
        end)
        
        tabButton:SetScript("OnLeave", function(self)
            if not optionsFrame.activeTab or self.tabId ~= optionsFrame.activeTab then
                self:SetAlpha(0.7)
            end
        end)
        
        tabButton:SetScript("OnClick", function(self)
            UI:ShowOptionsTab(self.tabId)
        end)
        
        optionsFrame.tabs[tab.id] = tabButton
        
        -- Create tab panel
        local panel = CreateFrame("Frame", "HealIQPanel" .. tab.id, parent)
        -- Fix: Adjust panel position to account for moved tabs (was -35, now -65)
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -65)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 40)
        panel:Hide()
        
        optionsFrame.tabPanels[tab.id] = panel
    end
    
    -- Create content for each tab
    self:CreateGeneralTab(optionsFrame.tabPanels.general)
    self:CreateDisplayTab(optionsFrame.tabPanels.display)
    self:CreateRulesTab(optionsFrame.tabPanels.rules)
    self:CreateStrategyTab(optionsFrame.tabPanels.strategy)
    self:CreateQueueTab(optionsFrame.tabPanels.queue)
    
    -- Show first tab by default
    self:ShowOptionsTab("general")
end
function UI:ShowOptionsTab(tabId)
    -- Hide all panels and reset tab states
    for id, panel in pairs(optionsFrame.tabPanels) do
        panel:Hide()
        -- Reset button appearance for inactive tabs
        local tab = optionsFrame.tabs[id]
        tab:SetAlpha(0.7)
        tab:SetNormalFontObject("GameFontNormal")
    end
    
    -- Show selected panel and mark tab as active
    if optionsFrame.tabPanels[tabId] then
        optionsFrame.tabPanels[tabId]:Show()
        -- Highlight the active tab
        local activeTab = optionsFrame.tabs[tabId]
        activeTab:SetAlpha(1.0)
        activeTab:SetNormalFontObject("GameFontHighlight")
        
        -- Track the active tab for hover effects
        optionsFrame.activeTab = tabId
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
    
    -- Session stats checkbox
    local statsCheck = CreateFrame("CheckButton", "HealIQStatsCheck", panel, "UICheckButtonTemplate")
    statsCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    statsCheck.text = statsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsCheck.text:SetPoint("LEFT", statsCheck, "RIGHT", 5, 0)
    statsCheck.text:SetText("Session Statistics")
    statsCheck:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        if enabled then
            if not HealIQ.sessionStats then
                HealIQ.sessionStats = {
                    startTime = time(),
                    suggestions = 0,
                    rulesProcessed = 0,
                    errorsLogged = 0,
                    eventsHandled = 0,
                }
            elseif not HealIQ.sessionStats.startTime then
                HealIQ.sessionStats.startTime = time()
            end
            HealIQ:Message("Session statistics enabled")
        else
            if HealIQ.sessionStats then
                HealIQ.sessionStats.startTime = nil
            end
            HealIQ:Message("Session statistics disabled")
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
    yOffset = yOffset - 30
    
    local showIconCheck = CreateFrame("CheckButton", "HealIQShowIconCheck", panel, "UICheckButtonTemplate")
    showIconCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    showIconCheck.text = showIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showIconCheck.text:SetPoint("LEFT", showIconCheck, "RIGHT", 5, 0)
    showIconCheck.text:SetText("Show minimap icon")
    showIconCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.showIcon = self:GetChecked()
            if HealIQ.UI then
                HealIQ.UI:UpdateMinimapButtonVisibility()
            end
        end
    end)
    self:AddTooltip(showIconCheck, "Show Minimap Icon", "Display the HealIQ minimap button.")
    optionsFrame.showIconCheck = showIconCheck
    yOffset = yOffset - 30
    
    -- Targeting display options
    local showTargetingCheck = CreateFrame("CheckButton", "HealIQShowTargetingCheck", panel, "UICheckButtonTemplate")
    showTargetingCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    showTargetingCheck.text = showTargetingCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showTargetingCheck.text:SetPoint("LEFT", showTargetingCheck, "RIGHT", 5, 0)
    showTargetingCheck.text:SetText("Show targeting suggestions")
    showTargetingCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.showTargeting = self:GetChecked()
            -- Force UI update to refresh targeting display
            if HealIQ.Engine then
                HealIQ.Engine:ForceUpdate()
            end
        end
    end)
    self:AddTooltip(showTargetingCheck, "Show Targeting Suggestions", "Display suggested targets for spells in the spell name and tooltips.")
    optionsFrame.showTargetingCheck = showTargetingCheck
    yOffset = yOffset - 30
    
    local showTargetingIconCheck = CreateFrame("CheckButton", "HealIQShowTargetingIconCheck", panel, "UICheckButtonTemplate")
    showTargetingIconCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    showTargetingIconCheck.text = showTargetingIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showTargetingIconCheck.text:SetPoint("LEFT", showTargetingIconCheck, "RIGHT", 5, 0)
    showTargetingIconCheck.text:SetText("Show targeting icons")
    showTargetingIconCheck:SetScript("OnClick", function(self)
        if HealIQ.db and HealIQ.db.ui then
            HealIQ.db.ui.showTargetingIcon = self:GetChecked()
            -- Force UI update to refresh targeting display
            if HealIQ.Engine then
                HealIQ.Engine:ForceUpdate()
            end
        end
    end)
    self:AddTooltip(showTargetingIconCheck, "Show Targeting Icons", "Display small targeting indicator icons overlaid on spell suggestions.")
    optionsFrame.showTargetingIconCheck = showTargetingIconCheck
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
    }
    return tooltips[ruleKey]
end

function UI:CreateStrategyTab(panel)
    local yOffset = -10
    
    -- Strategy section
    local strategyHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    strategyHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    strategyHeader:SetText("Healing Strategy Settings")
    strategyHeader:SetTextColor(1, 0.8, 0, 1)
    yOffset = yOffset - 30
    
    local strategyDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    strategyDesc:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    strategyDesc:SetText("Configure enhanced healing strategy based on Wowhead guide")
    strategyDesc:SetTextColor(0.8, 0.8, 0.8, 1)
    yOffset = yOffset - 25
    
    -- Create a scrollable frame for strategy options
    local scrollFrame = CreateFrame("ScrollFrame", "HealIQStrategyScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, yOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -25, 10)
    
    local scrollChild = CreateFrame("Frame", "HealIQStrategyScrollChild", scrollFrame)
    scrollChild:SetSize(350, 800) -- Large height for all controls
    scrollFrame:SetScrollChild(scrollChild)
    
    local scrollYOffset = -10
    
    -- Core Strategy Toggles Section
    local coreHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    coreHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, scrollYOffset)
    coreHeader:SetText("Core Strategy Toggles:")
    coreHeader:SetTextColor(0.8, 1, 0.8, 1)
    scrollYOffset = scrollYOffset - 25
    
    -- Store strategy controls for updating
    optionsFrame.strategyControls = {}
    
    -- Core toggle settings
    local coreToggles = {
        {key = "prioritizeEfflorescence", name = "Prioritize Efflorescence", desc = "Keep Efflorescence active frequently"},
        {key = "maintainLifebloomOnTank", name = "Maintain Lifebloom on Tank", desc = "Always keep Lifebloom on tank with proper refresh timing"},
        {key = "preferClearcastingRegrowth", name = "Prefer Clearcasting Regrowth", desc = "Prioritize Regrowth when you have Clearcasting procs"},
        {key = "swiftmendWildGrowthCombo", name = "Swiftmend + Wild Growth Combo", desc = "Link Swiftmend and Wild Growth usage"},
        {key = "avoidRandomRejuvenationDowntime", name = "Avoid Random Rejuvenation in Downtime", desc = "Don't cast random Rejuvenations during downtime periods"},
        {key = "useWrathForMana", name = "Use Wrath for Mana", desc = "Fill downtime with Wrath for mana restoration"},
        {key = "poolGroveGuardians", name = "Pool Grove Guardians", desc = "Pool Grove Guardian charges for major cooldowns"},
        {key = "emergencyNaturesSwiftness", name = "Emergency Nature's Swiftness", desc = "Use Nature's Swiftness for emergency healing"},
    }
    
    for _, toggle in ipairs(coreToggles) do
        local check = CreateFrame("CheckButton", "HealIQStrategy" .. toggle.key, scrollChild, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, scrollYOffset)
        check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        check.text:SetPoint("LEFT", check, "RIGHT", 5, 0)
        check.text:SetText(toggle.name)
        check:SetScript("OnClick", function(self)
            if HealIQ.db and HealIQ.db.strategy then
                HealIQ.db.strategy[toggle.key] = self:GetChecked()
                -- Force engine update to apply changes
                if HealIQ.Engine then
                    HealIQ.Engine:ForceUpdate()
                end
            end
        end)
        
        self:AddTooltip(check, toggle.name, toggle.desc)
        optionsFrame.strategyControls[toggle.key] = check
        scrollYOffset = scrollYOffset - 25
    end
    
    scrollYOffset = scrollYOffset - 15
    
    -- Tunable Thresholds Section
    local thresholdsHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thresholdsHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, scrollYOffset)
    thresholdsHeader:SetText("Tunable Thresholds:")
    thresholdsHeader:SetTextColor(0.8, 1, 0.8, 1)
    scrollYOffset = scrollYOffset - 25
    
    -- Numeric settings with sliders
    local numericSettings = {
        {key = "lifebloomRefreshWindow", name = "Lifebloom Refresh Window", desc = "Refresh Lifebloom within this many seconds for bloom effect", min = 2, max = 8, step = 0.5},
        {key = "wildGrowthMinTargets", name = "Wild Growth Min Targets", desc = "Minimum targets damaged to suggest Wild Growth", min = 2, max = 6, step = 1},
        {key = "tranquilityMinTargets", name = "Tranquility Min Targets", desc = "Minimum targets damaged to suggest Tranquility", min = 3, max = 8, step = 1},
        {key = "efflorescenceMinTargets", name = "Efflorescence Min Targets", desc = "Minimum targets damaged to suggest Efflorescence", min = 2, max = 6, step = 1},
        {key = "flourishMinHots", name = "Flourish Min HoTs", desc = "Minimum expiring HoTs to suggest Flourish", min = 2, max = 6, step = 1},
        {key = "rejuvenationRampThreshold", name = "Rejuvenation Ramp Threshold", desc = "Start ramping Rejuvenation when damage expected in this many seconds", min = 5, max = 30, step = 1},
        {key = "recentDamageWindow", name = "Recent Damage Window", desc = "Time window to consider 'recent damage' (seconds)", min = 1, max = 10, step = 1},
        {key = "lowHealthThreshold", name = "Low Health Threshold", desc = "Health percentage to consider 'emergency' (0.0-1.0)", min = 0.1, max = 0.8, step = 0.05},
    }
    
    for _, setting in ipairs(numericSettings) do
        -- Setting label
        local label = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, scrollYOffset)
        label:SetText(setting.name .. ":")
        scrollYOffset = scrollYOffset - 20
        
        -- Slider
        local slider = CreateFrame("Slider", "HealIQStrategy" .. setting.key .. "Slider", scrollChild, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, scrollYOffset)
        slider:SetMinMaxValues(setting.min, setting.max)
        slider:SetValueStep(setting.step)
        slider:SetObeyStepOnDrag(true)
        slider.tooltipText = setting.desc
        _G[slider:GetName() .. "Low"]:SetText(tostring(setting.min))
        _G[slider:GetName() .. "High"]:SetText(tostring(setting.max))
        _G[slider:GetName() .. "Text"]:SetText("")
        
        -- Value display
        local valueText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        valueText:SetPoint("RIGHT", slider, "RIGHT", 30, 0)
        valueText:SetTextColor(1, 1, 0, 1)
        
        slider:SetScript("OnValueChanged", function(self, value)
            if HealIQ.db and HealIQ.db.strategy then
                HealIQ.db.strategy[setting.key] = value
                valueText:SetText(string.format("%.1f", value))
                -- Force engine update to apply changes
                if HealIQ.Engine then
                    HealIQ.Engine:ForceUpdate()
                end
            end
        end)
        
        self:AddTooltip(slider, setting.name, setting.desc)
        optionsFrame.strategyControls[setting.key] = {slider = slider, valueText = valueText}
        scrollYOffset = scrollYOffset - 40
    end
    
    scrollYOffset = scrollYOffset - 15
    
    -- Reset button
    local resetButton = CreateFrame("Button", "HealIQStrategyResetButton", scrollChild, "UIPanelButtonTemplate")
    resetButton:SetSize(120, 22)
    resetButton:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, scrollYOffset)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        -- Reset strategy settings to defaults
        if HealIQ.db and HealIQ.db.strategy then
            local defaults = {
                prioritizeEfflorescence = true,
                maintainLifebloomOnTank = true,
                lifebloomRefreshWindow = 4.5,
                preferClearcastingRegrowth = true,
                swiftmendWildGrowthCombo = true,
                rejuvenationRampThreshold = 15,
                avoidRandomRejuvenationDowntime = true,
                useWrathForMana = true,
                poolGroveGuardians = true,
                emergencyNaturesSwiftness = true,
                wildGrowthMinTargets = 3,
                tranquilityMinTargets = 4,
                efflorescenceMinTargets = 2,
                flourishMinHots = 2,
                recentDamageWindow = 3,
                lowHealthThreshold = 0.3,
            }
            
            for setting, defaultValue in pairs(defaults) do
                HealIQ.db.strategy[setting] = defaultValue
            end
            
            -- Update the UI controls
            UI:UpdateOptionsFrame()
            
            -- Force engine update
            if HealIQ.Engine then
                HealIQ.Engine:ForceUpdate()
            end
            
            HealIQ:Print("Strategy settings reset to defaults")
        end
    end)
    self:AddTooltip(resetButton, "Reset Strategy Settings", "Resets all strategy settings to their optimal default values.")
    
    scrollYOffset = scrollYOffset - 30
    
    -- Help text
    local helpText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, scrollYOffset)
    helpText:SetText("Strategy settings can also be configured via chat commands:\n/healiq strategy list - View all settings\n/healiq strategy set <setting> <value> - Change a setting")
    helpText:SetTextColor(0.7, 0.7, 0.7, 1)
    helpText:SetWidth(320)
    helpText:SetJustifyH("LEFT")
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
            
            -- Store current suggestion for click handling
            iconFrame.currentSuggestion = suggestion
            
            -- Show glow effect for primary suggestion
            if iconFrame.glow then
                iconFrame.glow:Show()
                if iconFrame.glowAnimation then
                    iconFrame.glowAnimation:Play()
                end
            end
            
            -- Update targeting indicator
            if iconFrame.targetingIcon and HealIQ.Engine then
                -- Check if targeting icons are enabled (default to true if not set)
                local showTargetingIcon = HealIQ.db.ui.showTargetingIcon
                if showTargetingIcon == nil then
                    showTargetingIcon = true -- Default to true
                end
                
                if showTargetingIcon then
                    local targetIcon = HealIQ.Engine:GetTargetingSuggestionsIcon(suggestion)
                    if targetIcon then
                        iconFrame.targetingIcon.icon:SetTexture(targetIcon)
                        iconFrame.targetingIcon:Show()
                    else
                        iconFrame.targetingIcon:Hide()
                    end
                else
                    iconFrame.targetingIcon:Hide()
                end
            elseif iconFrame.targetingIcon then
                iconFrame.targetingIcon:Hide()
            end
        end
        
        -- Update spell name with targeting info
        if spellNameText and HealIQ.db and HealIQ.db.ui and HealIQ.db.ui.showSpellName then
            local displayText = suggestion.name
            
            -- Add targeting suggestion to spell name if enabled
            local showTargeting = HealIQ.db.ui.showTargeting
            if showTargeting == nil then
                showTargeting = true -- Default to true if not set
            end
            
            if showTargeting and HealIQ.Engine then
                local targetText = HealIQ.Engine:GetTargetingSuggestionsText(suggestion)
                if targetText then
                    -- Truncate target text if it's too long to prevent overflow
                    local maxTargetLength = 12 -- Reasonable limit for target text
                    if #targetText > maxTargetLength then
                        targetText = targetText:sub(1, maxTargetLength - 2) .. ".."
                    end
                    
                    -- Format the text with better spacing and color
                    displayText = displayText .. "\n|cFFFFCC00→ " .. targetText .. "|r"
                end
            end
            
            spellNameText:SetText(displayText)
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
                    local context = UI:GetSpellContext(suggestion)
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
        ["Flourish"] = "Extends duration of active HoTs"
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
            local radius = self:CalculateMinimapButtonRadius()
            
            -- Fixed: Position relative to Minimap center, not UIParent
            local x = radius * math.cos(HealIQ.db.ui.minimapAngle)
            local y = radius * math.sin(HealIQ.db.ui.minimapAngle)
            minimapButton:ClearAllPoints()
            minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
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
    -- Store current visibility state before destroying frames
    local wasVisible = mainFrame and mainFrame:IsShown()
    
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
    
    -- Restore visibility state if addon is enabled
    if wasVisible and HealIQ.db and HealIQ.db.enabled then
        self:Show()
    end
    
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
    
    -- Only show border when explicitly requested via showPositionBorder setting
    if HealIQ.db.ui.showPositionBorder then
        -- Show positioning aid border (cyan)
        mainFrame.border:SetColorTexture(unpack(BORDER_COLORS.positioning))
        mainFrame.border:Show()
    else
        -- Hide border when not explicitly requested
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
    
    -- Update session stats checkbox
    if optionsFrame.statsCheck then
        optionsFrame.statsCheck:SetChecked(HealIQ.sessionStats and HealIQ.sessionStats.startTime ~= nil)
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
        
        if optionsFrame.showIconCheck then
            optionsFrame.showIconCheck:SetChecked(HealIQ.db.ui.showIcon)
        end
        
        if optionsFrame.showTargetingCheck then
            local showTargeting = HealIQ.db.ui.showTargeting
            if showTargeting == nil then
                showTargeting = true -- Default to true
            end
            optionsFrame.showTargetingCheck:SetChecked(showTargeting)
        end
        
        if optionsFrame.showTargetingIconCheck then
            local showTargetingIcon = HealIQ.db.ui.showTargetingIcon
            if showTargetingIcon == nil then
                showTargetingIcon = true -- Default to true
            end
            optionsFrame.showTargetingIconCheck:SetChecked(showTargetingIcon)
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
    
    -- Update strategy controls
    if optionsFrame.strategyControls and HealIQ.db.strategy then
        for setting, control in pairs(optionsFrame.strategyControls) do
            local value = HealIQ.db.strategy[setting]
            if type(control) == "table" and control.slider then
                -- Numeric setting with slider
                control.slider:SetValue(value or 0)
                if control.valueText then
                    control.valueText:SetText(string.format("%.1f", value or 0))
                end
            else
                -- Boolean setting with checkbox
                control:SetChecked(value)
            end
        end
    end
end

HealIQ.UI = UI
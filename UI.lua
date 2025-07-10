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
    local queueIconSize = math.floor(ICON_SIZE * 0.75) -- Smaller icons for queue
    
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
    optionsFrame:SetSize(400, 700) -- Increased height for new rules
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
        optionsFrame.ruleChecks[rule.key] = check
    end
    
    -- Display options
    local displayLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayLabel:SetPoint("TOPLEFT", rulesLabel, "BOTTOMLEFT", 0, -340) -- Adjusted for more rules
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
        elseif spellNameText then
            spellNameText:Hide()
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
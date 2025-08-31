-- AFKTracker UI Module
-- Custom settings panel for WoW Classic Era

AFKTrackerUI = AFKTrackerUI or {}
local UI = AFKTrackerUI

-- Local references
local frame = nil
local battleFrame = nil

-- Default position for the settings frame
local DEFAULT_POSITION = {
    point = "CENTER",
    relativePoint = "CENTER",
    xOfs = 0,
    yOfs = 0
}

local DEFAULT_BATTLE_POSITION = {
    point = "RIGHT",
    relativePoint = "RIGHT",
    xOfs = -100,
    yOfs = 0
}

-- Initialize saved variables for UI
local function InitializeSavedVariables()
    AFKTrackerDB = AFKTrackerDB or {}
    AFKTrackerDB.config = AFKTrackerDB.config or {}
    AFKTrackerDB.ui = AFKTrackerDB.ui or {}
    AFKTrackerDB.ui.position = AFKTrackerDB.ui.position or DEFAULT_POSITION
    AFKTrackerDB.ui.battlePosition = AFKTrackerDB.ui.battlePosition or DEFAULT_BATTLE_POSITION
    AFKTrackerDB.ui.showInAV = AFKTrackerDB.ui.showInAV ~= false -- Default to true

    -- Ensure config defaults exist
    local defaults = {
        deathThreshold = 2,
        honorThreshold = 1386,
        seenThreshold = 2,
        redeemThreshold = 1,
        historyExpireHours = 24,
        debug = false,
        showBattleUI = true
    }
    for k, v in pairs(defaults) do
        if AFKTrackerDB.config[k] == nil then
            AFKTrackerDB.config[k] = v
        end
    end
end

-- Create an input box for a config option
local function CreateConfigOption(parent, labelText, configKey, yOffset, tooltip, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(30)
    container:SetPoint("TOPLEFT", 20, yOffset)
    container:SetPoint("TOPRIGHT", -20, yOffset)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(labelText .. ":")
    label:SetTextColor(1, 0.84, 0) -- Gold color
    label:SetWidth(180)
    label:SetJustifyH("LEFT")

    local input = CreateFrame("EditBox", nil, container)
    input:SetSize(80, 20)
    input:SetPoint("LEFT", label, "RIGHT", 10, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(10)
    input:SetFontObject(GameFontHighlight)

    -- Create background for input
    local inputBG = input:CreateTexture(nil, "BACKGROUND")
    inputBG:SetAllPoints()
    inputBG:SetColorTexture(0, 0, 0, 0.5)

    -- Create border textures
    local borderLeft = input:CreateTexture(nil, "BORDER")
    borderLeft:SetSize(2, 20)
    borderLeft:SetPoint("LEFT", -2, 0)
    borderLeft:SetColorTexture(0.4, 0.4, 0.4, 1)

    local borderRight = input:CreateTexture(nil, "BORDER")
    borderRight:SetSize(2, 20)
    borderRight:SetPoint("RIGHT", 2, 0)
    borderRight:SetColorTexture(0.4, 0.4, 0.4, 1)

    local borderTop = input:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(2)
    borderTop:SetPoint("TOPLEFT", -2, 2)
    borderTop:SetPoint("TOPRIGHT", 2, 2)
    borderTop:SetColorTexture(0.4, 0.4, 0.4, 1)

    local borderBottom = input:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(2)
    borderBottom:SetPoint("BOTTOMLEFT", -2, -2)
    borderBottom:SetPoint("BOTTOMRIGHT", 2, -2)
    borderBottom:SetColorTexture(0.4, 0.4, 0.4, 1)

    -- Set current value
    local value = AFKTrackerDB.config[configKey]
    input:SetText(tostring(value))

    -- Tooltip
    if tooltip then
        input:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        input:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    -- Save on enter or focus lost
    local function SaveValue()
        local text = input:GetText()
        local numValue = tonumber(text)

        if numValue and numValue > 0 then
            AFKTrackerDB.config[configKey] = numValue
            if onChange then
                onChange()
            end
        else
            -- Revert to previous value
            input:SetText(tostring(AFKTrackerDB.config[configKey]))
            print("|cFF4A90E2[AFK Tracker]|r Invalid value. Must be a positive number.")
        end
    end

    input:SetScript("OnEnterPressed", function(self)
        SaveValue()
        self:ClearFocus()
    end)

    input:SetScript("OnEditFocusLost", SaveValue)

    return input
end

-- Get tracking statistics
local function GetTrackingStats()
    local playerCount = 0
    local playersSeen = {}

    if AFKTrackerDB and AFKTrackerDB.records then
        for _, record in ipairs(AFKTrackerDB.records) do
            if not playersSeen[record.name] then
                playersSeen[record.name] = true
                playerCount = playerCount + 1
            end
        end
    end

    local expireHours = (AFKTrackerDB and AFKTrackerDB.config and AFKTrackerDB.config.historyExpireHours) or 24

    return playerCount, expireHours
end

-- Create checkbox for debug option
local function CreateDebugCheckbox(parent, yOffset)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 20, yOffset)

    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetText("Enable Debug Messages")
    label:SetTextColor(1, 0.84, 0) -- Gold color

    -- Set initial state
    checkbox:SetChecked(AFKTrackerDB.config.debug)

    -- Handle clicks
    checkbox:SetScript("OnClick", function(self)
        AFKTrackerDB.config.debug = self:GetChecked() and true or false
        if AFKTrackerDB.config.debug then
            print("|cFF4A90E2[AFK Tracker]|r Debug messages enabled")
        else
            print("|cFF4A90E2[AFK Tracker]|r Debug messages disabled")
        end
    end)

    -- Tooltip
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Enable debug messages for troubleshooting", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    return checkbox
end

-- Create checkbox for battle UI option with reset button
local function CreateBattleUICheckbox(parent, yOffset)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 20, yOffset)

    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetText("Show Battle UI in AV")
    label:SetTextColor(1, 0.84, 0) -- Gold color

    -- Set initial state
    checkbox:SetChecked(AFKTrackerDB.ui.showInAV)

    -- Handle clicks
    checkbox:SetScript("OnClick", function(self)
        AFKTrackerDB.ui.showInAV = self:GetChecked() and true or false
        if AFKTrackerDB.ui.showInAV then
            print("|cFF4A90E2[AFK Tracker]|r Battle UI will show in AV")
        else
            print("|cFF4A90E2[AFK Tracker]|r Battle UI will not auto-show in AV")
        end
    end)

    -- Tooltip
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Automatically show the battle UI when entering Alterac Valley", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Create Reset button next to checkbox
    local resetBtn = CreateFrame("Button", nil, parent)
    resetBtn:SetSize(50, 20)
    resetBtn:SetPoint("LEFT", label, "RIGHT", 10, 0)

    -- Background
    local bg = resetBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    resetBtn.bg = bg

    -- Border
    local border = {}
    border.top = resetBtn:CreateTexture(nil, "BORDER")
    border.top:SetHeight(1)
    border.top:SetPoint("TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", 0, 0)
    border.top:SetColorTexture(0.3, 0.3, 0.3, 1)

    border.bottom = resetBtn:CreateTexture(nil, "BORDER")
    border.bottom:SetHeight(1)
    border.bottom:SetPoint("BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    border.bottom:SetColorTexture(0.3, 0.3, 0.3, 1)

    border.left = resetBtn:CreateTexture(nil, "BORDER")
    border.left:SetWidth(1)
    border.left:SetPoint("TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", 0, 0)
    border.left:SetColorTexture(0.3, 0.3, 0.3, 1)

    border.right = resetBtn:CreateTexture(nil, "BORDER")
    border.right:SetWidth(1)
    border.right:SetPoint("TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", 0, 0)
    border.right:SetColorTexture(0.3, 0.3, 0.3, 1)

    resetBtn.border = border

    -- Text
    resetBtn:SetNormalFontObject("GameFontNormalSmall")
    resetBtn:SetHighlightFontObject("GameFontHighlightSmall")
    resetBtn:SetText("Reset")

    -- Highlight
    resetBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Battle UI position to default")
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)

    -- Click handler
    resetBtn:SetScript("OnClick", function()
        AFKTrackerDB.ui.battlePosition = DEFAULT_BATTLE_POSITION
        if battleFrame then
            battleFrame:ClearAllPoints()
            battleFrame:SetPoint(DEFAULT_BATTLE_POSITION.point, UIParent, DEFAULT_BATTLE_POSITION.relativePoint,
                DEFAULT_BATTLE_POSITION.xOfs, DEFAULT_BATTLE_POSITION.yOfs)
            print("|cFF4A90E2[AFK Tracker]|r Battle UI position reset to default.")
        else
            print("|cFF4A90E2[AFK Tracker]|r Battle UI position will be reset when shown.")
        end
    end)

    return checkbox
end

-- Create the compact battle UI frame
local function CreateBattleFrame()
    if battleFrame then return battleFrame end

    -- Main frame
    local f = CreateFrame("Frame", "AFKTrackerBattleFrame", UIParent)
    f:SetSize(140, 70)
    f:SetPoint(AFKTrackerDB.ui.battlePosition.point, UIParent, AFKTrackerDB.ui.battlePosition.relativePoint,
        AFKTrackerDB.ui.battlePosition.xOfs, AFKTrackerDB.ui.battlePosition.yOfs)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
        AFKTrackerDB.ui.battlePosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)
    f:Hide()

    -- Create background
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

    -- Create border
    local CreateBorder = function(parent, thickness)
        local border = {}
        border.top = parent:CreateTexture(nil, "BORDER")
        border.top:SetHeight(thickness)
        border.top:SetPoint("TOPLEFT", 0, 0)
        border.top:SetPoint("TOPRIGHT", 0, 0)
        border.top:SetColorTexture(0.3, 0.3, 0.3, 1)

        border.bottom = parent:CreateTexture(nil, "BORDER")
        border.bottom:SetHeight(thickness)
        border.bottom:SetPoint("BOTTOMLEFT", 0, 0)
        border.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
        border.bottom:SetColorTexture(0.3, 0.3, 0.3, 1)

        border.left = parent:CreateTexture(nil, "BORDER")
        border.left:SetWidth(thickness)
        border.left:SetPoint("TOPLEFT", 0, 0)
        border.left:SetPoint("BOTTOMLEFT", 0, 0)
        border.left:SetColorTexture(0.3, 0.3, 0.3, 1)

        border.right = parent:CreateTexture(nil, "BORDER")
        border.right:SetWidth(thickness)
        border.right:SetPoint("TOPRIGHT", 0, 0)
        border.right:SetPoint("BOTTOMRIGHT", 0, 0)
        border.right:SetColorTexture(0.3, 0.3, 0.3, 1)

        return border
    end

    f.border = CreateBorder(f, 1)

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOP", f, "TOP", 0, -5)
    f.title:SetText("AFK Tracker")
    f.title:SetTextColor(0.29, 0.57, 0.89)

    -- Close button
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetSize(20, 20)
    f.closeBtn:SetPoint("TOPRIGHT", 2, 2)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Settings button (gear icon)
    f.settingsBtn = CreateFrame("Button", nil, f)
    f.settingsBtn:SetSize(14, 14)
    f.settingsBtn:SetPoint("TOPRIGHT", -18, -3)
    f.settingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    f.settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
    f.settingsBtn:GetHighlightTexture():SetAlpha(0.3)
    f.settingsBtn:SetScript("OnClick", function()
        UI:ToggleSettingsFrame()
    end)
    f.settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    f.settingsBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- List button
    local listBtn = CreateFrame("Button", nil, f)
    listBtn:SetSize(60, 20)
    listBtn:SetPoint("TOPLEFT", 5, -25)

    listBtn.bg = listBtn:CreateTexture(nil, "BACKGROUND")
    listBtn.bg:SetAllPoints()
    listBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)

    listBtn:SetNormalFontObject("GameFontNormalSmall")
    listBtn:SetHighlightFontObject("GameFontHighlightSmall")
    listBtn:SetText("List AFK")

    listBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("List AFKers in BG chat")
        GameTooltip:Show()
    end)
    listBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)
    listBtn:SetScript("OnClick", function()
        -- Simulate /afkt list bg command
        SlashCmdList["AFKT"]("list bg")
    end)

    -- Announce button
    local announceBtn = CreateFrame("Button", nil, f)
    announceBtn:SetSize(60, 20)
    announceBtn:SetPoint("TOPRIGHT", -5, -25)

    announceBtn.bg = announceBtn:CreateTexture(nil, "BACKGROUND")
    announceBtn.bg:SetAllPoints()
    announceBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)

    announceBtn:SetNormalFontObject("GameFontNormalSmall")
    announceBtn:SetHighlightFontObject("GameFontHighlightSmall")
    announceBtn:SetText("Announce")

    announceBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Announce target as AFK")
        GameTooltip:Show()
    end)
    announceBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)
    announceBtn:SetScript("OnClick", function()
        -- Simulate /afkt announce command
        SlashCmdList["AFKT"]("announce")
    end)

    battleFrame = f
    return f
end

-- Create the main settings frame
local function CreateSettingsFrame()
    if frame then return frame end

    -- Main frame
    local f = CreateFrame("Frame", "AFKTrackerSettingsFrame", UIParent)
    f:SetSize(400, 420)
    f:SetPoint(AFKTrackerDB.ui.position.point, UIParent, AFKTrackerDB.ui.position.relativePoint,
        AFKTrackerDB.ui.position.xOfs, AFKTrackerDB.ui.position.yOfs)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
        AFKTrackerDB.ui.position = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)
    f:Hide()

    -- Create background texture
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Create border
    local CreateBorder = function(parent, thickness)
        local border = {}

        -- Top
        border.top = parent:CreateTexture(nil, "BORDER")
        border.top:SetHeight(thickness)
        border.top:SetPoint("TOPLEFT", 0, 0)
        border.top:SetPoint("TOPRIGHT", 0, 0)
        border.top:SetColorTexture(0.3, 0.3, 0.3, 1)

        -- Bottom
        border.bottom = parent:CreateTexture(nil, "BORDER")
        border.bottom:SetHeight(thickness)
        border.bottom:SetPoint("BOTTOMLEFT", 0, 0)
        border.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
        border.bottom:SetColorTexture(0.3, 0.3, 0.3, 1)

        -- Left
        border.left = parent:CreateTexture(nil, "BORDER")
        border.left:SetWidth(thickness)
        border.left:SetPoint("TOPLEFT", 0, 0)
        border.left:SetPoint("BOTTOMLEFT", 0, 0)
        border.left:SetColorTexture(0.3, 0.3, 0.3, 1)

        -- Right
        border.right = parent:CreateTexture(nil, "BORDER")
        border.right:SetWidth(thickness)
        border.right:SetPoint("TOPRIGHT", 0, 0)
        border.right:SetPoint("BOTTOMRIGHT", 0, 0)
        border.right:SetColorTexture(0.3, 0.3, 0.3, 1)

        return border
    end

    f.border = CreateBorder(f, 2)

    -- Title bar
    f.titleBar = f:CreateTexture(nil, "ARTWORK")
    f.titleBar:SetHeight(35)
    f.titleBar:SetPoint("TOPLEFT", 2, -2)
    f.titleBar:SetPoint("TOPRIGHT", -2, -2)
    f.titleBar:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- Title text
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f.titleBar, "TOP", 0, -10)
    f.title:SetText("AFK Tracker Settings")
    f.title:SetTextColor(0.29, 0.57, 0.89) -- Light blue

    -- Close button
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", 3, 3)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 10, -45)
    content:SetPoint("BOTTOMRIGHT", -10, 55)

    -- Content background
    local contentBG = content:CreateTexture(nil, "BACKGROUND")
    contentBG:SetAllPoints()
    contentBG:SetColorTexture(0.08, 0.08, 0.08, 0.8)

    -- Add tracking status
    local statusText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOP", content, "TOP", 0, -10)
    statusText:SetTextColor(0.7, 0.7, 0.7)

    -- Function to update status text
    local function UpdateStatusText()
        local playerCount, expireHours = GetTrackingStats()
        statusText:SetText(string.format("Currently tracking %d players over the last %d hours", playerCount, expireHours))
    end

    -- Update status on show
    f:SetScript("OnShow", function(self)
        UpdateStatusText()
    end)

    -- Initial update
    UpdateStatusText()

    -- Add config options
    local inputs = {}

    inputs.deathThreshold = CreateConfigOption(content, "Death Threshold", "deathThreshold", -50,
        "Number of deaths below which a player is considered AFK")

    inputs.honorThreshold = CreateConfigOption(content, "Honor Threshold", "honorThreshold", -90,
        "Minimum honor gained to consider a player for AFK tracking")

    inputs.seenThreshold = CreateConfigOption(content, "Seen Threshold", "seenThreshold", -130,
        "Minimum times seen AFK to include in lists/announcements")

    inputs.redeemThreshold = CreateConfigOption(content, "Redeem Threshold", "redeemThreshold", -170,
        "HKs in a single match to remove from tracking")

    inputs.historyExpireHours = CreateConfigOption(content, "History Expire (hrs)", "historyExpireHours", -210,
        "Hours after which AFK records expire", UpdateStatusText)

    -- Debug checkbox instead of input
    inputs.debug = CreateDebugCheckbox(content, -250)

    -- Battle UI checkbox
    inputs.showBattleUI = CreateBattleUICheckbox(content, -280)

    -- Create custom button function
    local function CreateButton(parent, text, width, height)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width, height)

        -- Background
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        btn.bg = bg

        -- Border
        local border = CreateBorder(btn, 1)
        btn.border = border

        -- Text
        btn:SetNormalFontObject("GameFontNormal")
        btn:SetHighlightFontObject("GameFontHighlight")
        btn:SetText(text)

        -- Highlight
        btn:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        end)

        return btn
    end

    -- Reset to Defaults button
    local resetButton = CreateButton(f, "Reset Defaults", 120, 25)
    resetButton:SetPoint("BOTTOMLEFT", 20, 15)
    resetButton:SetScript("OnClick", function()
        -- Reset to defaults
        local defaults = {
            deathThreshold = 2,
            honorThreshold = 1386,
            seenThreshold = 2,
            redeemThreshold = 1,
            historyExpireHours = 24,
            debug = false
        }

        for key, value in pairs(defaults) do
            AFKTrackerDB.config[key] = value
            if inputs[key] then
                if key == "debug" then
                    inputs[key]:SetChecked(value)
                else
                    inputs[key]:SetText(tostring(value))
                end
            end
        end

        -- Reset UI settings
        AFKTrackerDB.ui.showInAV = true
        AFKTrackerDB.ui.battlePosition = DEFAULT_BATTLE_POSITION
        if inputs.showBattleUI then
            inputs.showBattleUI:SetChecked(true)
        end

        -- Reposition battle frame if it exists
        if battleFrame then
            battleFrame:ClearAllPoints()
            battleFrame:SetPoint(DEFAULT_BATTLE_POSITION.point, UIParent, DEFAULT_BATTLE_POSITION.relativePoint,
                DEFAULT_BATTLE_POSITION.xOfs, DEFAULT_BATTLE_POSITION.yOfs)
        end

        print("|cFF4A90E2[AFK Tracker]|r Settings reset to defaults.")
        UpdateStatusText()
    end)

    -- Clear History button
    local clearButton = CreateButton(f, "Clear History", 120, 25)
    clearButton:SetPoint("BOTTOMRIGHT", -20, 15)
    clearButton:SetScript("OnClick", function()
        AFKTrackerDB.records = {}
        print("|cFF4A90E2[AFK Tracker]|r AFK history cleared.")
        UpdateStatusText()
    end)

    -- Help text
    local helpText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpText:SetPoint("BOTTOM", f, "BOTTOM", 0, 45)
    helpText:SetText("Press Enter to save changes")
    helpText:SetTextColor(0.6, 0.6, 0.6)

    f.inputs = inputs
    frame = f
    return f
end

-- Toggle settings frame visibility
function UI:ToggleSettingsFrame()
    InitializeSavedVariables()

    if not frame then
        frame = CreateSettingsFrame()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Show battle frame
function UI:ShowBattleFrame()
    if not battleFrame then
        battleFrame = CreateBattleFrame()
    end
    if battleFrame then
        battleFrame:Show()
    end
end

-- Hide battle frame
function UI:HideBattleFrame()
    if battleFrame then
        battleFrame:Hide()
    end
end

-- Check if in AV
function UI:CheckZone()
    local zone = GetZoneText()
    if zone == "Alterac Valley" then
        if AFKTrackerDB.ui.showInAV then
            UI:ShowBattleFrame()
        end
    else
        UI:HideBattleFrame()
    end
end

-- Reset battle UI position
function UI:ResetBattlePosition()
    AFKTrackerDB.ui.battlePosition = DEFAULT_BATTLE_POSITION
    if battleFrame then
        battleFrame:ClearAllPoints()
        battleFrame:SetPoint(DEFAULT_BATTLE_POSITION.point, UIParent, DEFAULT_BATTLE_POSITION.relativePoint,
            DEFAULT_BATTLE_POSITION.xOfs, DEFAULT_BATTLE_POSITION.yOfs)
    end
end

-- Initialize the UI
function UI:Initialize()
    InitializeSavedVariables()

    -- Register for zone changes
    local zoneFrame = CreateFrame("Frame")
    zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    zoneFrame:SetScript("OnEvent", function(self, event)
        UI:CheckZone()
    end)
end

-- Simple initialization on login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, function()
            UI:Initialize()
        end)
    end
end)

local _, Addon = ...
local UI = assert(Addon.AchievementUI,
    "EasyAchievement achievement UI environment was not loaded")

-- WoW uses Lua 5.1 semantics; local development uses newer Lua.
-- Both branches bind this chunk to the same addon-private environment.
if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end

local MIN_LAUNCHER_SCALE = 0
local MAX_LAUNCHER_SCALE = 1
local LAUNCHER_SCALE_STEP = 0.05
local DEFAULT_MINIMAP_ANGLE = 225
local achievementLauncherSettings
local achievementMinimapButton

local function GetAchievementLauncherScale()
    return math.max(MIN_LAUNCHER_SCALE,
        math.min(MAX_LAUNCHER_SCALE,
            tonumber(Addon:GetSetting("achievementLauncherScale")) or 1))
end

local function ShouldShowAchievementLauncher()
    return Addon:GetSetting("enableAchievementEnhancement")
        and not Addon:GetSetting("achievementLauncherHidden")
        and GetAchievementLauncherScale() > 0
end

function OpenAchievementPanel()
    if achievementFavoritesPanel then
        achievementFavoritesPanel:Hide()
    end
    local currentFrame = achievementTreeFrame
    if currentFrame and (currentFrame.sourceAchievementID
        or currentFrame.rewardCategoryMode)
    then
        if not currentFrame:IsShown() then
            SaveCurrentAchievementNavigation(currentFrame)
            currentFrame:Show()
            if currentFrame.rewardCategoryMode then
                ShowAchievementRewardCategory(currentFrame.rewardCategoryMode.key,
                    "history", AchievementData.CopyNavigationState(
                        currentFrame.history[currentFrame.historyIndex]))
            else
                ShowAchievementTree(currentFrame.sourceAchievementID, "refresh")
            end
        end
        currentFrame:Raise()
        return
    end
    local achievementID = Addon:GetSetting("achievementLastTreeID")
        or GetAchievementFavorites()[1]
        or GetAchievementRecent()[1]
    if IsAchievementValid(achievementID) then
        ShowAchievementTree(achievementID)
        return
    end

    local frame = CreateAchievementTreeFrame()
    frame.sourceAchievementID = nil
    frame.rewardCategoryMode = nil
    frame.pendingRewardCategory = nil
    for _, nodeButton in ipairs(frame.nodeButtons) do
        nodeButton:Hide()
    end
    for _, line in ipairs(frame.lines) do
        line:Hide()
    end
    UpdateAchievementHeader(frame, L.ACHIEVEMENT_ENHANCEMENT, "")
    UpdateAchievementRewardHeader(frame, nil)
    frame.ATTButton:Hide()
    frame.IncompleteOnly:Hide()
    frame.IncompleteOnlyLabel:Hide()
    frame.TreeScaleControls:Hide()
    frame.EmptyText:SetText(L.ACHIEVEMENT_LAUNCHER_EMPTY)
    frame.EmptyText:Show()
    if achievementRewardFrame then
        achievementRewardFrame:Hide()
    end
    frame:Show()
    frame:Raise()
end

local function RefreshLauncherSettings()
    if achievementLauncherSettings then
        local scale = GetAchievementLauncherScale()
        achievementLauncherSettings.ScaleValue:SetText(string.format("%d%%",
            math.floor(scale * 100 + 0.5)))
        achievementLauncherSettings.ScaleMinus:SetEnabled(
            scale > MIN_LAUNCHER_SCALE)
        achievementLauncherSettings.ScalePlus:SetEnabled(
            scale < MAX_LAUNCHER_SCALE)
        achievementLauncherSettings.HideLauncher:SetChecked(
            Addon:GetSetting("achievementLauncherHidden"))
        achievementLauncherSettings.ShowMinimap:SetChecked(
            Addon:GetSetting("achievementShowMinimapIcon"))
    end
    if RefreshAchievementLauncherSettingsPanel then
        RefreshAchievementLauncherSettingsPanel()
    end
end

local function CreateLauncherCheckButton(parent, labelText, anchor)
    local checkButton = CreateFrame("CheckButton", nil, parent,
        "UICheckButtonTemplate")
    checkButton:SetSize(22, 22)
    checkButton:SetPoint("TOPLEFT", 10, anchor)
    local label = checkButton:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    label:SetPoint("LEFT", checkButton, "RIGHT", 2, 0)
    label:SetText(labelText)
    checkButton.Label = label
    return checkButton
end

local function CreateAchievementLauncherSettings(owner)
    if achievementLauncherSettings then
        achievementLauncherSettings:ClearAllPoints()
        achievementLauncherSettings:SetPoint("TOPLEFT", owner, "TOPRIGHT",
            4, 0)
        return achievementLauncherSettings
    end

    local panel = CreateFrame("Frame", "EasyAchievementLauncherSettings",
        UIParent)
    panel:SetSize(220, 100)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.035, 0.035, 0.035, 0.98)
    local border = panel:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT")
    border:SetPoint("BOTTOMRIGHT")
    border:SetColorTexture(0.72, 0.52, 0.14, 0.95)
    local inset = panel:CreateTexture(nil, "ARTWORK")
    inset:SetPoint("TOPLEFT", 1, -1)
    inset:SetPoint("BOTTOMRIGHT", -1, 1)
    inset:SetColorTexture(0.035, 0.035, 0.035, 1)

    local scaleLabel = panel:CreateFontString(nil, "OVERLAY",
        "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", 12, -12)
    scaleLabel:SetText(L.ACHIEVEMENT_LAUNCHER_SCALE)
    local minus = CreateFrame("Button", nil, panel,
        "UIPanelButtonTemplate")
    minus:SetPoint("LEFT", scaleLabel, "RIGHT", 8, 0)
    minus:SetSize(20, 20)
    minus:SetText("-")
    local value = panel:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    value:SetPoint("LEFT", minus, "RIGHT", 5, 0)
    value:SetWidth(38)
    value:SetJustifyH("CENTER")
    local plus = CreateFrame("Button", nil, panel,
        "UIPanelButtonTemplate")
    plus:SetPoint("LEFT", value, "RIGHT", 5, 0)
    plus:SetSize(20, 20)
    plus:SetText("+")
    minus:SetScript("OnClick", function()
        Addon:SetSetting("achievementLauncherScale",
            GetAchievementLauncherScale() - LAUNCHER_SCALE_STEP)
    end)
    plus:SetScript("OnClick", function()
        Addon:SetSetting("achievementLauncherScale",
            GetAchievementLauncherScale() + LAUNCHER_SCALE_STEP)
    end)
    panel.ScaleMinus = minus
    panel.ScaleValue = value
    panel.ScalePlus = plus

    local hideLauncher = CreateLauncherCheckButton(panel,
        L.ACHIEVEMENT_LAUNCHER_HIDE, -38)
    hideLauncher:SetScript("OnClick", function(self)
        Addon:SetSetting("achievementLauncherHidden",
            self:GetChecked() == true)
    end)
    panel.HideLauncher = hideLauncher

    local showMinimap = CreateLauncherCheckButton(panel,
        L.ACHIEVEMENT_MINIMAP_SHOW, -66)
    showMinimap:SetScript("OnClick", function(self)
        Addon:SetSetting("achievementShowMinimapIcon",
            self:GetChecked() == true)
    end)
    panel.ShowMinimap = showMinimap
    panel:Hide()
    table.insert(UISpecialFrames, panel:GetName())
    achievementLauncherSettings = panel
    RefreshLauncherSettings()
    return panel
end

local function PositionMinimapButton(button, angle)
    angle = math.rad(tonumber(angle) or DEFAULT_MINIMAP_ANGLE)
    local radius = (Minimap:GetWidth() or 140) / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * radius, math.sin(angle) * radius)
end

local function GetCursorMinimapAngle()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    local offsetY = cursorY / scale - centerY
    local offsetX = cursorX / scale - centerX
    local radians
    if math.atan2 then
        radians = math.atan2(offsetY, offsetX)
    elseif offsetX > 0 then
        radians = math.atan(offsetY / offsetX)
    elseif offsetX < 0 then
        radians = math.atan(offsetY / offsetX)
            + (offsetY >= 0 and math.pi or -math.pi)
    else
        radians = offsetY >= 0 and math.pi / 2 or -math.pi / 2
    end
    return (math.deg(radians) + 360) % 360
end

local function CreateAchievementMinimapButton()
    if achievementMinimapButton then
        return achievementMinimapButton
    end
    if not Minimap then
        return nil
    end

    local button = CreateFrame("Button", "EasyAchievementMinimapButton",
        Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("CENTER")
    background:SetSize(26, 26)
    background:SetColorTexture(0.02, 0.02, 0.02, 1)
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetPoint("CENTER")
    mask:SetSize(26, 26)
    background:AddMaskTexture(mask)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(20, 20)
    if not SetTextureAtlas(icon, "UI-Achievement-Shield-NoPoints") then
        icon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
        icon:SetTexCoord(0, 0.5, 0, 0.5)
    end
    icon:AddMaskTexture(mask)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT")
    border:SetSize(54, 54)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture(
        "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(self)
        if not self.wasDragged then
            OpenAchievementPanel()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.ACHIEVEMENT_ENHANCEMENT)
        GameTooltip:AddLine(L.ACHIEVEMENT_MINIMAP_OPEN, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        self.wasDragged = true
        self:SetScript("OnUpdate", function(dragButton)
            PositionMinimapButton(dragButton, GetCursorMinimapAngle())
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        Addon:SetSetting("achievementMinimapAngle",
            GetCursorMinimapAngle())
        C_Timer.After(0, function()
            self.wasDragged = nil
        end)
    end)
    PositionMinimapButton(button,
        Addon:GetSetting("achievementMinimapAngle"))
    button:Hide()
    achievementMinimapButton = button
    return button
end

function UpdateAchievementLauncherVisibility()
    if achievementLauncher then
        achievementLauncher:SetShown(ShouldShowAchievementLauncher())
        if not achievementLauncher:IsShown() then
            achievementLauncher.QuickSearch:HideSearch()
            if achievementLauncherSettings then
                achievementLauncherSettings:Hide()
            end
        end
    end
    if achievementMinimapButton then
        achievementMinimapButton:SetShown(
            Addon:GetSetting("enableAchievementEnhancement")
                and Addon:GetSetting("achievementShowMinimapIcon"))
    end
    RefreshLauncherSettings()
end

function ApplyAchievementLauncherScale(value)
    local scale = math.max(MIN_LAUNCHER_SCALE,
        math.min(MAX_LAUNCHER_SCALE, tonumber(value) or 1))
    if achievementLauncher and scale > 0 then
        achievementLauncher:SetScale(scale)
        achievementLauncher.QuickSearch:SetScale(scale)
    end
    UpdateAchievementLauncherVisibility()
end

function CreateAchievementLauncher()
    if achievementLauncher then
        return achievementLauncher
    end
    if not CreateFrame or not UIParent then
        return nil
    end

    local button = CreateFrame("Button", "EasyAchievementLauncher",
        UIParent)
    button:SetSize(42, 42)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    if button.SetDontSavePosition then
        button:SetDontSavePosition(true)
    end
    if Addon.Anchors then
        Addon.Anchors:Position(button, "achievementLauncherPosition",
            0.035, 0.65)
    else
        button:SetPoint("LEFT", UIParent, "LEFT", 40, 0)
    end

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(34, 34)
    if not SetTextureAtlas(icon, "UI-Achievement-Shield-NoPoints") then
        icon:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Shields")
        icon:SetTexCoord(0, 0.5, 0, 0.5)
    end
    button.Icon = icon

    local hoverIcon = button:CreateTexture(nil, "OVERLAY")
    hoverIcon:SetPoint("CENTER")
    hoverIcon:SetSize(34, 34)
    if not SetTextureAtlas(hoverIcon,
        "UI-Achievement-Shield-NoPoints")
    then
        hoverIcon:SetTexture(
            "Interface\\AchievementFrame\\UI-Achievement-Shields")
        hoverIcon:SetTexCoord(0, 0.5, 0, 0.5)
    end
    hoverIcon:SetBlendMode("ADD")
    hoverIcon:SetAlpha(0.15)
    hoverIcon:Hide()
    button.HoverIcon = hoverIcon
    local hoverPulse = hoverIcon:CreateAnimationGroup()
    hoverPulse:SetLooping("REPEAT")
    local hoverFadeIn = hoverPulse:CreateAnimation("Alpha")
    hoverFadeIn:SetFromAlpha(0.15)
    hoverFadeIn:SetToAlpha(0.75)
    hoverFadeIn:SetDuration(0.4)
    hoverFadeIn:SetOrder(1)
    local hoverFadeOut = hoverPulse:CreateAnimation("Alpha")
    hoverFadeOut:SetFromAlpha(0.75)
    hoverFadeOut:SetToAlpha(0.15)
    hoverFadeOut:SetDuration(0.4)
    hoverFadeOut:SetOrder(2)
    button.HoverPulse = hoverPulse
    button.QuickSearch = CreateAchievementLauncherSearch(button)

    button:SetScript("OnDragStart", function(self)
        self.wasDragged = true
        self.QuickSearch:HideSearch()
        self:StartMoving()
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if Addon.Anchors then
            Addon.Anchors:SavePosition(self,
                "achievementLauncherPosition")
        end
        C_Timer.After(0, function()
            self.wasDragged = nil
        end)
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.wasDragged then
            return
        end
        self.QuickSearch:HideSearch()
        if mouseButton == "RightButton" then
            local panel = CreateAchievementLauncherSettings(self)
            if panel:IsShown() then
                panel:Hide()
            else
                panel:Show()
                panel:Raise()
            end
            return
        end
        OpenAchievementPanel()
    end)
    button:SetScript("OnEnter", function(self)
        self.HoverIcon:Show()
        self.HoverPulse:Play()
        self.QuickSearch:ShowAnimated()
    end)
    button:SetScript("OnLeave", function(self)
        self.HoverPulse:Stop()
        self.HoverIcon:Hide()
        self.QuickSearch:ScheduleHide()
    end)
    achievementLauncher = button
    ApplyAchievementLauncherScale(
        Addon:GetSetting("achievementLauncherScale"))
    return button
end

function ApplyAchievementEnhancement(enabled)
    if enabled then
        local launcher = CreateAchievementLauncher()
        CreateAchievementMinimapButton()
        if launcher then
            ApplyAchievementLauncherScale(
                Addon:GetSetting("achievementLauncherScale"))
        end
        for _, popupID in ipairs(
            Addon:GetSetting("achievementPopupIDs") or {})
        do
            ShowAchievementPopup(popupID, false)
        end
    else
        if achievementLauncher then
            achievementLauncher:Hide()
            achievementLauncher.QuickSearch:HideSearch()
        end
        if achievementLauncherSettings then
            achievementLauncherSettings:Hide()
        end
        if achievementMinimapButton then
            achievementMinimapButton:Hide()
        end
        if achievementTreeFrame then
            achievementTreeFrame:Hide()
        end
        if achievementFavoritesPanel then
            achievementFavoritesPanel:Hide()
        end
        for _, popup in ipairs(achievementPopupFrames) do
            popup:Hide()
        end
        if achievementRewardFrame then
            achievementRewardFrame:Hide()
        end
    end
end

function RefreshAchievementPopup()
    for _, frame in ipairs(achievementPopupFrames) do
        if frame:IsShown() and frame.achievementID then
            local data = GetAchievementData(frame.achievementID)
            if data then
                PopulateAchievementPopup(frame, data)
            end
        end
    end
end

criteriaRefreshPending = false
function RefreshVisibleCriteriaProgress()
    criteriaRefreshPending = false
    RefreshAchievementPopup()

    local frame = achievementTreeFrame
    if frame and frame:IsShown() and frame.AchievementCard
        and frame.AchievementCard:IsShown()
    then
        local header = frame.AchievementCardHeader
        local achievementID = header and header.node and header.node.id
        if achievementID then
            ShowAchievementCardInTree(frame, achievementID)
        end
    end
    if achievementFavoritesPanel and achievementFavoritesPanel:IsShown()
        and RefreshFavoritesPanel
    then
        RefreshFavoritesPanel()
    end
end

function OnCriteriaUpdate()
    if criteriaRefreshPending then
        return
    end
    criteriaRefreshPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(CRITERIA_REFRESH_DELAY, RefreshVisibleCriteriaProgress)
    else
        RefreshVisibleCriteriaProgress()
    end
end

function OnAchievementEarned(_, achievementID)
    RefreshAchievementPopup()
    local frame = achievementTreeFrame
    if not frame or not frame:IsShown() or not frame.sourceAchievementID then
        return
    end
    ShowAchievementTree(frame.sourceAchievementID, "refresh")
    for _, node in ipairs(frame.layoutNodes or {}) do
        if node.id == achievementID and node.button
            and node.button.CompletionAnimation
        then
            node.button.CompletionAnimation:Stop()
            node.button.CompletionAnimation:Play()
            break
        end
    end
end

function OnRewardItemInfoReceived(_, itemID)
    local frame = achievementTreeFrame
    if not frame or not frame:IsShown() or not frame.sourceAchievementID
        or not achievementRewardFrame
        or not achievementRewardFrame:IsShown()
        or not achievementRewardFrame.rewardItemIDs
        or not achievementRewardFrame.rewardItemIDs[itemID]
    then
        return
    end
    UpdateAchievementRewardPanel(frame, frame.sourceAchievementID)
end

local rewardCollectionRefreshPending = false
local function OnRewardCollectionChanged(event)
    if event == "NEW_MOUNT_ADDED" then
        AchievementRewards.InvalidateCollectionIndexes("mount")
    elseif event == "TRANSMOG_COLLECTION_UPDATED" then
        AchievementRewards.InvalidateCollectionIndexes("appearance")
    end
    local frame = achievementTreeFrame
    if rewardCollectionRefreshPending or not frame or not frame:IsShown()
        or not frame.sourceAchievementID or not achievementRewardFrame
        or not achievementRewardFrame:IsShown()
    then
        return
    end
    rewardCollectionRefreshPending = true
    C_Timer.After(0, function()
        rewardCollectionRefreshPending = false
        if frame:IsShown() and frame.sourceAchievementID
            and achievementRewardFrame:IsShown()
        then
            UpdateAchievementRewardHeader(frame, frame.sourceAchievementID)
            UpdateAchievementRewardPanel(frame, frame.sourceAchievementID)
        end
    end)
end

Addon:RegisterSetting("enableAchievementEnhancement", true,
    Addon.BooleanSetting, ApplyAchievementEnhancement)
Addon:RegisterSetting("achievementTreeWidth", DEFAULT_FRAME_WIDTH,
    Addon.NumberSetting(MIN_FRAME_WIDTH, MAX_FRAME_WIDTH, 1))
Addon:RegisterSetting("achievementTreeHeight", DEFAULT_FRAME_HEIGHT,
    Addon.NumberSetting(MIN_FRAME_HEIGHT, MAX_FRAME_HEIGHT, 1))
Addon:RegisterSetting("achievementCardScale", 1,
    Addon.NumberSetting(MIN_ACHIEVEMENT_CARD_SCALE,
        MAX_ACHIEVEMENT_CARD_SCALE, ACHIEVEMENT_CARD_SCALE_STEP),
    ApplyAchievementCardScale)
Addon:RegisterSetting("achievementPopupScale", 1,
    Addon.NumberSetting(MIN_ACHIEVEMENT_CARD_SCALE,
        MAX_ACHIEVEMENT_CARD_SCALE, ACHIEVEMENT_CARD_SCALE_STEP),
    ApplyAchievementPopupScale)
Addon:RegisterSetting("achievementPopupAlpha", 1,
    Addon.NumberSetting(MIN_ACHIEVEMENT_POPUP_ALPHA,
        MAX_ACHIEVEMENT_POPUP_ALPHA, ACHIEVEMENT_POPUP_ALPHA_STEP),
    ApplyAchievementPopupAlpha)
Addon:RegisterSetting("achievementPopupIDs", {},
    SanitizeAchievementFavorites)
Addon:RegisterSetting("achievementPopupPosition", nil, Addon.PositionSetting)
Addon:RegisterSetting("achievementLastTreeID", nil, SanitizeAchievementID)
Addon:RegisterSetting("achievementLauncherPosition", nil,
    Addon.PositionSetting)
Addon:RegisterSetting("achievementLauncherScale", 1,
    Addon.NumberSetting(MIN_LAUNCHER_SCALE, MAX_LAUNCHER_SCALE,
        LAUNCHER_SCALE_STEP), ApplyAchievementLauncherScale)
Addon:RegisterSetting("achievementLauncherHidden", false,
    Addon.BooleanSetting, UpdateAchievementLauncherVisibility)
Addon:RegisterSetting("achievementShowMinimapIcon", false,
    Addon.BooleanSetting, UpdateAchievementLauncherVisibility)
Addon:RegisterSetting("achievementMinimapAngle", DEFAULT_MINIMAP_ANGLE,
    Addon.NumberSetting(0, 360, 1), function(value)
        if achievementMinimapButton then
            PositionMinimapButton(achievementMinimapButton, value)
        end
    end)
Addon:RegisterSetting("achievementFavorites", {},
    SanitizeAchievementFavorites)
Addon:RegisterSetting("achievementRecent", {}, SanitizeAchievementFavorites)
Addon:RegisterSetting("achievementTreeStates", {},
    SanitizeAchievementTreeStates)
Addon:RegisterSetting("achievementRewardCategoryStates", {},
    SanitizeAchievementRewardCategoryStates)
Addon:RegisterEvent("ACHIEVEMENT_EARNED", OnAchievementEarned)
Addon:RegisterEvent("CRITERIA_UPDATE", OnCriteriaUpdate)
Addon:RegisterEvent("GET_ITEM_INFO_RECEIVED", OnRewardItemInfoReceived)
Addon:RegisterEvent("PET_JOURNAL_LIST_UPDATE", OnRewardCollectionChanged)
Addon:RegisterEvent("NEW_MOUNT_ADDED", OnRewardCollectionChanged)
Addon:RegisterEvent("TRANSMOG_COLLECTION_UPDATED", OnRewardCollectionChanged)
Addon:RegisterEvent("TOYS_UPDATED", OnRewardCollectionChanged)
Addon:RegisterEvent("PLAYER_LOGIN", function()
    ApplyAchievementEnhancement(
        Addon:GetSetting("enableAchievementEnhancement"))
end)

_G.SLASH_EASYACHIEVEMENT1 = "/eat"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.EASYACHIEVEMENT = function()
    OpenAchievementPanel()
end

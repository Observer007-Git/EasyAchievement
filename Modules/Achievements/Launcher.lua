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
            local panel = CreateAchievementFavoritesPanel(self)
            if panel:IsShown() then
                panel:Hide()
            else
                panel:Show()
                panel:Raise()
            end
            return
        end
        if achievementFavoritesPanel then
            achievementFavoritesPanel:Hide()
        end
        local achievementID = Addon:GetSetting("achievementLastTreeID")
            or GetAchievementFavorites()[1]
            or GetAchievementRecent()[1]
        if IsAchievementValid(achievementID) then
            ShowAchievementTree(achievementID)
        else
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
    button:Hide()
    achievementLauncher = button
    return button
end

function ApplyAchievementEnhancement(enabled)
    if enabled then
        local launcher = CreateAchievementLauncher()
        if launcher then
            launcher:Show()
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
Addon:RegisterSetting("achievementFavorites", {},
    SanitizeAchievementFavorites)
Addon:RegisterSetting("achievementRecent", {}, SanitizeAchievementFavorites)
Addon:RegisterSetting("achievementTreeStates", {},
    SanitizeAchievementTreeStates)
Addon:RegisterEvent("ACHIEVEMENT_EARNED", OnAchievementEarned)
Addon:RegisterEvent("CRITERIA_UPDATE", OnCriteriaUpdate)
Addon:RegisterEvent("GET_ITEM_INFO_RECEIVED", OnRewardItemInfoReceived)
Addon:RegisterEvent("PLAYER_LOGIN", function()
    ApplyAchievementEnhancement(
        Addon:GetSetting("enableAchievementEnhancement"))
end)

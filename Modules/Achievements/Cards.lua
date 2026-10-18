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

function FormatAchievementCardDate(card, data)
    if not card or not card.DateCompleted or not data or not data.completed
        or type(data.year) ~= "number" or type(data.month) ~= "number"
        or type(data.day) ~= "number"
    then
        return
    end
    local fullYear = data.year < 100 and 2000 + data.year or data.year
    card.DateCompleted:ClearAllPoints()
    card.DateCompleted:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 8)
    card.DateCompleted:SetWidth(180)
    card.DateCompleted:SetJustifyH("RIGHT")
    card.DateCompleted:SetText(string.format(
        L.ACHIEVEMENT_COMPLETION_DATE_FORMAT,
        fullYear, data.month, data.day))
    card.DateCompleted:Show()
end

function ConfigureAchievementCardChildLinks(objectivesFrame)
    for _, button in ipairs(objectivesFrame.metas or {}) do
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
            if not IsAchievementValid(self.id) then
                return
            end
            if mouseButton == "RightButton" then
                OpenAchievementContextMenu(self, self.id)
            elseif IsShiftKeyDown() then
                InsertAchievementLink(self.id)
            else
                ShowAchievementTree(self.id, nil, nil, true)
            end
        end)
    end
end

function SaveAchievementPopupIDs()
    local achievementIDs = {}
    for _, frame in ipairs(achievementPopupFrames) do
        if frame.achievementID then
            achievementIDs[#achievementIDs + 1] = frame.achievementID
        end
    end
    Addon:SetSetting("achievementPopupIDs", achievementIDs)
end

ReflowAchievementPopups = function()
    for index, frame in ipairs(achievementPopupFrames) do
        frame:ClearAllPoints()
        if index == 1 then
            if Addon.Anchors then
                Addon.Anchors:Position(frame, "achievementPopupPosition",
                    0.5, 0.65)
            else
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
            end
        else
            frame:SetPoint("TOPLEFT", achievementPopupFrames[index - 1],
                "BOTTOMLEFT", 0, -6)
        end
    end
end

function CloseAchievementPopup(frame)
    for index, popup in ipairs(achievementPopupFrames) do
        if popup == frame then
            table.remove(achievementPopupFrames, index)
            break
        end
    end
    frame.achievementID = nil
    frame:Hide()
    achievementPopupPool[#achievementPopupPool + 1] = frame
    ReflowAchievementPopups()
    SaveAchievementPopupIDs()
end

function CreateAchievementPopupFrame()
    local frame = table.remove(achievementPopupPool)
    if frame then
        achievementPopupFrames[#achievementPopupFrames + 1] = frame
        ReflowAchievementPopups()
        return frame
    end
    if not LoadAchievementUI() then
        return nil
    end

    achievementPopupFrameSerial = achievementPopupFrameSerial + 1
    frame = CreateFrame("Frame", "EasyAchievementPopupFrame"
        .. achievementPopupFrameSerial, UIParent)
    frame:SetSize(434, 142)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    if frame.SetDontSavePosition then
        frame:SetDontSavePosition(true)
    end

    local card = CreateFrame("Button", "EasyAchievementPopupCard"
        .. achievementPopupFrameSerial, frame, "AchievementTemplate")
    card:SetPoint("TOPLEFT")
    card.EasyAchievementPopup = true
    card.GetElementData = function(self)
        return self.EasyAchievementElementData
    end
    local objectives = CreateFrame("Frame", nil, card,
        "AchievementFrameAchievementsObjectivesTemplate")
    card.GetObjectiveFrame = function()
        return objectives
    end
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnClick", function(self, mouseButton)
        if self.EasyAchievementWasDragged then
            return
        end
        if self.EasyAchievementElementData then
            if mouseButton == "RightButton" then
                OpenAchievementContextMenu(self,
                    self.EasyAchievementElementData.id)
            elseif IsShiftKeyDown() then
                InsertAchievementLink(self.EasyAchievementElementData.id)
            else
                ShowAchievementTree(self.EasyAchievementElementData.id,
                    nil, nil, true)
            end
        end
    end)
    card:SetScript("OnEnter", function() end)
    card:SetScript("OnLeave", function() end)
    local cardHighlight = card:GetHighlightTexture()
    if cardHighlight then
        cardHighlight:SetAlpha(0)
    end
    card:SetScript("OnDragStart", function(self)
        self.EasyAchievementWasDragged = true
        local root = achievementPopupFrames[1]
        if root then
            self.EasyAchievementDragRoot = root
            root:StartMoving()
        end
    end)
    card:SetScript("OnDragStop", function(self)
        local root = self.EasyAchievementDragRoot
        self.EasyAchievementDragRoot = nil
        if root then
            root:StopMovingOrSizing()
        end
        if root and Addon.Anchors then
            Addon.Anchors:SavePosition(root, "achievementPopupPosition")
        end
        ReflowAchievementPopups()
        if C_Timer then
            C_Timer.After(0, function()
                self.EasyAchievementWasDragged = nil
            end)
        else
            self.EasyAchievementWasDragged = nil
        end
    end)
    frame.Card = card

    local closeButton = CreateFrame("Button", nil, frame,
        "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", card, "TOPRIGHT", 5, 5)
    closeButton:SetSize(24, 24)
    closeButton:SetFrameLevel(card:GetFrameLevel() + 6)
    closeButton:SetScript("OnClick", function()
        CloseAchievementPopup(frame)
    end)

    frame:Hide()
    achievementPopupFrames[#achievementPopupFrames + 1] = frame
    ReflowAchievementPopups()
    return frame
end

function PopulateAchievementPopup(frame, data)
    local card = frame.Card
    card.EasyAchievementElementData = { id = data.id }
    card:Init(card.EasyAchievementElementData)
    local cardHighlight = card:GetHighlightTexture()
    if cardHighlight then
        cardHighlight:SetAlpha(0)
    end
    local height = card:DisplayObjectives(data.id, card.completed)
    card:Expand(height)
    FormatAchievementCardDate(card, data)
    frame.achievementID = data.id
    ApplyAchievementPopupScale(GetAchievementPopupScale())
    frame:SetAlpha(GetAchievementPopupAlpha())
    frame:Show()
    frame:Raise()
end

ShowAchievementPopup = function(achievementID, saveSelection)
    local data = GetAchievementData(achievementID)
    if not data then
        return
    end
    local frame
    for _, popup in ipairs(achievementPopupFrames) do
        if popup.achievementID == data.id then
            frame = popup
            break
        end
    end
    frame = frame or CreateAchievementPopupFrame()
    if not frame then
        return
    end

    PopulateAchievementPopup(frame, data)
    if saveSelection ~= false then
        SaveAchievementPopupIDs()
    end
end

function ShowAchievementCardInTree(frame, achievementID)
    if not LoadAchievementUI() then
        return false
    end
    local data = GetAchievementData(achievementID)
    if not data then
        return false
    end

    local card = frame.AchievementCard
    if not card then
        card = CreateFrame("Button", "EasyAchievementTreeCard", frame,
            "AchievementTemplate")
        card:SetFrameLevel(frame:GetFrameLevel() + 50)
        card.EasyAchievementPopup = true
        card.GetElementData = function(self)
            return self.EasyAchievementElementData
        end
        local objectives = CreateFrame("Frame", nil, card,
            "AchievementFrameAchievementsObjectivesTemplate")
        card.GetObjectiveFrame = function()
            return objectives
        end
        card:EnableMouse(false)
        frame.AchievementCard = card

        local header = CreateFrame("Button", nil, frame)
        header:SetHeight(30)
        header:SetFrameLevel(card:GetFrameLevel() + 2)
        header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local highlight = header:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture(
            "Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.75)
        local icon = header:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", 4, 0)
        icon:SetSize(20, 20)
        icon:SetTexCoord(0, 1, 0, 1)
        header.Icon = icon
        local border = header:CreateTexture(nil, "OVERLAY")
        border:SetPoint("CENTER", icon, "CENTER", -0.33, 0.67)
        border:SetSize(28, 28)
        border:SetTexture(
            "Interface\\AchievementFrame\\UI-Achievement-IconFrame")
        border:SetTexCoord(0, 0.5625, 0, 0.5625)
        header.Border = border
        local rewardBorder = header:CreateTexture(nil, "OVERLAY", nil, 7)
        rewardBorder:SetAllPoints(icon)
        SetTextureAtlas(rewardBorder, "duit_Arrows_Socketed")
        rewardBorder:Hide()
        header.RewardBorder = rewardBorder
        local label = header:CreateFontString(nil, "OVERLAY",
            "GameFontNormalLarge")
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        header.Label = label
        header:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" and self.node
                and OpenAchievementContextMenu
            then
                OpenAchievementContextMenu(self, self.node.id)
            elseif mouseButton == "LeftButton" and self.node
                and IsShiftKeyDown()
            then
                InsertAchievementLink(self.node.id)
            end
        end)
        header:SetScript("OnEnter", function(self)
            SetAchievementTextColor(self.Label,
                self.node and self.node.completed, true, 0.72)
            ShowAchievementTooltip(self)
        end)
        header:SetScript("OnLeave", function(self)
            SetAchievementTextColor(self.Label,
                self.node and self.node.completed, false, 0.72)
            GameTooltip:Hide()
        end)
        frame.AchievementCardHeader = header

        local treeButton = CreateFrame("Button", nil, frame,
            "UIPanelButtonTemplate")
        treeButton:SetSize(112, 22)
        treeButton:SetFrameLevel(card:GetFrameLevel() + 2)
        treeButton:SetText(L.ACHIEVEMENT_TREE_VIEW)
        treeButton:SetScript("OnClick", function(self)
            if self.achievementID then
                ShowAchievementTree(self.achievementID)
            end
        end)
        treeButton:Hide()
        frame.AchievementCardTreeButton = treeButton

        local backButton = CreateFrame("Button", nil, frame)
        backButton:SetSize(48, 67)
        backButton:SetFrameLevel(card:GetFrameLevel() + 2)
        backButton:SetNormalAtlas(
            "CovenantSanctum-Renown-DoubleArrow", true)
        backButton:SetPushedAtlas(
            "CovenantSanctum-Renown-DoubleArrow-Depressed", true)
        backButton:SetScript("OnClick", function()
            NavigateAchievementHistory(frame, -1)
        end)
        backButton:Hide()
        frame.AchievementCardBackButton = backButton

        local forwardButton = CreateFrame("Button", nil, frame)
        forwardButton:SetSize(48, 67)
        forwardButton:SetFrameLevel(card:GetFrameLevel() + 2)
        forwardButton:SetNormalAtlas(
            "CovenantSanctum-Renown-DoubleArrow", true)
        forwardButton:GetNormalTexture():SetRotation(math.pi)
        forwardButton:SetPushedAtlas(
            "CovenantSanctum-Renown-DoubleArrow-Depressed", true)
        forwardButton:GetPushedTexture():SetRotation(math.pi)
        forwardButton:SetScript("OnClick", function()
            NavigateAchievementHistory(frame, 1)
        end)
        forwardButton:Hide()
        frame.AchievementCardForwardButton = forwardButton
    end

    card.EasyAchievementElementData = { id = data.id }
    card:Init(card.EasyAchievementElementData)
    local height = card:DisplayObjectives(data.id, card.completed)
    ConfigureAchievementCardChildLinks(card:GetObjectiveFrame())
    card:Expand(height)
    FormatAchievementCardDate(card, data)
    UpdateAchievementRewardPanel(frame, data.id)
    local cardOffsetX = -(GetAchievementRewardPanelWidth(frame) / 2 + 6)
    card:ClearAllPoints()
    card:SetPoint("CENTER", frame, "CENTER", cardOffsetX, -45)
    ApplyAchievementCardScale(GetAchievementCardScale())
    card:Show()
    local canGoBack = (frame.historyIndex or 1) > 1
    local canGoForward = (frame.historyIndex or 0)
        < #(frame.history or {})
    local cardBackButton = frame.AchievementCardBackButton
    cardBackButton:ClearAllPoints()
    cardBackButton:SetPoint("RIGHT", card, "LEFT", -2, 0)
    cardBackButton:SetShown(canGoBack)
    local cardForwardButton = frame.AchievementCardForwardButton
    cardForwardButton:ClearAllPoints()
    cardForwardButton:SetPoint("LEFT", card, "RIGHT", 2, 0)
    cardForwardButton:SetShown(canGoForward)
    local header = frame.AchievementCardHeader
    header.node = data
    header.Icon:SetTexture(data.icon)
    header.Icon:SetDesaturated(not data.completed)
    header.Border:SetDesaturated(not data.completed)
    header.Border:SetAlpha(data.completed and 1 or 0.72)
    header.RewardBorder:SetShown(
        Addon.AchievementRewards.Has(data.id, data))
    header.Label:SetText(data.name)
    SetAchievementTextColor(header.Label, data.completed, false, 0.72)
    header:SetWidth(34 + math.ceil(header.Label:GetStringWidth()) + 6)
    header:ClearAllPoints()
    header:SetPoint("BOTTOM", card, "TOP", 0, 10)
    header:Show()
    local treeButton = frame.AchievementCardTreeButton
    treeButton.achievementID = data.id
    treeButton:ClearAllPoints()
    treeButton:SetPoint("TOP", card, "BOTTOM", 0, -8)
    treeButton:SetShown(#GetChildAchievementIDs(data.id) > 0)
    frame.Stats:SetText("")
    frame.Stats:Hide()
    frame.Legend:Hide()
    LayoutAchievementHeader(frame)
    frame.CardScaleControls:Show()
    frame.TreeScaleControls:Hide()
    frame.IncompleteOnly:Hide()
    frame.IncompleteOnlyLabel:Hide()
    frame.FitButton:Hide()
    frame.ScrollFrame:Hide()
    frame.HorizontalScroll:Hide()
    frame.Navigator:Hide()
    frame.EmptyText:Hide()
    return true
end

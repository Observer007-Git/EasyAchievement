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
            local achievementID = self.id
            local function OpenCard()
                local frame = achievementTreeFrame
                if frame and objectivesFrame:GetParent()
                    == frame.AchievementCard
                then
                    OpenAchievementPathCard(frame, achievementID)
                else
                    Navigation.OpenCard(achievementID)
                end
            end
            if mouseButton == "RightButton" then
                OpenAchievementContextMenu(self, achievementID, OpenCard,
                    function()
                        local frame = achievementTreeFrame
                        if frame and objectivesFrame:GetParent() == frame.AchievementCard then
                            Navigation.OpenRelatedTree(frame, achievementID)
                        else
                            ShowAchievementTree(achievementID)
                        end
                    end)
            elseif IsShiftKeyDown() then
                InsertAchievementLink(self.id)
            else
                OpenCard()
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
                Navigation.OpenCard(self.EasyAchievementElementData.id)
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
    ConfigureAchievementCardChildLinks(card:GetObjectiveFrame())
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

local CARD_LIST_ROW_HEIGHT = 26

local function UpdateAchievementCardList(frame, context, card)
    local list = frame.AchievementCardList
    if not context then
        if list then list:Hide() end
        return
    end
    if not list then
        list = CreateFrame("Frame", nil, frame)
        list:SetFrameLevel(frame:GetFrameLevel() + 52)
        list:SetClampedToScreen(true)
        local background = list:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.06, 0.05, 0.04, 0.88)
        local divider = list:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPRIGHT")
        divider:SetPoint("BOTTOMRIGHT")
        divider:SetWidth(2)
        divider:SetColorTexture(0.38, 0.27, 0.1, 0.8)
        local scroll = CreateFrame("ScrollFrame", nil, list)
        scroll:SetPoint("TOPLEFT", 4, -4)
        scroll:SetPoint("BOTTOMRIGHT", -6, 4)
        scroll:EnableMouseWheel(true)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(1, 1)
        scroll:SetScrollChild(content)
        list.Scroll = scroll
        list.Content = content
        list.Rows = {}
        local function RefreshRows()
            local active = list.Context
            if not active then return end
            local first = math.floor(scroll:GetVerticalScroll()
                / CARD_LIST_ROW_HEIGHT) + 1
            for slot, row in ipairs(list.Rows) do
                local index = first + slot - 1
                local id = active.achievementIDs[index]
                row:SetShown(id ~= nil)
                if id then
                    local data = GetAchievementData(id)
                    row.index = index
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0,
                        -(index - 1) * CARD_LIST_ROW_HEIGHT)
                    row:SetWidth(content:GetWidth())
                    row.Icon:SetTexture(data and data.icon or 134400)
                    row.Label:SetText(index .. ". " ..
                        (data and data.name or tostring(id)))
                    row.Selected:SetShown(index == active.index)
                    row.Label:SetTextColor(index == active.index
                        and 1 or 0.85, index == active.index
                        and 0.82 or 0.82, index == active.index
                        and 0.36 or 0.73)
                end
            end
        end
        local function ScrollBy(delta)
            scroll:SetVerticalScroll(math.max(0, math.min(
                scroll:GetVerticalScrollRange(),
                scroll:GetVerticalScroll()
                    - delta * CARD_LIST_ROW_HEIGHT * 3)))
            RefreshRows()
        end
        scroll:SetScript("OnMouseWheel", function(_, delta)
            ScrollBy(delta)
        end)
        for slot = 1, 42 do
            local row = CreateFrame("Button", nil, content)
            row:SetHeight(CARD_LIST_ROW_HEIGHT)
            row:EnableMouseWheel(true)
            local selected = row:CreateTexture(nil, "BACKGROUND")
            selected:SetAllPoints()
            selected:SetColorTexture(0.46, 0.32, 0.1, 0.55)
            row.Selected = selected
            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(0.65, 0.48, 0.14, 0.2)
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", 3, 0)
            icon:SetSize(18, 18)
            row.Icon = icon
            local label = row:CreateFontString(nil, "OVERLAY",
                "GameFontHighlightSmall")
            label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            label:SetPoint("RIGHT", -3, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            row.Label = label
            row:SetScript("OnClick", function(self)
                local active = list.Context
                if active and self.index ~= active.index then
                    if active.kind == "tree" then
                        NavigateAchievementTreeCard(frame,
                            self.index - active.index)
                    else
                        NavigateAchievementRewardCategoryCard(frame,
                            self.index - active.index)
                    end
                end
            end)
            row:SetScript("OnMouseWheel", function(_, delta)
                ScrollBy(delta)
            end)
            list.Rows[slot] = row
        end
        list.RefreshRows = RefreshRows
        frame.AchievementCardList = list
    end
    local inset = 24
    local cardLeft = card:GetLeft()
    local frameLeft = frame:GetLeft()
    local available = cardLeft and frameLeft
        and cardLeft - frameLeft - inset - 62 or 0
    local inside = available >= 120
    local width = inside and math.min(180, available) or 180
    list:ClearAllPoints()
    if inside then
        list:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -135)
        list:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, 26)
    else
        list:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, -135)
        list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -6, 26)
    end
    list:SetWidth(width)
    list.Content:SetSize(width - 10,
        math.max(1, #context.achievementIDs * CARD_LIST_ROW_HEIGHT))
    local contextKey = context.key or context.rootID
    if list.VisitID ~= context.visitID or list.Key ~= contextKey then
        list.Scroll:SetVerticalScroll(0)
    end
    list.VisitID = context.visitID
    list.Key = contextKey
    list.Context = context
    list:Show()
    local offset = list.Scroll:GetVerticalScroll()
    local top = (context.index - 1) * CARD_LIST_ROW_HEIGHT
    local bottom = top + CARD_LIST_ROW_HEIGHT
    local height = list.Scroll:GetHeight()
    if top < offset then
        list.Scroll:SetVerticalScroll(top)
    elseif height > 0 and bottom > offset + height then
        list.Scroll:SetVerticalScroll(bottom - height)
    end
    list.RefreshRows()
end

UpdateAchievementCardList = function(frame)
    if frame and frame.AchievementCardList and frame.AchievementCardList:IsShown()
        and frame.AchievementCard
    then
        UpdateAchievementCardList(frame,
            frame.rewardCategoryCardContext or frame.treeCardContext,
            frame.AchievementCard)
    end
end

local function GetCatalogFallbackCard(frame)
    if frame.CatalogFallbackCard then return frame.CatalogFallbackCard end
    local card = CreateFrame("Frame", nil, frame)
    card:SetFrameLevel(frame:GetFrameLevel() + 50)
    card:SetSize(330, 160)
    local background = card:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.09, 0.07, 0.04, 0.96)
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = card:CreateTexture(nil, "BORDER")
        line:SetColorTexture(0.55, 0.4, 0.18, 0.85)
        if edge == "TOP" or edge == "BOTTOM" then
            line:SetHeight(1)
            line:SetPoint(edge .. "LEFT", card, edge .. "LEFT")
            line:SetPoint(edge .. "RIGHT", card, edge .. "RIGHT")
        else
            line:SetWidth(1)
            line:SetPoint("TOP" .. edge, card, "TOP" .. edge)
            line:SetPoint("BOTTOM" .. edge, card, "BOTTOM" .. edge)
        end
    end
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 18, -18)
    icon:SetSize(36, 36)
    card.Icon = icon
    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    title:SetJustifyH("LEFT")
    card.Title = title
    local points = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    points:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    card.Points = points
    local description = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -75)
    description:SetWidth(294)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    card.Description = description
    card:Hide()
    frame.CatalogFallbackCard = card
    return card
end

function ShowAchievementCardInTree(frame, achievementID, progressOnly)
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
        local rewardMarker = header:CreateTexture(nil, "OVERLAY", nil, 7)
        rewardMarker:SetPoint("CENTER", icon, "TOPRIGHT")
        rewardMarker:SetSize(12, 12)
        SetTextureAtlas(rewardMarker, "SoulBinds_Collection_Charge_Pending")
        rewardMarker:Hide()
        header.RewardMarker = rewardMarker
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
                OpenAchievementContextMenu(self, self.node.id, function()
                    ShowAchievementTree(frame.sourceAchievementID, "refresh")
                end, function()
                    Navigation.OpenRelatedTree(frame, self.node.id)
                end)
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
                Navigation.OpenRelatedTree(frame, self.achievementID)
            end
        end)
        treeButton:Hide()
        frame.AchievementCardTreeButton = treeButton

        local categoryPosition = frame:CreateFontString(nil, "OVERLAY",
            "GameFontHighlight")
        categoryPosition:Hide()
        frame.AchievementCardCategoryPosition = categoryPosition

        local categoryReturnButton = CreateFrame("Button", nil, frame,
            "UIPanelButtonTemplate")
        categoryReturnButton:SetSize(160, 22)
        categoryReturnButton:SetFrameLevel(card:GetFrameLevel() + 2)
        categoryReturnButton:SetScript("OnClick", function()
            if frame.officialContext then
                ReturnToOfficialAchievementCategory(frame)
            else
                ReturnToAchievementRewardCategory(frame)
            end
        end)
        categoryReturnButton:Hide()
        frame.AchievementCardCategoryReturnButton = categoryReturnButton

        local backButton = CreateFrame("Button", nil, frame)
        backButton:SetSize(48, 67)
        backButton:SetFrameLevel(card:GetFrameLevel() + 2)
        backButton:SetNormalAtlas(
            "CovenantSanctum-Renown-DoubleArrow", true)
        backButton:SetPushedAtlas(
            "CovenantSanctum-Renown-DoubleArrow-Depressed", true)
        backButton:SetScript("OnClick", function()
            if frame.rewardCategoryCardContext then
                NavigateAchievementRewardCategoryCard(frame, -1)
            elseif frame.officialContext then
                NavigateOfficialAchievementCard(frame, -1)
            elseif frame.treeCardContext then
                NavigateAchievementTreeCard(frame, -1)
            else
                NavigateAchievementHistory(frame, -1)
            end
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
            if frame.rewardCategoryCardContext then
                NavigateAchievementRewardCategoryCard(frame, 1)
            elseif frame.officialContext then
                NavigateOfficialAchievementCard(frame, 1)
            elseif frame.treeCardContext then
                NavigateAchievementTreeCard(frame, 1)
            else
                NavigateAchievementHistory(frame, 1)
            end
        end)
        forwardButton:Hide()
        frame.AchievementCardForwardButton = forwardButton

        for _, button in ipairs({ backButton, forwardButton }) do
            button:SetScript("OnEnter", function(self)
                local previous = self == backButton
                local label
                if frame.rewardCategoryCardContext then
                    label = previous and L.ACHIEVEMENT_CATEGORY_PREVIOUS
                        or L.ACHIEVEMENT_CATEGORY_NEXT
                elseif frame.officialContext then
                    label = previous and L.ACHIEVEMENT_CATEGORY_PREVIOUS
                        or L.ACHIEVEMENT_CATEGORY_NEXT
                elseif frame.treeCardContext then
                    label = previous and L.ACHIEVEMENT_TREE_PREVIOUS
                        or L.ACHIEVEMENT_TREE_NEXT
                else
                    label = previous and L.ACHIEVEMENT_HISTORY_BACK
                        or L.ACHIEVEMENT_HISTORY_FORWARD
                end
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(label)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        frame:EnableKeyboard(true)
        frame:SetPropagateKeyboardInput(true)
        frame:SetScript("OnKeyDown", function(self, key)
            local inputHasFocus = GetCurrentKeyBoardFocus
                and GetCurrentKeyBoardFocus() ~= nil
            if not GetCurrentKeyBoardFocus then
                inputHasFocus = self.SearchBox
                    and self.SearchBox:HasFocus()
            end
            local navigationButton
            if not inputHasFocus and card:IsShown() then
                if key == "LEFT" then
                    navigationButton = self.AchievementCardBackButton
                elseif key == "RIGHT" then
                    navigationButton = self.AchievementCardForwardButton
                end
            end
            local handled = navigationButton
                and navigationButton:IsShown()
                and navigationButton:IsEnabled()
            self:SetPropagateKeyboardInput(not handled)
            if handled then
                navigationButton:Click()
            end
        end)
    end

    if data.catalogOnly or IsAchievementValid
        and not IsAchievementValid(data.id)
    then
        card:Hide()
        card = GetCatalogFallbackCard(frame)
        card.Icon:SetTexture(data.icon)
        card.Title:SetText(data.name)
        card.Points:SetText(tostring(data.points or 0))
        card.Description:SetText(data.description or "")
        card:SetHeight(math.max(160,
            math.ceil(card.Description:GetStringHeight()) + 100))
    else
        if frame.CatalogFallbackCard then
            frame.CatalogFallbackCard:Hide()
        end
        card.EasyAchievementElementData = { id = data.id }
        card:Init(card.EasyAchievementElementData)
        local height = card:DisplayObjectives(data.id, card.completed)
        ConfigureAchievementCardChildLinks(card:GetObjectiveFrame())
        card:Expand(height)
        FormatAchievementCardDate(card, data)
    end
    if not progressOnly then
        UpdateAchievementRewardPanel(frame, data.id)
    end
    card:ClearAllPoints()
    card:SetPoint("CENTER", frame, "CENTER",
        GetAchievementCardRewardOffset(frame, data.id, data), -45)
    ApplyAchievementCardScale(GetAchievementCardScale())
    card:Show()
    local categoryContext = frame.rewardCategoryCardContext
    local treeContext = frame.treeCardContext
    local canGoBack
    local canGoForward
    if categoryContext then
        canGoBack = categoryContext.index > 1
        canGoForward = categoryContext.index
            < #categoryContext.achievementIDs
    elseif treeContext then
        canGoBack = treeContext.index > 1
        canGoForward = treeContext.index
            < #treeContext.achievementIDs
    elseif frame.officialContext then
        canGoBack = frame.officialContext.index > 1
        canGoForward = frame.officialContext.index
            < #frame.officialContext.achievementIDs
    else
        canGoBack = (frame.historyIndex or 1) > 1
        canGoForward = (frame.historyIndex or 0)
            < #(frame.history or {})
    end
    local cardBackButton = frame.AchievementCardBackButton
    cardBackButton:ClearAllPoints()
    cardBackButton:SetPoint("RIGHT", card, "LEFT", -2, 0)
    cardBackButton:SetShown(canGoBack)
    local cardForwardButton = frame.AchievementCardForwardButton
    cardForwardButton:ClearAllPoints()
    cardForwardButton:SetPoint("LEFT", card, "RIGHT", 2, 0)
    cardForwardButton:SetShown(canGoForward)
    if card == frame.AchievementCard then
        UpdateAchievementCardList(frame, categoryContext or treeContext,
            card)
    elseif frame.AchievementCardList then
        frame.AchievementCardList:Hide()
    end
    local header = frame.AchievementCardHeader
    header.node = data
    header.Icon:SetTexture(data.icon)
    header.Icon:SetDesaturated(not data.completed)
    header.Border:SetDesaturated(not data.completed)
    header.Border:SetAlpha(data.completed and 1 or 0.72)
    header.RewardMarker:SetShown(
        Addon.AchievementRewards.Has(data.id, data))
    header.Label:SetText(data.name)
    SetAchievementTextColor(header.Label, data.completed, false, 0.72)
    header:SetWidth(34 + math.ceil(header.Label:GetStringWidth()) + 6)
    header:ClearAllPoints()
    header:SetPoint("BOTTOM", card, "TOP", 0, 10)
    header:Show()
    local treeButton = frame.AchievementCardTreeButton
    treeButton.achievementID = data.id
    treeButton:SetShown(not categoryContext
        and #GetChildAchievementIDs(data.id) > 0)
    local categoryPosition = frame.AchievementCardCategoryPosition
    local categoryReturnButton = frame.AchievementCardCategoryReturnButton
    if categoryContext or frame.officialContext then
        local active = categoryContext or frame.officialContext
        categoryPosition:SetText(string.format(
            L.ACHIEVEMENT_REWARD_CATEGORY_POSITION,
            active.index, #active.achievementIDs))
        categoryPosition:ClearAllPoints()
        categoryPosition:SetPoint("TOP", card, "BOTTOM", 0, -8)
        categoryPosition:Show()
        categoryReturnButton:SetText(string.format(
            L.ACHIEVEMENT_REWARD_CATEGORY_RETURN,
            categoryContext and categoryContext.label
                or (Addon.AchievementCatalog
                    and Addon.AchievementCatalog.GetCategories()
                        [active.categoryID] or {}).name
                or GetCategoryInfo(active.categoryID)))
        categoryReturnButton:Show()
    else
        categoryPosition:Hide()
        local origin = frame.rewardCategoryOrigin
        categoryReturnButton:SetShown(origin ~= nil)
        if origin then
            categoryReturnButton:SetText(string.format(
                L.ACHIEVEMENT_REWARD_CATEGORY_RETURN, origin.label))
        end
    end
    local attButton = frame.ATTButton
    attButton.achievementID = data.id
    attButton:SetShown(CanOpenAchievementATTGuide())
    local actionButtons = {}
    for _, button in ipairs({ categoryReturnButton, treeButton,
        attButton }) do
        if button:IsShown() then
            actionButtons[#actionButtons + 1] = button
        end
    end
    local gap = 8
    local totalWidth = math.max(0, #actionButtons - 1) * gap
    for _, button in ipairs(actionButtons) do
        totalWidth = totalWidth + button:GetWidth()
    end
    local anchor = categoryPosition:IsShown() and categoryPosition or card
    local topOffset = categoryPosition:IsShown() and -6 or -8
    for index, button in ipairs(actionButtons) do
        button:ClearAllPoints()
        if index == 1 then
            button:SetPoint("TOPLEFT", anchor, "BOTTOM",
                -totalWidth / 2, topOffset)
        else
            button:SetPoint("LEFT", actionButtons[index - 1],
                "RIGHT", gap, 0)
        end
    end
    frame.Stats:SetText("")
    frame.Stats:Hide()
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

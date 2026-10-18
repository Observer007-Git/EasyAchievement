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

function UpdateBreadcrumb(frame)
    frame.Breadcrumb:Hide()
    frame.BreadcrumbButtons = frame.BreadcrumbButtons or {}
    local offset = 128
    for index, achievementID in ipairs(frame.breadcrumbIDs or {}) do
        local button = frame.BreadcrumbButtons[index]
        if not button then
            button = CreateFrame("Button", nil, frame)
            button:SetHeight(24)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetTexture(
                "Interface\\QuestFrame\\UI-QuestTitleHighlight")
            highlight:SetBlendMode("ADD")
            highlight:SetAlpha(0.75)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", 5, 1)
            icon:SetSize(17, 17)
            icon:SetTexCoord(0, 1, 0, 1)
            button.Icon = icon
            local border = button:CreateTexture(nil, "OVERLAY")
            border:SetPoint("CENTER", icon, "CENTER", -0.33, 0.67)
            border:SetSize(24, 24)
            border:SetTexture(
                "Interface\\AchievementFrame\\UI-Achievement-IconFrame")
            border:SetTexCoord(0, 0.5625, 0, 0.5625)
            button.Border = border
            local text = button:CreateFontString(nil, "OVERLAY",
                "GameFontHighlightSmall")
            text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            button.Text = text
            frame.BreadcrumbButtons[index] = button
        end
        local data = GetAchievementData(achievementID)
        local text = data and data.name or tostring(achievementID)
        if index < #(frame.breadcrumbIDs or {}) then
            text = text .. "  >"
        end
        button.Text:SetText(text)
        button.Icon:SetTexture(data and data.icon or nil)
        button.Icon:SetDesaturated(data and not data.completed or false)
        button.Border:SetDesaturated(data and not data.completed or false)
        button.Border:SetAlpha(data and data.completed and 1 or 0.72)
        local width = 32 + math.ceil(button.Text:GetStringWidth()) + 8
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("LEFT", frame, "TOPLEFT", offset, -127)
        button.achievementID = achievementID
        button.pathIndex = index
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                OpenAchievementContextMenu(self, self.achievementID)
                return
            elseif IsShiftKeyDown() then
                InsertAchievementLink(self.achievementID)
                return
            end
            local path = {}
            for pathIndex = 1, self.pathIndex do
                path[pathIndex] = frame.breadcrumbIDs[pathIndex]
            end
            ShowAchievementTree(self.achievementID, nil, path, true)
        end)
        button:Show()
        offset = offset + width
    end
    for index = #(frame.breadcrumbIDs or {}) + 1,
        #frame.BreadcrumbButtons
    do
        frame.BreadcrumbButtons[index]:Hide()
    end
end

UpdateTreeSearch = function(frame)
    local query = (frame.searchText or ""):lower()
    for _, node in ipairs(frame.layoutNodes or {}) do
        local button = node.button
        if button and button.node == node and button:IsShown() then
            local searchMatches = query ~= "" and (
                node.name:lower():find(query, 1, true)
                or tostring(node.id):find(query, 1, true))
            if searchMatches then
                button.SearchHighlight:Show()
                if button.SearchHighlightQuery ~= query
                    or button.SearchHighlightAchievementID ~= node.id
                then
                    button.SearchHighlightPulse:Stop()
                    button.SearchHighlight:SetAlpha(0.9)
                    button.SearchHighlightPulse:Play()
                    button.SearchHighlightQuery = query
                    button.SearchHighlightAchievementID = node.id
                end
                SetAchievementTextColor(button.Label, node.completed, true)
            else
                button.SearchHighlightPulse:Stop()
                button.SearchHighlight:SetAlpha(0.9)
                button.SearchHighlight:Hide()
                button.SearchHighlightQuery = nil
                button.SearchHighlightAchievementID = nil
                SetAchievementTextColor(button.Label, node.completed, false)
            end
        end
    end
end

function RevealAchievementNode(frame, achievementID)
    for _, node in ipairs(frame.layoutNodes or {}) do
        local button = node.id == achievementID and node.button
        if button and button.node == node and button:IsShown() then
            local horizontalMaximum = math.max(0,
                frame.Content:GetWidth() - frame.ScrollFrame:GetWidth())
            local verticalMaximum = math.max(0,
                frame.Content:GetHeight() - frame.ScrollFrame:GetHeight())
            frame.HorizontalScroll:SetValue(math.max(0,
                math.min(horizontalMaximum,
                    (node.navigatorX or 0)
                        - frame.ScrollFrame:GetWidth() / 2)))
            frame.ScrollFrame:SetVerticalScroll(math.max(0,
                math.min(verticalMaximum,
                    (node.navigatorY or 0)
                        - frame.ScrollFrame:GetHeight() / 2)))
            UpdateAchievementNavigatorViewport(frame)
            button.RevealHighlightPulse:Stop()
            button.RevealGlow:SetAlpha(0.25)
            button.RevealHighlightPulse:Play()
            button.RevealStarBurstPulse:Stop()
            button.RevealStarBurstPulse:Play()
            return
        end
    end
end

ShowAchievementTree = function(achievementID, navigationMode, breadcrumbIDs,
    showCardOnly)
    local frameWasShown = achievementTreeFrame
        and achievementTreeFrame:IsShown() or false
    local nodes, edges, root = BuildAchievementTree(achievementID)
    if nodes then
        local frame = CreateAchievementTreeFrame()
        local rootChanged = frame.sourceAchievementID ~= achievementID
        if frame.sourceAchievementID and rootChanged then
            SaveAchievementTreeState(frame)
        end
        frame.sourceAchievementID = achievementID
        if navigationMode ~= "refresh" then
            frame.cardOnlyAchievementID = showCardOnly
                and achievementID or nil
        end
        if rootChanged then
            RestoreAchievementTreeState(frame, achievementID)
        end
        Addon:SetSetting("achievementLastTreeID", achievementID)
        RefreshAchievementFavoritesBar(frame)
        frame.history = frame.history or {}
        frame.collapsedNodes = frame.collapsedNodes or {}
        if navigationMode ~= "refresh" and navigationMode ~= "history" then
            local currentID, currentShowCardOnly =
                GetAchievementHistoryEntry(
                    frame.history[frame.historyIndex or 0])
            if currentID ~= achievementID
                or currentShowCardOnly ~= (showCardOnly == true)
            then
                for index = #frame.history, (frame.historyIndex or 0) + 1, -1 do
                    table.remove(frame.history, index)
                end
                frame.historyIndex = AchievementData.AppendHistory(
                    frame.history, {
                        achievementID = achievementID,
                        showCardOnly = showCardOnly == true,
                    })
            end
            frame.breadcrumbIDs = breadcrumbIDs or { achievementID }
            RecordRecentAchievement(achievementID)
        elseif navigationMode == "history" then
            frame.breadcrumbIDs = { achievementID }
            RecordRecentAchievement(achievementID)
        end
        frame.breadcrumbIDs = frame.breadcrumbIDs or { achievementID }
        frame.fullNodes = nodes
        frame.fullEdges = edges
        for _, node in ipairs(nodes) do
            node.hasChildren = false
        end
        for _, edge in ipairs(edges) do
            edge.parent.hasChildren = true
        end
        local fullChildren = {}
        for _, node in ipairs(nodes) do
            fullChildren[node.id] = {}
        end
        for _, edge in ipairs(edges) do
            fullChildren[edge.parent.id][#fullChildren[edge.parent.id] + 1] =
                edge.child
        end
        local function CountDescendants(node)
            local seen = {}
            local count = 0
            local function Visit(parent)
                for _, child in ipairs(fullChildren[parent.id] or {}) do
                    if not seen[child.id] then
                        seen[child.id] = true
                        count = count + 1
                        Visit(child)
                    end
                end
            end
            Visit(node)
            node.descendantCount = count
        end
        for _, node in ipairs(nodes) do
            node.descendantCount = nil
            if frame.collapsedNodes[node.id] then
                CountDescendants(node)
            end
        end
        local revealAchievementID = frame.pendingRevealAchievementID
        if revealAchievementID then
            frame.incompleteOnly = false
            frame.IncompleteOnly:SetChecked(false)
            local parentsByID = {}
            for _, edge in ipairs(edges) do
                local parents = parentsByID[edge.child.id]
                if not parents then
                    parents = {}
                    parentsByID[edge.child.id] = parents
                end
                parents[#parents + 1] = edge.parent.id
            end
            local visited = {}
            local function ExpandAncestors(nodeID)
                if visited[nodeID] then
                    return
                end
                visited[nodeID] = true
                for _, parentID in ipairs(parentsByID[nodeID] or {}) do
                    frame.collapsedNodes[parentID] = nil
                    ExpandAncestors(parentID)
                end
            end
            ExpandAncestors(revealAchievementID)
        end
        local stats = GetAchievementTreeStats(nodes)
        if stats.incomplete == 0 and frame.incompleteOnly then
            frame.incompleteOnly = false
            frame.IncompleteOnly:SetChecked(false)
        end
        local layoutNodes, layoutEdges, layoutRoot = nodes, edges, root
        if frame.incompleteOnly then
            layoutNodes, layoutEdges, layoutRoot =
                FilterIncompleteTree(nodes, edges)
        end
        layoutNodes, layoutEdges = FilterCollapsedTree(layoutNodes,
            layoutEdges, frame.collapsedNodes)
        LayoutAchievementTree(layoutNodes, layoutEdges, layoutRoot,
            navigationMode == "refresh", stats, root,
            frame.cardOnlyAchievementID)
        UpdateBreadcrumb(frame)
        if revealAchievementID then
            frame.pendingRevealAchievementID = nil
            RevealAchievementNode(frame, revealAchievementID)
            SaveAchievementTreeState(frame)
        end
        if frameWasShown and navigationMode ~= "refresh" then
            PlayAchievementSound(SOUNDKIT
                and SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end
    end
end

function IsAchievementTracked(achievementID)
    return C_ContentTracking and C_ContentTracking.IsTracking
        and C_ContentTracking.IsTracking(
            Enum.ContentTrackingType.Achievement, achievementID)
end

function ToggleAchievementTracking(achievementID)
    if not C_ContentTracking then
        return
    end
    if IsAchievementTracked(achievementID) then
        C_ContentTracking.StopTracking(
            Enum.ContentTrackingType.Achievement, achievementID,
            Enum.ContentTrackingStopType.Manual)
    else
        local trackingError = C_ContentTracking.StartTracking(
            Enum.ContentTrackingType.Achievement, achievementID)
        if trackingError and ContentTrackingUtil then
            ContentTrackingUtil.DisplayTrackingError(trackingError)
        end
    end
end

InsertAchievementLink = function(achievementID)
    local link = GetAchievementLink and GetAchievementLink(achievementID)
    if not link then
        return
    end
    if ChatFrameUtil and ChatFrameUtil.InsertLink
        and ChatFrameUtil.InsertLink(link)
    then
        return
    end
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then
        return
    end
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(link)
        return
    end
    print(link)
end

OpenAchievementContextMenu = function(button, achievementID)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return
    end

    local data = GetAchievementData(achievementID)
    if not data then
        return
    end

    MenuUtil.CreateContextMenu(button, function(_, rootDescription)
        rootDescription:CreateTitle(data.name)
        local favoriteLabel = IsAchievementFavorite(achievementID)
            and L.ACHIEVEMENT_FAVORITE_REMOVE
            or L.ACHIEVEMENT_FAVORITE_ADD
        rootDescription:CreateButton(favoriteLabel, function()
            ToggleAchievementFavorite(achievementID)
        end)
        local trackingLabel = IsAchievementTracked(achievementID)
            and L.ACHIEVEMENT_UNTRACK or L.ACHIEVEMENT_TRACK
        rootDescription:CreateButton(trackingLabel, function()
            ToggleAchievementTracking(achievementID)
        end)
        rootDescription:CreateButton(L.ACHIEVEMENT_CARD_VIEW, function()
            ShowAchievementTree(achievementID, nil, nil, true)
        end)
        if #GetChildAchievementIDs(achievementID) > 0 then
            rootDescription:CreateButton(L.ACHIEVEMENT_TREE_VIEW,
                function()
                    ShowAchievementTree(achievementID)
                end)
        end
        rootDescription:CreateButton(L.ACHIEVEMENT_POPUP_SHOW, function()
            ShowAchievementPopup(achievementID)
        end)
    end)
end

function CreateAchievementLauncherSearch(anchor)
    local panel = CreateFrame("Frame", nil, UIParent)
    local collapsedHeight = math.max(1, anchor:GetHeight() or 42)
    local searchHeight = collapsedHeight
    local searchTopInset = 0
    local resultsGap = 3
    local resultsBottomPadding = 4
    panel:SetSize(336, collapsedHeight)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()

    local search = CreateFrame("EditBox", nil, panel,
        "SearchBoxNineSliceTemplate")
    search:SetPoint("TOPLEFT", 4, -searchTopInset)
    search:SetPoint("TOPRIGHT", -4, -searchTopInset)
    search:SetHeight(searchHeight)
    search:SetAutoFocus(false)
    search:SetMaxLetters(20)
    if search.SetInstructions then
        search:SetInstructions(L.ACHIEVEMENT_TREE_SEARCH)
    end

    local rows = {}
    local resultIDs = {}
    local function HidePanel()
        search:ClearFocus()
        panel:Hide()
    end
    local function OpenResult(row, mouseButton)
        if not row.achievementID then
            return
        end
        if mouseButton == "RightButton" then
            OpenAchievementContextMenu(row, row.achievementID)
        elseif IsShiftKeyDown() then
            InsertAchievementLink(row.achievementID)
        else
            HidePanel()
            ShowAchievementTree(row.achievementID, nil, nil, true)
        end
    end
    for index = 1, 6 do
        local row = CreateFrame("Button", nil, panel)
        row:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0,
            -resultsGap - (index - 1) * 28)
        row:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0,
            -resultsGap - (index - 1) * 28)
        row:SetHeight(28)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        if not SetTextureAtlas(highlight, "search-highlight") then
            highlight:SetColorTexture(0.85, 0.65, 0.2, 0.25)
        end
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", 4, 0)
        icon:SetSize(20, 20)
        icon:SetTexCoord(0, 1, 0, 1)
        row.Icon = icon
        local name = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetPoint("RIGHT", -8, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row.Name = name
        row:SetScript("OnClick", OpenResult)
        row:SetScript("OnEnter", function(self)
            if self.node then
                SetAchievementTextColor(self.Name,
                    self.node.completed, true, 0.82)
                ShowAchievementTooltip(self)
            end
        end)
        row:SetScript("OnLeave", function(self)
            if self.node then
                SetAchievementTextColor(self.Name,
                    self.node.completed, false, 0.82)
            end
            GameTooltip:Hide()
        end)
        row:Hide()
        rows[index] = row
    end

    local message = panel:CreateFontString(nil, "OVERLAY",
        "GameFontDisableSmall")
    message:SetPoint("TOP", search, "BOTTOM", 0, -9)
    message:Hide()

    local function RenderResults()
        local shown = 0
        for _, achievementID in ipairs(resultIDs) do
            local data = GetAchievementData(achievementID)
            if data and shown < #rows then
                shown = shown + 1
                local row = rows[shown]
                row.achievementID = data.id
                row.node = data
                row.Icon:SetTexture(data.icon)
                row.Icon:SetDesaturated(not data.completed)
                row.Name:SetText(data.name)
                SetAchievementTextColor(row.Name,
                    data.completed, false, 0.82)
                row:Show()
            end
        end
        for index = shown + 1, #rows do
            rows[index]:Hide()
            rows[index].achievementID = nil
            rows[index].node = nil
        end
        message:SetShown(shown == 0)
        message:SetText(L.ACHIEVEMENT_SEARCH_NO_RESULTS)
        panel:SetHeight(shown > 0 and searchTopInset + searchHeight
            + resultsGap + shown * 28 + resultsBottomPadding
            or collapsedHeight + 24)
    end

    local function RefreshResults()
        resultIDs = {}
        local seen = {}
        local query = search:GetText() or ""
        local exactID = tonumber(query)
        local function AddResult(achievementID)
            if #resultIDs >= #rows or seen[achievementID]
                or not IsAchievementValid(achievementID)
            then
                return
            end
            local isStatistic = select(15,
                GetAchievementInfo(achievementID))
            if not isStatistic then
                seen[achievementID] = true
                resultIDs[#resultIDs + 1] = achievementID
            end
        end
        if exactID then
            AddResult(math.floor(exactID))
        end
        for index = 1, GetNumFilteredAchievements() or 0 do
            AddResult(GetFilteredAchievementID(index))
        end
        RenderResults()
    end

    search:HookScript("OnTextChanged", function(self)
        local query = self:GetText() or ""
        if #query < (MIN_CHARACTER_SEARCH or 3) then
            resultIDs = {}
            for _, row in ipairs(rows) do
                row:Hide()
            end
            message:Hide()
            panel:SetHeight(collapsedHeight)
            return
        end
        achievementSearchOwner = panel
        local finished = SetAchievementSearchString(query)
        if finished then
            RefreshResults()
        else
            message:SetText(L.ACHIEVEMENT_SEARCHING)
            message:Show()
            panel:SetHeight(collapsedHeight + 24)
        end
    end)
    search:SetScript("OnEscapePressed", HidePanel)
    search:SetScript("OnEnterPressed", function()
        if rows[1]:IsShown() then
            OpenResult(rows[1], "LeftButton")
        end
    end)
    panel:RegisterEvent("ACHIEVEMENT_SEARCH_UPDATED")
    panel:SetScript("OnEvent", function()
        if panel:IsShown() and achievementSearchOwner == panel
            and #(search:GetText() or "") >= (MIN_CHARACTER_SEARCH or 3)
        then
            RefreshResults()
        end
    end)

    local function ScheduleHide()
        C_Timer.After(0.12, function()
            if panel:IsShown() and not panel:IsMouseOver()
                and not anchor:IsMouseOver()
            then
                panel:Hide()
            end
        end)
    end
    panel:SetScript("OnLeave", ScheduleHide)
    search:HookScript("OnEditFocusLost", ScheduleHide)

    function panel:ShowAnimated()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 3, 0)
        self.animationStartedAt = GetTime()
        self:SetAlpha(0)
        self:Show()
        self:SetScript("OnUpdate", function(searchPanel)
            local progress = math.min(1,
                (GetTime() - searchPanel.animationStartedAt) / 0.15)
            searchPanel:SetAlpha(progress)
            searchPanel:ClearAllPoints()
            searchPanel:SetPoint("TOPLEFT", anchor, "TOPRIGHT",
                3 - (1 - progress) * 8, 0)
            if progress >= 1 then
                searchPanel:SetScript("OnUpdate", nil)
                search:SetFocus()
            end
        end)
    end
    panel.ScheduleHide = ScheduleHide
    panel.HideSearch = HidePanel
    panel.SearchBox = search
    return panel
end

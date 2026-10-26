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
    local entries, widths = {}, {}
    if frame.breadcrumbCategory then
        entries[1] = {
            label = GetAchievementRewardCategoryLabel(frame.breadcrumbCategory),
            category = frame.breadcrumbCategory,
        }
    end
    for pathIndex, achievementID in ipairs(frame.breadcrumbIDs or {}) do
        local data = GetAchievementData(achievementID)
        entries[#entries + 1] = {
            id = achievementID, pathIndex = pathIndex, data = data,
            label = data and data.name or tostring(achievementID),
        }
    end
    local function Activate(entry, mouseButton)
        if entry.category then
            if frame.rewardCategoryCardContext or frame.rewardCategoryOrigin then
                ReturnToAchievementRewardCategory(frame)
            else
                ShowAchievementRewardCategory(entry.category)
            end
        elseif mouseButton == "RightButton" then
            OpenAchievementContextMenu(frame, entry.id, function()
                OpenAchievementPathCard(frame, entry.id)
            end, function()
                Navigation.OpenRelatedTree(frame, entry.id)
            end)
        elseif IsShiftKeyDown() then
            InsertAchievementLink(entry.id)
        elseif entry.pathIndex < #(frame.breadcrumbIDs or {}) then
            OpenAchievementPathCard(frame, entry.id)
        end
    end
    local ruler = frame.Breadcrumb
    for index, entry in ipairs(entries) do
        ruler:SetText(entry.label or "")
        widths[index] = math.ceil(ruler:GetStringWidth()) + 48
    end
    local layout = AchievementData.GetBreadcrumbLayout(widths,
        math.max(60, ruler:GetWidth()))
    local offset = frame.breadcrumbLeftOffset or 82
    for index, item in ipairs(layout) do
        local entry = entries[item.index]
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
            text:SetPoint("RIGHT", -4, 0)
            text:SetWordWrap(false)
            button.Text = text
            frame.BreadcrumbButtons[index] = button
        end
        local data = entry and entry.data
        local text = entry and entry.label or "…"
        if index < #layout and item.index ~= 0 then
            text = text .. "  >"
        end
        button.Text:SetText(text)
        local categoryIcon, categoryAtlas
        if entry and entry.category then
            categoryIcon, categoryAtlas = GetAchievementRewardCategoryIcon(
                entry.category)
        end
        if not (categoryAtlas and SetTextureAtlas(button.Icon, categoryAtlas))
        then
            button.Icon:SetTexture(data and data.icon or categoryIcon
                or entry and 134400 or nil)
            button.Icon:SetTexCoord(0, 1, 0, 1)
        end
        button.Icon:SetShown(item.index ~= 0)
        button.Border:SetShown(item.index ~= 0)
        button.Icon:SetDesaturated(data and not data.completed or false)
        button.Border:SetDesaturated(data and not data.completed or false)
        button.Border:SetAlpha(data and data.completed and 1 or 0.72)
        button.Text:ClearAllPoints()
        button.Text:SetPoint("LEFT", item.index == 0 and 2 or 28, 0)
        button.Text:SetPoint("RIGHT", -4, 0)
        local width = item.width
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("LEFT", frame, "TOPLEFT", offset, -113)
        button:SetScript("OnClick", function(self, mouseButton)
            if entry then
                Activate(entry, mouseButton)
            elseif MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(self, function(_, menu)
                    for hiddenIndex = 2, #entries - 1 do
                        local hiddenEntry = entries[hiddenIndex]
                        menu:CreateButton(hiddenEntry.label, function()
                            Activate(hiddenEntry, "LeftButton")
                        end)
                    end
                end)
            end
        end)
        button:SetScript("OnEnter", function(self)
            if entry then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(entry.label)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:Show()
        offset = offset + width
    end
    for index = #layout + 1,
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

local function RenderAchievementPage(frame, nodes, edges, root, preserveScroll,
    revealAchievementID)
    frame.fullNodes = nodes
    frame.fullEdges = edges
    for _, node in ipairs(nodes) do
        node.hasChildren = false
    end
    local children, parents = {}, {}
    for _, node in ipairs(nodes) do children[node.id] = {} end
    for _, edge in ipairs(edges) do
        edge.parent.hasChildren = true
        table.insert(children[edge.parent.id], edge.child)
        parents[edge.child.id] = parents[edge.child.id] or {}
        table.insert(parents[edge.child.id], edge.parent.id)
    end
    for _, node in ipairs(nodes) do
        node.descendantCount = nil
        if frame.collapsedNodes[node.id] then
            local seen, count = {}, 0
            local function Visit(parent)
                for _, child in ipairs(children[parent.id] or {}) do
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
    end
    if revealAchievementID then
        frame.incompleteOnly = false
        frame.IncompleteOnly:SetChecked(false)
        local visited = {}
        local function ExpandAncestors(id)
            if visited[id] then return end
            visited[id] = true
            for _, parentID in ipairs(parents[id] or {}) do
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
        layoutNodes, layoutEdges, layoutRoot = FilterIncompleteTree(nodes, edges)
    end
    layoutNodes, layoutEdges = FilterCollapsedTree(layoutNodes, layoutEdges,
        frame.collapsedNodes)
    LayoutAchievementTree(layoutNodes, layoutEdges, layoutRoot,
        preserveScroll, stats, root, frame.cardOnlyAchievementID)
    UpdateBreadcrumb(frame)
    if revealAchievementID then
        RevealAchievementNode(frame, revealAchievementID)
        SaveAchievementTreeState(frame)
    end
    SaveCurrentAchievementNavigation(frame)
end

function RefreshAchievementTreePage(frame)
    if not frame or not frame.sourceAchievementID then return false end
    local id = frame.sourceAchievementID
    local nodes, edges, root
    if frame.cardOnlyAchievementID then
        root = AchievementData.CreateNode(GetAchievementData(id))
        if root then nodes, edges = { root }, {} end
    else
        nodes, edges, root = BuildAchievementTree(id)
    end
    if not nodes then return false end
    frame.navigationRevision = (frame.navigationRevision or 0) + 1
    RenderAchievementPage(frame, nodes, edges, root, true)
    return true
end

ShowAchievementTree = function(achievementID, navigationMode, breadcrumbIDs,
    showCardOnly, rewardCategoryCardContext, navigationEntry)
    if navigationMode == "refresh" then
        return RefreshAchievementTreePage(achievementTreeFrame)
    end
    local frameWasShown = achievementTreeFrame
        and achievementTreeFrame:IsShown() or false
    local cardOnlyAchievementID = showCardOnly and achievementID or nil
    local nodes, edges, root
    if cardOnlyAchievementID == achievementID then
        root = AchievementData.CreateNode(GetAchievementData(achievementID))
        if root then
            nodes, edges = { root }, {}
        end
    else
        nodes, edges, root = BuildAchievementTree(achievementID)
    end
    if nodes then
        local frame = CreateAchievementTreeFrame()
        local previousCategoryContext = frame.rewardCategoryCardContext
        local previousCardOnly = frame.cardOnlyAchievementID
        if navigationMode ~= "history" then
            SaveCurrentAchievementNavigation(frame)
        end
        if frame.rewardCategoryMode then
            SaveAchievementRewardCategoryState(frame)
        end
        local rootChanged = frame.sourceAchievementID ~= achievementID
        if frame.sourceAchievementID and (rootChanged
            or not previousCardOnly and cardOnlyAchievementID)
        then
            SaveAchievementTreeState(frame)
        end
        Navigation.ApplyPage(frame, {
            kind = showCardOnly and "card" or "tree",
            achievementID = achievementID,
            categoryContext = rewardCategoryCardContext,
            treeCardContext = navigationEntry
                and navigationEntry.treeCardContext,
            officialContext = navigationEntry
                and navigationEntry.officialContext,
            officialBrowser = navigationEntry
                and navigationEntry.officialBrowser,
            categoryOrigin = navigationEntry and navigationEntry.categoryOrigin,
            breadcrumbIDs = breadcrumbIDs or { achievementID },
            breadcrumbCategory = navigationEntry
                and navigationEntry.breadcrumbCategory
                or rewardCategoryCardContext and rewardCategoryCardContext.key,
        })
        if rootChanged or previousCardOnly and not cardOnlyAchievementID then
            RestoreAchievementTreeState(frame, achievementID)
        end
        if navigationEntry and navigationEntry.viewState then
            RestoreAchievementNavigationState(frame, navigationEntry.viewState)
        end
        Addon:SetSetting("achievementLastTreeID", achievementID)
        RefreshAchievementFavoritesBar(frame)
        frame.history = frame.history or {}
        frame.collapsedNodes = frame.collapsedNodes or {}
        RecordRecentAchievement(achievementID)
        if navigationMode ~= "history" then
            local replace = navigationMode == "category"
                and previousCategoryContext and rewardCategoryCardContext
                and previousCategoryContext.visitID == rewardCategoryCardContext.visitID
                or navigationMode == "tree-card"
                    and frame.history and frame.history[frame.historyIndex]
                    and frame.history[frame.historyIndex].treeCardContext
                    and navigationEntry and navigationEntry.treeCardContext
                    and frame.history[frame.historyIndex].treeCardContext.visitID
                        == navigationEntry.treeCardContext.visitID
                or navigationMode == "official-card"
                    and frame.history and frame.history[frame.historyIndex]
                    and frame.history[frame.historyIndex].officialContext
                    and navigationEntry and navigationEntry.officialContext
                    and frame.history[frame.historyIndex].officialContext.categoryID
                        == navigationEntry.officialContext.categoryID
            RecordAchievementNavigation(frame, replace)
        end
        RenderAchievementPage(frame, nodes, edges, root, false,
            navigationEntry and navigationEntry.revealAchievementID)
        if frameWasShown then
            PlayAchievementSound(SOUNDKIT
                and SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end
        return true
    end
    return false
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

OpenAchievementContextMenu = function(button, achievementID, openCard, openTree)
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
            if openCard then
                openCard()
            else
                Navigation.OpenCard(achievementID)
            end
        end)
        if #GetChildAchievementIDs(achievementID) > 0 then
            rootDescription:CreateButton(L.ACHIEVEMENT_TREE_VIEW,
                function()
                    if openTree then
                        openTree()
                    else
                        ShowAchievementTree(achievementID)
                    end
                end)
        end
        local hasPopup = false
        for _, popup in ipairs(achievementPopupFrames) do
            if popup.achievementID == achievementID then
                hasPopup = true
                break
            end
        end
        if not hasPopup then
            rootDescription:CreateButton(L.ACHIEVEMENT_POPUP_SHOW, function()
                ShowAchievementPopup(achievementID)
            end)
        end
        if CanOpenAchievementATTGuide() then
            rootDescription:CreateButton(L.ACHIEVEMENT_ATT_OPEN, function()
                OpenAchievementATTGuide(achievementID)
            end)
        end
    end)
end

function CreateAchievementLauncherSearch(anchor, icon)
    local panel = CreateFrame("Frame", nil, UIParent)
    local anchorHeight = math.max(1, anchor:GetHeight() or 42)
    local inputOffsetX = (anchor:GetWidth() + icon:GetWidth()) / 2 + 1
    local collapsedHeight = 32
    local searchHeight = collapsedHeight
    local anchorOffsetY = (collapsedHeight - anchorHeight) / 2
    local searchTopInset = 0
    local resultsGap = 3
    local resultsBottomPadding = 4
    panel:SetSize(1, collapsedHeight)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:Hide()

    local search = CreateFrame("EditBox", nil, panel,
        "SearchBoxNineSliceTemplate")
    search:SetPoint("TOPLEFT", 0, -searchTopInset)
    search:SetPoint("TOPRIGHT", -4, -searchTopInset)
    search:SetHeight(searchHeight)
    search:SetAutoFocus(false)
    search:SetMaxLetters(MAX_ACHIEVEMENT_SEARCH_CHARACTERS)
    panel:SetWidth(GetAchievementSearchBoxWidth(search) + 8)
    if search.SetInstructions then
        search:SetInstructions(L.ACHIEVEMENT_TREE_SEARCH)
    end
    if search.searchIcon then search.searchIcon:Hide() end
    if search.SetTextInsets then search:SetTextInsets(0, 22, 0, 0) end
    if search.Instructions then
        search.Instructions:ClearAllPoints()
        search.Instructions:SetPoint("TOPLEFT", search, "TOPLEFT", 0, 0)
        search.Instructions:SetPoint("BOTTOMRIGHT", search,
            "BOTTOMRIGHT", -22, 0)
    end
    local searchBackground = search.Background
    searchBackground:SetParent(anchor)
    searchBackground:ClearAllPoints()
    searchBackground:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    searchBackground:SetSize(inputOffsetX + panel:GetWidth(), anchorHeight)
    searchBackground:Hide()
    panel:HookScript("OnHide", function()
        searchBackground:Hide()
    end)

    local resultsBackground = panel:CreateTexture(nil, "BACKGROUND")
    resultsBackground:SetPoint("TOPLEFT", search, "BOTTOMLEFT",
        -inputOffsetX, -resultsGap)
    resultsBackground:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
    resultsBackground:SetColorTexture(0.025, 0.025, 0.025, 0.96)
    local roundedBottom = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
    roundedBottom:SetPoint("BOTTOMLEFT", resultsBackground,
        "BOTTOMLEFT", 0, -4)
    roundedBottom:SetSize(inputOffsetX + panel:GetWidth(), anchorHeight)
    if not SetTextureAtlas(roundedBottom, searchBackground:GetAtlas()) then
        roundedBottom:SetTexture(searchBackground:GetTexture())
        roundedBottom:SetTexCoord(searchBackground:GetTexCoord())
    end
    roundedBottom:Hide()
    local resultsEdges = {}
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local edge = panel:CreateTexture(nil, "BORDER")
        edge:SetPoint("TOP" .. side, resultsBackground, "TOP" .. side)
        edge:SetPoint("BOTTOM" .. side, resultsBackground,
            "BOTTOM" .. side)
        edge:SetWidth(1)
        edge:SetColorTexture(0.38, 0.35, 0.29, 0.9)
        edge:Hide()
        resultsEdges[#resultsEdges + 1] = edge
    end
    resultsBackground:Hide()
    local function ShowResults(shown)
        resultsBackground:SetShown(shown)
        roundedBottom:SetShown(shown)
        for _, edge in ipairs(resultsEdges) do
            edge:SetShown(shown)
        end
    end
    local function SetPanelHeight(height)
        panel:SetHeight(height)
    end

    local rows = {}
    local resultEntries = {}
    local resultOffset = 0
    local mapBuilding = false
    local function HidePanel()
        ReleaseAchievementSearch(panel)
        search:ClearFocus()
        panel:Hide()
    end
    local function OpenResult(row, mouseButton)
        if not row.entry then return end
        if row.entry.kind ~= "achievement" then
            local entry = row.entry
            HidePanel()
            Addon.MapSearch.Activate(entry)
        elseif mouseButton == "RightButton" then
            OpenAchievementContextMenu(row, row.achievementID)
        elseif IsShiftKeyDown() then
            InsertAchievementLink(row.achievementID)
        else
            HidePanel()
            Navigation.OpenCard(row.achievementID)
        end
    end
    for index = 1, MAX_ACHIEVEMENT_SEARCH_RESULTS do
        local row = CreateFrame("Button", nil, panel)
        row:SetPoint("TOPLEFT", resultsBackground, "TOPLEFT", 0,
            -(index - 1) * 28)
        row:SetPoint("TOPRIGHT", resultsBackground, "TOPRIGHT", 0,
            -(index - 1) * 28)
        row:SetHeight(28)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            panel:GetScript("OnMouseWheel")(panel, delta)
        end)
        local separatorBase = row:CreateTexture(nil, "OVERLAY")
        separatorBase:SetPoint("TOPLEFT", row, "TOPLEFT")
        separatorBase:SetPoint("TOPRIGHT", row, "TOPRIGHT")
        separatorBase:SetHeight(1)
        separatorBase:SetColorTexture(0.38, 0.28, 0.12, 0.65)
        local separator = row:CreateTexture(nil, "OVERLAY")
        separator:SetPoint("LEFT", row, "TOPLEFT")
        separator:SetPoint("RIGHT", row, "TOPRIGHT")
        separator:SetHeight(8)
        if not SetTextureAtlas(separator, "AftLevelup-GlowLine") then
            separator:SetColorTexture(0.38, 0.28, 0.12, 0.85)
        end
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.75)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", (anchor:GetWidth() - 20) / 2, 0)
        icon:SetSize(20, 20)
        icon:SetTexCoord(0, 1, 0, 1)
        row.Icon = icon
        local achievementIconBorder = row:CreateTexture(nil, "OVERLAY")
        achievementIconBorder:SetPoint("CENTER", icon, "CENTER",
            -0.33, 0.67)
        achievementIconBorder:SetSize(27, 27)
        achievementIconBorder:SetTexture(
            "Interface\\AchievementFrame\\UI-Achievement-IconFrame")
        achievementIconBorder:SetTexCoord(0, 0.5625, 0, 0.5625)
        achievementIconBorder:Hide()
        row.AchievementIconBorder = achievementIconBorder
        local mapIconBorder = row:CreateTexture(nil, "OVERLAY")
        mapIconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
        mapIconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
        mapIconBorder:SetTexture("Interface\\SPELLBOOK\\RotationIconFrame")
        mapIconBorder:Hide()
        row.MapIconBorder = mapIconBorder
        local name = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        name:SetPoint("LEFT", row, "LEFT", inputOffsetX, 0)
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

    local messageRow = CreateFrame("Frame", nil, panel)
    messageRow:SetPoint("TOPLEFT", resultsBackground, "TOPLEFT")
    messageRow:SetPoint("TOPRIGHT", resultsBackground, "TOPRIGHT")
    messageRow:SetHeight(28)
    messageRow:EnableMouse(false)
    local messageSeparatorBase = messageRow:CreateTexture(nil, "OVERLAY")
    messageSeparatorBase:SetPoint("TOPLEFT", messageRow, "TOPLEFT")
    messageSeparatorBase:SetPoint("TOPRIGHT", messageRow, "TOPRIGHT")
    messageSeparatorBase:SetHeight(1)
    messageSeparatorBase:SetColorTexture(0.38, 0.28, 0.12, 0.65)
    local messageSeparator = messageRow:CreateTexture(nil, "OVERLAY")
    messageSeparator:SetPoint("LEFT", messageRow, "TOPLEFT")
    messageSeparator:SetPoint("RIGHT", messageRow, "TOPRIGHT")
    messageSeparator:SetHeight(8)
    if not SetTextureAtlas(messageSeparator, "AftLevelup-GlowLine") then
        messageSeparator:SetColorTexture(0.38, 0.28, 0.12, 0.85)
    end
    local message = messageRow:CreateFontString(nil, "OVERLAY",
        "GameFontDisableSmall")
    message:SetPoint("LEFT", messageRow, "LEFT", inputOffsetX, 0)
    message:SetPoint("RIGHT", messageRow, "RIGHT", -8, 0)
    message:SetJustifyH("LEFT")
    message:SetWordWrap(false)
    messageRow:Hide()
    local resultFooter = panel:CreateFontString(nil, "OVERLAY",
        "GameFontDisableSmall")
    resultFooter:SetPoint("BOTTOM", resultsBackground, "BOTTOM", 0, 4)
    local footerFont, footerSize, footerFlags = resultFooter:GetFont()
    resultFooter:Hide()

    local function RenderResults()
        local total = #resultEntries
        local maximumOffset = math.max(0,
            total - MAX_ACHIEVEMENT_SEARCH_RESULTS)
        resultOffset = math.max(0, math.min(resultOffset, maximumOffset))
        local first = resultOffset + 1
        local last = math.min(total,
            resultOffset + MAX_ACHIEVEMENT_SEARCH_RESULTS)
        local shown = 0
        for resultIndex = first, last do
            local entry = resultEntries[resultIndex]
            local data = entry.kind == "achievement"
                and GetAchievementData(entry.id)
            if data or entry.kind ~= "achievement" then
                shown = shown + 1
                local row = rows[shown]
                row.entry = entry
                row.achievementID = data and data.id
                row.node = data
                local resultAtlas = entry.kind == "map"
                    and "poi-islands-table"
                    or entry.kind == "coordinate"
                        and "Waypoint-MapPin-Minimap-Tracked"
                if resultAtlas and SetTextureAtlas(row.Icon,
                    resultAtlas) then
                    row.Icon:SetSize(20, 20)
                else
                    row.Icon:SetTexture(data and data.icon or entry.icon)
                    row.Icon:SetTexCoord(0, 1, 0, 1)
                end
                row.Icon:SetDesaturated(data and not data.completed or false)
                row.AchievementIconBorder:SetShown(data ~= nil)
                row.AchievementIconBorder:SetDesaturated(data
                    and not data.completed or false)
                row.MapIconBorder:SetShown(entry.kind == "map"
                    or entry.kind == "coordinate")
                row.Name:SetText(data and data.name or entry.kind == "map"
                    and string.format(L.ACHIEVEMENT_SEARCH_MAP, entry.name)
                    or string.format(L.ACHIEVEMENT_SEARCH_COORDINATE,
                        entry.x, entry.y))
                if data then
                    SetAchievementTextColor(row.Name,
                        data.completed, false, 0.82)
                else
                    row.Name:SetTextColor(1, 0.82, 0)
                end
                row:Show()
            end
        end
        for index = shown + 1, #rows do
            rows[index]:Hide()
            rows[index].achievementID = nil
            rows[index].node = nil
            rows[index].entry = nil
        end
        messageRow:SetShown(shown == 0)
        message:SetText(mapBuilding and L.ACHIEVEMENT_SEARCHING
            or L.ACHIEVEMENT_SEARCH_NO_RESULTS)
        if total > MAX_ACHIEVEMENT_SEARCH_RESULTS then
            resultFooter:SetText(string.format(L.ACHIEVEMENT_SEARCH_RESULTS,
                first, last, total))
            if footerFont and footerSize then
                resultFooter:SetFont(footerFont, footerSize, footerFlags)
                local textWidth = resultFooter.GetUnboundedStringWidth
                    and resultFooter:GetUnboundedStringWidth()
                    or resultFooter:GetStringWidth()
                local availableWidth = math.max(1,
                    resultsBackground:GetWidth() - 12)
                if textWidth > availableWidth then
                    resultFooter:SetFont(footerFont,
                        footerSize * availableWidth / textWidth,
                        footerFlags)
                end
            end
            resultFooter:Show()
        else
            resultFooter:Hide()
        end
        local resultHeight = math.max(shown, 1) * 28
            + resultsBottomPadding
            + (resultFooter:IsShown() and 22 or 0)
        roundedBottom:SetHeight(math.min(anchorHeight, resultHeight))
        ShowResults(true)
        SetPanelHeight(searchTopInset + searchHeight + resultsGap
            + resultHeight)
    end

    local function RefreshResults(includeAchievements)
        local seen = {}
        local query = search:GetText() or ""
        resultEntries, mapBuilding = Addon.MapSearch.Find(query, 3)
        local exactID = tonumber(query)
        local function AddResult(achievementID)
            if seen[achievementID] or not IsAchievementValid(achievementID)
            then
                return
            end
            local isStatistic = select(15,
                GetAchievementInfo(achievementID))
            if not isStatistic then
                seen[achievementID] = true
                resultEntries[#resultEntries + 1] = {
                    kind = "achievement", id = achievementID }
            end
        end
        if includeAchievements then
            if exactID then AddResult(math.floor(exactID)) end
            for index = 1, GetNumFilteredAchievements() or 0 do
                AddResult(GetFilteredAchievementID(index))
            end
        end
        RenderResults()
    end

    search:HookScript("OnTextChanged", function(self)
        local query = self:GetText() or ""
        resultOffset = 0
        if #query < (MIN_CHARACTER_SEARCH or 3) then
            ReleaseAchievementSearch(panel)
            resultEntries = {}
            for _, row in ipairs(rows) do
                row:Hide()
            end
            messageRow:Hide()
            resultFooter:Hide()
            ShowResults(false)
            SetPanelHeight(collapsedHeight)
            return
        end
        if Addon.MapSearch.ParseCoordinates(query) then
            ReleaseAchievementSearch(panel)
            RefreshResults(false)
            return
        end
        local finished = SetOwnedAchievementSearch(panel, query)
        if finished then
            RefreshResults(true)
        else
            RefreshResults(false)
        end
    end)
    search:SetScript("OnEscapePressed", HidePanel)
    panel:SetScript("OnMouseWheel", function(_, delta)
        if #resultEntries <= MAX_ACHIEVEMENT_SEARCH_RESULTS then return end
        local maximumOffset = #resultEntries - MAX_ACHIEVEMENT_SEARCH_RESULTS
        resultOffset = math.max(0, math.min(maximumOffset,
            resultOffset - delta * MAX_ACHIEVEMENT_SEARCH_RESULTS))
        RenderResults()
    end)
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
            RefreshResults(true)
        end
    end)
    Addon.MapSearch.Subscribe(function()
        if panel:IsShown() and #(search:GetText() or "") >=
            (MIN_CHARACTER_SEARCH or 3) then
            RefreshResults(achievementSearchOwner == panel)
        end
    end)

    local function ScheduleHide()
        C_Timer.After(0.12, function()
            local overResults = searchBackground:IsShown()
                and searchBackground.IsMouseOver
                and searchBackground:IsMouseOver()
            overResults = overResults or resultsBackground:IsShown()
                and resultsBackground.IsMouseOver
                and resultsBackground:IsMouseOver()
            if not overResults then
                for _, row in ipairs(rows) do
                    if row:IsShown() and row:IsMouseOver() then
                        overResults = true
                        break
                    end
                end
            end
            if panel:IsShown() and not panel:IsMouseOver()
                and not anchor:IsMouseOver() and not overResults
            then
                HidePanel()
            end
        end)
    end
    panel:SetScript("OnLeave", ScheduleHide)
    search:HookScript("OnEditFocusLost", ScheduleHide)

    function panel:ShowAnimated()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "TOPLEFT", inputOffsetX,
            anchorOffsetY)
        self.animationStartedAt = GetTime()
        self:SetAlpha(0)
        searchBackground:SetWidth(anchor:GetWidth())
        searchBackground:SetAlpha(0)
        searchBackground:Show()
        self:Show()
        self:SetScript("OnUpdate", function(searchPanel)
            local progress = math.min(1,
                (GetTime() - searchPanel.animationStartedAt) / 0.15)
            searchPanel:SetAlpha(progress)
            searchBackground:SetWidth(anchor:GetWidth()
                + (inputOffsetX + searchPanel:GetWidth()
                    - anchor:GetWidth()) * progress)
            searchBackground:SetAlpha(progress)
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

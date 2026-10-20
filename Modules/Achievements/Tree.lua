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

function AcquireNodeButton(frame, index)
    local button = frame.nodeButtons[index]
    if button then
        button:Show()
        return button
    end

    button = CreateFrame("Button", nil, frame.Content)
    button:SetSize(NODE_SIZE, NODE_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local rootGlow = button:CreateTexture(nil, "BACKGROUND", nil, -2)
    rootGlow:SetPoint("CENTER")
    rootGlow:SetSize(34, 34)
    if not SetTextureAtlas(rootGlow, "AftLevelup-WhiteStarBurst") then
        rootGlow:SetColorTexture(1, 0.72, 0.12, 0.22)
    end
    rootGlow:SetVertexColor(1, 0.72, 0.12, 0.35)
    rootGlow:SetBlendMode("ADD")
    rootGlow:Hide()
    button.RootGlow = rootGlow

    local icon = button:CreateTexture(nil, "BORDER")
    icon:SetPoint("CENTER", 0, 1)
    icon:SetSize(NODE_ICON_SIZE, NODE_ICON_SIZE)
    icon:SetTexCoord(0, 1, 0, 1)
    button.Icon = icon

    local disabledOverlay = button:CreateTexture(nil, "BORDER", nil, 1)
    disabledOverlay:SetPoint("CENTER", 0, 1)
    disabledOverlay:SetSize(NODE_ICON_SIZE, NODE_ICON_SIZE)
    disabledOverlay:SetColorTexture(0, 0, 0, 0.3)
    button.DisabledOverlay = disabledOverlay

    local border = button:CreateTexture(nil, "ARTWORK")
    border:SetPoint("CENTER", -0.33, 0.67)
    border:SetSize(24, 24)
    border:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    border:SetTexCoord(0, 0.5625, 0, 0.5625)
    button.Border = border

    local label = button:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    label:SetPoint("LEFT", button, "RIGHT", LABEL_LEFT_GAP, 1)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    button.Label = label
    button.LabelFontPath, button.LabelFontSize, button.LabelFontFlags =
        label:GetFont()

    local hoverGlow = button:CreateTexture(nil, "OVERLAY")
    hoverGlow:SetPoint("LEFT", border, "LEFT", 1, 0)
    hoverGlow:SetPoint("RIGHT", label, "RIGHT", 3, 0)
    hoverGlow:SetHeight(22)
    hoverGlow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:SetAlpha(0.75)
    hoverGlow:Hide()
    button.HoverGlow = hoverGlow

    local searchHighlight = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    searchHighlight:SetPoint("LEFT", border, "LEFT", 1, 0)
    searchHighlight:SetPoint("RIGHT", label, "RIGHT", 3, 0)
    searchHighlight:SetHeight(22)
    searchHighlight:SetTexture(
        "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    searchHighlight:SetBlendMode("ADD")
    searchHighlight:SetAlpha(0.9)
    searchHighlight:Hide()
    button.SearchHighlight = searchHighlight
    local searchPulse = searchHighlight:CreateAnimationGroup()
    local pulseIn1 = searchPulse:CreateAnimation("Alpha")
    pulseIn1:SetFromAlpha(0.35)
    pulseIn1:SetToAlpha(1)
    pulseIn1:SetDuration(0.35)
    pulseIn1:SetOrder(1)
    local pulseOut1 = searchPulse:CreateAnimation("Alpha")
    pulseOut1:SetFromAlpha(1)
    pulseOut1:SetToAlpha(0.45)
    pulseOut1:SetDuration(0.35)
    pulseOut1:SetOrder(2)
    local pulseIn2 = searchPulse:CreateAnimation("Alpha")
    pulseIn2:SetFromAlpha(0.45)
    pulseIn2:SetToAlpha(1)
    pulseIn2:SetDuration(0.35)
    pulseIn2:SetOrder(3)
    local pulseSettle = searchPulse:CreateAnimation("Alpha")
    pulseSettle:SetFromAlpha(1)
    pulseSettle:SetToAlpha(0.9)
    pulseSettle:SetDuration(0.35)
    pulseSettle:SetOrder(4)
    button.SearchHighlightPulse = searchPulse

    local revealGlow = button:CreateTexture(nil, "OVERLAY", nil, 1)
    revealGlow:SetPoint("LEFT", border, "LEFT", 1, 0)
    revealGlow:SetPoint("RIGHT", label, "RIGHT", 3, 0)
    revealGlow:SetHeight(22)
    revealGlow:SetTexture(
        "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    revealGlow:SetBlendMode("ADD")
    revealGlow:SetVertexColor(1, 0.68, 0.08)
    revealGlow:Hide()
    button.RevealGlow = revealGlow
    local revealPulse = revealGlow:CreateAnimationGroup()
    for order = 1, 4 do
        local pulse = revealPulse:CreateAnimation("Alpha")
        if order % 2 == 1 then
            pulse:SetFromAlpha(0.25)
            pulse:SetToAlpha(1)
        else
            pulse:SetFromAlpha(1)
            pulse:SetToAlpha(0.25)
        end
        pulse:SetDuration(0.32)
        pulse:SetOrder(order)
    end
    revealPulse:SetScript("OnPlay", function()
        revealGlow:Show()
        SetAchievementTextColor(button.Label,
            button.node and button.node.completed, true)
    end)
    revealPulse:SetScript("OnFinished", function()
        revealGlow:Hide()
        SetAchievementTextColor(button.Label,
            button.node and button.node.completed,
            button.SearchHighlightQuery ~= nil)
    end)
    button.RevealHighlightPulse = revealPulse

    local revealStarBurst = button:CreateTexture(nil, "OVERLAY", nil, 2)
    revealStarBurst:SetPoint("CENTER", button.Icon, "CENTER")
    revealStarBurst:SetSize(84, 84)
    SetTextureAtlas(revealStarBurst, "AftLevelup-WhiteStarBurst")
    revealStarBurst:SetBlendMode("ADD")
    revealStarBurst:Hide()
    button.RevealStarBurst = revealStarBurst
    local revealStarBurstPulse = revealStarBurst:CreateAnimationGroup()
    for flash = 1, 5 do
        local fadeIn = revealStarBurstPulse:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(0.9)
        fadeIn:SetDuration(0.18)
        fadeIn:SetOrder(flash * 2 - 1)
        local fadeOut = revealStarBurstPulse:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(0.9)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.24)
        fadeOut:SetOrder(flash * 2)
    end
    revealStarBurstPulse:SetScript("OnPlay", function()
        revealStarBurst:SetAlpha(0)
        revealStarBurst:Show()
    end)
    revealStarBurstPulse:SetScript("OnFinished", function()
        revealStarBurst:Hide()
    end)
    revealStarBurstPulse:SetScript("OnStop", function()
        revealStarBurst:Hide()
    end)
    button.RevealStarBurstPulse = revealStarBurstPulse

    local favoriteStar = button:CreateFontString(nil, "OVERLAY",
        "GameFontNormalSmall")
    favoriteStar:SetPoint("CENTER", button, "TOPRIGHT", 3, -2)
    favoriteStar:SetText("|cffffd100★|r")
    favoriteStar:Hide()
    button.FavoriteStar = favoriteStar
    button.FavoriteStarFontPath, button.FavoriteStarFontSize,
        button.FavoriteStarFontFlags = favoriteStar:GetFont()

    local rewardMarker = button:CreateTexture(nil, "OVERLAY", nil, 7)
    rewardMarker:SetPoint("CENTER", icon, "TOPRIGHT")
    SetTextureAtlas(rewardMarker, "SoulBinds_Collection_Charge_Pending")
    rewardMarker:Hide()
    button.RewardMarker = rewardMarker

    local completionGlow = button:CreateTexture(nil, "OVERLAY")
    completionGlow:SetPoint("TOPLEFT", -5, 5)
    completionGlow:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 5, -5)
    completionGlow:SetColorTexture(1, 0.78, 0.1, 0.8)
    completionGlow:Hide()
    local completionAnimation = completionGlow:CreateAnimationGroup()
    local fadeIn = completionAnimation:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.75)
    fadeIn:SetDuration(0.28)
    fadeIn:SetOrder(1)
    local fadeOut = completionAnimation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.75)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.65)
    fadeOut:SetOrder(2)
    completionAnimation:SetScript("OnPlay", function()
        completionGlow:Show()
    end)
    completionAnimation:SetScript("OnFinished", function()
        completionGlow:Hide()
    end)
    button.CompletionAnimation = completionAnimation

    local collapseButton = CreateFrame("Button", nil, button)
    collapseButton:SetPoint("CENTER", button, "BOTTOMRIGHT", 2, 2)
    collapseButton:SetSize(26, 13)
    local collapseText = collapseButton:CreateFontString(nil, "OVERLAY",
        "GameFontNormalSmall")
    collapseText:SetPoint("CENTER")
    collapseButton.Text = collapseText
    collapseButton.TextFontPath, collapseButton.TextFontSize,
        collapseButton.TextFontFlags = collapseText:GetFont()
    collapseButton:SetScript("OnClick", function()
        if button.node and button.node.hasChildren then
            frame.collapsedNodes = frame.collapsedNodes or {}
            frame.collapsedNodes[button.node.id] =
                not frame.collapsedNodes[button.node.id] or nil
            ShowAchievementTree(frame.sourceAchievementID, "refresh")
        end
    end)
    button.CollapseButton = collapseButton

    button:SetScript("OnEnter", function(self)
        self.HoverGlow:Show()
        HighlightNodeLines(frame, self.node)
        SetAchievementTextColor(self.Label,
            self.node and self.node.completed, true)
        ShowAchievementTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.HoverGlow:Hide()
        if frame.hoveredNode == self.node then
            ClearHoveredLines(frame)
        end
        SetAchievementTextColor(self.Label,
            self.node and self.node.completed,
            self.SearchHighlightQuery ~= nil)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDoubleClick", function(self, mouseButton)
        if mouseButton == "LeftButton" and self.node
            and self.node.hasChildren and not IsShiftKeyDown()
        then
            self.clickSerial = (self.clickSerial or 0) + 1
            frame.collapsedNodes = frame.collapsedNodes or {}
            frame.collapsedNodes[self.node.id] =
                not frame.collapsedNodes[self.node.id] or nil
            ShowAchievementTree(frame.sourceAchievementID, "refresh")
        end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if not self.node then
            return
        end
        if mouseButton == "RightButton" then
            if OpenAchievementContextMenu then
                OpenAchievementContextMenu(self, self.node.id)
            end
        elseif IsShiftKeyDown() then
            self.clickSerial = (self.clickSerial or 0) + 1
            InsertAchievementLink(self.node.id)
        else
            self.clickSerial = (self.clickSerial or 0) + 1
            local serial = self.clickSerial
            local achievementID = self.node.id
            C_Timer.After(0.24, function()
                if self.clickSerial == serial then
                    if frame.rewardCategoryMode
                        and OpenAchievementRewardCategoryCard
                    then
                        OpenAchievementRewardCategoryCard(frame,
                            achievementID)
                    else
                        OpenAchievementPathCard(frame, achievementID)
                    end
                end
            end)
        end
    end)

    frame.nodeButtons[index] = button
    return button
end

function AcquireLine(frame, index)
    local line = frame.lines[index]
    if not line then
        line = frame.Content:CreateLine(nil, "BACKGROUND")
        line:SetThickness(6)
        frame.lines[index] = line
    end
    line:Show()
    return line
end

LayoutAchievementTree = function(nodes, edges, root, preserveScroll, stats,
    titleRoot, cardAchievementID)
    local frame = CreateAchievementTreeFrame()
    local categoryMode = frame.rewardCategoryMode
    cardAchievementID = cardAchievementID
        or frame.cardOnlyAchievementID
    ClearHoveredLines(frame)
    frame.Stats:Show()
    frame.Legend:SetShown(not categoryMode)
    if frame.RootAncestorButton then
        frame.RootAncestorButton:Hide()
    end
    if achievementRewardFrame then
        achievementRewardFrame:Hide()
    end
    if frame.AchievementCard then
        frame.AchievementCard:Hide()
        frame.AchievementCardHeader:Hide()
        frame.AchievementCardTreeButton:Hide()
        frame.AchievementCardBackButton:Hide()
        frame.AchievementCardForwardButton:Hide()
        frame.AchievementCardCategoryPosition:Hide()
        frame.AchievementCardCategoryReturnButton:Hide()
    end
    frame.CardScaleControls:Show()
    frame.TreeScaleControls:Show()
    frame.FitButton:Show()
    frame.ScrollFrame:Show()
    frame.updatingLayout = true
    frame.layoutNodes = nodes
    frame.layoutEdges = edges
    frame.layoutRoot = root
    frame.layoutStats = stats
    frame.layoutTitleRoot = titleRoot
    titleRoot = titleRoot or root
    if not categoryMode then
        StartAchievementParentIndex()
    end
    stats = stats or GetAchievementTreeStats(nodes)
    local showIncompleteFilter = not categoryMode and stats.incomplete > 0
    frame.IncompleteOnly:SetShown(showIncompleteFilter)
    frame.IncompleteOnlyLabel:SetShown(showIncompleteFilter)
    frame.PortraitIcon:SetTexture(categoryMode and categoryMode.icon
        or titleRoot.icon)
    frame.ATTButton:SetShown(not categoryMode and CanOpenAchievementATTGuide())
    local completionPercent = stats.total > 0
        and math.floor(stats.completed * 100 / stats.total + 0.5) or 0
    if categoryMode then
        UpdateAchievementHeader(frame, categoryMode.label,
            string.format(L.ACHIEVEMENT_REWARD_CATEGORY_STATS, stats.total))
        UpdateAchievementRewardHeader(frame, nil)
    else
        UpdateAchievementHeader(frame,
            string.format(L.ACHIEVEMENT_TREE_TITLE, titleRoot.name),
            string.format(L.ACHIEVEMENT_TREE_STATS,
                stats.total, stats.completed, stats.incomplete,
                completionPercent))
        UpdateAchievementRewardHeader(frame, titleRoot.id)
    end
    local canGoBack = (frame.historyIndex or 1) > 1
    local canGoForward = (frame.historyIndex or 0)
        < #(frame.history or {})
    frame.BackButton:SetShown(not categoryMode or canGoBack)
    frame.ForwardButton:SetShown(not categoryMode or canGoForward)
    frame.BackButton:SetEnabled(canGoBack)
    frame.BackButton:SetAlpha(canGoBack and 1 or 0.35)
    frame.ForwardButton:SetEnabled(canGoForward)
    frame.ForwardButton:SetAlpha(canGoForward and 1 or 0.35)
    if categoryMode then
        frame.Breadcrumb:Hide()
        for _, button in ipairs(frame.BreadcrumbButtons or {}) do
            button:Hide()
        end
    else
        frame.Breadcrumb:Show()
    end

    if not categoryMode then
        cardAchievementID = cardAchievementID
            or (#nodes == 1 and #edges == 0 and nodes[1].id)
    end
    if cardAchievementID
        and ShowAchievementCardInTree(frame, cardAchievementID)
    then
        for _, button in ipairs(frame.nodeButtons) do
            button:Hide()
            button.node = nil
        end
        for _, line in ipairs(frame.lines) do
            line:Hide()
        end
        frame.HorizontalScroll:SetMinMaxValues(0, 0)
        frame.HorizontalScroll:SetValue(0)
        frame.pendingHorizontalScroll = nil
        frame.pendingVerticalScroll = nil
        frame.updatingLayout = false
        frame:Show()
        frame:Raise()
        SaveAchievementTreeState(frame)
        return
    end

    if #nodes == 0 then
        for _, button in ipairs(frame.nodeButtons) do
            button:Hide()
            button.node = nil
        end
        for _, line in ipairs(frame.lines) do
            line:Hide()
        end
        frame.Content:SetSize(math.max(1, frame.ScrollFrame:GetWidth()),
            math.max(1, frame.ScrollFrame:GetHeight()))
        frame.HorizontalScroll:SetMinMaxValues(0, 0)
        frame.HorizontalScroll:SetValue(0)
        frame.HorizontalScroll:Hide()
        frame.ScrollFrame:SetVerticalScroll(0)
        frame.pendingHorizontalScroll = nil
        frame.pendingVerticalScroll = nil
        frame.Navigator:Hide()
        frame.EmptyText:Show()
        frame.updatingLayout = false
        frame:Show()
        frame:Raise()
        SaveAchievementTreeState(frame)
        return
    end
    frame.EmptyText:Hide()
    local scale = frame.treeScale or 1
    local nodeSize = NODE_SIZE * scale
    local nodeIconSize = NODE_ICON_SIZE * scale
    local nodeRowPitch = nodeSize + 1
    local levelGap = LEVEL_GAP * scale
    local labelLeftGap = LABEL_LEFT_GAP * scale
    local treePadding = TREE_PADDING * scale
    local topmostAchievementIDs = {}
    local topmostAchievementID
    local hasAncestor = false
    if not categoryMode then
        local ancestorDepth
        topmostAchievementIDs, ancestorDepth =
            GetTopmostAchievementIDs(titleRoot.id)
        topmostAchievementID = topmostAchievementIDs[1]
        hasAncestor = ancestorDepth > 0
            and topmostAchievementID ~= titleRoot.id
    end
    local ancestorButtonWidth = math.max(6, 18 * scale)
    local treeLeftPadding = treePadding
        + (hasAncestor and ancestorButtonWidth + 3 * scale or 0)
    local viewportWidth = math.max(1, frame.ScrollFrame:GetWidth())
    local viewportHeight = math.max(1, frame.ScrollFrame:GetHeight())
    local availableTreeHeight = math.max(nodeRowPitch,
        viewportHeight - treePadding * 2)
    local favoriteSet = {}
    for _, achievementID in ipairs(GetAchievementFavorites()) do
        favoriteSet[achievementID] = true
    end

    local buttonIndex = 0
    for _, node in ipairs(nodes) do
        buttonIndex = buttonIndex + 1
        local button = AcquireNodeButton(frame, buttonIndex)
        button:SetSize(nodeSize, nodeSize)
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("CENTER", button, "CENTER", 0, scale)
        button.Icon:SetSize(nodeIconSize, nodeIconSize)
        button.DisabledOverlay:ClearAllPoints()
        button.DisabledOverlay:SetPoint("CENTER", button, "CENTER", 0,
            scale)
        button.DisabledOverlay:SetSize(nodeIconSize, nodeIconSize)
        button.Border:ClearAllPoints()
        button.Border:SetPoint("CENTER", button, "CENTER",
            -nodeSize / 60, nodeSize / 30)
        button.Border:SetSize(nodeSize * 1.2, nodeSize * 1.2)
        button.HoverGlow:SetHeight(nodeSize * 1.2 - 2 * scale)
        button.SearchHighlight:SetHeight(nodeSize * 1.2 - 2 * scale)
        button.RevealGlow:SetHeight(nodeSize * 1.2 - 2 * scale)
        button.RevealHighlightPulse:Stop()
        button.RevealGlow:Hide()
        button.RevealStarBurstPulse:Stop()
        button.RevealStarBurst:SetSize(84 * scale, 84 * scale)
        button.RevealStarBurst:Hide()
        button.RootGlow:SetSize(34 * scale, 34 * scale)
        local markerSize = math.max(6, math.floor(
            (button.FavoriteStarFontSize or 10) * scale + 0.5))
        if button.FavoriteStarFontPath then
            button.FavoriteStar:SetFont(button.FavoriteStarFontPath,
                markerSize,
                button.FavoriteStarFontFlags)
        end
        button.RewardMarker:ClearAllPoints()
        button.RewardMarker:SetPoint("CENTER", button.Icon, "TOPRIGHT")
        button.RewardMarker:SetSize(markerSize, markerSize)
        if button.CollapseButton.TextFontPath then
            button.CollapseButton.Text:SetFont(
                button.CollapseButton.TextFontPath,
                math.max(6, math.floor(
                    button.CollapseButton.TextFontSize * scale + 0.5)),
                button.CollapseButton.TextFontFlags)
        end
        if button.LabelFontPath then
            button.Label:SetFont(button.LabelFontPath,
                math.max(6, math.floor(button.LabelFontSize * scale + 0.5)),
                button.LabelFontFlags)
        end
        button.Label:ClearAllPoints()
        button.Label:SetPoint("LEFT", button, "RIGHT", labelLeftGap, scale)
        button.node = node
        button.Icon:SetTexture(node.icon)
        button.Icon:SetDesaturated(not node.completed)
        button.BaseIconAlpha = node.completed and 1 or 0.58
        button.BaseLabelAlpha = 1
        button.Icon:SetAlpha(button.BaseIconAlpha)
        local hasReward = Addon.AchievementRewards.Has(node.id, node)
        local isFavorite = favoriteSet[node.id] == true
        button.RewardMarker:SetShown(hasReward)
        button.Label:SetAlpha(button.BaseLabelAlpha)
        button.DisabledOverlay:SetShown(not node.completed)
        button.DisabledOverlay:SetAlpha(node.completed and 0 or 0.45)
        button.Border:SetDesaturated(not node.completed)
        button.Border:SetAlpha(node.completed and 1 or 0.72)
        button.FavoriteStar:ClearAllPoints()
        if hasReward and isFavorite then
            button.FavoriteStar:SetPoint(
                "RIGHT", button.RewardMarker, "LEFT", 0, 0)
        else
            button.FavoriteStar:SetPoint("CENTER", button.Icon, "TOPRIGHT")
        end
        button.FavoriteStar:SetShown(isFavorite)
        button.Label:SetText(node.name)
        SetAchievementTextColor(button.Label, node.completed, false)
        button.RootGlow:SetShown(not categoryMode and node == root)
        local collapsed = frame.collapsedNodes
            and frame.collapsedNodes[node.id] == true
        button.CollapseButton:SetShown(node.hasChildren == true and collapsed)
        button.CollapseButton.Text:SetText("+"
            .. tostring(node.descendantCount or 0))
        node.button = button

        local labelWidth = math.ceil(button.Label:GetStringWidth())
        node.layoutWidth = nodeSize + labelLeftGap + labelWidth
        button:SetHitRectInsets(0, -(node.layoutWidth - nodeSize), -3, -3)
    end
    for index = buttonIndex + 1, #frame.nodeButtons do
        frame.nodeButtons[index]:Hide()
        frame.nodeButtons[index].node = nil
    end

    local calculatedLayout = AchievementTreeLayout.Calculate(
        nodes, edges, root, {
            availableHeight = availableTreeHeight,
            branchGap = BRANCH_GAP,
            levelGap = levelGap,
            nodeRowPitch = nodeRowPitch,
            leftPadding = treeLeftPadding,
            padding = treePadding,
            viewportWidth = viewportWidth,
            viewportHeight = viewportHeight,
        })
    frame.requiredTreeWidth = calculatedLayout.requiredWidth
    frame.requiredTreeHeight = calculatedLayout.requiredHeight
    local contentWidth = calculatedLayout.contentWidth
    local contentHeight = calculatedLayout.contentHeight
    frame.Content:SetSize(contentWidth, contentHeight)

    for _, node in ipairs(nodes) do
        local button = node.button
        local horizontal = calculatedLayout.horizontalPositions[node.id]
        local vertical = calculatedLayout.verticalPositions[node.id]
        node.navigatorX = horizontal + nodeSize / 2
        node.navigatorY = calculatedLayout.treeTop + vertical
        button:ClearAllPoints()
        button:SetPoint("LEFT", frame.Content, "TOPLEFT",
            horizontal, -(calculatedLayout.treeTop + vertical))
    end

    local rootButton = titleRoot.button
    if hasAncestor and rootButton and rootButton.node == titleRoot
        and rootButton:IsShown()
    then
        local ancestorButton = frame.RootAncestorButton
        if not ancestorButton then
            ancestorButton = CreateFrame("Button", nil, frame.Content,
                "UIPanelButtonTemplate")
            ancestorButton:SetText("+")
            ancestorButton:SetFrameLevel(frame.Content:GetFrameLevel() + 20)
            ancestorButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.ACHIEVEMENT_TREE_FULL_TOOLTIP)
                GameTooltip:Show()
            end)
            ancestorButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            ancestorButton:SetScript("OnClick", function(self)
                local achievementIDs = self.achievementIDs or {}
                local function OpenFullTree(rootID)
                    frame.pendingRevealAchievementID =
                        self.originAchievementID
                    ShowAchievementTree(rootID)
                end
                if #achievementIDs == 1 then
                    OpenFullTree(achievementIDs[1])
                elseif #achievementIDs > 1 and MenuUtil
                    and MenuUtil.CreateContextMenu
                then
                    MenuUtil.CreateContextMenu(self,
                        function(_, rootDescription)
                            rootDescription:CreateTitle(
                                L.ACHIEVEMENT_TREE_CHOOSE_ROOT)
                            for _, achievementID in ipairs(achievementIDs) do
                                local rootID = achievementID
                                local data = GetAchievementData(rootID)
                                local label = data and string.format(
                                    "%s (%d)", data.name, rootID)
                                    or tostring(rootID)
                                rootDescription:CreateButton(label,
                                    function()
                                        OpenFullTree(rootID)
                                    end)
                            end
                        end)
                end
            end)
            frame.RootAncestorButton = ancestorButton
        end
        ancestorButton.achievementID = topmostAchievementID
        ancestorButton.achievementIDs = topmostAchievementIDs
        ancestorButton.originAchievementID = titleRoot.id
        ancestorButton:SetSize(ancestorButtonWidth, ancestorButtonWidth)
        ancestorButton:ClearAllPoints()
        ancestorButton:SetPoint("RIGHT", rootButton, "LEFT",
            -3 * scale, 0)
        ancestorButton:Show()
    end

    local lineIndex = 0
    for _, edge in ipairs(edges) do
        if edge.parent.button and edge.child.button then
            lineIndex = lineIndex + 1
            local line = AcquireLine(frame, lineIndex)
            line.BaseThickness = math.max(1, 6 * scale)
            line:SetThickness(line.BaseThickness)
            line:ClearAllPoints()
            line:SetStartPoint("RIGHT", edge.parent.button.Label, 0, 0)
            line:SetEndPoint("LEFT", edge.child.button, 0, 0)
            line.ParentNode = edge.parent
            line.ChildNode = edge.child
            if edge.parent == root and root.completed then
                line.BaseTexture =
                    "Interface\\Artifacts\\_Artifacts-DependencyBar-Fill"
                line.BaseRed, line.BaseGreen, line.BaseBlue = 0.2, 1, 0.2
            elseif edge.parent == root then
                line.BaseTexture =
                    "Interface\\Artifacts\\_Artifacts-DependencyBar-Fill"
                line.BaseRed, line.BaseGreen, line.BaseBlue = 1, 0.82, 0.18
            elseif edge.parent.completed and edge.child.completed then
                line.BaseTexture =
                    "Interface\\Artifacts\\_Artifacts-DependencyBar-Fill"
                line.BaseRed, line.BaseGreen, line.BaseBlue = 0.2, 1, 0.2
            else
                line.BaseTexture =
                    "Interface\\Artifacts\\_Artifacts-DependencyBar-Fill"
                line.BaseRed, line.BaseGreen, line.BaseBlue = 0.68, 0.68, 0.68
            end
            line.BaseColorAlpha = 0.95
            RestoreLineAppearance(line)
        end
    end
    for index = lineIndex + 1, #frame.lines do
        frame.lines[index]:Hide()
    end

    local horizontalMaximum = math.max(0, contentWidth - viewportWidth)
    local desiredHorizontal = frame.pendingHorizontalScroll
        or (preserveScroll and frame.ScrollFrame:GetHorizontalScroll())
        or 0
    local desiredVertical = frame.pendingVerticalScroll
        or (preserveScroll and frame.ScrollFrame:GetVerticalScroll())
        or 0
    frame.HorizontalScroll:SetMinMaxValues(0, horizontalMaximum)
    frame.HorizontalScroll:SetShown(horizontalMaximum > 0.5)
    frame.HorizontalScroll:SetValue(math.min(desiredHorizontal,
        horizontalMaximum))
    local verticalMaximum = math.max(0, contentHeight - viewportHeight)
    frame.ScrollFrame:SetVerticalScroll(math.min(desiredVertical,
        verticalMaximum))
    frame.pendingHorizontalScroll = nil
    frame.pendingVerticalScroll = nil
    RefreshAchievementNavigator(frame, nodes, edges)
    frame.updatingLayout = false
    frame:Show()
    frame:Raise()
    if UpdateTreeSearch then
        UpdateTreeSearch(frame)
    end
    SaveAchievementTreeState(frame)
end

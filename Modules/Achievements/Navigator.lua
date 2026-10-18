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

UpdateAchievementNavigatorViewport = function(frame)
    local navigator = frame and frame.Navigator
    if not navigator or not navigator:IsShown() or not navigator.mapScale then
        return
    end
    local scrollFrame = frame.ScrollFrame
    local contentWidth = navigator.contentWidth
    local contentHeight = navigator.contentHeight
    local scale = navigator.mapScale
    local left = navigator.mapLeft
        + scrollFrame:GetHorizontalScroll() * scale
    local bottom = navigator.mapBottom
        + (contentHeight - scrollFrame:GetVerticalScroll()
            - math.min(scrollFrame:GetHeight(), contentHeight)) * scale
    local width = math.min(scrollFrame:GetWidth(), contentWidth) * scale
    local height = math.min(scrollFrame:GetHeight(), contentHeight) * scale
    local lines = navigator.ViewportLines
    lines[1]:ClearAllPoints()
    lines[1]:SetPoint("BOTTOMLEFT", navigator, "BOTTOMLEFT", left, bottom)
    lines[1]:SetSize(width, 1)
    lines[2]:ClearAllPoints()
    lines[2]:SetPoint("TOPLEFT", lines[1], "BOTTOMLEFT", 0, height)
    lines[2]:SetSize(width, 1)
    lines[3]:ClearAllPoints()
    lines[3]:SetPoint("BOTTOMLEFT", lines[1], "BOTTOMLEFT")
    lines[3]:SetSize(1, height)
    lines[4]:ClearAllPoints()
    lines[4]:SetPoint("BOTTOMRIGHT", lines[1], "BOTTOMRIGHT")
    lines[4]:SetSize(1, height)
end

RefreshAchievementNavigator = function(frame, nodes, edges)
    local navigator = frame and frame.Navigator
    if not navigator then
        return
    end
    local contentWidth = frame.Content:GetWidth()
    local contentHeight = frame.Content:GetHeight()
    local viewportWidth = frame.ScrollFrame:GetWidth()
    local viewportHeight = frame.ScrollFrame:GetHeight()
    local isLarge = contentWidth > viewportWidth + 1
        or contentHeight > viewportHeight + 1
    navigator:SetShown(isLarge)
    if not isLarge then
        return
    end

    local innerWidth = navigator:GetWidth() - 8
    local innerHeight = navigator:GetHeight() - 8
    local scale = math.min(innerWidth / contentWidth,
        innerHeight / contentHeight)
    navigator.contentWidth = contentWidth
    navigator.contentHeight = contentHeight
    navigator.mapScale = scale
    navigator.mapLeft = 4 + (innerWidth - contentWidth * scale) / 2
    navigator.mapBottom = 4 + (innerHeight - contentHeight * scale) / 2

    local function MapPoint(node)
        return navigator.mapLeft + (node.navigatorX or 0) * scale,
            navigator.mapBottom
                + (contentHeight - (node.navigatorY or 0)) * scale
    end

    for index, edge in ipairs(edges) do
        local line = navigator.LineTextures[index]
        if not line then
            line = navigator:CreateLine(nil, "ARTWORK")
            navigator.LineTextures[index] = line
        end
        local startX, startY = MapPoint(edge.parent)
        local endX, endY = MapPoint(edge.child)
        line:ClearAllPoints()
        line:SetStartPoint("BOTTOMLEFT", navigator, startX, startY)
        line:SetEndPoint("BOTTOMLEFT", navigator, endX, endY)
        line:SetThickness(1)
        if edge.parent == frame.layoutRoot and edge.parent.completed then
            line:SetColorTexture(0.2, 1, 0.2, 0.5)
        elseif edge.parent.completed and edge.child.completed then
            line:SetColorTexture(0.2, 1, 0.2, 0.5)
        else
            line:SetColorTexture(0.72, 0.72, 0.72, 0.42)
        end
        line:Show()
    end
    for index = #edges + 1, #navigator.LineTextures do
        navigator.LineTextures[index]:Hide()
    end

    for index, node in ipairs(nodes) do
        local dot = navigator.NodeTextures[index]
        if not dot then
            dot = navigator:CreateTexture(nil, "OVERLAY")
            navigator.NodeTextures[index] = dot
        end
        local x, y = MapPoint(node)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", navigator, "BOTTOMLEFT", x, y)
        dot:SetSize(node == frame.layoutRoot and 4 or 2,
            node == frame.layoutRoot and 4 or 2)
        if node == frame.layoutRoot then
            dot:SetColorTexture(1, 0.82, 0.18, 0.95)
        elseif node.completed then
            dot:SetColorTexture(0.2, 1, 0.2, 0.8)
        else
            dot:SetColorTexture(0.72, 0.72, 0.72, 0.72)
        end
        dot:Show()
    end
    for index = #nodes + 1, #navigator.NodeTextures do
        navigator.NodeTextures[index]:Hide()
    end
    UpdateAchievementNavigatorViewport(frame)
end

FitAchievementTreeToWindow = function(frame)
    if not frame or not frame.layoutNodes or #frame.layoutNodes == 0 then
        return
    end
    if not frame.rewardCategoryMode
        and AchievementTreeData.IsParentIndexBuilding()
    then
        frame.fitAfterParentIndexID = frame.sourceAchievementID
        return
    end
    frame.deferTreeStateSave = true
    local viewportWidth = math.max(1, frame.ScrollFrame:GetWidth())
    local maximumWidth = viewportWidth
    local function FitsPanel()
        return (frame.requiredTreeWidth or frame.Content:GetWidth())
            <= maximumWidth
    end

    local minimumStep = math.ceil(
        MIN_TREE_SCALE / TREE_SCALE_STEP - 0.000001)
    local maximumStep = math.floor(
        MAX_TREE_SCALE / TREE_SCALE_STEP + 0.000001)
    local low, high = minimumStep, maximumStep
    local bestStep = minimumStep
    while low <= high do
        local middle = math.floor((low + high) / 2)
        frame.ScaleSlider:SetValue(middle * TREE_SCALE_STEP)
        if FitsPanel() then
            bestStep = middle
            low = middle + 1
        else
            high = middle - 1
        end
    end
    frame.ScaleSlider:SetValue(bestStep * TREE_SCALE_STEP)
    while bestStep > minimumStep and not FitsPanel() do
        bestStep = bestStep - 1
        frame.ScaleSlider:SetValue(bestStep * TREE_SCALE_STEP)
    end
    frame.HorizontalScroll:SetValue(0)
    frame.ScrollFrame:SetVerticalScroll(0)
    UpdateAchievementNavigatorViewport(frame)
    frame.deferTreeStateSave = nil
    SaveAchievementTreeState(frame)
end

function RestoreLineAppearance(line)
    if not line.BaseTexture then
        return
    end
    line:SetTexture(line.BaseTexture)
    line:SetVertexColor(line.BaseRed, line.BaseGreen, line.BaseBlue,
        line.BaseColorAlpha)
    line:SetThickness(line.BaseThickness)
    line:SetAlpha(1)
end

ClearHoveredLines = function(frame)
    if frame.hoveredLines then
        for _, line in ipairs(frame.hoveredLines) do
            RestoreLineAppearance(line)
        end
    end
    if frame.hoveredButtons then
        for _, button in ipairs(frame.hoveredButtons) do
            button.Icon:SetAlpha(button.BaseIconAlpha or 1)
            button.Label:SetAlpha(button.BaseLabelAlpha or 1)
            if button.node then
                SetAchievementTextColor(button.Label,
                    button.node.completed,
                    button.SearchHighlightQuery ~= nil)
            end
        end
    end
    frame.hoveredLines = nil
    frame.hoveredButtons = nil
    frame.hoveredNode = nil
    frame.linePulseElapsed = nil
    frame:SetScript("OnUpdate", nil)
end

function HighlightNodeLines(frame, node)
    ClearHoveredLines(frame)
    local hoveredLines = {}
    local hoveredButtons = {}
    local buttonSeen = {}
    local function AddHoveredButton(button)
        if button and not buttonSeen[button] then
            buttonSeen[button] = true
            hoveredButtons[#hoveredButtons + 1] = button
            if button.node then
                SetAchievementTextColor(button.Label,
                    button.node.completed, true)
            end
        end
    end
    for _, line in ipairs(frame.lines) do
        if line:IsShown()
            and (line.ParentNode == node or line.ChildNode == node)
        then
            line:SetTexture(
                "Interface\\Artifacts\\_Artifacts-DependencyBar-Fill")
            line:SetVertexColor(1, 0.15, 0.1, 1)
            line:SetThickness(line.BaseThickness * 2)
            hoveredLines[#hoveredLines + 1] = line
            AddHoveredButton(line.ParentNode and line.ParentNode.button)
            AddHoveredButton(line.ChildNode and line.ChildNode.button)
        end
    end
    if #hoveredLines == 0 then
        return
    end
    frame.hoveredLines = hoveredLines
    frame.hoveredButtons = hoveredButtons
    frame.hoveredNode = node
    frame.linePulseElapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.linePulseElapsed = (self.linePulseElapsed + elapsed) % 1.4
        local wave = (math.sin(self.linePulseElapsed
            * math.pi * 2 / 1.4) + 1) / 2
        local alpha = 0.68 + wave * 0.32
        for _, line in ipairs(self.hoveredLines) do
            line:SetAlpha(alpha)
        end
        for _, button in ipairs(self.hoveredButtons) do
            button.Icon:SetAlpha((button.BaseIconAlpha or 1) * alpha)
            button.Label:SetAlpha((button.BaseLabelAlpha or 1) * alpha)
        end
    end)
end

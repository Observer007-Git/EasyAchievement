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

LayoutAchievementHeader = function(frame)
    frame.HeaderRow:SetWidth(math.max(1, frame:GetWidth() - 76))
    frame.Title:SetWidth(math.max(1, frame:GetWidth() - 340))
    frame.StatsRuler:SetText(frame.Stats:GetText() or "")
    frame.Stats:SetWidth(math.max(125,
        math.ceil(frame.StatsRuler:GetStringWidth()) + 8))
    frame.Stats:ClearAllPoints()
    frame.Stats:SetPoint("RIGHT", frame, "TOPRIGHT", -38, -12)
end

function UpdateAchievementHeader(frame, titleText, statsText)
    frame.Title:SetText(titleText or "")
    frame.Stats:SetText(statsText or "")
    LayoutAchievementHeader(frame)
end

UpdateAchievementRewardHeader = function(frame, achievementID)
    if achievementRewardFrame and achievementRewardFrame:IsShown()
        and achievementRewardFrame.achievementID ~= achievementID
    then
        achievementRewardFrame:Hide()
    end
    LayoutAchievementHeader(frame)
end

SaveAchievementTreeState = function(frame)
    if not frame or frame.restoringTreeState or frame.deferTreeStateSave then
        return
    end
    if frame.rewardCategoryMode then
        if SaveAchievementRewardCategoryState then
            SaveAchievementRewardCategoryState(frame)
        end
        return
    elseif not frame.sourceAchievementID or frame.cardOnlyAchievementID then
        return
    end
    local states = {}
    for rootID, state in pairs(
        Addon:GetSetting("achievementTreeStates") or {})
    do
        states[rootID] = state
    end
    local collapsed = {}
    for nodeID, isCollapsed in pairs(frame.collapsedNodes or {}) do
        if isCollapsed then
            collapsed[tostring(nodeID)] = true
        end
    end
    states[tostring(frame.sourceAchievementID)] = {
        scale = frame.treeScale or 1,
        horizontal = frame.ScrollFrame
            and frame.ScrollFrame:GetHorizontalScroll() or 0,
        vertical = frame.ScrollFrame
            and frame.ScrollFrame:GetVerticalScroll() or 0,
        incompleteOnly = frame.incompleteOnly == true,
        collapsed = collapsed,
        lastUsed = GetServerTime and GetServerTime()
            or time and time() or 0,
    }
    Addon:SetSetting("achievementTreeStates",
        TrimAchievementTreeStates(states, frame.sourceAchievementID))
end

RestoreAchievementTreeState = function(frame, achievementID)
    local states = Addon:GetSetting("achievementTreeStates") or {}
    local state = states[tostring(achievementID)]
    frame.restoringTreeState = true
    frame.collapsedNodes = {}
    if state then
        for nodeID, isCollapsed in pairs(state.collapsed or {}) do
            local id = SanitizeAchievementID(nodeID)
            if id and isCollapsed then
                frame.collapsedNodes[id] = true
            end
        end
        frame.incompleteOnly = state.incompleteOnly == true
        frame.treeScale = state.scale or 1
        frame.pendingHorizontalScroll = state.horizontal or 0
        frame.pendingVerticalScroll = state.vertical or 0
    else
        frame.incompleteOnly = false
        frame.treeScale = 1
        frame.pendingHorizontalScroll = 0
        frame.pendingVerticalScroll = 0
    end
    frame.IncompleteOnly:SetChecked(frame.incompleteOnly)
    frame.ScaleSlider:SetValue(frame.treeScale)
    frame.restoringTreeState = false
end

function CreateAchievementTreeFrame()
    if achievementTreeFrame then
        return achievementTreeFrame
    end

    local frame = CreateFrame("Frame", "EasyAchievementTreeFrame",
        UIParent)
    frame:SetSize(
        Addon:GetSetting("achievementTreeWidth") or DEFAULT_FRAME_WIDTH,
        Addon:GetSetting("achievementTreeHeight") or DEFAULT_FRAME_HEIGHT
    )
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT,
        MAX_FRAME_WIDTH, MAX_FRAME_HEIGHT)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:Hide()

    local borderFrame = CreateFrame("Frame", nil, frame,
        "NineSlicePanelTemplate")
    borderFrame:SetAllPoints()
    borderFrame:SetFrameLevel(frame:GetFrameLevel() + 103)
    if NineSliceUtil and NineSliceLayouts
        and NineSliceLayouts.PortraitFrameTemplateMinimizable
    then
        NineSliceUtil.ApplyLayout(borderFrame,
            NineSliceLayouts.PortraitFrameTemplateMinimizable)
    end

    local background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.12, 0.12, 0.12, 0.98)

    local portraitIconFrame = CreateFrame("Frame", nil, frame)
    portraitIconFrame:SetPoint("TOPLEFT", -4, 9)
    portraitIconFrame:SetSize(62, 62)
    portraitIconFrame:SetFrameLevel(borderFrame:GetFrameLevel())
    local portraitIcon = portraitIconFrame:CreateTexture(nil, "ARTWORK")
    portraitIcon:SetPoint("CENTER", -1, -2)
    portraitIcon:SetSize(58, 58)
    portraitIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    local portraitMask = portraitIconFrame:CreateMaskTexture()
    portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    portraitMask:SetPoint("TOPLEFT", portraitIcon, "TOPLEFT", 2, 0)
    portraitMask:SetPoint("BOTTOMRIGHT", portraitIcon, "BOTTOMRIGHT",
        -2, 4)
    portraitIcon:AddMaskTexture(portraitMask)
    frame.PortraitIcon = portraitIcon

    local headerRow = CreateFrame("Frame", nil, frame)
    headerRow:SetPoint("TOP", frame, "TOP", 0, 0)
    headerRow:SetSize(1, 24)
    headerRow:SetFrameLevel(borderFrame:GetFrameLevel() + 3)
    frame.HeaderRow = headerRow

    local title = headerRow:CreateFontString(nil, "OVERLAY",
        "GameFontNormalLarge")
    title:SetPoint("CENTER", headerRow, "CENTER")
    title:SetWordWrap(false)
    title:SetJustifyV("MIDDLE")
    title:SetTextColor(1, 0.82, 0)
    frame.Title = title

    local stats = headerRow:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    stats:SetWordWrap(false)
    stats:SetPoint("RIGHT", frame, "TOPRIGHT", -38, -12)
    stats:SetWidth(125)
    stats:SetJustifyH("RIGHT")
    stats:SetJustifyV("MIDDLE")
    stats:SetTextColor(0.85, 0.85, 0.85)
    frame.Stats = stats
    local statsRuler = headerRow:CreateFontString(nil, "ARTWORK",
        "GameFontHighlightSmall")
    statsRuler:Hide()
    frame.StatsRuler = statsRuler

    local settingsPanel = CreateFrame("Frame", nil, frame)
    settingsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -135)
    settingsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 26)
    settingsPanel:SetFrameLevel(borderFrame:GetFrameLevel() + 20)
    settingsPanel:EnableMouse(true)
    local settingsBackground = settingsPanel:CreateTexture(nil, "BACKGROUND")
    settingsBackground:SetAllPoints()
    settingsBackground:SetColorTexture(0.035, 0.035, 0.035, 0.4)
    settingsPanel:Hide()
    frame.SettingsPanel = settingsPanel

    local function CreateScaleControls(parent, labelText)
        local controls = CreateFrame("Frame", nil, parent)
        controls:SetHeight(22)
        local minus = CreateFrame("Button", nil, controls,
            "UIPanelButtonTemplate")
        local labelWidth = 0
        if labelText and labelText ~= "" then
            local label = controls:CreateFontString(nil, "OVERLAY",
                "GameFontNormalSmall")
            label:SetPoint("LEFT")
            label:SetText(labelText)
            labelWidth = math.ceil(label:GetStringWidth()) + 5
            minus:SetPoint("LEFT", label, "RIGHT", 5, 0)
        else
            minus:SetPoint("LEFT")
        end
        minus:SetSize(20, 20)
        minus:SetText("-")
        local value = controls:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        value:SetPoint("LEFT", minus, "RIGHT", 5, 0)
        value:SetWidth(38)
        value:SetJustifyH("CENTER")
        local plus = CreateFrame("Button", nil, controls,
            "UIPanelButtonTemplate")
        plus:SetPoint("LEFT", value, "RIGHT", 5, 0)
        plus:SetSize(20, 20)
        plus:SetText("+")
        controls:SetWidth(labelWidth + 88)
        return controls, minus, value, plus
    end

    local breadcrumbArrowHeight = 34
    local breadcrumbArrowWidth = breadcrumbArrowHeight * 48 / 67
    local backButton = CreateFrame("Button", nil, frame)
    backButton:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 24, -130)
    backButton:SetSize(breadcrumbArrowWidth, breadcrumbArrowHeight)
    backButton:SetNormalAtlas(
        "CovenantSanctum-Renown-DoubleArrow", false)
    backButton:SetPushedAtlas(
        "CovenantSanctum-Renown-DoubleArrow-Depressed", false)
    backButton:SetScript("OnClick", function()
        NavigateAchievementHistory(frame, -1)
    end)
    backButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.ACHIEVEMENT_HISTORY_BACK)
        GameTooltip:Show()
    end)
    backButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.BackButton = backButton

    local forwardButton = CreateFrame("Button", nil, frame)
    forwardButton:SetPoint("LEFT", backButton, "RIGHT", 3, 0)
    forwardButton:SetSize(breadcrumbArrowWidth, breadcrumbArrowHeight)
    forwardButton:SetNormalAtlas(
        "CovenantSanctum-Renown-DoubleArrow", false)
    forwardButton:GetNormalTexture():SetRotation(math.pi)
    forwardButton:SetPushedAtlas(
        "CovenantSanctum-Renown-DoubleArrow-Depressed", false)
    forwardButton:GetPushedTexture():SetRotation(math.pi)
    forwardButton:SetScript("OnClick", function()
        NavigateAchievementHistory(frame, 1)
    end)
    forwardButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.ACHIEVEMENT_HISTORY_FORWARD)
        GameTooltip:Show()
    end)
    forwardButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.ForwardButton = forwardButton

    local incompleteOnly = CreateFrame("CheckButton", nil, frame,
        "UICheckButtonTemplate")
    incompleteOnly:SetSize(22, 22)
    local incompleteOnlyLabel = incompleteOnly:CreateFontString(nil,
        "OVERLAY", "GameFontNormalSmall")
    incompleteOnlyLabel:SetPoint("LEFT", incompleteOnly, "RIGHT", 2, 0)
    incompleteOnlyLabel:SetText(L.ACHIEVEMENT_TREE_INCOMPLETE_ONLY)
    incompleteOnly:SetScript("OnClick", function(self)
        frame.incompleteOnly = self:GetChecked() == true
        if frame.sourceAchievementID and ShowAchievementTree then
            ShowAchievementTree(frame.sourceAchievementID, "refresh")
        end
    end)
    frame.IncompleteOnly = incompleteOnly
    frame.IncompleteOnlyLabel = incompleteOnlyLabel

    local treeScaleControls, scaleMinus, scaleValue, scalePlus =
        CreateScaleControls(frame)
    treeScaleControls:Hide()
    frame.TreeScaleControls = treeScaleControls
    frame.TreeScaleMinus = scaleMinus
    frame.TreeScaleValue = scaleValue
    frame.TreeScalePlus = scalePlus

    local scaleSlider = CreateFrame("Slider",
        "EasyAchievementTreeScaleSlider", frame,
        "OptionsSliderTemplate")
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetSize(1, 1)
    scaleSlider:SetMinMaxValues(MIN_TREE_SCALE, MAX_TREE_SCALE)
    scaleSlider:SetValueStep(TREE_SCALE_STEP)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:Hide()

    local fitButton = CreateFrame("Button", nil, frame)
    fitButton:SetSize(52, 52)
    fitButton:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    fitButton:SetFrameLevel(borderFrame:GetFrameLevel() + 1)
    fitButton:SetAlpha(0.7)
    local fitVisual = CreateFrame("Frame", nil, fitButton)
    fitVisual:SetAllPoints()
    fitVisual:EnableMouse(false)
    local fitArrow = fitVisual:CreateTexture(nil, "ARTWORK")
    fitArrow:SetPoint("CENTER")
    fitArrow:SetSize(48, 48)
    SetTextureAtlas(fitArrow, "decor-controls-exit-active")
    fitButton.Arrow = fitArrow
    local fitMotion = fitVisual:CreateAnimationGroup()
    fitMotion:SetLooping("REPEAT")
    local rise = fitMotion:CreateAnimation("Translation")
    rise:SetOffset(0, 3)
    rise:SetDuration(0.45)
    rise:SetSmoothing("IN_OUT")
    rise:SetOrder(1)
    local fall = fitMotion:CreateAnimation("Translation")
    fall:SetOffset(0, -3)
    fall:SetDuration(0.45)
    fall:SetSmoothing("IN_OUT")
    fall:SetOrder(2)
    fitButton.HoverMotion = fitMotion
    fitButton:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        self.HoverMotion:Play()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.ACHIEVEMENT_TREE_FIT)
        GameTooltip:Show()
    end)
    fitButton:SetScript("OnLeave", function(self)
        self:SetAlpha(0.7)
        self.HoverMotion:Stop()
        GameTooltip:Hide()
    end)
    fitButton:SetScript("OnClick", function()
        if FitAchievementTreeToWindow then
            FitAchievementTreeToWindow(frame)
        end
    end)
    fitButton:Hide()
    frame.FitButton = fitButton
    frame.treeScale = 1
    scaleSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / TREE_SCALE_STEP + 0.5)
            * TREE_SCALE_STEP
        frame.treeScale = value
        scaleMinus:SetEnabled(value > MIN_TREE_SCALE)
        scalePlus:SetEnabled(value < MAX_TREE_SCALE)
        scaleValue:SetText(string.format("%d%%", math.floor(value * 100 + 0.5)))
        if not frame.updatingLayout and not frame.restoringTreeState
            and frame.layoutNodes
            and LayoutAchievementTree
        then
            Content.Relayout(frame)
            if not frame.rewardCategoryMode and UpdateBreadcrumb then
                UpdateBreadcrumb(frame)
            end
        end
    end)
    scaleMinus:SetScript("OnClick", function()
        scaleSlider:SetValue(math.max(MIN_TREE_SCALE,
            scaleSlider:GetValue() - TREE_SCALE_STEP))
        SaveAchievementTreeState(frame)
    end)
    scalePlus:SetScript("OnClick", function()
        scaleSlider:SetValue(math.min(MAX_TREE_SCALE,
            scaleSlider:GetValue() + TREE_SCALE_STEP))
        SaveAchievementTreeState(frame)
    end)
    scaleSlider:SetValue(1)
    frame.ScaleSlider = scaleSlider

    local favoritesScroll = CreateFrame("ScrollFrame", nil, frame)
    favoritesScroll:SetPoint("TOPLEFT", 24, -69)
    favoritesScroll:SetPoint("TOPRIGHT", -24, -69)
    favoritesScroll:SetHeight(24)
    favoritesScroll:EnableMouseWheel(true)
    local favoritesContent = CreateFrame("Frame", nil, favoritesScroll)
    favoritesContent:SetSize(1, 24)
    favoritesScroll:SetScrollChild(favoritesContent)
    favoritesScroll:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0,
            favoritesContent:GetWidth() - self:GetWidth())
        self:SetHorizontalScroll(math.max(0, math.min(maximum,
            self:GetHorizontalScroll() - delta * 80)))
    end)
    frame.FavoritesScroll = favoritesScroll
    frame.FavoritesContent = favoritesContent

    local favoritesDivider = frame:CreateTexture(nil, "ARTWORK")
    favoritesDivider:SetPoint("TOPLEFT", favoritesScroll, "BOTTOMLEFT",
        0, -2)
    favoritesDivider:SetPoint("TOPRIGHT", favoritesScroll, "BOTTOMRIGHT",
        0, -2)
    favoritesDivider:SetHeight(1)
    favoritesDivider:SetColorTexture(0.38, 0.27, 0.10, 0.85)

    local favoritesEmpty = favoritesContent:CreateFontString(nil,
        "OVERLAY", "GameFontDisableSmall")
    favoritesEmpty:SetPoint("LEFT", 2, 0)
    favoritesEmpty:SetText(L.ACHIEVEMENT_FAVORITES_EMPTY)
    frame.FavoritesEmpty = favoritesEmpty

    local searchBox = CreateFrame("EditBox", nil, frame,
        "SearchBoxTemplate")
    searchBox:SetPoint("RIGHT", frame, "TOPRIGHT", -24, -45)
    local searchBoxWidth = GetAchievementSearchBoxWidth(searchBox)
    searchBox:SetSize(searchBoxWidth, 24)
    searchBox:SetHeight(24)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(MAX_ACHIEVEMENT_SEARCH_CHARACTERS)
    if searchBox.SetInstructions then
        searchBox:SetInstructions(L.ACHIEVEMENT_TREE_SEARCH)
    end

    local searchResults = CreateFrame("Frame", nil, frame)
    searchResults:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -2)
    local searchResultsWidth = searchBoxWidth + 4
    searchResults:SetSize(searchResultsWidth, 32)
    searchResults:SetFrameLevel(borderFrame:GetFrameLevel() + 10)
    searchResults:EnableMouse(true)
    searchResults:EnableMouseWheel(true)
    searchResults:Hide()
    local resultsBackground = searchResults:CreateTexture(nil, "BACKGROUND")
    resultsBackground:SetAllPoints()
    resultsBackground:SetColorTexture(0.025, 0.025, 0.025, 0.98)
    local function CreateSearchBorder(point, width)
        local texture = searchResults:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(0.72, 0.52, 0.14, 0.9)
        texture:SetPoint(point)
        if width == 1 then
            texture:SetPoint(point == "TOPLEFT" and "BOTTOMLEFT"
                or "BOTTOMRIGHT")
            texture:SetWidth(1)
        else
            texture:SetPoint(point == "TOPLEFT" and "TOPRIGHT"
                or "BOTTOMRIGHT")
            texture:SetHeight(1)
        end
    end
    CreateSearchBorder("TOPLEFT", searchResultsWidth)
    CreateSearchBorder("BOTTOMLEFT", searchResultsWidth)
    CreateSearchBorder("TOPLEFT", 1)
    CreateSearchBorder("TOPRIGHT", 1)

    local searchMessage = searchResults:CreateFontString(nil, "OVERLAY",
        "GameFontDisableSmall")
    searchMessage:SetPoint("CENTER")
    searchMessage:Hide()

    local searchFooter = searchResults:CreateFontString(nil, "OVERLAY",
        "GameFontDisableSmall")
    searchFooter:SetPoint("BOTTOM", 0, 6)
    local footerFont, footerSize, footerFlags = searchFooter:GetFont()
    searchFooter:Hide()

    local searchRows = {}
    local function OpenSearchResult(entry)
        if not entry then return end
        if entry.kind == "achievement" and
            not IsAchievementValid(entry.id)
            and not (Addon.AchievementCatalog
                and Addon.AchievementCatalog.GetRecord(entry.id))
        then return end
        searchResults:Hide()
        searchBox:ClearFocus()
        searchBox:SetText("")
        if entry.kind == "achievement" then
            Navigation.OpenCard(entry.id)
        else
            Addon.MapSearch.Activate(entry)
        end
    end
    local function SetSearchSelection(index)
        local shown = frame.searchShownCount or 0
        if shown == 0 then
            frame.searchSelectedIndex = nil
            return
        end
        index = (index - 1) % shown + 1
        frame.searchSelectedIndex = index
        for rowIndex, row in ipairs(searchRows) do
            local selected = rowIndex == index and row:IsShown()
            row.Selected:SetShown(selected)
            if row.node then
                SetAchievementTextColor(row.Name, row.node.completed,
                    selected, 0.82)
            end
        end
    end
    for index = 1, MAX_ACHIEVEMENT_SEARCH_RESULTS do
        local row = CreateFrame("Button", nil, searchResults)
        row:SetPoint("TOPLEFT", 2, -2 - (index - 1) * 28)
        row:SetPoint("TOPRIGHT", -2, -2 - (index - 1) * 28)
        row:SetHeight(28)
        local rowBackground = row:CreateTexture(nil, "BACKGROUND")
        rowBackground:SetAllPoints()
        if not SetTextureAtlas(rowBackground, "_search-rowbg") then
            rowBackground:SetColorTexture(0.08, 0.08, 0.08, 0.96)
        end
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetAllPoints()
        if not SetTextureAtlas(selected, "search-highlight") then
            selected:SetColorTexture(0.8, 0.58, 0.12, 0.28)
        end
        selected:Hide()
        row.Selected = selected
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        if not SetTextureAtlas(highlight, "search-highlight") then
            highlight:SetColorTexture(0.85, 0.65, 0.2, 0.25)
        end
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", 5, 0)
        icon:SetSize(20, 20)
        icon:SetTexCoord(0, 1, 0, 1)
        row.Icon = icon
        local iconBorder = row:CreateTexture(nil, "OVERLAY")
        iconBorder:SetPoint("CENTER", icon, "CENTER", -0.33, 0.67)
        iconBorder:SetSize(27, 27)
        iconBorder:SetTexture(
            "Interface\\AchievementFrame\\UI-Achievement-IconFrame")
        iconBorder:SetTexCoord(0, 0.5625, 0, 0.5625)
        row.IconBorder = iconBorder
        local mapIconBorder = row:CreateTexture(nil, "OVERLAY")
        mapIconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
        mapIconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
        mapIconBorder:SetTexture("Interface\\SPELLBOOK\\RotationIconFrame")
        mapIconBorder:Hide()
        row.MapIconBorder = mapIconBorder
        local name = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetPoint("RIGHT", -42, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row.Name = name
        local points = row:CreateFontString(nil, "OVERLAY",
            "GameFontNormalSmall")
        points:SetPoint("RIGHT", -8, 0)
        row.Points = points
        row:SetScript("OnEnter", function(self)
            SetSearchSelection(self.resultIndex)
            if self.node then ShowAchievementTooltip(self) end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, mouseButton)
            if self.entry and self.entry.kind ~= "achievement" then
                OpenSearchResult(self.entry)
            elseif mouseButton == "RightButton" then
                OpenAchievementContextMenu(self, self.achievementID)
            elseif IsShiftKeyDown() then
                InsertAchievementLink(self.achievementID)
            else
                OpenSearchResult(self.entry)
            end
        end)
        row:Hide()
        searchRows[index] = row
    end

    local function ShowSearchMessage(text)
        for _, row in ipairs(searchRows) do
            row:Hide()
            row.node = nil
            row.entry = nil
        end
        frame.searchShownCount = 0
        frame.searchSelectedIndex = nil
        searchFooter:Hide()
        searchMessage:SetText(text)
        searchMessage:Show()
        searchResults:SetHeight(32)
        searchResults:Show()
    end

    local function RenderSearchResults()
        local entries = frame.searchEntries or {}
        local total = #entries
        if total == 0 then
            ShowSearchMessage(frame.searchMapBuilding
                and L.ACHIEVEMENT_SEARCHING
                or L.ACHIEVEMENT_SEARCH_NO_RESULTS)
            return
        end
        local maximumOffset = math.max(0,
            total - MAX_ACHIEVEMENT_SEARCH_RESULTS)
        frame.searchResultOffset = math.max(0, math.min(
            frame.searchResultOffset or 0, maximumOffset))
        local first = frame.searchResultOffset + 1
        local last = math.min(total,
            frame.searchResultOffset + MAX_ACHIEVEMENT_SEARCH_RESULTS)
        local shown = 0
        searchMessage:Hide()
        for resultIndex = first, last do
            local entry = entries[resultIndex]
            local data = entry.kind == "achievement"
                and (Addon.AchievementCatalog
                        and Addon.AchievementCatalog.GetData(entry.id)
                    or GetAchievementData(entry.id))
            if data or entry.kind ~= "achievement" then
                shown = shown + 1
                local row = searchRows[shown]
                row.resultIndex = shown
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
                row.IconBorder:SetDesaturated(data and not data.completed or false)
                row.IconBorder:SetShown(entry.kind == "achievement")
                row.MapIconBorder:SetShown(entry.kind == "map"
                    or entry.kind == "coordinate")
                row.Name:SetText(data and data.name or entry.kind == "map"
                    and string.format(L.ACHIEVEMENT_SEARCH_MAP, entry.name)
                    or string.format(L.ACHIEVEMENT_SEARCH_COORDINATE,
                        entry.x, entry.y))
                if data then
                    SetAchievementTextColor(row.Name, data.completed,
                        false, 0.82)
                else
                    row.Name:SetTextColor(1, 0.82, 0)
                end
                row.Points:SetText(data and tostring(data.points or 0) or "")
                row:Show()
            end
        end
        for index = shown + 1, #searchRows do
            searchRows[index]:Hide()
            searchRows[index].node = nil
            searchRows[index].entry = nil
        end
        frame.searchShownCount = shown
        if total > MAX_ACHIEVEMENT_SEARCH_RESULTS then
            searchFooter:SetText(string.format(L.ACHIEVEMENT_SEARCH_RESULTS,
                first, last, total))
            if footerFont and footerSize then
                searchFooter:SetFont(footerFont, footerSize, footerFlags)
                local textWidth = searchFooter.GetUnboundedStringWidth
                    and searchFooter:GetUnboundedStringWidth()
                    or searchFooter:GetStringWidth()
                local availableWidth = math.max(1,
                    searchResults:GetWidth() - 12)
                if textWidth > availableWidth then
                    searchFooter:SetFont(footerFont,
                        footerSize * availableWidth / textWidth,
                        footerFlags)
                end
            end
            searchFooter:Show()
        else
            searchFooter:Hide()
        end
        local footerHeight = searchFooter:IsShown() and 22 or 4
        searchResults:SetHeight(shown * 28 + footerHeight)
        searchResults:Show()
        SetSearchSelection(1)
    end

    local function RefreshSearchResults(includeAchievements)
        local query = searchBox:GetText() or ""
        local minimumLength = MIN_CHARACTER_SEARCH or 3
        if #query < minimumLength then
            searchResults:Hide()
            return
        end
        local entries, mapBuilding = Addon.MapSearch.Find(query, 3)
        frame.searchMapBuilding = mapBuilding
        local seen = {}
        local function AddResult(achievementID)
            if seen[achievementID] or not IsAchievementValid(achievementID)
                and not (Addon.AchievementCatalog
                    and Addon.AchievementCatalog.GetRecord(achievementID))
            then
                return
            end
            if Addon.AchievementCatalog
                and not Addon.AchievementCatalog.IsVisible(achievementID)
            then
                return
            end
            local isStatistic = not Addon.AchievementCatalog
                and select(15, GetAchievementInfo(achievementID))
            if isStatistic then
                return
            end
            seen[achievementID] = true
            entries[#entries + 1] = { kind = "achievement",
                id = achievementID }
        end
        if includeAchievements then
            if Addon.AchievementCatalog then
                for _, id in ipairs(Addon.AchievementCatalog.Search(query,
                    function()
                        if frame:IsShown()
                            and searchBox:GetText() == query
                        then
                            RefreshSearchResults(true)
                        end
                    end)) do
                    AddResult(id)
                end
            else
                for index = 1, GetNumFilteredAchievements() or 0 do
                    AddResult(GetFilteredAchievementID(index))
                end
            end
        end
        frame.searchMapBuilding = mapBuilding or includeAchievements
            and Addon.AchievementCatalog
            and not Addon.AchievementCatalog.IsSearchReady()
        frame.searchEntries = entries
        frame.searchResultOffset = 0
        RenderSearchResults()
    end

    searchBox:HookScript("OnTextChanged", function(self)
        frame.searchText = self:GetText() or ""
        if UpdateTreeSearch then
            UpdateTreeSearch(frame)
        end
        local minimumLength = MIN_CHARACTER_SEARCH or 3
        if #frame.searchText < minimumLength then
            ReleaseAchievementSearch(frame)
            searchResults:Hide()
            return
        end
        frame.searchResultOffset = 0
        if Addon.MapSearch.ParseCoordinates(frame.searchText) then
            ReleaseAchievementSearch(frame)
            RefreshSearchResults(false)
            return
        end
        local finished = SetOwnedAchievementSearch(frame, frame.searchText)
        if finished then
            ScheduleAchievementCatalogSearch(frame, function()
                RefreshSearchResults(true)
            end)
        else
            RefreshSearchResults(false)
        end
    end)
    searchBox:SetScript("OnEnterPressed", function()
        local index = frame.searchSelectedIndex or 1
        local row = searchRows[index]
        if row and row:IsShown() then
            OpenSearchResult(row.entry)
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        ReleaseAchievementSearch(frame)
        searchResults:Hide()
        self:ClearFocus()
    end)
    searchBox:SetScript("OnKeyDown", function(self, key)
        local handled = searchResults:IsShown()
            and (key == "UP" or key == "DOWN")
        self:SetPropagateKeyboardInput(not handled)
        if handled then
            local delta = key == "UP" and -1 or 1
            SetSearchSelection((frame.searchSelectedIndex or 1) + delta)
        end
    end)
    searchBox:HookScript("OnEditFocusGained", function()
        if #(searchBox:GetText() or "") >= (MIN_CHARACTER_SEARCH or 3)
            and frame.searchEntries
        then
            RenderSearchResults()
        end
    end)
    searchBox:HookScript("OnEditFocusLost", function()
        if C_Timer then
            C_Timer.After(0, function()
                if not searchResults:IsMouseOver() then
                    ReleaseAchievementSearch(frame)
                    searchResults:Hide()
                end
            end)
        end
    end)
    searchResults:SetScript("OnMouseWheel", function(_, delta)
        local entries = frame.searchEntries or {}
        if #entries <= MAX_ACHIEVEMENT_SEARCH_RESULTS then
            return
        end
        local page = MAX_ACHIEVEMENT_SEARCH_RESULTS
        local maximumOffset = math.max(0, #entries - page)
        frame.searchResultOffset = math.max(0, math.min(maximumOffset,
            (frame.searchResultOffset or 0) - delta * page))
        RenderSearchResults()
    end)
    for _, row in ipairs(searchRows) do
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            searchResults:GetScript("OnMouseWheel")(searchResults, delta)
        end)
    end
    frame:RegisterEvent("ACHIEVEMENT_SEARCH_UPDATED")
    frame:SetScript("OnEvent", function(self, event)
        if event == "ACHIEVEMENT_SEARCH_UPDATED" and self:IsShown()
            and not Addon.AchievementCatalog
            and achievementSearchOwner == self
        then
            RefreshSearchResults(true)
        end
    end)
    Addon.MapSearch.Subscribe(function()
        if frame.SearchBox and frame.SearchBox:HasFocus()
            and #(frame.SearchBox:GetText() or "") >=
                (MIN_CHARACTER_SEARCH or 3) then
            RefreshSearchResults(achievementSearchOwner == frame)
        end
    end)
    frame.SearchBox = searchBox
    frame.SearchResults = searchResults

    local breadcrumb = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    breadcrumb:SetPoint("LEFT", frame, "TOPLEFT", 82, -113)
    breadcrumb:SetJustifyH("LEFT")
    breadcrumb:SetWordWrap(false)
    frame.Breadcrumb = breadcrumb

    treeScaleControls:ClearAllPoints()
    treeScaleControls:SetPoint("RIGHT", frame, "TOPRIGHT", -24, -113)
    breadcrumb:SetPoint("RIGHT", treeScaleControls, "LEFT", -8, 0)
    incompleteOnlyLabel:ClearAllPoints()
    incompleteOnlyLabel:SetPoint("RIGHT", treeScaleControls, "LEFT", -8, 0)
    incompleteOnly:ClearAllPoints()
    incompleteOnly:SetPoint("RIGHT", incompleteOnlyLabel, "LEFT", -2, 0)

    local cardScaleControls, cardScaleMinus, cardScaleValue, cardScalePlus =
        CreateScaleControls(settingsPanel, L.ACHIEVEMENT_CARD_SCALE)
    cardScaleControls:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 10, -7)
    cardScaleMinus:SetScript("OnClick", function()
        Addon:SetSetting("achievementCardScale",
            GetAchievementCardScale() - ACHIEVEMENT_CARD_SCALE_STEP)
    end)
    cardScalePlus:SetScript("OnClick", function()
        Addon:SetSetting("achievementCardScale",
            GetAchievementCardScale() + ACHIEVEMENT_CARD_SCALE_STEP)
    end)
    frame.CardScaleControls = cardScaleControls
    frame.CardScaleMinus = cardScaleMinus
    frame.CardScaleValue = cardScaleValue
    frame.CardScalePlus = cardScalePlus
    local initialCardScale = GetAchievementCardScale()
    cardScaleValue:SetText(string.format("%d%%",
        math.floor(initialCardScale * 100 + 0.5)))
    cardScaleMinus:SetEnabled(initialCardScale
        > MIN_ACHIEVEMENT_CARD_SCALE)
    cardScalePlus:SetEnabled(initialCardScale
        < MAX_ACHIEVEMENT_CARD_SCALE)

    local popupScaleControls, popupScaleMinus, popupScaleValue,
        popupScalePlus = CreateScaleControls(settingsPanel,
            L.ACHIEVEMENT_POPUP_SCALE)
    popupScaleControls:SetPoint("LEFT", cardScaleControls, "RIGHT", 10, 0)
    popupScaleMinus:SetScript("OnClick", function()
        Addon:SetSetting("achievementPopupScale",
            GetAchievementPopupScale() - ACHIEVEMENT_CARD_SCALE_STEP)
    end)
    popupScalePlus:SetScript("OnClick", function()
        Addon:SetSetting("achievementPopupScale",
            GetAchievementPopupScale() + ACHIEVEMENT_CARD_SCALE_STEP)
    end)
    frame.PopupScaleControls = popupScaleControls
    frame.PopupScaleMinus = popupScaleMinus
    frame.PopupScaleValue = popupScaleValue
    frame.PopupScalePlus = popupScalePlus
    local initialPopupScale = GetAchievementPopupScale()
    popupScaleValue:SetText(string.format("%d%%",
        math.floor(initialPopupScale * 100 + 0.5)))
    popupScaleMinus:SetEnabled(initialPopupScale
        > MIN_ACHIEVEMENT_CARD_SCALE)
    popupScalePlus:SetEnabled(initialPopupScale
        < MAX_ACHIEVEMENT_CARD_SCALE)

    local popupAlphaControls, popupAlphaMinus, popupAlphaValue,
        popupAlphaPlus = CreateScaleControls(settingsPanel,
            L.ACHIEVEMENT_POPUP_ALPHA)
    popupAlphaControls:SetPoint("LEFT", popupScaleControls, "RIGHT", 10, 0)
    popupAlphaMinus:SetScript("OnClick", function()
        Addon:SetSetting("achievementPopupAlpha",
            GetAchievementPopupAlpha() - ACHIEVEMENT_POPUP_ALPHA_STEP)
    end)
    popupAlphaPlus:SetScript("OnClick", function()
        Addon:SetSetting("achievementPopupAlpha",
            GetAchievementPopupAlpha() + ACHIEVEMENT_POPUP_ALPHA_STEP)
    end)
    frame.PopupAlphaControls = popupAlphaControls
    frame.PopupAlphaMinus = popupAlphaMinus
    frame.PopupAlphaValue = popupAlphaValue
    frame.PopupAlphaPlus = popupAlphaPlus
    local initialPopupAlpha = GetAchievementPopupAlpha()
    popupAlphaValue:SetText(string.format("%d%%",
        math.floor(initialPopupAlpha * 100 + 0.5)))
    popupAlphaMinus:SetEnabled(initialPopupAlpha
        > MIN_ACHIEVEMENT_POPUP_ALPHA)
    popupAlphaPlus:SetEnabled(initialPopupAlpha
        < MAX_ACHIEVEMENT_POPUP_ALPHA)


    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetPoint("TOPRIGHT", 1, -1)
    closeButton:SetSize(20, 20)
    closeButton:SetFrameLevel(borderFrame:GetFrameLevel() + 1)
    local closeNormal = closeButton:CreateTexture(nil, "ARTWORK")
    if not SetTextureAtlas(closeNormal, "RedButton-Exit") then
        closeNormal:SetColorTexture(0.55, 0.08, 0.04, 1)
    end
    closeNormal:SetAllPoints()
    closeButton:SetNormalTexture(closeNormal)
    local closePushed = closeButton:CreateTexture(nil, "ARTWORK")
    if not SetTextureAtlas(closePushed, "RedButton-exit-pressed") then
        closePushed:SetColorTexture(0.35, 0.035, 0.02, 1)
    end
    closePushed:SetAllPoints()
    closeButton:SetPushedTexture(closePushed)
    local closeHighlight = closeButton:CreateTexture(nil, "HIGHLIGHT")
    if not SetTextureAtlas(closeHighlight, "RedButton-Highlight") then
        closeHighlight:SetColorTexture(1, 0.35, 0.15, 0.35)
    end
    closeHighlight:SetAllPoints()
    closeHighlight:SetBlendMode("ADD")
    closeButton:SetHighlightTexture(closeHighlight)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local attButton = CreateFrame("Button", nil, frame,
        "UIPanelButtonTemplate")
    attButton:SetPoint("RIGHT", frame, "TOPRIGHT", -24, -113)
    attButton:SetSize(116, 22)
    attButton:SetText(L.ACHIEVEMENT_ATT_OPEN)
    attButton:SetFrameLevel(borderFrame:GetFrameLevel() + 1)
    attButton:SetScript("OnClick", function(self)
        OpenAchievementATTGuide(self.achievementID
            or frame.sourceAchievementID)
    end)
    attButton:Hide()
    frame.ATTButton = attButton

    local scrollFrame = CreateFrame("ScrollFrame",
        "EasyAchievementTreeScrollFrame", frame)
    scrollFrame:SetPoint("TOPLEFT", 24, -135)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 26)
    scrollFrame:EnableMouse(true)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if ZoomAchievementTreeWithWheel then
            ZoomAchievementTreeWithWheel(frame, delta)
        end
    end)
    scrollFrame:RegisterForDrag("LeftButton")
    scrollFrame:SetScript("OnDragStart", function(self)
        local cursorX, cursorY = GetCursorPosition()
        local effectiveScale = self:GetEffectiveScale()
        self.EasyAchievementPanStartX = cursorX / effectiveScale
        self.EasyAchievementPanStartY = cursorY / effectiveScale
        self.EasyAchievementPanStartHorizontal = self:GetHorizontalScroll()
        self.EasyAchievementPanStartVertical = self:GetVerticalScroll()
        self:SetScript("OnUpdate", function(panFrame)
            local currentX, currentY = GetCursorPosition()
            local currentScale = panFrame:GetEffectiveScale()
            currentX = currentX / currentScale
            currentY = currentY / currentScale
            local horizontalMaximum = math.max(0,
                frame.Content:GetWidth() - panFrame:GetWidth())
            local verticalMaximum = math.max(0,
                frame.Content:GetHeight() - panFrame:GetHeight())
            local horizontal = math.max(0, math.min(horizontalMaximum,
                panFrame.EasyAchievementPanStartHorizontal
                    - (currentX - panFrame.EasyAchievementPanStartX)))
            local vertical = math.max(0, math.min(verticalMaximum,
                panFrame.EasyAchievementPanStartVertical
                    + (currentY - panFrame.EasyAchievementPanStartY)))
            frame.HorizontalScroll:SetValue(horizontal)
            panFrame:SetVerticalScroll(vertical)
            if UpdateAchievementNavigatorViewport then
                UpdateAchievementNavigatorViewport(frame)
            end
        end)
    end)
    scrollFrame:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        SaveAchievementTreeState(frame)
    end)
    frame.ScrollFrame = scrollFrame
    CreateAchievementRewardCategoryRail(frame)
    searchBox:SetFrameLevel(frame.RewardCategoryRail:GetFrameLevel() + 2)
    searchResults:SetFrameLevel(frame.RewardCategoryRail:GetFrameLevel() + 3)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    frame.Content = content
    frame.nodeButtons = {}
    frame.lines = {}

    local emptyText = content:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightLarge")
    emptyText:SetPoint("CENTER")
    emptyText:SetText(L.ACHIEVEMENT_TREE_NO_INCOMPLETE)
    emptyText:SetTextColor(0.65, 0.65, 0.65)
    emptyText:Hide()
    frame.EmptyText = emptyText

    local horizontalScroll = CreateFrame("Slider",
        "EasyAchievementTreeHorizontalScroll", frame,
        "OptionsSliderTemplate")
    horizontalScroll:SetOrientation("HORIZONTAL")
    horizontalScroll:SetPoint("BOTTOMLEFT", 46, 6)
    horizontalScroll:SetPoint("BOTTOMRIGHT", -52, 6)
    horizontalScroll:SetHeight(16)
    horizontalScroll:SetMinMaxValues(0, 0)
    horizontalScroll:SetValueStep(1)
    horizontalScroll:SetObeyStepOnDrag(false)
    local sliderLow = horizontalScroll.Low
        or _G[horizontalScroll:GetName() .. "Low"]
    local sliderHigh = horizontalScroll.High
        or _G[horizontalScroll:GetName() .. "High"]
    local sliderText = horizontalScroll.Text
        or _G[horizontalScroll:GetName() .. "Text"]
    if sliderLow then sliderLow:SetText("") end
    if sliderHigh then sliderHigh:SetText("") end
    if sliderText then sliderText:SetText("") end
    horizontalScroll:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetHorizontalScroll(value)
        if UpdateAchievementNavigatorViewport then
            UpdateAchievementNavigatorViewport(frame)
        end
    end)
    horizontalScroll:HookScript("OnMouseUp", function()
        SaveAchievementTreeState(frame)
    end)
    horizontalScroll:Hide()
    frame.HorizontalScroll = horizontalScroll

    local navigator = CreateFrame("Frame", nil, frame)
    navigator:SetSize(180, 110)
    navigator:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -8, 8)
    navigator:SetFrameLevel(frame:GetFrameLevel() + 40)
    navigator:EnableMouse(true)
    navigator:Hide()
    local navigatorBackground = navigator:CreateTexture(nil, "BACKGROUND")
    navigatorBackground:SetAllPoints()
    navigatorBackground:SetColorTexture(0.02, 0.02, 0.02, 0.42)
    navigator.Background = navigatorBackground
    navigator.NodeTextures = {}
    navigator.LineTextures = {}
    navigator.ViewportLines = {}
    for index = 1, 4 do
        local line = navigator:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 0.78, 0.12, 0.9)
        navigator.ViewportLines[index] = line
    end
    local function NavigateFromCursor()
        if not navigator.mapScale then
            return
        end
        local cursorX, cursorY = GetCursorPosition()
        local effectiveScale = navigator:GetEffectiveScale()
        local localX = cursorX / effectiveScale - navigator:GetLeft()
        local localY = cursorY / effectiveScale - navigator:GetBottom()
        local contentX = (localX - navigator.mapLeft)
            / navigator.mapScale
        local contentY = navigator.contentHeight
            - (localY - navigator.mapBottom) / navigator.mapScale
        local horizontalMaximum = math.max(0,
            frame.Content:GetWidth() - scrollFrame:GetWidth())
        local verticalMaximum = math.max(0,
            frame.Content:GetHeight() - scrollFrame:GetHeight())
        frame.HorizontalScroll:SetValue(math.max(0,
            math.min(horizontalMaximum,
                contentX - scrollFrame:GetWidth() / 2)))
        scrollFrame:SetVerticalScroll(math.max(0,
            math.min(verticalMaximum,
                contentY - scrollFrame:GetHeight() / 2)))
        UpdateAchievementNavigatorViewport(frame)
    end
    navigator:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        NavigateFromCursor()
        self:SetScript("OnUpdate", NavigateFromCursor)
    end)
    navigator:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        SaveAchievementTreeState(frame)
    end)
    frame.Navigator = navigator

    local resizeButton = CreateFrame("Button", nil, frame,
        "PanelResizeButtonTemplate")
    resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeButton:SetSize(20, 20)
    resizeButton:SetFrameLevel(borderFrame:GetFrameLevel() + 1)
    resizeButton:SetHitRectInsets(-8, -8, -8, -8)
    resizeButton:RegisterForDrag("LeftButton")
    local function LayoutCurrentTree()
        if frame.settingsPageShown then
            frame.pendingResizeLayout = nil
            return
        end
        if not frame.updatingLayout and frame.layoutNodes
            and not (frame.currentPage
                and frame.currentPage.kind == "official-category")
            and LayoutAchievementTree
        then
            frame.pendingResizeLayout = nil
            Content.Relayout(frame)
        end
    end
    local function FlushResizeLayout()
        frame.resizeLayoutSerial = (frame.resizeLayoutSerial or 0) + 1
        frame.resizeLayoutScheduled = nil
        LayoutCurrentTree()
    end
    local function ScheduleResizeLayout()
        frame.pendingResizeLayout = true
        if frame.resizeLayoutScheduled then
            return
        end
        if not C_Timer or not C_Timer.After then
            LayoutCurrentTree()
            return
        end
        frame.resizeLayoutScheduled = true
        local serial = (frame.resizeLayoutSerial or 0) + 1
        frame.resizeLayoutSerial = serial
        C_Timer.After(RESIZE_LAYOUT_INTERVAL, function()
            if frame.resizeLayoutSerial ~= serial then
                return
            end
            frame.resizeLayoutScheduled = nil
            if frame.pendingResizeLayout then
                LayoutCurrentTree()
            end
        end)
    end
    local function StartResize()
        frame.deferTreeStateSave = true
        frame:StartSizing("BOTTOMRIGHT")
    end
    local function StopResize()
        frame:StopMovingOrSizing()
        Addon:SetSetting("achievementTreeWidth", frame:GetWidth())
        Addon:SetSetting("achievementTreeHeight", frame:GetHeight())
        FlushResizeLayout()
        frame.deferTreeStateSave = nil
        SaveAchievementTreeState(frame)
    end
    resizeButton:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            StartResize()
        end
    end)
    resizeButton:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            StopResize()
        end
    end)
    resizeButton:SetScript("OnDragStart", StartResize)
    resizeButton:SetScript("OnDragStop", StopResize)
    frame.ResizeButton = resizeButton

    frame:SetScript("OnSizeChanged", function(self)
        LayoutAchievementHeader(self)
        if not self.settingsPageShown and not self.updatingLayout
            and self.layoutNodes then
            ScheduleResizeLayout()
        end
    end)
    frame:SetScript("OnShow", function()
        PlayAchievementSound(SOUNDKIT and SOUNDKIT.ACHIEVEMENT_MENU_OPEN)
    end)
    frame:SetScript("OnHide", function()
        frame.navigationRevision = (frame.navigationRevision or 0) + 1
        AchievementRewards.CancelRequest()
        ReleaseAchievementSearch(frame)
        PlayAchievementSound(SOUNDKIT and SOUNDKIT.ACHIEVEMENT_MENU_CLOSE)
        SaveAchievementTreeState(frame)
        if achievementRewardFrame then
            achievementRewardFrame:Hide()
        end
        if ClearHoveredLines then
            ClearHoveredLines(frame)
        end
        frame.SettingsPanel:Hide()
        GameTooltip:Hide()
    end)
    table.insert(UISpecialFrames, frame:GetName())

    achievementTreeFrame = frame
    RefreshAchievementFavoritesBar(frame)
    return frame
end

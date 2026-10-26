local _, Addon = ...
local UI = assert(Addon.AchievementUI)
if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end

local Copy = Addon.AchievementData.CopyNavigationState
local LEFT_WIDTH = 214
local LEFT_ROW_HEIGHT = 26
local RIGHT_ROW_HEIGHT = 40
local RIGHT_CELL_MIN_WIDTH = 220
local OVERVIEW_CATEGORY_ID = 0
local ShowCategoryContent

local function ReadCategories()
    local categories, roots = {}, {}
    local categoryIDs = GetCategoryList and GetCategoryList() or {}
    for _, id in ipairs(categoryIDs) do
        local name, parent = GetCategoryInfo(id)
        if name then
            categories[id] = { id = id, name = name, parent = parent,
                children = {} }
        end
    end
    for _, id in ipairs(categoryIDs) do
        local category = categories[id]
        if category then
            local parent = categories[category.parent]
            local list = parent and parent.children or roots
            list[#list + 1] = category
        end
    end
    return categories, roots
end

local function GetCategoryAchievements(browser, categoryID)
    if browser.achievementCache[categoryID] then
        return browser.achievementCache[categoryID]
    end
    local ids, seen = {}, {}
    local count = GetCategoryNumAchievements(categoryID) or 0
    for index = 1, count do
        local id = select(1, GetAchievementInfo(categoryID, index))
        if id and not seen[id]
            and (not GetAchievementCategory
                or GetAchievementCategory(id) == categoryID)
            and GetAchievementData(id)
        then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    browser.achievementCache[categoryID] = ids
    return ids
end

local function GetVisibleCategoryAchievements(browser, categoryID)
    local ids = GetCategoryAchievements(browser, categoryID)
    local state = browser.frame.officialBrowserState
    if not state or not state.incompleteOnly then return ids end
    local visible = browser.incompleteCache[categoryID]
    if not visible then
        visible = {}
        for _, id in ipairs(ids) do
            local data = GetAchievementData(id)
            if data and not data.completed then
                visible[#visible + 1] = id
            end
        end
        browser.incompleteCache[categoryID] = visible
    end
    return visible
end

local function GetCategoryTotals(browser, category)
    local cached = browser.categoryTotals[category.id]
    if cached then return cached[1], cached[2] end
    local total, completed = GetCategoryNumAchievements(category.id, true)
    total, completed = total or 0, completed or 0
    for _, child in ipairs(category.children) do
        local childTotal, childCompleted = GetCategoryTotals(browser, child)
        total = total + childTotal
        completed = completed + childCompleted
    end
    browser.categoryTotals[category.id] = { total, completed }
    return total, completed
end

local function ScrollBy(scroll, delta, rowHeight)
    scroll:SetVerticalScroll(math.max(0, math.min(
        scroll:GetVerticalScrollRange(),
        scroll:GetVerticalScroll() - delta * rowHeight * 3)))
end

local function MakeScroll(parent, topLeft, bottomRight, rowHeight)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", topLeft[1], topLeft[2])
    scroll:SetPoint("BOTTOMRIGHT", bottomRight[1], bottomRight[2])
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        ScrollBy(self, delta, rowHeight)
        if self.RefreshRows then self:RefreshRows() end
    end)
    scroll.Content = content
    return scroll
end

local function BuildLeftEntries(browser, state)
    local entries = { { overview = true, name = L.ACHIEVEMENT_OVERVIEW,
        depth = 0 } }
    local function Add(categories, depth)
        for _, category in ipairs(categories) do
            entries[#entries + 1] = { categoryID = category.id,
                depth = depth, name = category.name,
                hasChildren = #category.children > 0 }
            if state.expanded[category.id] then
                Add(category.children, depth + 1)
                if state.categoryID == category.id then
                    for _, id in ipairs(GetVisibleCategoryAchievements(browser,
                        category.id)) do
                        entries[#entries + 1] = { achievementID = id,
                            depth = depth + 1 }
                    end
                end
            end
        end
    end
    Add(browser.roots, 0)
    browser.leftEntries = entries
    browser.leftScroll.Content:SetSize(LEFT_WIDTH - 4,
        math.max(1, #entries * LEFT_ROW_HEIGHT))
end

local function GetOverviewTotals(browser)
    local total, completed = 0, 0
    for _, category in ipairs(browser.roots) do
        local categoryTotal, categoryCompleted = GetCategoryTotals(browser,
            category)
        total = total + categoryTotal
        completed = completed + categoryCompleted
    end
    return total, completed
end

local function DrawLeftRows(browser)
    local state = browser.frame.officialBrowserState
    if not state then return end
    local scroll = browser.leftScroll
    local first = math.floor(scroll:GetVerticalScroll() / LEFT_ROW_HEIGHT) + 1
    for slot, row in ipairs(browser.leftRows) do
        local index = first + slot - 1
        local entry = browser.leftEntries[index]
        row:SetShown(entry ~= nil)
        if entry then
            row.entry = entry
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scroll.Content, "TOPLEFT", 0,
                -(index - 1) * LEFT_ROW_HEIGHT)
            row:SetWidth(LEFT_WIDTH - 4)
            local isOverview = entry.overview == true
            local isCategory = entry.categoryID ~= nil or isOverview
            row.CategoryBackground:SetShown(isCategory)
            local selected = isOverview
                and state.categoryID == OVERVIEW_CATEGORY_ID
                or isCategory and not isOverview
                and state.categoryID == entry.categoryID
                and not state.selectedAchievementID
                or not isCategory
                    and state.selectedAchievementID == entry.achievementID
            row.Selected:SetShown(isCategory and selected)
            row.OptionsSelected:SetShown(not isCategory and selected)
            row.CategoryHover:SetShown(isCategory)
            row.OptionsHover:SetShown(not isCategory and not selected)
            local data = not isCategory and GetAchievementData(
                entry.achievementID)
            if isCategory and not isOverview then
                local atlas = state.expanded[entry.categoryID]
                    and "common-button-list-minus"
                    or "common-button-list-plus"
                SetTextureAtlas(row.CollapseIcon, atlas, true)
                SetTextureAtlas(row.CollapseHover, atlas, true)
            end
            row.CollapseIcon:SetShown(isCategory and not isOverview)
            row.CollapseHover:SetShown(isCategory and not isOverview)
            local hasReward = data and Addon.AchievementRewards.Has(
                entry.achievementID, data) or false
            row.RewardMarker:SetShown(hasReward)
            local hasCount = isCategory
            row.Count:SetShown(hasCount or false)
            if hasCount then
                local total, completed
                if isOverview then
                    total, completed = GetOverviewTotals(browser)
                else
                    total, completed = GetCategoryTotals(browser,
                        browser.categories[entry.categoryID])
                end
                row.Count:SetText(string.format(
                    "%d(|cff33cc33%d|r/|cff999999%d|r)", total,
                    completed, math.max(0, total - completed)))
            end
            row.Label:ClearAllPoints()
            local labelLeft = 5 + entry.depth * 13
                + (isCategory and not isOverview and 14 or 0)
            row.Label:SetPoint("LEFT", row, "LEFT",
                labelLeft, 0)
            row.Label:SetText(isCategory and entry.name
                or data and data.name or tostring(entry.achievementID))
            if isCategory then
                if not isOverview and not state.expanded[entry.categoryID] then
                    local textHeight = row.Label:GetStringHeight()
                    row.CollapseIcon:SetSize(textHeight, textHeight)
                end
                row.Label:SetPoint("RIGHT", hasCount and row.Count or row,
                    hasCount and "LEFT" or "RIGHT", -4, 0)
            else
                row.Label:SetPoint("RIGHT", row, "RIGHT",
                    hasReward and -18 or -4, 0)
                row.RewardMarker:ClearAllPoints()
                row.RewardMarker:SetPoint("CENTER", row.Label, "TOPLEFT",
                    math.min(row.Label:GetStringWidth(),
                        math.max(1, LEFT_WIDTH - 4 - labelLeft - 18)) + 3,
                    0)
            end
            if data and data.completed then
                row.Label:SetTextColor(0.2, 1, 0.2)
            elseif not isCategory then
                local color = selected and 0.7 or 0.55
                row.Label:SetTextColor(color, color, color)
            else
                row.Label:SetTextColor(selected and 1 or 0.95,
                    selected and 0.82 or 0.78,
                    selected and 0.36 or 0.45)
            end
            row.CollapseIcon:ClearAllPoints()
            row.CollapseIcon:SetPoint("CENTER", row.Label, "LEFT", -8, 0)
        end
    end
end

local function RefreshLeft(browser)
    local state = browser.frame.officialBrowserState
    if not state then return end
    BuildLeftEntries(browser, state)
    DrawLeftRows(browser)
end

local function RevealLeftSelection(browser)
    local state = browser.frame.officialBrowserState
    if not state then return end
    local selectedID = state.selectedAchievementID
    local scroll = browser.leftScroll
    for index, entry in ipairs(browser.leftEntries) do
        if selectedID and entry.achievementID == selectedID
            or not selectedID and (entry.categoryID == state.categoryID
                or entry.overview
                    and state.categoryID == OVERVIEW_CATEGORY_ID)
        then
            local top = (index - 1) * LEFT_ROW_HEIGHT
            local current = scroll:GetVerticalScroll()
            if top < current then
                scroll:SetVerticalScroll(top)
            elseif top + LEFT_ROW_HEIGHT > current + scroll:GetHeight() then
                scroll:SetVerticalScroll(top + LEFT_ROW_HEIGHT
                    - scroll:GetHeight())
            end
            DrawLeftRows(browser)
            return
        end
    end
end

local function CreateRightRow(browser)
    local row = CreateFrame("Button", nil, browser.rightScroll.Content)
    row:SetHeight(RIGHT_ROW_HEIGHT - 2)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetAllPoints()
    selected:SetColorTexture(0.42, 0.29, 0.09, 0.5)
    row.Selected = selected
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("LEFT", 4, 0)
    hover:SetPoint("RIGHT", -4, 0)
    hover:SetHeight(34)
    hover:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hover:SetBlendMode("ADD")
    hover:SetAlpha(0.75)
    local icon = row:CreateTexture(nil, "BORDER")
    icon:SetPoint("LEFT", 10, 0)
    icon:SetSize(28, 28)
    icon:SetTexCoord(0, 1, 0, 1)
    row.Icon = icon
    local border = row:CreateTexture(nil, "ARTWORK")
    border:SetPoint("CENTER", icon, "CENTER", -0.5, 0.5)
    border:SetSize(38, 38)
    border:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    border:SetTexCoord(0, 0.5625, 0, 0.5625)
    row.Border = border
    local name = row:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.Name = name
    local rewardMarker = row:CreateTexture(nil, "OVERLAY", nil, 7)
    rewardMarker:SetPoint("CENTER", icon, "TOPRIGHT")
    rewardMarker:SetSize(12, 12)
    SetTextureAtlas(rewardMarker, "SoulBinds_Collection_Charge_Pending")
    rewardMarker:Hide()
    row.RewardMarker = rewardMarker
    row:SetScript("OnClick", function(self, mouseButton)
        local achievementID = self.achievementID
        if not achievementID then return end
        if mouseButton == "RightButton" then
            OpenAchievementContextMenu(self, achievementID,
                function()
                    OpenOfficialAchievementCard(achievementID)
                end)
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            InsertAchievementLink(achievementID)
        else
            OpenOfficialAchievementCard(achievementID)
        end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.node then return end
        SetAchievementTextColor(self.Name, self.node.completed, true, 0.8)
        ShowAchievementTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        if self.node then
            SetAchievementTextColor(self.Name, self.node.completed,
                false, 0.8)
        end
        GameTooltip:Hide()
    end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
        ScrollBy(browser.rightScroll, delta, RIGHT_ROW_HEIGHT)
        browser.rightScroll:RefreshRows()
    end)
    browser.rightRows[#browser.rightRows + 1] = row
    return row
end

local function RefreshOverview(browser)
    local scroll = browser.overview
    browser.empty:Hide()
    local content = scroll.Content
    local contentWidth = math.max(1, scroll:GetWidth() - 4)
    local rowCount = math.ceil(#browser.roots / 2)
    local rowHeight = math.min(46, math.max(1,
        math.floor((scroll:GetHeight() - 76) / math.max(1, rowCount))))
    local cellWidth = math.max(1, (contentWidth - 32) / 2)
    content:SetSize(contentWidth, math.max(1,
        76 + rowCount * rowHeight))
    scroll:SetVerticalScroll(0)
    local total, completed = GetOverviewTotals(browser)
    browser.overviewCount:SetText(string.format(
        L.ACHIEVEMENT_OVERVIEW_TOTALS, total, completed,
        math.max(0, total - completed)))
    browser.overviewBar:SetMinMaxValues(0, math.max(1, total))
    browser.overviewBar:SetValue(completed)
    for index, category in ipairs(browser.roots) do
        local row = browser.overviewRows[index]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT",
            8 + ((index - 1) % 2) * (cellWidth + 16),
            -76 - math.floor((index - 1) / 2) * rowHeight)
        row:SetSize(cellWidth, rowHeight)
        row.Bar:SetHeight(math.max(4, math.min(12, rowHeight - 18)))
        local categoryTotal, categoryCompleted = GetCategoryTotals(browser,
            category)
        row.categoryID = category.id
        row.Label:SetText(category.name)
        row.Count:SetText(string.format(
            "%d(|cff33cc33%d|r/|cff999999%d|r)", categoryTotal,
            categoryCompleted, math.max(0,
                categoryTotal - categoryCompleted)))
        row.Bar:SetMinMaxValues(0, math.max(1, categoryTotal))
        row.Bar:SetValue(categoryCompleted)
    end
    browser.frame.Stats:SetText(string.format(
        L.ACHIEVEMENT_EARNED_PROGRESS, completed, total))
    LayoutAchievementHeader(browser.frame)
end

local function RefreshRight(browser)
    local state = browser.frame.officialBrowserState
    if not state then return end
    if state.categoryID == OVERVIEW_CATEGORY_ID then
        RefreshOverview(browser)
        return
    end
    local scroll = browser.rightScroll
    local ids = GetVisibleCategoryAchievements(browser, state.categoryID)
    browser.rightIDs = ids
    browser.frame.Stats:SetText(string.format(
        L.ACHIEVEMENT_REWARD_CATEGORY_STATS, #ids))
    local contentWidth = math.max(1, scroll:GetWidth() - 4)
    local columns = math.max(1, math.floor(contentWidth
        / RIGHT_CELL_MIN_WIDTH))
    local cellWidth = contentWidth / columns
    local rowCount = math.ceil(#ids / columns)
    browser.rightColumns = columns
    scroll.Content:SetSize(contentWidth,
        math.max(1, rowCount * RIGHT_ROW_HEIGHT))
    local firstRow = math.floor(scroll:GetVerticalScroll() / RIGHT_ROW_HEIGHT)
    local visibleRows = math.ceil(scroll:GetHeight() / RIGHT_ROW_HEIGHT) + 1
    local visibleSlots = math.min(#ids, visibleRows * columns)
    for slot = #browser.rightRows + 1, visibleSlots do
        CreateRightRow(browser)
    end
    for slot, row in ipairs(browser.rightRows) do
        local rowIndex = firstRow + math.floor((slot - 1) / columns)
        local column = (slot - 1) % columns
        local index = rowIndex * columns + column + 1
        local id = ids[index]
        row:SetShown(slot <= visibleSlots and id ~= nil)
        if slot <= visibleSlots and id then
            local data = GetAchievementData(id)
            row.achievementID = id
            row.node = data
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scroll.Content, "TOPLEFT",
                column * cellWidth, -rowIndex * RIGHT_ROW_HEIGHT)
            row:SetWidth(cellWidth)
            row.Icon:SetTexture(data and data.icon or 134400)
            row.Icon:SetDesaturated(not data or not data.completed)
            row.Border:SetDesaturated(not data or not data.completed)
            row.Border:SetAlpha(data and data.completed and 1 or 0.72)
            row.Name:SetText(data and data.name or tostring(id))
            SetAchievementTextColor(row.Name, data and data.completed,
                false, 0.8)
            row.Selected:SetShown(state.selectedAchievementID == id)
            row.RewardMarker:SetShown(data
                and Addon.AchievementRewards.Has(id, data) or false)
        else
            row.achievementID = nil
            row.node = nil
        end
    end
    browser.empty:SetShown(#ids == 0)
    browser.empty:SetText(state.incompleteOnly
        and L.ACHIEVEMENT_TREE_NO_INCOMPLETE
        or L.ACHIEVEMENT_ALL_CATEGORIES_EMPTY)
end

local function RevealRightSelection(browser)
    local selectedID = browser.frame.officialBrowserState
        and browser.frame.officialBrowserState.selectedAchievementID
    if not selectedID then return end
    local scroll = browser.rightScroll
    for index, id in ipairs(browser.rightIDs) do
        if id == selectedID then
            local top = math.floor((index - 1)
                / (browser.rightColumns or 1)) * RIGHT_ROW_HEIGHT
            local current = scroll:GetVerticalScroll()
            if top < current then
                scroll:SetVerticalScroll(top)
            elseif top + RIGHT_ROW_HEIGHT > current + scroll:GetHeight() then
                scroll:SetVerticalScroll(top + RIGHT_ROW_HEIGHT
                    - scroll:GetHeight())
            end
            RefreshRight(browser)
            return
        end
    end
end

local function CreateBrowser(frame)
    if frame.OfficialCategoryBrowser then
        return frame.OfficialCategoryBrowser
    end
    local categories, roots = ReadCategories()
    local browser = { frame = frame, categories = categories, roots = roots,
        achievementCache = {}, incompleteCache = {}, categoryTotals = {},
        leftRows = {}, rightRows = {} }
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -135)
    pane:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 26)
    pane:SetWidth(LEFT_WIDTH)
    pane:SetFrameLevel(frame:GetFrameLevel() + 44)
    local background = pane:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.055, 0.045, 0.03, 0.94)
    local divider = pane:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPRIGHT")
    divider:SetPoint("BOTTOMRIGHT")
    divider:SetWidth(2)
    divider:SetColorTexture(0.45, 0.32, 0.1, 0.9)
    browser.leftScroll = MakeScroll(pane, { 2, -4 }, { -2, 4 },
        LEFT_ROW_HEIGHT)
    browser.leftScroll.RefreshRows = function() DrawLeftRows(browser) end
    browser.leftScroll:SetScript("OnVerticalScroll", function()
        DrawLeftRows(browser)
    end)
    for slot = 1, 35 do
        local row = CreateFrame("Button", nil, browser.leftScroll.Content)
        row:SetHeight(LEFT_ROW_HEIGHT)
        local categoryBackground = row:CreateTexture(nil, "BACKGROUND")
        categoryBackground:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        categoryBackground:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 2)
        SetTextureAtlas(categoryBackground, "common-button-list-collapseExpand")
        row.CategoryBackground = categoryBackground
        local selected = row:CreateTexture(nil, "BACKGROUND")
        selected:SetPoint("TOPLEFT", categoryBackground, "TOPLEFT")
        selected:SetPoint("BOTTOMRIGHT", categoryBackground, "BOTTOMRIGHT")
        selected:SetColorTexture(0.42, 0.29, 0.09, 0.65)
        row.Selected = selected
        local categoryHover = row:CreateTexture(nil, "HIGHLIGHT")
        categoryHover:SetPoint("TOPLEFT", categoryBackground, "TOPLEFT")
        categoryHover:SetPoint("BOTTOMRIGHT", categoryBackground,
            "BOTTOMRIGHT")
        SetTextureAtlas(categoryHover, "common-button-list-collapseExpand")
        categoryHover:SetBlendMode("ADD")
        categoryHover:SetAlpha(0.4)
        row.CategoryHover = categoryHover
        local optionsSelected = row:CreateTexture(nil, "BACKGROUND")
        optionsSelected:SetPoint("TOPLEFT", row, "TOPLEFT")
        optionsSelected:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 0)
        SetTextureAtlas(optionsSelected, "Options_List_Active")
        row.OptionsSelected = optionsSelected
        local optionsHover = row:CreateTexture(nil, "HIGHLIGHT")
        optionsHover:SetPoint("TOPLEFT", row, "TOPLEFT")
        optionsHover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 0)
        SetTextureAtlas(optionsHover, "Options_List_Hover")
        row.OptionsHover = optionsHover
        local collapseIcon = row:CreateTexture(nil, "ARTWORK")
        row.CollapseIcon = collapseIcon
        local collapseHover = row:CreateTexture(nil, "HIGHLIGHT")
        collapseHover:SetAllPoints(collapseIcon)
        collapseHover:SetBlendMode("ADD")
        collapseHover:SetAlpha(0.4)
        row.CollapseHover = collapseHover
        local label = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        row.Label = label
        local count = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        count:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        count:SetTextColor(0.8, 0.7, 0.5)
        row.Count = count
        local rewardMarker = row:CreateTexture(nil, "OVERLAY", nil, 7)
        rewardMarker:SetSize(12, 12)
        SetTextureAtlas(rewardMarker, "SoulBinds_Collection_Charge_Pending")
        rewardMarker:Hide()
        row.RewardMarker = rewardMarker
        row:SetScript("OnClick", function(self)
            local entry = self.entry
            if entry.overview then
                ShowOfficialAchievementCategory(OVERVIEW_CATEGORY_ID)
            elseif entry.categoryID then
                ShowOfficialAchievementCategory(entry.categoryID, true)
            else
                OpenOfficialAchievementCard(entry.achievementID)
            end
        end)
        row:SetScript("OnMouseDown", function(self)
            if self.entry and self.entry.categoryID then
                self.CollapseIcon:AdjustPointsOffset(1, -1)
                self.Label:AdjustPointsOffset(1, -1)
            end
        end)
        row:SetScript("OnMouseUp", function(self)
            if self.entry and self.entry.categoryID then
                self.CollapseIcon:AdjustPointsOffset(-1, 1)
                self.Label:AdjustPointsOffset(-1, 1)
            end
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            ScrollBy(browser.leftScroll, delta, LEFT_ROW_HEIGHT)
            DrawLeftRows(browser)
        end)
        browser.leftRows[slot] = row
    end
    browser.pane = pane

    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPLEFT", pane, "TOPRIGHT", 10, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 26)
    right:SetFrameLevel(frame:GetFrameLevel() + 43)
    local rightBackground = right:CreateTexture(nil, "BACKGROUND")
    rightBackground:SetAllPoints()
    rightBackground:SetColorTexture(0.04, 0.035, 0.03, 0.9)
    browser.rightScroll = MakeScroll(right, { 4, -4 }, { -4, 4 },
        RIGHT_ROW_HEIGHT)
    browser.rightScroll.RefreshRows = function() RefreshRight(browser) end
    browser.rightScroll:SetScript("OnVerticalScroll", function()
        RefreshRight(browser)
    end)
    local overview = MakeScroll(right, { 12, -12 }, { -12, 12 }, 46)
    overview:EnableMouseWheel(false)
    local overviewTitle = overview.Content:CreateFontString(nil, "OVERLAY",
        "GameFontNormalLarge")
    overviewTitle:SetPoint("TOPLEFT", overview.Content, "TOPLEFT", 8, -6)
    overviewTitle:SetText(L.ACHIEVEMENT_PROGRESS_OVERVIEW)
    local overviewCount = overview.Content:CreateFontString(nil, "OVERLAY",
        "GameFontHighlight")
    overviewCount:SetPoint("TOPRIGHT", overview.Content, "TOPRIGHT",
        -8, -10)
    browser.overviewCount = overviewCount
    local function CreateBar(parent)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(0.16, 0.72, 0.16)
        bar:SetHeight(12)
        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.11, 0.08, 0.04, 0.85)
        return bar
    end
    local overviewBar = CreateBar(overview.Content)
    overviewBar:SetPoint("TOPLEFT", overview.Content, "TOPLEFT", 8, -38)
    overviewBar:SetPoint("TOPRIGHT", overview.Content, "TOPRIGHT", -8, -38)
    browser.overviewBar = overviewBar
    browser.overviewRows = {}
    for index = 1, #roots do
        local row = CreateFrame("Button", nil, overview.Content)
        row:SetHeight(40)
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        SetTextureAtlas(hover, "Options_List_Hover")
        row.Hover = hover
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT")
        row.Label = label
        local count = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        count:SetPoint("TOPRIGHT")
        row.Count = count
        local bar = CreateBar(row)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
        bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 3)
        row.Bar = bar
        row:SetScript("OnClick", function(self)
            ShowOfficialAchievementCategory(self.categoryID)
        end)
        browser.overviewRows[index] = row
    end
    overview:Hide()
    browser.overview = overview
    browser.empty = right:CreateFontString(nil, "OVERLAY",
        "GameFontDisable")
    browser.empty:SetPoint("CENTER")
    browser.empty:SetText(L.ACHIEVEMENT_ALL_CATEGORIES_EMPTY)
    browser.right = right
    local incompleteOnly = CreateFrame("CheckButton", nil, frame,
        "UICheckButtonTemplate")
    incompleteOnly:SetSize(22, 22)
    incompleteOnly:SetPoint("RIGHT", frame, "TOPRIGHT", -24, -113)
    incompleteOnly:SetFrameLevel(frame:GetFrameLevel() + 44)
    local incompleteLabel = incompleteOnly:CreateFontString(nil,
        "OVERLAY", "GameFontNormalSmall")
    incompleteLabel:SetPoint("RIGHT", incompleteOnly, "LEFT", -2, 0)
    incompleteLabel:SetText(L.ACHIEVEMENT_TREE_INCOMPLETE_ONLY)
    incompleteOnly:SetScript("OnClick", function(self)
        local state = frame.officialBrowserState
        if not state then return end
        state.incompleteOnly = self:GetChecked() == true
        state.rightScroll = 0
        browser.rightScroll:SetVerticalScroll(0)
        ShowCategoryContent(frame)
        RefreshLeft(browser)
    end)
    incompleteOnly:Hide()
    browser.incompleteOnly = incompleteOnly
    right:SetScript("OnSizeChanged", function()
        if frame.officialBrowserState
            and frame.currentPage.kind == "official-category"
        then
            RefreshRight(browser)
        end
    end)
    pane:Hide()
    right:Hide()
    frame.OfficialCategoryBrowser = browser
    return browser
end

function CaptureOfficialAchievementBrowser(frame)
    local state = frame.officialBrowserState
    if not state then return nil end
    local browser = frame.OfficialCategoryBrowser
    local copy = Copy(state)
    if browser then
        copy.leftScroll = browser.leftScroll:GetVerticalScroll()
        copy.rightScroll = browser.rightScroll:GetVerticalScroll()
    end
    return copy
end

function UpdateOfficialAchievementBrowser(frame)
    local state = frame.officialBrowserState
    local browser = frame.OfficialCategoryBrowser
    if not state then
        if browser then
            browser.pane:Hide()
            browser.right:Hide()
            browser.overview:Hide()
            browser.incompleteOnly:Hide()
        end
        frame.ScrollFrame:ClearAllPoints()
        frame.ScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -135)
        frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 26)
        frame.HorizontalScroll:ClearAllPoints()
        frame.HorizontalScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 46, 6)
        frame.HorizontalScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -52, 6)
        if UpdateAchievementRewardCategoryRail then
            UpdateAchievementRewardCategoryRail(frame)
        end
        return
    end
    browser = CreateBrowser(frame)
    frame.SettingsPanel:Hide()
    frame.ScrollFrame:ClearAllPoints()
    frame.ScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT",
        24 + LEFT_WIDTH + 10, -135)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        -24, 26)
    frame.HorizontalScroll:ClearAllPoints()
    frame.HorizontalScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT",
        46 + LEFT_WIDTH + 10, 6)
    frame.HorizontalScroll:SetPoint("BOTTOMRIGHT", frame,
        "BOTTOMRIGHT", -52, 6)
    browser.pane:Show()
    browser.right:SetShown(frame.currentPage.kind == "official-category")
    browser.rightScroll:SetShown(state.categoryID ~= OVERVIEW_CATEGORY_ID)
    browser.overview:SetShown(state.categoryID == OVERVIEW_CATEGORY_ID)
    browser.incompleteOnly:SetChecked(state.incompleteOnly == true)
    browser.incompleteOnly:SetShown(
        frame.currentPage.kind == "official-category"
            and state.categoryID ~= OVERVIEW_CATEGORY_ID)
    browser.leftScroll:SetVerticalScroll(state.leftScroll or 0)
    browser.rightScroll:SetVerticalScroll(state.rightScroll or 0)
    RefreshLeft(browser)
    RevealLeftSelection(browser)
    if UpdateAchievementRewardCategoryRail then
        UpdateAchievementRewardCategoryRail(frame)
    end
end

function RefreshOfficialAchievementBrowser(frame, reason)
    local browser = frame and frame.OfficialCategoryBrowser
    if not browser or not frame.officialBrowserState then return end
    if reason == "earned" then
        browser.achievementCache = {}
        browser.incompleteCache = {}
        browser.categoryTotals = {}
    end
    RefreshLeft(browser)
    if frame.currentPage.kind == "official-category" then
        RefreshRight(browser)
    end
end

ShowCategoryContent = function(frame)
    local browser = CreateBrowser(frame)
    local state = frame.officialBrowserState
    frame.ScrollFrame:Hide()
    frame.HorizontalScroll:Hide()
    frame.Navigator:Hide()
    frame.EmptyText:Hide()
    frame.CardScaleControls:Hide()
    frame.TreeScaleControls:Hide()
    frame.IncompleteOnly:Hide()
    frame.IncompleteOnlyLabel:Hide()
    frame.FitButton:Hide()
    browser.incompleteOnly:SetChecked(state.incompleteOnly == true)
    browser.incompleteOnly:SetShown(
        state.categoryID ~= OVERVIEW_CATEGORY_ID)
    frame.Breadcrumb:Hide()
    for _, button in ipairs(frame.BreadcrumbButtons or {}) do
        button:Hide()
    end
    frame.ATTButton:Hide()
    if frame.AchievementCard then
        frame.AchievementCard:Hide()
        frame.AchievementCardHeader:Hide()
        frame.AchievementCardTreeButton:Hide()
        frame.AchievementCardBackButton:Hide()
        frame.AchievementCardForwardButton:Hide()
        frame.AchievementCardCategoryPosition:Hide()
        frame.AchievementCardCategoryReturnButton:Hide()
    end
    if frame.AchievementCardList then frame.AchievementCardList:Hide() end
    UpdateAchievementRewardHeader(frame, nil)
    local category = browser.categories[state.categoryID]
    if state.categoryID == OVERVIEW_CATEGORY_ID then
        local total, completed = GetOverviewTotals(browser)
        UpdateAchievementHeader(frame, L.ACHIEVEMENT_OVERVIEW,
            string.format(L.ACHIEVEMENT_EARNED_PROGRESS, completed, total))
    else
        UpdateAchievementHeader(frame, category and category.name
            or L.ACHIEVEMENT_ALL_CATEGORIES,
            string.format(L.ACHIEVEMENT_REWARD_CATEGORY_STATS,
                #GetVisibleCategoryAchievements(browser, state.categoryID)))
    end
    frame.Stats:Show()
    frame.PortraitIcon:ClearAllPoints()
    frame.PortraitIcon:SetPoint("CENTER", -1, -2)
    frame.PortraitIcon:SetSize(58, 58)
    SetTextureAtlas(frame.PortraitIcon, "UI-Achievement-Shield-NoPoints")
    frame.BackButton:SetShown((frame.historyIndex or 1) > 1)
    frame.ForwardButton:SetShown((frame.historyIndex or 0)
        < #(frame.history or {}))
    frame.BackButton:SetEnabled((frame.historyIndex or 1) > 1)
    frame.ForwardButton:SetEnabled((frame.historyIndex or 0)
        < #(frame.history or {}))
    frame:Show()
    browser.right:Show()
    browser.rightScroll:SetShown(state.categoryID ~= OVERVIEW_CATEGORY_ID)
    browser.overview:SetShown(state.categoryID == OVERVIEW_CATEGORY_ID)
    RefreshRight(browser)
    if state.categoryID ~= OVERVIEW_CATEGORY_ID then
        RevealRightSelection(browser)
    end
    frame:Raise()
end

function ShowOfficialAchievementCategory(categoryID, toggleExpansion,
    navigationMode, snapshot)
    local frame = CreateAchievementTreeFrame()
    local browser = CreateBrowser(frame)
    local category = browser.categories[categoryID]
    if not category and categoryID ~= OVERVIEW_CATEGORY_ID then return false end
    if navigationMode ~= "history" then
        SaveCurrentAchievementNavigation(frame)
    end
    local state = snapshot and Copy(snapshot.officialBrowser)
        or CaptureOfficialAchievementBrowser(frame)
        or { expanded = {}, leftScroll = 0, rightScroll = 0 }
    state.expanded = state.expanded or {}
    if navigationMode ~= "history" then
        local wasExpanded = state.expanded[categoryID] == true
        state.categoryID = categoryID
        state.selectedAchievementID = nil
        state.rightScroll = 0
        state.expanded = {}
        local current = category
        while current do
            state.expanded[current.id] = true
            current = browser.categories[current.parent]
        end
        if toggleExpansion then
            state.expanded[categoryID] = not wasExpanded
        end
    end
    Navigation.ApplyPage(frame, { kind = "official-category",
        officialBrowser = state })
    if navigationMode ~= "history" then
        RecordAchievementNavigation(frame)
    end
    ShowCategoryContent(frame)
    return true
end

function OpenOfficialAchievementCard(achievementID, navigationMode)
    local frame = CreateAchievementTreeFrame()
    local browser = CreateBrowser(frame)
    local state = CaptureOfficialAchievementBrowser(frame)
    if not state or not GetAchievementData(achievementID) then return false end
    local ids = GetVisibleCategoryAchievements(browser, state.categoryID)
    local index
    for i, id in ipairs(ids) do
        if id == achievementID then index = i; break end
    end
    if not index then return false end
    state.selectedAchievementID = achievementID
    local category = browser.categories[state.categoryID]
    while category do
        state.expanded[category.id] = true
        category = browser.categories[category.parent]
    end
    return ShowAchievementTree(achievementID, navigationMode, nil, true,
        nil, { officialBrowser = state,
            officialContext = { categoryID = state.categoryID,
                achievementIDs = Copy(ids), index = index } })
end

function ReturnToOfficialAchievementCategory(frame)
    local context = frame and frame.officialContext
    if not context then return end
    for index = (frame.historyIndex or 0) - 1, 1, -1 do
        local entry = frame.history[index]
        if entry and entry.kind == "official-category"
            and entry.officialBrowser.categoryID == context.categoryID
        then
            NavigateAchievementHistory(frame, index - frame.historyIndex)
            return
        end
    end
    ShowOfficialAchievementCategory(context.categoryID)
end

function NavigateOfficialAchievementCard(frame, offset)
    local context = frame and frame.officialContext
    if not context then return end
    local id = context.achievementIDs[context.index + offset]
    if id then OpenOfficialAchievementCard(id, "official-card") end
end

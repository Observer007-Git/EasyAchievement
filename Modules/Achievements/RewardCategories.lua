local _, Addon = ...
local UI = assert(Addon.AchievementUI,
    "EasyAchievement achievement UI environment was not loaded")

if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end
local CATEGORY_DEFINITIONS = {
    { key = "mount", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_MOUNT",
        icon = "Interface\\Icons\\MountJournalPortrait" },
    { key = "pet", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_PET",
        icon = "Interface\\Icons\\PetJournalPortrait" },
    { key = "toy", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_TOY",
        icon = "Interface\\Icons\\Trade_Archaeology_ChestofTinyGlassAnimals" },
    { key = "decor", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_DECOR",
        icon = "Interface\\Icons\\Spell_Housing" },
    { key = "title", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_TITLE",
        icon = "Interface\\Icons\\INV_Misc_Note_01" },
    {
        key = "appearance",
        labelKey = "ACHIEVEMENT_REWARD_CATEGORY_APPEARANCE",
        icon = "Interface\\Icons\\INV_Chest_Cloth_17",
    },
    { key = "other", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_OTHER",
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        iconAtlas = "decor-placement-list-default" },
}

local categoryIndex
local categoryIndexState
local categoryIndexCallbacks = {}

local VALID_CATEGORIES = {}
for _, definition in ipairs(CATEGORY_DEFINITIONS) do
    VALID_CATEGORIES[definition.key] = true
end

function SanitizeAchievementRewardCategoryStates(value)
    local states = {}
    if type(value) ~= "table" then
        return states
    end
    for category, state in pairs(value) do
        if VALID_CATEGORIES[category] and type(state) == "table" then
            states[category] = {
                scale = math.max(MIN_TREE_SCALE, math.min(MAX_TREE_SCALE,
                    tonumber(state.scale) or 1)),
                horizontal = math.max(0, tonumber(state.horizontal) or 0),
                vertical = math.max(0, tonumber(state.vertical) or 0),
                selectedAchievementID = SanitizeAchievementID(
                    state.selectedAchievementID),
                viewportWidth = tonumber(state.viewportWidth),
                viewportHeight = tonumber(state.viewportHeight),
            }
        end
    end
    return states
end

SaveAchievementRewardCategoryState = function(frame)
    local mode = frame and frame.rewardCategoryMode
    if not mode or not VALID_CATEGORIES[mode.key] then
        return
    end
    local states = {}
    for category, state in pairs(
        Addon:GetSetting("achievementRewardCategoryStates") or {})
    do
        states[category] = state
    end
    states[mode.key] = CaptureAchievementViewState(frame)
    Addon:SetSetting("achievementRewardCategoryStates", states)
end

local function RestoreCategoryState(frame, category, snapshot)
    local states = Addon:GetSetting("achievementRewardCategoryStates") or {}
    local state = snapshot or states[category]
    frame.categoryRestoreState = AchievementData.CopyNavigationState(state)
    frame.restoringTreeState = true
    frame.treeScale = state and state.scale or 1
    frame.pendingHorizontalScroll = state and state.horizontal or 0
    frame.pendingVerticalScroll = state and state.vertical or 0
    frame.ScaleSlider:SetValue(frame.treeScale)
    frame.restoringTreeState = false
end

local function AddCategoryAchievement(index, seen, category, achievementID)
    if seen[category][achievementID] then
        return
    end
    seen[category][achievementID] = true
    index[category][#index[category] + 1] = achievementID
end

local function BuildCategoryIndex()
    categoryIndexState = "loading"
    categoryIndex = {}
    local seen = {}
    for _, definition in ipairs(CATEGORY_DEFINITIONS) do
        categoryIndex[definition.key] = {}
        seen[definition.key] = {}
    end

    local achievementIDs = RewardDatabase.GetAchievementIDs()
    table.sort(achievementIDs)

    local names = {}
    local position = 1
    local function Finish()
        for _, definition in ipairs(CATEGORY_DEFINITIONS) do
            table.sort(categoryIndex[definition.key], function(left, right)
                local leftName = names[left] or tostring(left)
                local rightName = names[right] or tostring(right)
                if leftName ~= rightName then
                    return leftName < rightName
                end
                return left < right
            end)
        end
        categoryIndexState = "ready"
        local callbacks = categoryIndexCallbacks
        categoryIndexCallbacks = {}
        for _, callback in ipairs(callbacks) do
            callback(categoryIndex)
        end
    end

    local function ProcessChunk()
        local startedAt = debugprofilestop and debugprofilestop() or nil
        local processed = 0
        while position <= #achievementIDs do
            if processed > 0 and startedAt and debugprofilestop()
                - startedAt >= INDEX_BUDGET_MILLISECONDS
            then
                break
            elseif processed >= 60 and not startedAt then
                break
            end
            local achievementID = achievementIDs[position]
            position = position + 1
            processed = processed + 1
            local achievement = GetAchievementData(achievementID)
            if achievement then
                names[achievementID] = achievement.name
                for _, definition in ipairs(CATEGORY_DEFINITIONS) do
                    if RewardDatabase.HasCategory(achievementID,
                        definition.key)
                    then
                        AddCategoryAchievement(categoryIndex, seen,
                            definition.key, achievementID)
                    end
                end
            end
        end
        if position <= #achievementIDs and C_Timer and C_Timer.After then
            C_Timer.After(0, ProcessChunk)
        elseif position <= #achievementIDs then
            ProcessChunk()
        else
            Finish()
        end
    end
    ProcessChunk()
end

local function GetCategoryIndex(callback)
    if categoryIndexState == "ready" then
        callback(categoryIndex)
        return
    end
    categoryIndexCallbacks[#categoryIndexCallbacks + 1] = callback
    if not categoryIndexState then
        BuildCategoryIndex()
    end
end

local function GetCategoryDefinition(category)
    for _, definition in ipairs(CATEGORY_DEFINITIONS) do
        if definition.key == category then
            return definition
        end
    end
end

function GetAchievementRewardCategoryLabel(category)
    local definition = GetCategoryDefinition(category)
    return definition and L[definition.labelKey]
end

function GetAchievementRewardCategoryIcon(category)
    local definition = GetCategoryDefinition(category)
    return definition and definition.icon, definition and definition.iconAtlas
end

function UpdateAchievementRewardCategoryRail(frame)
    if not frame or not frame.RewardCategoryRailButtons then
        return
    end
    local category = frame.settingsPageShown and "settings"
        or frame.officialBrowserState and "all"
        or frame.rewardCategoryMode and frame.rewardCategoryMode.key
        or frame.rewardCategoryCardContext
            and frame.rewardCategoryCardContext.key
        or frame.rewardCategoryOrigin and frame.rewardCategoryOrigin.key
        or frame.breadcrumbCategory
    for key, button in pairs(frame.RewardCategoryRailButtons) do
        if button.Selected then
            button.Selected:SetShown(key == category)
            button.SelectedBottom:SetShown(key == category)
        end
    end
end

function CreateAchievementRewardCategoryRail(frame)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -31)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -31)
    bar:SetHeight(32)
    bar:SetFrameLevel(frame:GetFrameLevel() + 102)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, -4)
    background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, -4)
    background:SetHeight(46)
    SetTextureAtlas(background, "shop-header-menu-bg-middle")
    frame.RewardCategoryRail = bar
    frame.RewardCategoryRailButtons = {}
    local scroll = CreateFrame("ScrollFrame", nil, bar)
    scroll:SetPoint("TOPLEFT", bar, "TOPLEFT", 55, 0)
    scroll:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT",
        -GetAchievementSearchBoxWidth(frame.SearchBox) - 36, -6)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 38)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetHorizontalScroll(math.max(0, math.min(
            self:GetHorizontalScrollRange(),
            self:GetHorizontalScroll() - delta * 90)))
    end)
    bar.Scroll = scroll
    local tabs = { { key = "all", label = L.ACHIEVEMENT_ALL_TAB } }
    for _, definition in ipairs(CATEGORY_DEFINITIONS) do
        tabs[#tabs + 1] = { key = definition.key,
            label = string.format(L.ACHIEVEMENT_REWARD_TAB,
                L[definition.labelKey]) }
    end
    tabs[#tabs + 1] = { key = "settings", label = L.ACHIEVEMENT_SETTINGS_TAB }
    for index, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, content)
        button:SetHeight(32)
        local divider = button:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("RIGHT", button, "RIGHT", index == #tabs and -1 or 1, 0)
        SetTextureAtlas(divider, "shop-header-menu-bg-divider", true)
        local selectedAtlas = index == 1 and "shop-header-menu-selected-left"
            or index == #tabs and "shop-header-menu-selected-right"
            or "shop-header-menu-selected-middle"
        local selectedLineAtlas = index == 1
            and "shop-header-menu-selected-line-left"
            or index == #tabs and "shop-header-menu-selected-line-right"
            or "shop-header-menu-selected-line-middle"
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 0)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
        SetTextureAtlas(highlight, selectedAtlas)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.5)
        local pushed = button:CreateTexture(nil, "ARTWORK")
        pushed:SetAllPoints()
        SetTextureAtlas(pushed, selectedAtlas)
        button:SetPushedTexture(pushed)
        local selected = button:CreateTexture(nil, "ARTWORK")
        selected:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 0)
        selected:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
        SetTextureAtlas(selected, selectedAtlas)
        selected:SetBlendMode("ADD")
        selected:Hide()
        button.Selected = selected
        local selectedBottom = button:CreateTexture(nil, "OVERLAY")
        selectedBottom:SetPoint("LEFT", button, "BOTTOMLEFT", 0, -2)
        selectedBottom:SetPoint("RIGHT", button, "BOTTOMRIGHT", 0, -2)
        selectedBottom:SetHeight(6)
        SetTextureAtlas(selectedBottom, selectedLineAtlas)
        selectedBottom:Hide()
        button.SelectedBottom = selectedBottom
        local label = button:CreateFontString(nil, "OVERLAY",
            "GameFontNormalMed2")
        label:SetPoint("CENTER", button, "CENTER", 0, 2)
        label:SetTextColor(1, 1, 1)
        label:SetText(tab.label)
        button.Label = label
        button:SetScript("OnClick", function()
            if tab.key == "all" then
                ShowOfficialAchievementCategory(0)
            elseif tab.key == "settings" then
                ShowAchievementSettingsPage(frame)
            else
                ShowAchievementRewardCategory(tab.key)
            end
        end)
        frame.RewardCategoryRailButtons[tab.key] = button
        button:SetPoint("TOPLEFT", content, "TOPLEFT", 1, 0)
    end
    local function LayoutTabs()
        local width = math.max(66, scroll:GetWidth() / #tabs)
        for _, tab in ipairs(tabs) do
            width = math.max(width,
                frame.RewardCategoryRailButtons[tab.key].Label:GetStringWidth()
                    + 18)
        end
        content:SetWidth(width * #tabs + 2)
        for index, tab in ipairs(tabs) do
            local button = frame.RewardCategoryRailButtons[tab.key]
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", content, "TOPLEFT",
                1 + (index - 1) * width, 0)
            button:SetWidth(width)
        end
    end
    bar:SetScript("OnSizeChanged", LayoutTabs)
    LayoutTabs()
    frame.AllAchievementsButton = frame.RewardCategoryRailButtons.all
    UpdateAchievementRewardCategoryRail(frame)
end

local function RenderRewardCategory(frame, definition, achievementIDs,
    revealSelection)
    if frame.pendingRewardCategory ~= definition.key or not frame:IsShown() then
        return
    end
    local nodes = {}
    local orderedAchievementIDs = {}
    for _, achievementID in ipairs(achievementIDs or {}) do
        local node = AchievementData.CreateNode(GetAchievementData(achievementID))
        if node then
            node.depth = 1
            node.hasChildren = false
            nodes[#nodes + 1] = node
            orderedAchievementIDs[#orderedAchievementIDs + 1] = achievementID
        end
    end
    local label = L[definition.labelKey]
    local root = nodes[1] or {
        id = 0,
        name = label,
        icon = definition.icon,
        depth = 1,
    }
    frame.rewardCategoryMode = {
        key = definition.key,
        visitID = frame.currentPage.category.visitID,
        label = label,
        icon = definition.icon,
        iconAtlas = definition.iconAtlas,
        achievementIDs = orderedAchievementIDs,
        selectedAchievementID = frame.categoryRestoreState
            and frame.categoryRestoreState.selectedAchievementID,
    }
    frame.currentPage.category = frame.rewardCategoryMode
    frame.EmptyText:SetText(L.ACHIEVEMENT_REWARD_CATEGORY_EMPTY)
    LayoutAchievementTree(nodes, {}, root, false,
        GetAchievementTreeStats(nodes), root)
    local state = frame.categoryRestoreState
    frame.categoryRestoreState = nil
    if revealSelection and state and state.selectedAchievementID then
        for _, node in ipairs(nodes) do
            if node.id == state.selectedAchievementID then
                local x, y = node.navigatorX or 0, node.navigatorY or 0
                local scroll = frame.ScrollFrame
                local horizontal = scroll:GetHorizontalScroll()
                local vertical = scroll:GetVerticalScroll()
                local changed = state.viewportWidth ~= scroll:GetWidth()
                    or state.viewportHeight ~= scroll:GetHeight()
                local outside = x < horizontal or y < vertical
                    or x + (node.layoutWidth or NODE_SIZE)
                        > horizontal + scroll:GetWidth()
                    or y + NODE_SIZE > vertical + scroll:GetHeight()
                if changed or outside then
                    RevealAchievementNode(frame, node.id)
                elseif node.button then
                    node.button.RevealHighlightPulse:Stop()
                    node.button.RevealGlow:SetAlpha(0.25)
                    node.button.RevealHighlightPulse:Play()
                end
                break
            end
        end
    end
    SaveAchievementRewardCategoryState(frame)
    SaveCurrentAchievementNavigation(frame)
end

ShowAchievementRewardCategory = function(category, navigationMode, snapshot)
    local definition = GetCategoryDefinition(category)
    if not definition then
        return false
    end
    local frame = CreateAchievementTreeFrame()
    if navigationMode ~= "history" then
        SaveCurrentAchievementNavigation(frame)
    end
    if frame.rewardCategoryMode then
        SaveAchievementRewardCategoryState(frame)
    elseif frame.sourceAchievementID then
        SaveAchievementTreeState(frame)
    end
    frame.history = frame.history or {}
    Navigation.ApplyPage(frame, {
        kind = "category",
        category = {
            key = category,
            visitID = snapshot and snapshot.visitID
                or Navigation.NewCategoryVisit(),
            label = L[definition.labelKey],
            icon = definition.icon,
        },
    })
    local revision = frame.navigationRevision
    if navigationMode ~= "history" then
        RecordAchievementNavigation(frame)
    end
    if categoryIndexState == "ready" then
        RestoreCategoryState(frame, category, snapshot and snapshot.viewState)
        RenderRewardCategory(frame, definition,
            snapshot and snapshot.achievementIDs or categoryIndex[category],
            navigationMode == "return" or navigationMode == "history")
    else
        frame.EmptyText:SetText(L.ACHIEVEMENT_REWARD_CATEGORY_LOADING)
        local placeholder = {
            id = 0,
            name = L[definition.labelKey],
            icon = definition.icon,
            depth = 1,
        }
        LayoutAchievementTree({}, {}, placeholder, false,
            GetAchievementTreeStats({}), placeholder)
        GetCategoryIndex(function(index)
            if frame.navigationRevision == revision
                and frame.pendingRewardCategory == category and frame:IsShown()
            then
                RestoreCategoryState(frame, category,
                    snapshot and snapshot.viewState)
                RenderRewardCategory(frame, definition,
                    snapshot and snapshot.achievementIDs or index[category],
                    navigationMode == "return" or navigationMode == "history")
            end
        end)
    end
    return true
end

OpenAchievementRewardCategoryCard = function(frame, achievementID)
    local mode = frame and frame.rewardCategoryMode
    if not mode or type(mode.achievementIDs) ~= "table" then
        return
    end
    local selectedIndex
    for index, categoryAchievementID in ipairs(mode.achievementIDs) do
        if categoryAchievementID == achievementID then
            selectedIndex = index
            break
        end
    end
    if not selectedIndex then
        return
    end
    mode.selectedAchievementID = achievementID
    SaveAchievementRewardCategoryState(frame)
    local context = {
        key = mode.key,
        visitID = mode.visitID,
        label = mode.label,
        achievementIDs = mode.achievementIDs,
        index = selectedIndex,
        listState = CaptureAchievementViewState(frame),
    }
    ShowAchievementTree(achievementID, "category", nil, true, context)
end

NavigateAchievementRewardCategoryCard = function(frame, offset)
    local context = frame and frame.rewardCategoryCardContext
    if not context then
        return
    end
    local targetIndex = context.index + offset
    local achievementID = context.achievementIDs[targetIndex]
    if not achievementID then
        return
    end
    context = AchievementData.CopyNavigationState(context)
    context.index = targetIndex
    ShowAchievementTree(achievementID, "category", nil, true, context)
end

ReturnToAchievementRewardCategory = function(frame)
    local context = frame and (frame.rewardCategoryCardContext
        or frame.rewardCategoryOrigin)
    if context then
        local selectedID = context.achievementIDs[context.index]
        for index = (frame.historyIndex or 1) - 1, 1, -1 do
            local entry = frame.history[index]
            if type(entry) == "table" and context.visitID
                and entry.visitID == context.visitID
            then
                NavigateAchievementHistory(frame, index - frame.historyIndex)
                return
            end
        end
        local state = AchievementData.CopyNavigationState(context.listState or {})
        state.selectedAchievementID = selectedID
        ShowAchievementRewardCategory(context.key, "return", {
            visitID = context.visitID,
            achievementIDs = context.achievementIDs,
            viewState = state,
        })
    end
end

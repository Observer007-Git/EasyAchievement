local _, Addon = ...
local UI = assert(Addon.AchievementUI,
    "EasyAchievement achievement UI environment was not loaded")

if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end

local CATEGORY_DEFINITIONS = {
    { key = "mount", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_MOUNT" },
    { key = "pet", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_PET" },
    { key = "toy", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_TOY" },
    { key = "decor", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_DECOR" },
    { key = "title", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_TITLE" },
    {
        key = "appearance",
        labelKey = "ACHIEVEMENT_REWARD_CATEGORY_APPEARANCE",
    },
    { key = "other", labelKey = "ACHIEVEMENT_REWARD_CATEGORY_OTHER" },
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

local function RenderRewardCategory(frame, definition, achievementIDs)
    if frame.pendingRewardCategory ~= definition.key or not frame:IsShown() then
        return
    end
    local nodes = {}
    local orderedAchievementIDs = {}
    for _, achievementID in ipairs(achievementIDs or {}) do
        local node = GetAchievementData(achievementID)
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
        icon = 134400,
        depth = 1,
    }
    frame.rewardCategoryMode = {
        key = definition.key,
        label = label,
        icon = 134400,
        achievementIDs = orderedAchievementIDs,
        selectedAchievementID = frame.categoryRestoreState
            and frame.categoryRestoreState.selectedAchievementID,
    }
    frame.EmptyText:SetText(L.ACHIEVEMENT_REWARD_CATEGORY_EMPTY)
    LayoutAchievementTree(nodes, {}, root, false,
        GetAchievementTreeStats(nodes), root)
    local state = frame.categoryRestoreState
    frame.categoryRestoreState = nil
    if state and state.selectedAchievementID then
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
    frame.navigationRevision = (frame.navigationRevision or 0) + 1
    if navigationMode ~= "history" then
        SaveCurrentAchievementNavigation(frame)
    end
    if frame.rewardCategoryMode then
        SaveAchievementRewardCategoryState(frame)
    elseif frame.sourceAchievementID then
        SaveAchievementTreeState(frame)
    end
    frame.history = frame.history or {}
    frame.sourceAchievementID = nil
    frame.cardOnlyAchievementID = nil
    frame.rewardCategoryCardContext = nil
    frame.rewardCategoryOrigin = nil
    frame.breadcrumbCategory = nil
    frame.breadcrumbIDs = nil
    frame.pendingRewardCategory = category
    frame.rewardCategoryMode = {
        key = category,
        label = L[definition.labelKey],
        icon = 134400,
    }
    if navigationMode ~= "history" then
        RecordAchievementNavigation(frame)
    end
    if categoryIndexState == "ready" then
        RestoreCategoryState(frame, category, snapshot and snapshot.viewState)
        RenderRewardCategory(frame, definition,
            snapshot and snapshot.achievementIDs or categoryIndex[category])
    else
        frame.EmptyText:SetText(L.ACHIEVEMENT_REWARD_CATEGORY_LOADING)
        local placeholder = {
            id = 0,
            name = L[definition.labelKey],
            icon = 134400,
            depth = 1,
        }
        LayoutAchievementTree({}, {}, placeholder, false,
            GetAchievementTreeStats({}), placeholder)
        GetCategoryIndex(function(index)
            if frame.pendingRewardCategory == category and frame:IsShown() then
                RestoreCategoryState(frame, category,
                    snapshot and snapshot.viewState)
                RenderRewardCategory(frame, definition,
                    snapshot and snapshot.achievementIDs or index[category])
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
            if type(entry) == "table" and entry.rewardCategory == context.key
            then
                NavigateAchievementHistory(frame, index - frame.historyIndex)
                return
            end
        end
        local state = AchievementData.CopyNavigationState(context.listState or {})
        state.selectedAchievementID = selectedID
        ShowAchievementRewardCategory(context.key, "return", {
            achievementIDs = context.achievementIDs,
            viewState = state,
        })
    end
end

OpenAchievementRewardCategoryMenu = function(owner)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(L.ACHIEVEMENT_REWARD_CATEGORY_VIEW)
        for _, definition in ipairs(CATEGORY_DEFINITIONS) do
            local category = definition.key
            rootDescription:CreateButton(L[definition.labelKey], function()
                ShowAchievementRewardCategory(category)
            end)
        end
    end)
end

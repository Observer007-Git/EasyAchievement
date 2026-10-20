local _, Addon = ...
local UI = assert(Addon.AchievementUI)
if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end

local Copy = Addon.AchievementData.CopyNavigationState

function CaptureAchievementViewState(frame)
    local mode = frame.rewardCategoryMode
    return {
        scale = frame.treeScale or 1,
        horizontal = frame.pendingHorizontalScroll
            or frame.ScrollFrame:GetHorizontalScroll(),
        vertical = frame.pendingVerticalScroll
            or frame.ScrollFrame:GetVerticalScroll(),
        incompleteOnly = frame.incompleteOnly == true,
        collapsed = Copy(frame.collapsedNodes or {}),
        selectedAchievementID = mode and mode.selectedAchievementID,
        viewportWidth = frame.ScrollFrame:GetWidth(),
        viewportHeight = frame.ScrollFrame:GetHeight(),
    }
end

function RestoreAchievementNavigationState(frame, state)
    if not state then
        return
    end
    frame.restoringTreeState = true
    frame.treeScale = state.scale or 1
    frame.incompleteOnly = state.incompleteOnly == true
    frame.collapsedNodes = Copy(state.collapsed or {})
    frame.pendingHorizontalScroll = state.horizontal or 0
    frame.pendingVerticalScroll = state.vertical or 0
    frame.IncompleteOnly:SetChecked(frame.incompleteOnly)
    frame.ScaleSlider:SetValue(frame.treeScale)
    frame.restoringTreeState = false
end

local function CaptureNavigation(frame)
    if frame.rewardCategoryMode then
        return {
            rewardCategory = frame.rewardCategoryMode.key,
            achievementIDs = Copy(frame.rewardCategoryMode.achievementIDs),
            viewState = CaptureAchievementViewState(frame),
        }
    elseif frame.sourceAchievementID then
        return {
            achievementID = frame.sourceAchievementID,
            showCardOnly = frame.cardOnlyAchievementID ~= nil,
            breadcrumbIDs = Copy(frame.breadcrumbIDs),
            breadcrumbCategory = frame.breadcrumbCategory,
            categoryContext = Copy(frame.rewardCategoryCardContext),
            categoryOrigin = Copy(frame.rewardCategoryOrigin),
            viewState = not frame.cardOnlyAchievementID
                and CaptureAchievementViewState(frame) or nil,
        }
    end
end

function SaveCurrentAchievementNavigation(frame)
    local entry = frame.history and frame.history[frame.historyIndex or 0]
    if not entry then
        return
    end
    local snapshot = CaptureNavigation(frame)
    if snapshot then
        frame.history[frame.historyIndex] = snapshot
    end
end

function RecordAchievementNavigation(frame, replace)
    frame.history = frame.history or {}
    local snapshot = CaptureNavigation(frame)
    local current = frame.history[frame.historyIndex or 0]
    if replace and current then
        for index = #frame.history, frame.historyIndex + 1, -1 do
            table.remove(frame.history, index)
        end
        frame.history[frame.historyIndex] = snapshot
        return
    end
    if type(current) == "table" and snapshot
        and current.achievementID == snapshot.achievementID
        and current.showCardOnly == snapshot.showCardOnly
        and current.rewardCategory == snapshot.rewardCategory
        and current.breadcrumbCategory == snapshot.breadcrumbCategory
        and not current.categoryContext and not snapshot.categoryContext
    then
        frame.history[frame.historyIndex] = snapshot
        return
    end
    for index = #frame.history, (frame.historyIndex or 0) + 1, -1 do
        table.remove(frame.history, index)
    end
    frame.historyIndex = Addon.AchievementData.AppendHistory(
        frame.history, snapshot)
end

function NavigateAchievementHistory(frame, offset)
    local previousIndex = frame.historyIndex or 0
    local targetIndex = previousIndex + offset
    if targetIndex < 1 or targetIndex > #(frame.history or {}) then
        return
    end
    SaveCurrentAchievementNavigation(frame)
    local entry = Copy(frame.history[targetIndex])
    local achievementID, showCardOnly, rewardCategory =
        GetAchievementHistoryEntry(entry)
    if not rewardCategory and not GetAchievementData(achievementID) then
        return false
    end
    local context = frame.rewardCategoryCardContext or frame.rewardCategoryOrigin
    if rewardCategory and context and context.key == rewardCategory then
        entry.viewState = Copy(context.listState or entry.viewState or {})
        entry.viewState.selectedAchievementID =
            context.achievementIDs[context.index]
        entry.achievementIDs = Copy(context.achievementIDs)
    end
    frame.historyIndex = targetIndex
    local opened
    if rewardCategory then
        opened = ShowAchievementRewardCategory(rewardCategory, "history", entry)
    else
        opened = ShowAchievementTree(achievementID, "history",
            type(entry) == "table" and entry.breadcrumbIDs or nil,
            showCardOnly, type(entry) == "table" and entry.categoryContext
                or nil, type(entry) == "table" and entry or nil)
    end
    if opened == false then
        frame.historyIndex = previousIndex
        return false
    end
    return true
end

function OpenAchievementNodeCard(frame, achievementID)
    if frame.rewardCategoryMode then
        OpenAchievementRewardCategoryCard(frame, achievementID)
    else
        OpenAchievementPathCard(frame, achievementID)
    end
end

function ScheduleAchievementNodeClick(frame, button)
    button.clickSerial = (button.clickSerial or 0) + 1
    local serial = button.clickSerial
    local revision = frame.navigationRevision
    local achievementID = button.node.id
    C_Timer.After(0.24, function()
        if button.clickSerial == serial and frame:IsShown()
            and button:IsShown() and frame.navigationRevision == revision
            and button.node and button.node.id == achievementID
        then
            OpenAchievementNodeCard(frame, achievementID)
        end
    end)
end

function OpenAchievementPathCard(frame, achievementID)
    local path = Copy(frame.breadcrumbIDs or {})
    if frame.ScrollFrame:IsShown() and frame.sourceAchievementID
        and achievementID ~= frame.sourceAchievementID
    then
        local children, parents = {}, {}
        for _, edge in ipairs(frame.fullEdges or {}) do
            children[edge.parent.id] = children[edge.parent.id] or {}
            table.insert(children[edge.parent.id], edge.child.id)
        end
        local queue = { frame.sourceAchievementID }
        parents[frame.sourceAchievementID] = false
        local position = 1
        while queue[position] and parents[achievementID] == nil do
            local parentID = queue[position]
            position = position + 1
            for _, childID in ipairs(children[parentID] or {}) do
                if parents[childID] == nil then
                    parents[childID] = parentID
                    queue[#queue + 1] = childID
                end
            end
        end
        if parents[achievementID] then
            local suffix, currentID = {}, achievementID
            while currentID ~= frame.sourceAchievementID do
                table.insert(suffix, 1, currentID)
                currentID = parents[currentID]
            end
            for index = 1, #suffix - 1 do
                path[#path + 1] = suffix[index]
            end
        end
    end
    local existingIndex
    for index, id in ipairs(path) do
        if id == achievementID then
            existingIndex = index
            break
        end
    end
    if existingIndex then
        for index = #path, existingIndex + 1, -1 do
            table.remove(path, index)
        end
    else
        path[#path + 1] = achievementID
    end
    local origin = frame.rewardCategoryCardContext or frame.rewardCategoryOrigin
    local categoryContext = origin
        and origin.achievementIDs[origin.index] == achievementID and origin or nil
    ShowAchievementTree(achievementID, nil, path, true, categoryContext, {
        breadcrumbCategory = frame.breadcrumbCategory,
        categoryOrigin = not categoryContext and Copy(origin) or nil,
    })
end

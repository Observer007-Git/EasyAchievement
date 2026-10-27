local _, Addon = ...
local UI = assert(Addon.AchievementUI)
if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end

local Copy = Addon.AchievementData.CopyNavigationState
local Navigation = {}
Addon.Navigation = Navigation
UI.Navigation = Navigation
local categoryVisitSerial = 0
local treeCardVisitSerial = 0
local BuildAchievementPath

function Navigation.NewCategoryVisit()
    categoryVisitSerial = categoryVisitSerial + 1
    return categoryVisitSerial
end

-- The page owns navigation meaning; frame fields are renderer-facing aliases.
function Navigation.ApplyPage(frame, page)
    if frame.CatalogFallbackCard then
        frame.CatalogFallbackCard:Hide()
    end
    if HideAchievementSettingsPage then
        HideAchievementSettingsPage(frame)
    end
    if Addon.AchievementRewards then
        Addon.AchievementRewards.CancelRequest()
    end
    local wasOfficialBrowser = frame.officialBrowserState ~= nil
    page = Copy(page)
    frame.currentPage = page
    frame.sourceAchievementID = page.achievementID
    frame.cardOnlyAchievementID = page.kind == "card" and page.achievementID or nil
    frame.rewardCategoryMode = page.category
    frame.pendingRewardCategory = page.category and page.category.key or nil
    frame.rewardCategoryCardContext = page.categoryContext
    frame.treeCardContext = page.treeCardContext
    frame.officialContext = page.officialContext
    frame.officialBrowserState = page.officialBrowser
    frame.rewardCategoryOrigin = page.categoryOrigin
    frame.breadcrumbIDs = page.breadcrumbIDs
    frame.breadcrumbCategory = page.breadcrumbCategory
    frame.navigationRevision = (frame.navigationRevision or 0) + 1
    if UpdateAchievementRewardCategoryRail then
        UpdateAchievementRewardCategoryRail(frame)
    end
    if UpdateOfficialAchievementBrowser
        and (wasOfficialBrowser or page.officialBrowser)
    then
        UpdateOfficialAchievementBrowser(frame)
    end
end

function Navigation.OpenCard(achievementID)
    local catalog = Addon.AchievementCatalog
    if catalog and catalog.GetRecord(achievementID)
        and not Addon.AchievementData.Get(achievementID)
    then
        local categoryID = catalog.GetRecord(achievementID)[1]
        if ShowOfficialAchievementCategory(categoryID) then
            return OpenOfficialAchievementCard(achievementID)
        end
    end
    return ShowAchievementTree(achievementID, nil, nil, true)
end

function Navigation.OpenRelatedTree(frame, achievementID, revealID)
    local origin = frame.rewardCategoryCardContext or frame.rewardCategoryOrigin
    if frame.rewardCategoryMode then
        local mode = frame.rewardCategoryMode
        for index, id in ipairs(mode.achievementIDs or {}) do
            if id == achievementID then
                mode.selectedAchievementID = id
                origin = {
                    key = mode.key, label = mode.label, visitID = mode.visitID,
                    achievementIDs = Copy(mode.achievementIDs), index = index,
                    listState = CaptureAchievementViewState(frame),
                }
                break
            end
        end
    end
    local path = revealID and { achievementID }
        or BuildAchievementPath(frame, achievementID)
    return ShowAchievementTree(achievementID, nil, path, false, nil, {
        breadcrumbCategory = origin and origin.key or frame.breadcrumbCategory,
        categoryOrigin = Copy(origin),
        revealAchievementID = revealID,
    })
end

local function SamePath(left, right)
    left, right = left or {}, right or {}
    if #left ~= #right then return false end
    for index, id in ipairs(left) do
        if id ~= right[index] then return false end
    end
    return true
end

local function SameOrigin(left, right)
    if not left or not right then return left == right end
    return left.visitID == right.visitID and left.key == right.key
        and left.index == right.index
end

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
    local page = frame.currentPage
    if not page then return nil end
    if page.kind == "category" then
        return {
            kind = "category",
            visitID = page.category.visitID,
            rewardCategory = page.category.key,
            achievementIDs = Copy(page.category.achievementIDs),
            viewState = CaptureAchievementViewState(frame),
        }
    elseif page.kind == "official-category" then
        return { kind = "official-category",
            officialBrowser = CaptureOfficialAchievementBrowser(frame) }
    elseif page.achievementID then
        return {
            kind = page.kind,
            achievementID = page.achievementID,
            showCardOnly = page.kind == "card",
            breadcrumbIDs = Copy(page.breadcrumbIDs),
            breadcrumbCategory = page.breadcrumbCategory,
            categoryContext = Copy(page.categoryContext),
            treeCardContext = Copy(page.treeCardContext),
            officialContext = Copy(page.officialContext),
            officialBrowser = page.officialBrowser
                and CaptureOfficialAchievementBrowser(frame),
            categoryOrigin = Copy(page.categoryOrigin),
            viewState = page.kind == "tree"
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
        and current.kind == snapshot.kind
        and current.achievementID == snapshot.achievementID
        and current.showCardOnly == snapshot.showCardOnly
        and current.rewardCategory == snapshot.rewardCategory
        and current.breadcrumbCategory == snapshot.breadcrumbCategory
        and current.visitID == snapshot.visitID
        and (not current.officialBrowser and not snapshot.officialBrowser
            or current.officialBrowser and snapshot.officialBrowser
                and current.officialBrowser.categoryID
                    == snapshot.officialBrowser.categoryID)
        and SamePath(current.breadcrumbIDs, snapshot.breadcrumbIDs)
        and SameOrigin(current.categoryOrigin, snapshot.categoryOrigin)
        and not current.categoryContext and not snapshot.categoryContext
        and not current.treeCardContext and not snapshot.treeCardContext
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
    if entry.kind ~= "official-category" and not rewardCategory
        and not GetAchievementData(achievementID) then
        return false
    end
    if entry.kind == "official-category" and frame.officialContext
        and frame.officialContext.categoryID
            == entry.officialBrowser.categoryID
    then
        entry.officialBrowser.selectedAchievementID =
            frame.sourceAchievementID
    end
    local context = frame.rewardCategoryCardContext or frame.rewardCategoryOrigin
    if rewardCategory and context and context.visitID
        and context.visitID == entry.visitID
    then
        entry.viewState = Copy(context.listState or entry.viewState or {})
        entry.viewState.selectedAchievementID =
            context.achievementIDs[context.index]
        entry.achievementIDs = Copy(context.achievementIDs)
    end
    frame.historyIndex = targetIndex
    local opened
    if entry.kind == "official-category" then
        opened = ShowOfficialAchievementCategory(
            entry.officialBrowser.categoryID, false, "history", entry)
    elseif rewardCategory then
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

Navigation.Capture = CaptureNavigation
Navigation.BackOrForward = NavigateAchievementHistory

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

BuildAchievementPath = function(frame, achievementID)
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
    return path
end

function OpenAchievementPathCard(frame, achievementID)
    local treeContext = frame.treeCardContext
    if frame.ScrollFrame:IsShown() and not frame.rewardCategoryMode then
        local ids, selectedIndex = {}, nil
        for _, node in ipairs(frame.fullNodes or {}) do
            ids[#ids + 1] = node.id
            if node.id == achievementID then selectedIndex = #ids end
        end
        if selectedIndex and #ids > 1 then
            treeCardVisitSerial = treeCardVisitSerial + 1
            local parentByID = {}
            for _, edge in ipairs(frame.fullEdges or {}) do
                parentByID[edge.child.id] = parentByID[edge.child.id]
                    or edge.parent.id
            end
            treeContext = {
                kind = "tree", rootID = frame.sourceAchievementID,
                visitID = treeCardVisitSerial, achievementIDs = ids,
                index = selectedIndex,
                rootPath = Copy(frame.breadcrumbIDs),
                parentByID = parentByID,
            }
        else
            treeContext = nil
        end
    elseif treeContext then
        treeContext = Copy(treeContext)
        local selectedIndex
        for index, id in ipairs(treeContext.achievementIDs) do
            if id == achievementID then selectedIndex = index; break end
        end
        if selectedIndex then
            treeContext.index = selectedIndex
        else
            treeContext = nil
        end
    end
    local path = BuildAchievementPath(frame, achievementID)
    if treeContext and frame.treeCardContext then
        path = Navigation.GetTreeCardPath(treeContext, achievementID)
    end
    local origin = frame.rewardCategoryCardContext or frame.rewardCategoryOrigin
    local categoryContext = origin
        and origin.achievementIDs[origin.index] == achievementID and origin or nil
    ShowAchievementTree(achievementID, nil, path, true, categoryContext, {
        breadcrumbCategory = frame.breadcrumbCategory,
        categoryOrigin = not categoryContext and Copy(origin) or nil,
        treeCardContext = treeContext,
    })
end

function Navigation.GetTreeCardPath(context, achievementID)
    local suffix, currentID = {}, achievementID
    while currentID and currentID ~= context.rootID do
        table.insert(suffix, 1, currentID)
        currentID = context.parentByID[currentID]
    end
    if currentID ~= context.rootID then
        return { achievementID }
    end
    local path = Copy(context.rootPath or { context.rootID })
    for _, id in ipairs(suffix) do path[#path + 1] = id end
    return path
end

function NavigateAchievementTreeCard(frame, offset)
    local context = frame and frame.treeCardContext
    if not context then return end
    local targetIndex = context.index + offset
    local achievementID = context.achievementIDs[targetIndex]
    if not achievementID then return end
    context = Copy(context)
    context.index = targetIndex
    ShowAchievementTree(achievementID, "tree-card",
        Navigation.GetTreeCardPath(context, achievementID), true, nil, {
            treeCardContext = context,
            breadcrumbCategory = frame.breadcrumbCategory,
            categoryOrigin = Copy(frame.rewardCategoryOrigin),
        })
end

Navigation.OpenPathCard = OpenAchievementPathCard

local _, Addon = ...

local TreeData = {}
Addon.AchievementTreeData = TreeData

local Data = assert(Addon.AchievementData,
    "EasyAchievement achievement data service was not loaded")
local INDEX_BUDGET_MILLISECONDS =
    Addon.Config.Performance.IndexBudgetMilliseconds

local parentsByID = {}
local parentIndexState
local indexReadyCallback

function TreeData.SetIndexReadyCallback(callback)
    assert(callback == nil or type(callback) == "function",
        "Invalid achievement parent-index callback")
    indexReadyCallback = callback
end

function TreeData.IsParentIndexBuilding()
    return parentIndexState == "building"
end

local function AddParent(childID, parentID)
    if not Data.IsValid(childID)
        or not Data.IsValid(parentID)
        or childID == parentID
    then
        return
    end
    local parents = parentsByID[childID]
    if not parents then
        parents = {}
        parentsByID[childID] = parents
    end
    for _, knownParentID in ipairs(parents) do
        if knownParentID == parentID then
            return
        end
    end
    parents[#parents + 1] = parentID
end

local function GetKnownParents(achievementID)
    local nextID = GetNextAchievement
        and GetNextAchievement(achievementID)
    if Data.IsValid(nextID) then
        AddParent(achievementID, nextID)
    end
    return parentsByID[achievementID] or {}
end

function TreeData.GetTopmostIDs(achievementID)
    local rootsByID = {}
    local function Visit(currentID, depth, visiting)
        if visiting[currentID] then
            return
        end
        visiting[currentID] = true
        local visitedParent = false
        for _, parentID in ipairs(GetKnownParents(currentID)) do
            if not visiting[parentID] then
                visitedParent = true
                Visit(parentID, depth + 1, visiting)
            end
        end
        if not visitedParent then
            rootsByID[currentID] = math.max(rootsByID[currentID] or 0,
                depth)
        end
        visiting[currentID] = nil
    end
    Visit(achievementID, 0, {})

    local roots = {}
    local maximumDepth = 0
    for rootID, depth in pairs(rootsByID) do
        roots[#roots + 1] = { id = rootID, depth = depth }
        maximumDepth = math.max(maximumDepth, depth)
    end
    table.sort(roots, function(left, right)
        if left.depth ~= right.depth then
            return left.depth > right.depth
        end
        return left.id < right.id
    end)
    local rootIDs = {}
    for _, root in ipairs(roots) do
        rootIDs[#rootIDs + 1] = root.id
    end
    return rootIDs, maximumDepth
end

function TreeData.StartParentIndex()
    if parentIndexState then
        return
    end
    if not GetCategoryList or not GetCategoryNumAchievements
        or not GetAchievementInfo
    then
        parentIndexState = "ready"
        return
    end

    parentIndexState = "building"
    local categories = {}
    local categorySeen = {}
    local function AddCategories(list)
        for _, categoryID in ipairs(list or {}) do
            if not categorySeen[categoryID] then
                categorySeen[categoryID] = true
                categories[#categories + 1] = categoryID
            end
        end
    end
    AddCategories(GetCategoryList())
    if GetGuildCategoryList then
        AddCategories(GetGuildCategoryList())
    end

    local categoryIndex = 1
    local achievementIndex = 1
    local categoryCount = 0
    local seenAchievements = {}
    local function FinishIndex()
        parentIndexState = "ready"
        if indexReadyCallback then
            indexReadyCallback()
        end
    end
    local function ProcessChunk()
        local canDefer = C_Timer and C_Timer.After
        local startedAt = canDefer and debugprofilestop
            and debugprofilestop() or nil
        local processed = 0
        local function HasBudget()
            if not canDefer then
                return true
            end
            if startedAt then
                return processed == 0
                    or debugprofilestop() - startedAt
                        < INDEX_BUDGET_MILLISECONDS
            end
            return processed < 60
        end
        while categoryIndex <= #categories and HasBudget() do
            if categoryCount == 0 then
                categoryCount = GetCategoryNumAchievements(
                    categories[categoryIndex], true) or 0
                achievementIndex = 1
            end
            if achievementIndex > categoryCount then
                categoryIndex = categoryIndex + 1
                categoryCount = 0
            else
                local achievementID = select(1, GetAchievementInfo(
                    categories[categoryIndex], achievementIndex))
                achievementIndex = achievementIndex + 1
                processed = processed + 1
                if Data.IsValid(achievementID)
                    and not seenAchievements[achievementID]
                then
                    seenAchievements[achievementID] = true
                    GetKnownParents(achievementID)
                    for criteriaIndex = 1,
                        GetAchievementNumCriteria(achievementID) or 0
                    do
                        local _, criteriaType, _, _, _, _, _, assetID =
                            GetAchievementCriteriaInfo(achievementID,
                                criteriaIndex)
                        if criteriaType == CRITERIA_TYPE_ACHIEVEMENT then
                            AddParent(assetID, achievementID)
                        end
                    end
                end
            end
        end
        if categoryIndex > #categories then
            FinishIndex()
        elseif canDefer then
            C_Timer.After(0, ProcessChunk)
        else
            ProcessChunk()
        end
    end
    ProcessChunk()
end

function TreeData.GetChildIDs(achievementID)
    local children = {}
    local added = {}
    local numCriteria = GetAchievementNumCriteria(achievementID) or 0

    for index = 1, numCriteria do
        local _, criteriaType, _, _, _, _, _, assetID =
            GetAchievementCriteriaInfo(achievementID, index)
        if criteriaType == CRITERIA_TYPE_ACHIEVEMENT
            and Data.IsValid(assetID)
            and assetID ~= achievementID
            and not added[assetID]
        then
            added[assetID] = true
            children[#children + 1] = assetID
        end
    end

    local previousID = GetPreviousAchievement
        and GetPreviousAchievement(achievementID)
    if Data.IsValid(previousID)
        and previousID ~= achievementID
        and not added[previousID]
    then
        children[#children + 1] = previousID
    end

    return children
end

function TreeData.Build(rootID)
    local root = Data.CreateNode(Data.Get(rootID))
    if not root then
        return nil
    end

    root.depth = 1
    local nodes = { root }
    local byID = { [root.id] = root }
    local edges = {}
    local edgeKeys = {}
    local queueIndex = 1

    while queueIndex <= #nodes do
        local parent = nodes[queueIndex]
        queueIndex = queueIndex + 1

        for _, childID in ipairs(TreeData.GetChildIDs(parent.id)) do
            local child = byID[childID]
            if not child then
                child = Data.CreateNode(Data.Get(childID), parent.depth + 1)
                if child then
                    child.depth = parent.depth + 1
                    byID[childID] = child
                    nodes[#nodes + 1] = child
                end
            end

            if child and child.depth > parent.depth then
                local edgeKey = parent.id .. ":" .. child.id
                if not edgeKeys[edgeKey] then
                    edgeKeys[edgeKey] = true
                    edges[#edges + 1] = { parent = parent, child = child }
                    AddParent(child.id, parent.id)
                end
            end
        end
    end

    return nodes, edges, root
end

function TreeData.GetStats(nodes)
    local maxDepth = 0
    local completedCount = 0
    for _, node in ipairs(nodes) do
        maxDepth = math.max(maxDepth, node.depth or 1)
        if node.completed then
            completedCount = completedCount + 1
        end
    end
    return {
        levels = maxDepth,
        total = #nodes,
        completed = completedCount,
        incomplete = #nodes - completedCount,
    }
end

local function Filter(nodes, edges, predicate)
    local parentByID = {}
    local visibleByID = {}
    local filteredNodes = {}

    for _, edge in ipairs(edges) do
        parentByID[edge.child.id] = parentByID[edge.child.id]
            or edge.parent
    end
    for _, node in ipairs(nodes) do
        if predicate(node) then
            visibleByID[node.id] = node
            filteredNodes[#filteredNodes + 1] = node
        end
    end

    local visibleParentByID = {}
    local filteredEdges = {}
    for _, node in ipairs(filteredNodes) do
        local parent = parentByID[node.id]
        while parent and not visibleByID[parent.id] do
            parent = parentByID[parent.id]
        end
        if parent then
            visibleParentByID[node.id] = parent
            filteredEdges[#filteredEdges + 1] = {
                parent = parent,
                child = node,
            }
        end
    end

    local depths = {}
    local function GetDepth(node)
        if depths[node.id] then
            return depths[node.id]
        end
        local parent = visibleParentByID[node.id]
        local depth = parent and GetDepth(parent) + 1 or 1
        depths[node.id] = depth
        return depth
    end
    local filteredRoot
    for _, node in ipairs(filteredNodes) do
        node.depth = GetDepth(node)
        if not filteredRoot and not visibleParentByID[node.id] then
            filteredRoot = node
        end
    end

    return filteredNodes, filteredEdges, filteredRoot
end

function TreeData.FilterIncomplete(nodes, edges)
    return Filter(nodes, edges, function(node)
        return not node.completed
    end)
end

function TreeData.FilterCollapsed(nodes, edges, collapsedNodes)
    if not next(collapsedNodes or {}) then
        return nodes, edges
    end
    local parentByID = {}
    for _, edge in ipairs(edges) do
        parentByID[edge.child.id] = parentByID[edge.child.id]
            or edge.parent
    end
    local visibleByID = {}
    local visibleNodes = {}
    for _, node in ipairs(nodes) do
        local parent = parentByID[node.id]
        local visible = true
        while parent do
            if collapsedNodes[parent.id] then
                visible = false
                break
            end
            parent = parentByID[parent.id]
        end
        if visible then
            visibleByID[node.id] = true
            visibleNodes[#visibleNodes + 1] = node
        end
    end
    local visibleEdges = {}
    for _, edge in ipairs(edges) do
        if visibleByID[edge.parent.id] and visibleByID[edge.child.id] then
            visibleEdges[#visibleEdges + 1] = edge
        end
    end
    return visibleNodes, visibleEdges
end

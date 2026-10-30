local _, Addon = ...

local raw = assert(Addon.AchievementCatalogData,
    "EasyAchievement achievement catalog was not loaded")
assert(raw.schema == 2, "Unsupported achievement catalog schema")

local Catalog = {}
Addon.AchievementCatalog = Catalog
local categories, roots, byCategory, sortedIDs
local detailCache = {}
local completedByCategory = {}
local completedByFaction = { [0] = {}, [1] = {} }
local completedZeroByCategory = {}
local completedZeroByFaction = { [0] = {}, [1] = {} }
local completedPointsByCategory = {}
local completedPointsByFaction = { [0] = {}, [1] = {} }
local completedIDs = {}
local progressState
local progressCallbacks = {}
local searchState, searchText
local searchCallbacks = {}
local lastSearchQuery, lastSearchResults
local pointsOnly = false

local function SortCategories(list)
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
end

local function EnsureIndex()
    if categories then return end
    categories, roots, byCategory, sortedIDs = {}, {}, {}, {}
    for id, row in pairs(raw.categories) do
        local name = GetCategoryInfo and GetCategoryInfo(id)
        categories[id] = { id = id, parent = row[1], order = row[2],
            count = row[3], points = row[4],
            zeroCount = 0, zeroFactionCount = { [0] = 0, [1] = 0 },
            factionCount = { [0] = 0, [1] = 0 },
            factionPoints = { [0] = 0, [1] = 0 },
            name = name or string.format(
                Addon.L.ACHIEVEMENT_CATALOG_CATEGORY_ID or "Category #%d",
                id), children = {} }
        byCategory[id] = {}
    end
    for id, category in pairs(categories) do
        local parent = categories[category.parent]
        local list = parent and parent.children or roots
        list[#list + 1] = category
    end
    SortCategories(roots)
    for _, category in pairs(categories) do
        SortCategories(category.children)
    end
    for id, row in pairs(raw.achievements) do
        sortedIDs[#sortedIDs + 1] = id
        local list = byCategory[row[1]]
        if list then list[#list + 1] = id end
        local category = categories[row[1]]
        if category and row[2] == 0 then
            category.zeroCount = category.zeroCount + 1
            if category.zeroFactionCount[row[3]] then
                category.zeroFactionCount[row[3]] =
                    category.zeroFactionCount[row[3]] + 1
            end
        end
        if category and (row[3] == 0 or row[3] == 1) then
            category.factionCount[row[3]] =
                category.factionCount[row[3]] + 1
            category.factionPoints[row[3]] =
                category.factionPoints[row[3]] + row[2]
        end
    end
    table.sort(sortedIDs)
    for _, list in pairs(byCategory) do
        table.sort(list, function(a, b)
            local left, right = raw.achievements[a], raw.achievements[b]
            if left[4] ~= right[4] then return left[4] < right[4] end
            return a < b
        end)
    end
end

function Catalog.GetCategories()
    EnsureIndex()
    return categories, roots
end

function Catalog.GetCategoryIDs(categoryID)
    EnsureIndex()
    return byCategory[categoryID] or {}
end

function Catalog.GetIDs()
    EnsureIndex()
    return sortedIDs
end

function Catalog.GetRecord(id)
    return raw.achievements[id]
end

function Catalog.GetBuild()
    return raw.build
end

function Catalog.GetCategoryName(id)
    EnsureIndex()
    return categories[id] and categories[id].name
end

local selectedFaction

local function PlayerFaction()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "Alliance" and "Alliance" or "Horde"
end

function Catalog.GetSelectedFaction()
    return selectedFaction or PlayerFaction()
end

function Catalog.SetSelectedFaction(faction)
    if faction == "Horde" or faction == "Alliance" then
        selectedFaction = faction
    end
end

function Catalog.GetPointsOnly()
    return pointsOnly
end

function Catalog.SetPointsOnly(enabled)
    pointsOnly = enabled == true
end

function Catalog.IsVisible(id)
    local row = raw.achievements[id]
    if not row then
        return not pointsOnly or (tonumber(select(3,
            GetAchievementInfo(id))) or 0) > 0
    end
    if pointsOnly and row[2] <= 0 then return false end
    return row[3] == -1 or row[3] == (Catalog.GetSelectedFaction()
        == "Horde" and 0 or 1)
end

function Catalog.IsOppositeFaction(id)
    local row = raw.achievements[id]
    return row and row[3] == (PlayerFaction() == "Horde" and 1 or 0)
        or false
end

function Catalog.GetDirectTotals(categoryID)
    EnsureIndex()
    local category = categories[categoryID]
    if not category then return 0, 0 end
    local count, points = category.count, category.points
    local opposite = Catalog.GetSelectedFaction() == "Horde" and 1 or 0
    count = count - category.factionCount[opposite]
    points = points - category.factionPoints[opposite]
    if pointsOnly then
        count = count - category.zeroCount
            + category.zeroFactionCount[opposite]
    end
    return count, points
end

function Catalog.IsProgressReady()
    return progressState == "ready"
end

function Catalog.IsSearchReady()
    return searchState == "ready"
end

function Catalog.IsCompleted(id)
    return completedIDs[id] == true
end

function Catalog.GetCompleted(categoryID)
    EnsureIndex()
    local total = completedByCategory[categoryID] or 0
    local opposite = Catalog.GetSelectedFaction() == "Horde" and 1 or 0
    total = total - (completedByFaction[opposite][categoryID] or 0)
    if pointsOnly then
        total = total - (completedZeroByCategory[categoryID] or 0)
            + (completedZeroByFaction[opposite][categoryID] or 0)
    end
    local category = categories[categoryID]
    if category then
        for _, child in ipairs(category.children) do
            total = total + Catalog.GetCompleted(child.id)
        end
    end
    return total
end

function Catalog.GetCompletedPoints(categoryID)
    EnsureIndex()
    local total = completedPointsByCategory[categoryID] or 0
    local opposite = Catalog.GetSelectedFaction() == "Horde" and 1 or 0
    total = total - (completedPointsByFaction[opposite][categoryID] or 0)
    local category = categories[categoryID]
    if category then
        for _, child in ipairs(category.children) do
            total = total + Catalog.GetCompletedPoints(child.id)
        end
    end
    return total
end

function Catalog.StartProgressScan(callback)
    if callback then progressCallbacks[#progressCallbacks + 1] = callback end
    if progressState then
        if progressState == "ready" and callback then callback() end
        return
    end
    EnsureIndex()
    progressState = "building"
    local position = 1
    local function ProcessChunk()
        local startedAt = debugprofilestop and debugprofilestop() or nil
        local processed = 0
        while position <= #sortedIDs do
            if processed > 0 and startedAt and debugprofilestop()
                - startedAt >= Addon.Config.Performance.IndexBudgetMilliseconds
            then
                break
            elseif processed >= 60 and not startedAt then
                break
            end
            local id = sortedIDs[position]
            position = position + 1
            processed = processed + 1
            local data = detailCache[id]
            local completed
            if data then
                completed = data.completed
            else
                completed = select(4, GetAchievementInfo(id))
            end
            if completed and not completedIDs[id] then
                completedIDs[id] = true
                local row = raw.achievements[id]
                local categoryID = row[1]
                completedByCategory[categoryID] =
                    (completedByCategory[categoryID] or 0) + 1
                if row[2] == 0 then
                    completedZeroByCategory[categoryID] =
                        (completedZeroByCategory[categoryID] or 0) + 1
                end
                completedPointsByCategory[categoryID] =
                    (completedPointsByCategory[categoryID] or 0) + row[2]
                local faction = row[3]
                if completedByFaction[faction] then
                    local counts = completedByFaction[faction]
                    counts[categoryID] = (counts[categoryID] or 0) + 1
                    if row[2] == 0 then
                        local zeros = completedZeroByFaction[faction]
                        zeros[categoryID] = (zeros[categoryID] or 0) + 1
                    end
                    local points = completedPointsByFaction[faction]
                    points[categoryID] = (points[categoryID] or 0) + row[2]
                end
            end
        end
        if position <= #sortedIDs and C_Timer and C_Timer.After then
            C_Timer.After(0, ProcessChunk)
        elseif position <= #sortedIDs then
            ProcessChunk()
        else
            progressState = "ready"
            for _, listener in ipairs(progressCallbacks) do listener() end
            progressCallbacks = {}
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ProcessChunk)
    else
        ProcessChunk()
    end
end

function Catalog.RefreshCompletion(id)
    local row = raw.achievements[id]
    detailCache[id] = nil
    if row and not completedIDs[id]
        and select(4, GetAchievementInfo(id))
    then
        completedIDs[id] = true
        completedByCategory[row[1]] =
            (completedByCategory[row[1]] or 0) + 1
        if row[2] == 0 then
            completedZeroByCategory[row[1]] =
                (completedZeroByCategory[row[1]] or 0) + 1
        end
        completedPointsByCategory[row[1]] =
            (completedPointsByCategory[row[1]] or 0) + row[2]
        if completedByFaction[row[3]] then
            local counts = completedByFaction[row[3]]
            counts[row[1]] = (counts[row[1]] or 0) + 1
            if row[2] == 0 then
                local zeros = completedZeroByFaction[row[3]]
                zeros[row[1]] = (zeros[row[1]] or 0) + 1
            end
            local points = completedPointsByFaction[row[3]]
            points[row[1]] = (points[row[1]] or 0) + row[2]
        end
    end
end

function Catalog.GetData(id)
    local row = raw.achievements[id]
    if not row then return nil end
    if detailCache[id] then return detailCache[id] end
    local gameID, name, points, completed, month, day, year,
        description, flags, icon, rewardText, isGuild, wasEarnedByMe,
        earnedBy, isStatistic = GetAchievementInfo(id)
    local data = {
        id = id, name = name and name ~= "" and name
            or string.format(Addon.L.ACHIEVEMENT_CATALOG_ACHIEVEMENT_ID
                or "Achievement #%d", id),
        points = gameID and points or row[2],
        completed = completed == true, month = month, day = day,
        year = year, description = description or "",
        flags = flags, icon = icon and icon > 0 and icon
            or row[5] ~= 0 and row[5] or 134400,
        rewardText = rewardText or "",
        isGuild = isGuild, isStatistic = isStatistic,
        wasEarnedByMe = wasEarnedByMe, earnedBy = earnedBy,
        catalogOnly = not gameID,
    }
    detailCache[id] = data
    return data
end

local function StartSearchIndex(callback)
    if callback then searchCallbacks[#searchCallbacks + 1] = callback end
    if searchState then return end
    EnsureIndex()
    searchState, searchText = "building", {}
    local position = 1
    local function ProcessChunk()
        local startedAt = debugprofilestop and debugprofilestop() or nil
        local processed = 0
        while position <= #sortedIDs do
            if processed > 0 and startedAt and debugprofilestop()
                - startedAt >= Addon.Config.Performance.IndexBudgetMilliseconds
            then
                break
            elseif processed >= 60 and not startedAt then
                break
            end
            local id = sortedIDs[position]
            position = position + 1
            processed = processed + 1
            local data = detailCache[id]
            local name
            if data and not data.catalogOnly then
                name = data.name
            else
                local gameID, gameName = GetAchievementInfo(id)
                if gameID then
                    name = gameName
                end
            end
            if name and name ~= "" then
                searchText[id] = name:lower()
            end
        end
        if position <= #sortedIDs and C_Timer and C_Timer.After then
            C_Timer.After(0, ProcessChunk)
        elseif position <= #sortedIDs then
            ProcessChunk()
        else
            searchState = "ready"
            for _, listener in ipairs(searchCallbacks) do listener() end
            searchCallbacks = {}
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ProcessChunk)
    else
        ProcessChunk()
    end
end

function Catalog.Search(query, onReady)
    EnsureIndex()
    query = (query or ""):lower()
    if query == "" then return {} end
    local found = {}
    if searchState ~= "ready" then
        StartSearchIndex(onReady)
        if searchState ~= "ready" then return found end
    end
    if query == lastSearchQuery then return lastSearchResults end
    for _, id in ipairs(sortedIDs) do
        if searchText[id] and searchText[id]:find(query, 1, true)
        then
            found[#found + 1] = id
        end
    end
    lastSearchQuery, lastSearchResults = query, found
    return found
end

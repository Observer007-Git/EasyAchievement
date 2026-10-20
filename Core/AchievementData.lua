local _, Addon = ...

local Data = {}
Addon.AchievementData = Data

local Config = Addon.Config
local MIN_TREE_SCALE = Config.Tree.MinScale
local MAX_TREE_SCALE = Config.Tree.MaxScale
local MAX_TREE_STATES = Config.State.MaxTreeStates
local MAX_HISTORY_ENTRIES = Config.State.MaxHistoryEntries
local FACTION_IDS = { Horde = 0, Alliance = 1 }
local RewardDatabase = assert(Addon.RewardDatabase,
    "EasyAchievement reward database API was not loaded")

function Data.IsFactionAvailable(achievementID, factionGroup)
    local requiredFaction = RewardDatabase.GetFaction(achievementID)
    if requiredFaction ~= 0 and requiredFaction ~= 1 then
        return true
    end
    if not factionGroup and UnitFactionGroup then
        factionGroup = UnitFactionGroup("player")
    end
    local playerFaction = FACTION_IDS[factionGroup]
    return playerFaction == nil or playerFaction == requiredFaction
end

function Data.GetHistoryEntry(entry)
    if type(entry) == "table" then
        return entry.achievementID, entry.showCardOnly == true,
            entry.rewardCategory
    end
    return entry, false, nil
end

function Data.AppendHistory(history, entry)
    history[#history + 1] = entry
    local overflow = #history - MAX_HISTORY_ENTRIES
    for _ = 1, math.max(0, overflow) do
        table.remove(history, 1)
    end
    return #history
end

function Data.CopyNavigationState(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = Data.CopyNavigationState(item)
    end
    return copy
end

function Data.GetBreadcrumbLayout(widths, available)
    available = math.max(1, available)
    local total = 0
    for _, width in ipairs(widths) do
        total = total + width
    end
    local layout = {}
    if total <= available then
        for index, width in ipairs(widths) do
            layout[#layout + 1] = { index = index, width = width }
        end
    elseif #widths == 1 then
        layout[1] = { index = 1, width = available }
    elseif #widths > 1 then
        local overflow = #widths > 2 and 24 or 0
        local firstWidth = math.min(widths[1], (available - overflow) * 0.4)
        layout[1] = { index = 1, width = firstWidth }
        if overflow > 0 then
            layout[2] = { index = 0, width = overflow }
        end
        layout[#layout + 1] = {
            index = #widths, width = available - overflow - firstWidth,
        }
    end
    return layout
end

function Data.IsValid(achievementID)
    if type(achievementID) ~= "number" or achievementID <= 0 then
        return false
    end
    return not C_AchievementInfo
        or not C_AchievementInfo.IsValidAchievement
        or C_AchievementInfo.IsValidAchievement(achievementID)
end

function Data.SanitizeID(value)
    value = tonumber(value)
    if not value or value <= 0 then
        return nil
    end
    return math.floor(value)
end

function Data.SanitizeIDList(value)
    local result = {}
    local seen = {}
    if type(value) ~= "table" then
        return result
    end
    for _, achievementID in ipairs(value) do
        local id = Data.SanitizeID(achievementID)
        if id and not seen[id] then
            seen[id] = true
            result[#result + 1] = id
        end
    end
    return result
end

function Data.TrimTreeStates(states, preservedRootID)
    local entries = {}
    local preservedKey = preservedRootID
        and tostring(preservedRootID) or nil
    for rootID, state in pairs(states) do
        entries[#entries + 1] = {
            rootID = rootID,
            lastUsed = tonumber(state.lastUsed) or 0,
            preserved = rootID == preservedKey,
        }
    end
    if #entries <= MAX_TREE_STATES then
        return states
    end
    table.sort(entries, function(left, right)
        if left.preserved ~= right.preserved then
            return left.preserved
        end
        if left.lastUsed ~= right.lastUsed then
            return left.lastUsed > right.lastUsed
        end
        return tostring(left.rootID) < tostring(right.rootID)
    end)
    for index = MAX_TREE_STATES + 1, #entries do
        states[entries[index].rootID] = nil
    end
    return states
end

function Data.SanitizeTreeStates(value)
    local states = {}
    if type(value) ~= "table" then
        return states
    end
    for rootID, state in pairs(value) do
        local id = Data.SanitizeID(rootID)
        if id and type(state) == "table" then
            local collapsed = {}
            if type(state.collapsed) == "table" then
                for nodeID, isCollapsed in pairs(state.collapsed) do
                    local collapsedID = Data.SanitizeID(nodeID)
                    if collapsedID and isCollapsed then
                        collapsed[tostring(collapsedID)] = true
                    end
                end
            end
            states[tostring(id)] = {
                scale = math.max(MIN_TREE_SCALE, math.min(MAX_TREE_SCALE,
                    tonumber(state.scale) or 1)),
                horizontal = math.max(0,
                    tonumber(state.horizontal) or 0),
                vertical = math.max(0, tonumber(state.vertical) or 0),
                incompleteOnly = state.incompleteOnly == true,
                collapsed = collapsed,
                lastUsed = math.max(0, tonumber(state.lastUsed) or 0),
            }
        end
    end
    return Data.TrimTreeStates(states)
end

function Data.Get(achievementID)
    if not Data.IsValid(achievementID)
        or not Data.IsFactionAvailable(achievementID)
    then
        return nil
    end

    local id, name, points, completed, month, day, year, description,
        flags, icon, rewardText, isGuild = GetAchievementInfo(achievementID)
    if not id or not name then
        return nil
    end

    return {
        id = id,
        name = name,
        points = points or 0,
        completed = completed,
        month = month,
        day = day,
        year = year,
        description = description,
        flags = flags,
        icon = icon,
        rewardText = rewardText,
        isGuild = isGuild,
    }
end

function Data.GetProgress(achievementID)
    local completedCount = 0
    local total = GetAchievementNumCriteria(achievementID) or 0
    local hasProgress = false
    for index = 1, total do
        local _, _, completed, quantity =
            GetAchievementCriteriaInfo(achievementID, index)
        if completed then
            completedCount = completedCount + 1
            hasProgress = true
        elseif type(quantity) == "number" and quantity > 0 then
            hasProgress = true
        end
    end
    return completedCount, total, hasProgress
end

local _, Addon = ...

local MapSearch = {}
Addon.MapSearch = MapSearch

local roots = { 946, 947, 1, 2, 13, 197, 4080 }
local maps, listeners = {}, {}
local stack, seen
local ready, building = false, false

local function IsMapVisible(info)
    local mapType = info and info.mapType
    return info and info.name and info.name ~= ""
        and mapType ~= Enum.UIMapType.Cosmic
        and mapType ~= Enum.UIMapType.Phase
        and mapType ~= Enum.UIMapType.AzeriteMap
        and mapType ~= Enum.UIMapType.Orphan
end

local function ProcessBatch()
    for _ = 1, 50 do
        local task = table.remove(stack)
        if not task then
            ready, building = true, false
            for _, listener in ipairs(listeners) do listener() end
            return
        end
        local mapID = task[1]
        if task[2] <= 20 and not seen[mapID] then
            seen[mapID] = true
            local info = C_Map.GetMapInfo(mapID)
            if info then
                if IsMapVisible(info) then
                    maps[#maps + 1] = { kind = "map", mapID = mapID,
                        name = info.name, icon = "Interface\\Icons\\INV_Misc_Map_01" }
                end
                for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID) or {}) do
                    stack[#stack + 1] = { child.mapID, task[2] + 1 }
                end
            end
        end
    end
    C_Timer.After(0, ProcessBatch)
end

local function EnsureIndex()
    if ready or building or not C_Map or not C_Map.GetMapInfo
        or not C_Map.GetMapChildrenInfo or not C_Timer then return end
    stack, seen = {}, {}
    for index = #roots, 1, -1 do
        stack[#stack + 1] = { roots[index], 0 }
    end
    building = true
    C_Timer.After(0, ProcessBatch)
end

function MapSearch.Subscribe(listener)
    listeners[#listeners + 1] = listener
end

function MapSearch.GetContextMapID()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        return WorldMapFrame:GetMapID()
    end
    return C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetBestMapForUnit("player")
end

function MapSearch.ParseCoordinates(query)
    local text = (query or ""):match("^%s*(.-)%s*$"):gsub("，", ",")
    local xText, yText = text:match("^(%S+)%s*,%s*(%S+)$")
    if not xText then xText, yText = text:match("^(%S+)%s+(%S+)$") end
    local function Valid(value)
        return value and (value:match("^%d+$")
            or value:match("^%d+%.%d%d?$"))
    end
    if not Valid(xText) or not Valid(yText) then return end
    local x, y = tonumber(xText), tonumber(yText)
    if x <= 100 and y <= 100 then return x, y end
end

function MapSearch.Find(query, limit)
    local x, y = MapSearch.ParseCoordinates(query)
    if x then
        local mapID = MapSearch.GetContextMapID()
        if mapID then
            return { { kind = "coordinate", mapID = mapID,
                x = x, y = y, icon = "Interface\\Icons\\INV_Misc_Map_01" } }
        end
        return {}
    end
    EnsureIndex()
    local normalized = (query or ""):lower()
    if normalized == "" then return {} end
    local matches = {}
    for _, entry in ipairs(maps) do
        local name = entry.name:lower()
        local position = name:find(normalized, 1, true)
        if position then
            matches[#matches + 1] = { entry = entry,
                score = name == normalized and 0 or position == 1 and 1 or 2 }
        end
    end
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.entry.name ~= b.entry.name then
            return a.entry.name < b.entry.name
        end
        return a.entry.mapID < b.entry.mapID
    end)
    local results = {}
    for index = 1, math.min(limit or 6, #matches) do
        results[index] = matches[index].entry
    end
    return results, building
end

function MapSearch.Activate(entry)
    local mapID = entry and entry.mapID
    if not mapID or not C_Map or not C_Map.GetMapInfo
        or not C_Map.GetMapInfo(mapID) then return false end
    if entry.kind == "coordinate" then
        if not C_Map.SetUserWaypoint or not UiMapPoint
            or not UiMapPoint.CreateFromCoordinates
            or C_Map.CanSetUserWaypointOnMap
                and not C_Map.CanSetUserWaypointOnMap(mapID) then
            return false
        end
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID,
            entry.x / 100, entry.y / 100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_WorldMap")
    end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        local opened = C_Map.OpenWorldMap
            and pcall(C_Map.OpenWorldMap, mapID)
        if not opened and WorldMapFrame then
            pcall(WorldMapFrame.Show, WorldMapFrame)
        end
    end
    if WorldMapFrame and WorldMapFrame:IsShown()
        and WorldMapFrame:GetMapID() ~= mapID then
        return pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
    end
    return WorldMapFrame and WorldMapFrame:IsShown() or false
end

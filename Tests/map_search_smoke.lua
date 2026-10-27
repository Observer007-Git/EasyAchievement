local queued = {}
C_Timer = { After = function(_, callback)
    queued[#queued + 1] = callback
end }
Enum = { UIMapType = { Cosmic = 0, Phase = 1,
    AzeriteMap = 2, Orphan = 3 } }
local mapNames = { [946] = "Azeroth", [100] = "Stormwind City",
    [101] = "Stormsong Valley", [102] = "Dornogal",
    [103] = "Storm Peaks", [104] = "Stormwind Harbor" }
local opened, waypoint, tracked
WorldMapFrame = {
    shown = false, mapID = 100,
    IsShown = function(self) return self.shown end,
    GetMapID = function(self) return self.mapID end,
    SetMapID = function(self, id) self.mapID = id end,
}
C_Map = {
    GetMapInfo = function(id)
        return mapNames[id] and { name = mapNames[id], mapType = 5 }
    end,
    GetMapChildrenInfo = function(id)
        return id == 946 and { { mapID = 100 }, { mapID = 101 },
            { mapID = 102 }, { mapID = 103 }, { mapID = 104 } } or {}
    end,
    GetBestMapForUnit = function(unit)
        assert(unit == "player")
        return 100
    end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(point) waypoint = point end,
    OpenWorldMap = function(id)
        opened = id
        WorldMapFrame.shown = true
        WorldMapFrame.mapID = id
    end,
}
UiMapPoint = { CreateFromCoordinates = function(mapID, x, y)
    return { mapID = mapID, x = x, y = y }
end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(value)
    tracked = value
end }
local addon = {}
assert(loadfile("EasyAchievement/Core/MapSearch.lua"))(
    "EasyAchievement", addon)
local search = addon.MapSearch
local x, y = search.ParseCoordinates(" 22， 22.5 ")
assert(x == 22 and y == 22.5
    and not search.ParseCoordinates("101 22")
    and not search.ParseCoordinates("22 22.555"),
    "coordinate parser must accept only valid 0–100 pairs")
local coord = search.Find("22 22", 6)[1]
assert(coord and coord.kind == "coordinate" and coord.mapID == 100,
    "coordinate result must use the current player map")
WorldMapFrame.shown, WorldMapFrame.mapID = true, 101
coord = search.Find("22 22", 6)[1]
assert(coord.mapID == 101 and search.Activate(coord)
    and waypoint.mapID == 101 and waypoint.x == 0.22
    and waypoint.y == 0.22 and tracked
    and WorldMapFrame.mapID == 101,
    "coordinate selection must track and open the active map")
local highlighted, removed = nil, 0
WorldMapFrame.pinPools = {}
WorldMapFrame.GetCanvas = function() return {} end
WorldMapFrame.AcquirePin = function(_, _, entry) highlighted = entry end
WorldMapFrame.RemoveAllPinsByTemplate = function()
    removed = removed + 1
    highlighted = nil
end
MapCanvasPinMixin = { IsSuppressed = function() return false end }
CreateObjectPool = function(create, reset)
    return { creationFunc = create, resetterFunc = reset }
end
CreateFromMixins = function(mixin) return mixin end
Mixin = function(frame, mixin)
    return setmetatable(frame, { __index = mixin })
end
CreateFrame = function()
    return { EnableMouse = function() end }
end
assert(search.Activate(coord) and #queued == 1 and not highlighted,
    "coordinate highlight must wait for the map canvas")
local highlightPool = WorldMapFrame.pinPools.EasyAchievementCoordinateHighlightPin
local pin = highlightPool.creationFunc()
assert(pin:IsSuppressed() == false,
    "coordinate highlight pin must support map canvas suppression")
table.remove(queued, 1)()
assert(highlighted == coord and #queued == 1,
    "coordinate highlight must mark the selected map position")
local previousTimeout = table.remove(queued, 1)
search.Activate(coord)
table.remove(queued, 1)()
previousTimeout()
assert(highlighted == coord,
    "an older highlight timeout must not clear the new marker")
table.remove(queued, 1)()
assert(not highlighted and removed == 3,
    "coordinate highlight must disappear after its timeout")
local notified = false
search.Subscribe(function() notified = true end)
assert(#search.Find("Storm", 6) == 0 and #queued > 0,
    "map index should build asynchronously")
while #queued > 0 do table.remove(queued, 1)() end
local results = search.Find("Storm", 3)
assert(notified and #results == 3
    and results[1].name == "Storm Peaks"
    and results[2].name == "Stormsong Valley"
    and results[3].name == "Stormwind City"
    and search.Activate(results[3]) and WorldMapFrame.mapID == 100,
    "map search must rank matches and open the chosen map")
WorldMapFrame.shown = false
assert(search.Activate(results[1]) and opened == 103,
    "map result must open the world map when it is closed")
print("coordinate and map search: ok")

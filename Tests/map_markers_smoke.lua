local settings, definitions, callbacks, events = {}, {}, {}, {}
local addon = { L = {} }
function addon:RegisterSetting(key, default, sanitizer)
    definitions[key] = sanitizer
    settings[key] = sanitizer(default)
end
function addon:GetSetting(key) return settings[key] end
function addon:SetSetting(key, value)
    settings[key] = definitions[key](value)
    for _, callback in ipairs(callbacks[key] or {}) do callback() end
end
function addon:RegisterSettingCallback(key, callback)
    callbacks[key] = callbacks[key] or {}
    callbacks[key][#callbacks[key] + 1] = callback
end
function addon:RegisterEvent(event, callback) events[event] = callback end

local scheduled = {}
C_Timer = { After = function(_, callback) scheduled[#scheduled + 1] = callback end }
MapCanvasPinMixin = { IsSuppressed = function() return false end }
MapCanvasDataProviderMixin = {}
CreateObjectPool = function(create, reset)
    return { creationFunc = create, resetterFunc = reset }
end
CreateFromMixins = function(mixin) return setmetatable({}, { __index = mixin }) end
Mixin = function(object, mixin)
    local methods = getmetatable(object).__index
    return setmetatable(object, { __index = function(_, key)
        return mixin[key] or methods[key]
    end })
end
local pinMethods = {}
function pinMethods:CreateTexture()
    return setmetatable({}, { __index = pinMethods })
end
function pinMethods:CreateFontString()
    return setmetatable({}, { __index = pinMethods })
end
function pinMethods:SetScript(name, callback)
    self.scripts = self.scripts or {}
    self.scripts[name] = callback
end
function pinMethods:SetPosition(x, y) self.x, self.y = x, y end
function pinMethods:SetAtlas(atlas) self.atlas = atlas end
function pinMethods:SetText(value) self.text = value end
for _, method in ipairs({ "EnableMouse", "UseFrameLevelType",
    "SetScalingLimits", "SetSize", "SetAllPoints", "SetPoint",
    "SetShown", "RegisterForClicks", "Show", "Hide",
    "ClearAllPoints" }) do
    pinMethods[method] = function() end
end
CreateFrame = function()
    return setmetatable({}, { __index = pinMethods })
end
GameTooltip_Hide = function() end
local map = { pinPools = {}, mapID = 100, acquired = {}, removed = 0 }
function map:GetCanvas() return self end
function map:GetMapID() return self.mapID end
function map:AddDataProvider(provider)
    self.provider = provider
    provider.GetMap = function() return self end
end
function map:RemoveAllPinsByTemplate() self.removed = self.removed + 1 end
function map:AcquirePin(_, entry, index)
    self.acquired[#self.acquired + 1] = { entry, index }
end
WorldMapFrame = map

assert(loadfile("EasyAchievement/Core/MapMarkers.lua"))(
    "EasyAchievement", addon)
local markers = addon.MapMarkers
assert(markers.GetShortcutText() == "Alt" and #scheduled == 1,
    "map marker shortcut must default to Alt + left-click")
local alt, ctrl, shift, meta = true, false, false, false
IsAltKeyDown = function() return alt end
IsControlKeyDown = function() return ctrl end
IsShiftKeyDown = function() return shift end
IsMetaKeyDown = function() return meta end
IsKeyDown = function(key) return key == "K" end
assert(markers.IsShortcutDown(), "default map marker shortcut did not match")
ctrl = true
assert(not markers.IsShortcutDown(),
    "extra modifiers must not trigger map marker creation")
addon:SetSetting("achievementMapMarkerShortcut", { ctrl = true, key = "K" })
alt = false
assert(markers.IsShortcutDown(), "custom map marker shortcut did not match")

table.remove(scheduled, 1)()
assert(map.provider and map.removed == 1,
    "map marker provider did not attach to the world map")
local first = { mapID = 100, x = 22.5, y = 41, name = "Test pin",
    note = "Test note", texture = 19, showName = true, showIcon = true }
assert(markers.Save(nil, first) and #markers.GetAll() == 1
    and map.acquired[1][1].name == "Test pin"
    and map.acquired[1][2] == 1,
    "new map marker was not saved and rendered")
local pin = map.pinPools.EasyAchievementSavedMapPin.creationFunc()
assert(pin:IsSuppressed() == false,
    "saved marker pin must support map canvas suppression")
pin:OnAcquired(markers.GetAll()[1], 1)
assert(pin.x == 0.225 and pin.y == 0.41
    and pin.icon.atlas == "XMarksTheSpot"
    and pin.label.text == "Test pin",
    "world map pin did not use the saved position and atlas")
local editedIndex
markers.OpenEditor = function(index) editedIndex = index end
pin:OnClick("LeftButton")
assert(editedIndex == 1, "left-click on a map pin did not open edit")
editedIndex = nil
MenuUtil = { CreateContextMenu = function()
    error("right-click must not open a map pin menu")
end }
pin:OnClick("RightButton")
assert(not editedIndex and #markers.GetAll() == 1,
    "right-click on a map pin must not edit or delete it")
assert(not markers.Save(nil, { mapID = 100, x = 101, y = 0,
    name = "Invalid" }), "invalid coordinates must be rejected")
assert(markers.Save(1, { mapID = 100, x = 30, y = 40,
    name = "Edited", showName = false, showIcon = false })
    and markers.GetAll()[1].showIcon,
    "editing must keep at least one visible marker element")
map.mapID = 101
map.provider:RefreshAllData()
assert(#map.acquired == 2,
    "markers from another map must not be rendered")
assert(markers.Delete(1) and #markers.GetAll() == 0
    and not markers.Delete(1),
    "map marker deletion did not remove the saved entry")
print("world map markers and shortcut: ok")

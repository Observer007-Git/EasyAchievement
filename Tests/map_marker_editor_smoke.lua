local events, saved, deleted = {}, nil, nil
local markers = { textures = { "MonsterEnemy", "MonsterFriend" } }
function markers.Save(index, entry)
    saved = { index = index, entry = entry }
    return true
end
function markers.Delete(index) deleted = index; return true end
function markers.IsShortcutDown() return true end
local addon = { MapMarkers = markers, L = setmetatable({}, {
    __index = function(_, key) return key end,
}) }
function addon:RegisterEvent(event, callback) events[event] = callback end

local methods = {}
local function Widget()
    return setmetatable({ shown = false, scripts = {} }, { __index = methods })
end
function methods:CreateTexture() return Widget() end
function methods:CreateFontString() return Widget() end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:SetPoint(...) self.point = { ... } end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetShown(value) self.shown = value end
function methods:IsShown() return self.shown end
function methods:Show() self.shown = true end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide() end
end
function methods:GetParent() return self.parent end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return 1 end
for _, method in ipairs({ "SetSize", "SetFrameStrata", "SetFrameLevel",
    "SetClampedToScreen", "EnableMouse", "SetAllPoints",
    "SetAtlas", "SetAlpha", "SetBlendMode", "SetBackdrop",
    "SetBackdropBorderColor", "RegisterForClicks", "SetMaxLetters",
    "SetAutoFocus", "SetJustifyH", "SetColorTexture", "SetTexture",
    "SetFocus", "ClearAllPoints" }) do
    methods[method] = function() end
end
UIParent = Widget()
local editor
CreateFrame = function(_, name, parent)
    local frame = Widget()
    frame.parent = parent
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = frame
    end
    if name == "EasyAchievementMapMarkerEditor" then editor = frame end
    return frame
end
C_Map = { GetMapInfo = function() return { name = "Stormwind" } end }
local canvas = Widget()
local map = Widget()
map.ScrollContainer = canvas
map.mapID = 100
function map:GetMapID() return self.mapID end
function map:GetNormalizedCursorPosition() return 0.22, 0.33 end
WorldMapFrame = map
GetMouseFoci = function() return { canvas } end
GetCursorPosition = function() return 200, 250 end

assert(loadfile("EasyAchievement/Modules/MapMarkerEditor.lua"))(
    "EasyAchievement", addon)
markers.OpenEditor(nil, { mapID = 100, x = 22, y = 33 })
assert(editor.shown and editor.x:GetText() == "22.00"
    and editor.y:GetText() == "33.00" and not editor.delete.shown,
    "new map pin editor did not populate the clicked coordinates")
editor.name:SetText("My pin")
editor.note:SetText("A note")
editor.showName:SetChecked(true)
editor.showIcon:SetChecked(true)
editor.texture = 2
-- Save is a child button; find it through the frame's created children.
local saveButton
for _, child in ipairs(editor.children or {}) do
    if child.scripts.OnClick and child ~= editor.iconButton
        and child ~= editor.delete then
        saveButton = child
        break
    end
end
assert(saveButton, "map pin save button is missing")
saveButton.scripts.OnClick()
assert(saved and saved.index == nil and saved.entry.name == "My pin"
    and saved.entry.texture == 2 and saved.entry.mapID == 100
    and not editor.shown,
    "new map pin did not save the editor fields")
markers.OpenEditor(4, { mapID = 100, x = 12, y = 34,
    name = "Existing", showName = true, showIcon = true })
assert(editor.delete.shown and editor.name:GetText() == "Existing",
    "existing map pin did not open in edit mode")
editor.delete.scripts.OnClick()
assert(deleted == 4 and not editor.shown,
    "existing map pin did not delete from the editor")
map:Show()
events.GLOBAL_MOUSE_DOWN(nil, "LeftButton")
assert(editor.shown and editor.x:GetText() == "22.00"
    and editor.y:GetText() == "33.00",
    "map shortcut did not open the editor at the cursor")
print("map marker editor actions: ok")

local _, Addon = ...

local Markers = {}
Addon.MapMarkers = Markers

Markers.textures = {
    "MonsterEnemy", "MonsterFriend",
    "worldquest-questmarker-epic-supertracked",
    "worldquest-Capstone-questmarker-epic",
    "VignetteEvent-SuperTracked",
    "groupfinder-icon-class-color-deathknight",
    "groupfinder-icon-class-color-priest", "MiniMap-DeadArrow",
    "vignettekillboss-SuperTracked", "poi-traveldirections-arrow2",
    "poi-door-up", "poi-door-down", "poi-door-left", "poi-door-right",
    "CaveUnderground-Down", "CaveUnderground-Up",
    "friendslist-recentallies-Pin", "friendslist-recentallies-Pin-yellow",
    "XMarksTheSpot", "Ping_Map_Whole_OnMyWay",
}

local template = "EasyAchievementSavedMapPin"
local provider, initialized

local function SanitizeShortcut(value)
    if type(value) ~= "table" then return { alt = true } end
    local shortcut = {
        alt = value.alt == true,
        ctrl = value.ctrl == true,
        shift = value.shift == true,
        meta = value.meta == true,
    }
    if type(value.key) == "string" and #value.key <= 20 then
        shortcut.key = value.key
    end
    if not shortcut.alt and not shortcut.ctrl and not shortcut.shift
        and not shortcut.meta and not shortcut.key then
        return { alt = true }
    end
    return shortcut
end

local function SanitizeMarkers(value)
    local markers = {}
    if type(value) ~= "table" then return markers end
    for _, entry in ipairs(value) do
        if type(entry) == "table" then
            local mapID, x, y = tonumber(entry.mapID), tonumber(entry.x),
                tonumber(entry.y)
            local name = type(entry.name) == "string" and entry.name or ""
            if mapID and mapID > 0 and mapID % 1 == 0
                and x and x >= 0 and x <= 100
                and y and y >= 0 and y <= 100
                and name ~= "" and #name <= 120 then
                markers[#markers + 1] = {
                    mapID = mapID, x = x, y = y, name = name,
                    note = type(entry.note) == "string"
                        and entry.note:sub(1, 720) or "",
                    showName = entry.showName ~= false,
                    showIcon = entry.showIcon ~= false
                        or entry.showName == false,
                    texture = Markers.textures[tonumber(entry.texture)]
                        and tonumber(entry.texture) or 1,
                }
            end
        end
    end
    return markers
end

Addon:RegisterSetting("achievementMapMarkerShortcut", { alt = true },
    SanitizeShortcut)
Addon:RegisterSetting("achievementMapMarkers", {}, SanitizeMarkers)

function Markers.GetShortcutText()
    local value = Addon:GetSetting("achievementMapMarkerShortcut")
        or { alt = true }
    local parts = {}
    if value.alt then parts[#parts + 1] = "Alt" end
    if value.ctrl then parts[#parts + 1] = "Ctrl" end
    if value.shift then parts[#parts + 1] = "Shift" end
    if value.meta then parts[#parts + 1] = "Meta" end
    if value.key then parts[#parts + 1] = value.key end
    return table.concat(parts, " + ")
end

function Markers.IsShortcutDown()
    local value = Addon:GetSetting("achievementMapMarkerShortcut")
        or { alt = true }
    return value.alt == (IsAltKeyDown() and true or false)
        and value.ctrl == (IsControlKeyDown() and true or false)
        and value.shift == (IsShiftKeyDown() and true or false)
        and value.meta == (IsMetaKeyDown() and true or false)
        and (not value.key or IsKeyDown(value.key))
end

function Markers.GetAll()
    return Addon:GetSetting("achievementMapMarkers") or {}
end

function Markers.Save(index, entry)
    local saved = {}
    for current, marker in ipairs(Markers.GetAll()) do
        saved[current] = marker
    end
    if index then
        if not saved[index] then return false end
        saved[index] = entry
    else
        saved[#saved + 1] = entry
    end
    local sanitized = SanitizeMarkers(saved)
    if #sanitized ~= #saved then return false end
    Addon:SetSetting("achievementMapMarkers", sanitized)
    return true
end

function Markers.Delete(index)
    local saved = {}
    for current, marker in ipairs(Markers.GetAll()) do
        if current ~= index then saved[#saved + 1] = marker end
    end
    if #saved == #Markers.GetAll() then return false end
    Addon:SetSetting("achievementMapMarkers", saved)
    return true
end

local function CreatePinMixin()
    local mixin = CreateFromMixins(MapCanvasPinMixin)
    function mixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetScalingLimits(1, 0.8, 1.2)
    end
    function mixin:OnAcquired(entry, index)
        if not self.easyAchievementLoaded then
            self.easyAchievementLoaded = true
            self:OnLoad()
        end
        self.entry, self.index = entry, index
        self:SetPosition(entry.x / 100, entry.y / 100)
        self:SetSize(30, 30)
        if not self.icon then
            self.icon = self:CreateTexture(nil, "OVERLAY")
            self.icon:SetAllPoints(self)
            self.label = self:CreateFontString(nil, "OVERLAY",
                "GameFontNormalSmall")
            self.label:SetPoint("CENTER", self, "CENTER", 0, 23)
            self.labelHitbox = CreateFrame("Button", nil, self)
            self.labelHitbox:SetAllPoints(self.label)
            self.labelHitbox:EnableMouse(true)
            self.labelHitbox:RegisterForClicks("LeftButtonUp")
            self.labelHitbox:SetScript("OnClick", function(_, button)
                self:OnClick(button)
            end)
            self.labelHitbox:SetScript("OnEnter", function()
                self:OnMouseEnter()
            end)
            self.labelHitbox:SetScript("OnLeave", function()
                self:OnMouseLeave()
            end)
        end
        self.icon:SetAtlas(Markers.textures[entry.texture] or Markers.textures[1],
            false)
        self.icon:SetShown(entry.showIcon)
        self.label:SetText(entry.name)
        self.label:SetShown(entry.showName)
        self.labelHitbox:SetShown(entry.showName)
        self:Show()
    end
    function mixin:OnReleased()
        self.entry, self.index = nil, nil
        if self.icon then self.icon:Hide() end
        if self.label then self.label:Hide() end
        if self.labelHitbox then self.labelHitbox:Hide() end
        GameTooltip_Hide()
    end
    function mixin:OnMouseEnter()
        if not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry.name)
        GameTooltip:AddLine(string.format("%.2f, %.2f",
            self.entry.x, self.entry.y), 1, 0.82, 0)
        if self.entry.note ~= "" then
            GameTooltip:AddLine(self.entry.note, 0.25, 1, 0.35, true)
        end
        GameTooltip:AddLine(Addon.L.ACHIEVEMENT_MAP_MARKER_HINT,
            0.35, 0.85, 1)
        GameTooltip:Show()
    end
    function mixin:OnMouseLeave() GameTooltip_Hide() end
    function mixin:OnClick(button)
        if button ~= "LeftButton" then return end
        GameTooltip_Hide()
        Markers.OpenEditor(self.index, self.entry)
    end
    mixin.SetPassThroughButtons = function() end
    return mixin
end

function Markers.Initialize()
    local map = WorldMapFrame
    if initialized or not map or not MapCanvasPinMixin
        or not MapCanvasDataProviderMixin or not CreateObjectPool
        or not map.pinPools
        or not map.GetCanvas or not map.AddDataProvider then return end
    local pinMixin = CreatePinMixin()
    local function CreatePin()
        local pin = CreateFrame("Frame", nil, map:GetCanvas())
        pin.isEasyAchievementMapPin = true
        pin:EnableMouse(true)
        return Mixin(pin, pinMixin)
    end
    local function ResetPin(_, pin)
        pin:OnReleased()
        pin:Hide()
        pin:ClearAllPoints()
        pin.pinTemplate = nil
        pin.owningMap = nil
    end
    map.pinPools[template] = CreateObjectPool(CreatePin, ResetPin)
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(template)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        local mapID = self:GetMap():GetMapID()
        for index, entry in ipairs(Markers.GetAll()) do
            if entry.mapID == mapID
                and (entry.showName or entry.showIcon) then
                self:GetMap():AcquirePin(template, entry, index)
            end
        end
    end
    map:AddDataProvider(provider)
    initialized = true
    provider:RefreshAllData()
end

Addon:RegisterSettingCallback("achievementMapMarkers", function()
    if provider then provider:RefreshAllData() end
end)

Addon:RegisterEvent("ADDON_LOADED", function(_, name)
    if name == "Blizzard_WorldMap" then Markers.Initialize() end
end)
if C_Timer and C_Timer.After then
    C_Timer.After(0, function() Markers.Initialize() end)
end

local _, Addon = ...
local Markers = Addon.MapMarkers
local L = Addon.L

local editor

local border = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function MakeButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)
    button:RegisterForClicks("LeftButtonUp")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetAtlas("pet-list-bg-ferocity-active", false)
    background:SetAlpha(0.72)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetAllPoints()
    label:SetText(text)
    label:SetJustifyH("CENTER")
    return button
end

local function MakeInput(parent, labelText, y, maxLetters)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", parent, "TOPLEFT", 18, y)
    label:SetText(labelText)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(158, 24)
    input:SetPoint("RIGHT", parent, "TOPRIGHT", -18, y)
    input:SetAutoFocus(false)
    input:SetMaxLetters(maxLetters)
    return input
end

local function MakeCheck(parent, text, y)
    local check = CreateFrame("CheckButton", nil, parent,
        "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("LEFT", parent, "TOPLEFT", 18, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(text)
    return check
end

local function EnsureEditor()
    if editor then return editor end
    local frame = CreateFrame("Frame", "EasyAchievementMapMarkerEditor",
        UIParent, "BackdropTemplate")
    frame:SetSize(280, 380)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetPoint("TOPLEFT", 3, -3)
    background:SetPoint("BOTTOMRIGHT", -3, 3)
    background:SetAtlas("house-drawing-stone-bg", false)
    frame:SetBackdrop(border)
    frame:SetBackdropBorderColor(0.82, 0.62, 0.25, 1)

    frame.title = frame:CreateFontString(nil, "OVERLAY",
        "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -18)
    frame.mapName = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    frame.mapName:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    frame.name = MakeInput(frame, L.ACHIEVEMENT_MAP_MARKER_NAME, -85, 60)
    frame.note = MakeInput(frame, L.ACHIEVEMENT_MAP_MARKER_NOTE, -118, 360)
    frame.x = MakeInput(frame, "X", -151, 6)
    frame.y = MakeInput(frame, "Y", -184, 6)
    frame.showName = MakeCheck(frame,
        L.ACHIEVEMENT_MAP_MARKER_SHOW_NAME, -220)
    frame.showIcon = MakeCheck(frame,
        L.ACHIEVEMENT_MAP_MARKER_SHOW_ICON, -249)
    frame.iconButton = MakeButton(frame, "", 42)
    frame.iconButton:SetSize(42, 42)
    frame.iconButton:SetPoint("RIGHT", frame, "TOPRIGHT", -18, -288)
    frame.iconPreview = frame.iconButton:CreateTexture(nil, "ARTWORK")
    frame.iconPreview:SetPoint("TOPLEFT", 3, -3)
    frame.iconPreview:SetPoint("BOTTOMRIGHT", -3, 3)
    local iconLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconLabel:SetPoint("LEFT", frame, "TOPLEFT", 18, -288)
    iconLabel:SetText(L.ACHIEVEMENT_MAP_MARKER_TEXTURE)
    frame.iconButton:SetScript("OnClick", function()
        frame.picker:SetShown(not frame.picker:IsShown())
    end)

    local picker = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    picker:SetSize(180, 150)
    picker:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, -267)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(frame:GetFrameLevel() + 10)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    local pickerBackground = picker:CreateTexture(nil, "BACKGROUND", nil, -8)
    pickerBackground:SetPoint("TOPLEFT", 3, -3)
    pickerBackground:SetPoint("BOTTOMRIGHT", -3, 3)
    pickerBackground:SetAtlas("house-drawing-stone-bg", false)
    picker:SetBackdrop(border)
    picker:SetBackdropBorderColor(0.82, 0.62, 0.25, 1)
    for index, atlas in ipairs(Markers.textures) do
        local button = CreateFrame("Button", nil, picker)
        button:SetSize(28, 28)
        button:SetPoint("TOPLEFT", 7 + ((index - 1) % 5) * 34,
            -7 - math.floor((index - 1) / 5) * 34)
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("TOPLEFT", 3, -3)
        texture:SetPoint("BOTTOMRIGHT", -3, 3)
        texture:SetAtlas(atlas, false)
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.2)
        button:SetScript("OnClick", function()
            frame.texture = index
            frame.iconPreview:SetAtlas(atlas, false)
            picker:Hide()
        end)
    end
    frame.picker = picker

    frame.error = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    frame.error:SetPoint("BOTTOM", 0, 46)
    local save = MakeButton(frame, L.ACHIEVEMENT_MAP_MARKER_SAVE, 64)
    save:SetPoint("BOTTOMRIGHT", -12, 15)
    save:SetScript("OnClick", function()
        local name = frame.name:GetText():match("^%s*(.-)%s*$")
        local x, y = tonumber(frame.x:GetText()), tonumber(frame.y:GetText())
        if name == "" or not x or not y or x < 0 or x > 100
            or y < 0 or y > 100 then
            frame.error:SetText(L.ACHIEVEMENT_MAP_MARKER_INVALID)
            return
        end
        if Markers.Save(frame.index, {
            mapID = frame.mapID, x = x, y = y, name = name,
            note = frame.note:GetText(),
            showName = frame.showName:GetChecked() == true,
            showIcon = frame.showIcon:GetChecked() == true,
            texture = frame.texture,
        }) then frame:Hide() end
    end)
    frame.delete = MakeButton(frame, L.ACHIEVEMENT_MAP_MARKER_DELETE, 64)
    frame.delete:SetPoint("BOTTOM", 0, 15)
    frame.delete:SetScript("OnClick", function()
        if Markers.Delete(frame.index) then frame:Hide() end
    end)
    local cancel = MakeButton(frame, L.ACHIEVEMENT_MAP_MARKER_CANCEL, 64)
    cancel:SetPoint("BOTTOMLEFT", 12, 15)
    cancel:SetScript("OnClick", function() frame:Hide() end)
    frame:SetScript("OnHide", function() picker:Hide() end)
    picker:Hide()
    frame:Hide()
    editor = frame
    return frame
end

function Markers.OpenEditor(index, entry)
    local frame = EnsureEditor()
    frame.index = index
    frame.mapID = entry.mapID
    frame.title:SetText(index and L.ACHIEVEMENT_MAP_MARKER_EDIT
        or L.ACHIEVEMENT_MAP_MARKER_ADD)
    local info = C_Map and C_Map.GetMapInfo
        and C_Map.GetMapInfo(entry.mapID)
    frame.mapName:SetText(info and info.name or tostring(entry.mapID))
    frame.name:SetText(index and entry.name or "")
    frame.note:SetText(entry.note or "")
    frame.x:SetText(string.format("%.2f", entry.x))
    frame.y:SetText(string.format("%.2f", entry.y))
    frame.showName:SetChecked(entry.showName ~= false)
    frame.showIcon:SetChecked(entry.showIcon ~= false)
    frame.texture = entry.texture or 1
    frame.iconPreview:SetAtlas(Markers.textures[frame.texture], false)
    frame.delete:SetShown(index ~= nil)
    frame.error:SetText("")
    frame:ClearAllPoints()
    local cursorX, cursorY = GetCursorPosition()
    if cursorX and cursorY then
        local scale = UIParent:GetEffectiveScale()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            cursorX / scale + 140, cursorY / scale)
    else
        frame:SetPoint("CENTER")
    end
    frame:Show()
    frame.name:SetFocus()
end

local function IsOverCanvas()
    local container = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not container then return false end
    if GetMouseFoci then
        local overCanvas = false
        for _, focus in ipairs(GetMouseFoci() or {}) do
            local current = focus
            while current do
                if current.isEasyAchievementMapPin
                    or current.isSearchMakerMapPin then return false end
                if current == container then overCanvas = true end
                current = current.GetParent and current:GetParent() or nil
            end
        end
        return overCanvas
    end
    return container:IsMouseOver()
end

local function GetCursorCoordinates()
    local map = WorldMapFrame
    local x, y
    if map.GetNormalizedCursorPosition then
        x, y = map:GetNormalizedCursorPosition()
    end
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return x * 100, y * 100
    end
    local container = map.ScrollContainer
    local left, right, top, bottom = container:GetLeft(),
        container:GetRight(), container:GetTop(), container:GetBottom()
    if not left or not right or not top or not bottom
        or right == left or top == bottom then return end
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x = (cursorX / scale - left) / (right - left)
    y = (top - cursorY / scale) / (top - bottom)
    if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return x * 100, y * 100
    end
end

Addon:RegisterEvent("GLOBAL_MOUSE_DOWN", function(_, button)
    if button ~= "LeftButton" or not WorldMapFrame
        or not WorldMapFrame:IsShown()
        or not Markers.IsShortcutDown() or not IsOverCanvas() then return end
    local x, y = GetCursorCoordinates()
    local mapID = x and WorldMapFrame:GetMapID()
    if mapID then
        Markers.OpenEditor(nil, { mapID = mapID, x = x, y = y })
    end
end)

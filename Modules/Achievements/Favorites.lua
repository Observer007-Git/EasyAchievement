local _, Addon = ...
local UI = assert(Addon.AchievementUI,
    "EasyAchievement achievement UI environment was not loaded")

-- WoW uses Lua 5.1 semantics; local development uses newer Lua.
-- Both branches bind this chunk to the same addon-private environment.
if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end

function FormatAchievementListProgress(data)
    if data.completed then
        return "|cff33ff33✓|r"
    end
    local completed, total = GetAchievementProgress(data.id)
    if total > 0 then
        return string.format("|cffaaaaaa%d/%d|r", completed, total)
    end
    return ""
end

function MoveAchievementFavorite(sourceID, targetID)
    if sourceID == targetID then
        return
    end
    local favorites = {}
    local source
    for _, achievementID in ipairs(GetAchievementFavorites()) do
        if achievementID == sourceID then
            source = achievementID
        else
            favorites[#favorites + 1] = achievementID
        end
    end
    if not source then
        return
    end
    local reordered = {}
    for _, achievementID in ipairs(favorites) do
        if achievementID == targetID then
            reordered[#reordered + 1] = source
        end
        reordered[#reordered + 1] = achievementID
    end
    Addon:SetSetting("achievementFavorites", reordered)
    if achievementTreeFrame and achievementTreeFrame:IsShown()
        and achievementTreeFrame.sourceAchievementID
    then
        ShowAchievementTree(achievementTreeFrame.sourceAchievementID,
            "refresh")
    end
end

function CreateAchievementFavoritesPanel(anchor)
    if achievementFavoritesPanel then
        achievementFavoritesPanel.Anchor = anchor
        return achievementFavoritesPanel
    end

    local panel = CreateFrame("Frame", "EasyAchievementFavoritesPanel",
        UIParent, "BackdropTemplate")
    panel:SetSize(390, 360)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 7, right = 7, top = 7, bottom = 7 },
    })
    panel:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
    panel:Hide()
    panel.Anchor = anchor
    panel.mode = "favorites"
    panel.rows = {}

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local favoritesTab = CreateFrame("Button", nil, panel,
        "UIPanelButtonTemplate")
    favoritesTab:SetPoint("TOPLEFT", 14, -12)
    favoritesTab:SetSize(92, 22)
    favoritesTab:SetText(L.ACHIEVEMENT_FAVORITES)
    panel.FavoritesTab = favoritesTab

    local recentTab = CreateFrame("Button", nil, panel,
        "UIPanelButtonTemplate")
    recentTab:SetPoint("LEFT", favoritesTab, "RIGHT", 4, 0)
    recentTab:SetSize(92, 22)
    recentTab:SetText(L.ACHIEVEMENT_RECENT)
    panel.RecentTab = recentTab

    local search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
    search:SetPoint("TOPLEFT", 14, -43)
    search:SetPoint("TOPRIGHT", -14, -43)
    search:SetHeight(24)
    search:SetAutoFocus(false)
    panel.Search = search

    local incomplete = CreateFrame("CheckButton", nil, panel,
        "UICheckButtonTemplate")
    incomplete:SetPoint("TOPLEFT", 14, -70)
    incomplete:SetSize(22, 22)
    local incompleteLabel = incomplete:CreateFontString(nil, "OVERLAY",
        "GameFontNormalSmall")
    incompleteLabel:SetPoint("LEFT", incomplete, "RIGHT", 2, 0)
    incompleteLabel:SetText(L.ACHIEVEMENT_FAVORITES_INCOMPLETE)
    panel.IncompleteOnly = incomplete

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("RIGHT", panel, "RIGHT", -18, -81)
    hint:SetText(L.ACHIEVEMENT_FAVORITES_DRAG_HINT)

    local scroll = CreateFrame("ScrollFrame", nil, panel,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -96)
    scroll:SetPoint("BOTTOMRIGHT", -34, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(330, 1)
    scroll:SetScrollChild(content)
    panel.ScrollFrame = scroll
    panel.Content = content

    local empty = content:CreateFontString(nil, "OVERLAY",
        "GameFontDisable")
    empty:SetPoint("TOP", 0, -30)
    panel.EmptyText = empty

    local function AcquireRow(index)
        local row = panel.rows[index]
        if row then
            row:Show()
            return row
        end
        row = CreateFrame("Button", nil, content)
        row:SetHeight(32)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:RegisterForDrag("LeftButton")
        local background = row:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.16, 0.13, 0.08, 0.88)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.8, 0.6, 0.16, 0.25)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", 4, 0)
        icon:SetSize(24, 24)
        icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        row.Icon = icon
        local name = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetPoint("RIGHT", row, "RIGHT", -76, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row.Name = name
        local progress = row:CreateFontString(nil, "OVERLAY",
            "GameFontHighlightSmall")
        progress:SetPoint("RIGHT", row, "RIGHT", -27, 0)
        row.Progress = progress
        local remove = CreateFrame("Button", nil, row,
            "UIPanelCloseButton")
        remove:SetPoint("RIGHT", 1, 0)
        remove:SetSize(20, 20)
        remove:SetScript("OnClick", function()
            if row.achievementID then
                ToggleAchievementFavorite(row.achievementID)
            end
        end)
        row.Remove = remove
        row:SetScript("OnClick", function(self, mouseButton)
            if not self.wasDragged and self.achievementID then
                if mouseButton == "RightButton" then
                    OpenAchievementContextMenu(self,
                        self.achievementID)
                elseif IsShiftKeyDown() then
                    InsertAchievementLink(self.achievementID)
                else
                    panel:Hide()
                    Navigation.OpenCard(self.achievementID)
                end
            end
            self.wasDragged = nil
        end)
        row:SetScript("OnDragStart", function(self)
            if panel.mode == "favorites" then
                panel.draggingID = self.achievementID
                self.wasDragged = true
            end
        end)
        row:SetScript("OnDragStop", function(self)
            if panel.mode == "favorites" and panel.draggingID then
                for _, target in ipairs(panel.rows) do
                    if target:IsShown() and target:IsMouseOver() then
                        MoveAchievementFavorite(panel.draggingID,
                            target.achievementID)
                        break
                    end
                end
                panel.draggingID = nil
                RefreshFavoritesPanel()
                if C_Timer then
                    C_Timer.After(0, function()
                        self.wasDragged = nil
                    end)
                end
            end
        end)
        panel.rows[index] = row
        return row
    end

    RefreshFavoritesPanel = function()
        if not achievementFavoritesPanel then
            return
        end
        local ids = panel.mode == "recent"
            and GetAchievementRecent() or GetAchievementFavorites()
        local query = (panel.Search:GetText() or ""):lower()
        local count = 0
        for _, achievementID in ipairs(ids) do
            local data = GetAchievementData(achievementID)
            local matches = data and (query == ""
                or data.name:lower():find(query, 1, true)
                or tostring(data.id):find(query, 1, true))
            if matches and (not panel.IncompleteOnly:GetChecked()
                or not data.completed)
            then
                count = count + 1
                local row = AcquireRow(count)
                row:SetPoint("TOPLEFT", 0, -(count - 1) * 34)
                row:SetPoint("TOPRIGHT", 0, -(count - 1) * 34)
                row.achievementID = data.id
                row.Icon:SetTexture(data.icon)
                row.Name:SetText(data.name)
                row.Name:SetTextColor(data.completed and 0.2 or 1,
                    data.completed and 1 or 0.82,
                    data.completed and 0.2 or 0.25)
                row.Progress:SetText(FormatAchievementListProgress(data))
                row.Remove:SetShown(panel.mode == "favorites")
            end
        end
        for index = count + 1, #panel.rows do
            panel.rows[index]:Hide()
            panel.rows[index].achievementID = nil
        end
        panel.EmptyText:SetText(panel.mode == "recent"
            and L.ACHIEVEMENT_RECENT_EMPTY
            or L.ACHIEVEMENT_FAVORITES_EMPTY)
        panel.EmptyText:SetShown(count == 0)
        content:SetHeight(math.max(1, count * 34))
        panel.FavoritesTab:SetEnabled(panel.mode ~= "favorites")
        panel.RecentTab:SetEnabled(panel.mode ~= "recent")
    end

    favoritesTab:SetScript("OnClick", function()
        panel.mode = "favorites"
        RefreshFavoritesPanel()
    end)
    recentTab:SetScript("OnClick", function()
        panel.mode = "recent"
        RefreshFavoritesPanel()
    end)
    search:HookScript("OnTextChanged", function()
        RefreshFavoritesPanel()
    end)
    incomplete:SetScript("OnClick", function()
        RefreshFavoritesPanel()
    end)
    panel:SetScript("OnShow", function()
        panel:ClearAllPoints()
        panel:SetPoint("TOPRIGHT", panel.Anchor, "BOTTOMRIGHT", 0, -4)
        RefreshFavoritesPanel()
    end)

    achievementFavoritesPanel = panel
    return panel
end

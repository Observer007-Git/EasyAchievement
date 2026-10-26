local addonName, Addon = ...
local UI = assert(Addon.AchievementUI)
if setfenv then setfenv(1, UI) else _ENV = UI end

local OPTIONS = {
    { key = "card", label = "ACHIEVEMENT_CARD_SCALE",
        controls = "CardScaleControls" },
    { key = "popupScale", label = "ACHIEVEMENT_POPUP_SCALE",
        controls = "PopupScaleControls" },
    { key = "popupAlpha", label = "ACHIEVEMENT_POPUP_ALPHA",
        controls = "PopupAlphaControls" },
    { key = "launcher", label = "ACHIEVEMENT_LAUNCHER_SCALE" },
    { key = "screenIcon", label = "ACHIEVEMENT_LAUNCHER_SHOW" },
    { key = "minimap", label = "ACHIEVEMENT_MINIMAP_SHOW" },
}

local function IsScreenIconVisible()
    return not Addon:GetSetting("achievementLauncherHidden")
        and (tonumber(Addon:GetSetting("achievementLauncherScale")) or 1) > 0
end

local function RefreshPreview(frame)
    local page = frame.SettingsPanel
    if not page or not page.SettingsRows or not page.CardPreview
        or not page.PopupPreview or not page.LauncherPreview then return end
    local key = page.selectedKey
    for optionKey, row in pairs(page.SettingsRows) do
        row.Selected:SetShown(optionKey == key)
        row.ActiveControls:SetShown(optionKey == key)
        if row.Controls then row.Controls:SetShown(optionKey == key) end
        if row.RefreshValue then row.RefreshValue() end
        if row.Check then
            row.Check:SetChecked(optionKey == "minimap"
                and Addon:GetSetting("achievementShowMinimapIcon")
                or optionKey == "screenIcon"
                    and IsScreenIconVisible())
        end
    end
    page.CardPreview:SetShown(key == "card")
    page.PopupPreview:SetShown(key == "popupScale"
        or key == "popupAlpha")
    page.CardPreview:SetScale(GetAchievementCardScale())
    page.PopupPreview:SetScale(GetAchievementPopupScale())
    page.PopupPreview:SetAlpha(GetAchievementPopupAlpha())
    page.LauncherPreview:SetShown(key == "launcher")
end

function HideAchievementSettingsPage(frame)
    if not frame or not frame.settingsPageShown then return end
    frame.settingsPageShown = nil
    frame.SettingsPanel:Hide()
    if frame.SettingsPanel.PopupPreview then
        frame.SettingsPanel.PopupPreview:Hide()
    end
    UpdateAchievementRewardCategoryRail(frame)
end

local function BuildSettingsPage(frame)
    local page = frame.SettingsPanel
    if page.SettingsRows then return true end
    if not LoadAchievementUI() then return false end
    page:SetFrameLevel(frame:GetFrameLevel() + 45)
    local rows = {}
    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", page, "TOPLEFT", 222, 0)
    divider:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 222, 0)
    divider:SetWidth(1)
    divider:SetColorTexture(0.45, 0.31, 0.1, 0.8)

    local card = CreateFrame("Button", nil, page, "AchievementTemplate")
    card:SetPoint("CENTER", page, "CENTER", 110, 0)
    card:EnableMouse(false)
    card.EasyAchievementPopup = true
    card.GetElementData = function(self) return self.EasyAchievementElementData end
    local objectives = CreateFrame("Frame", nil, card,
        "AchievementFrameAchievementsObjectivesTemplate")
    card.GetObjectiveFrame = function() return objectives end
    local sample = GetAchievementData(6)
    if sample then
        card.EasyAchievementElementData = { id = sample.id }
        card:Init(card.EasyAchievementElementData)
    end
    page.CardPreview = card

    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(20)
    popup:SetSize(434, 142)
    popup:SetPoint("CENTER", page, "CENTER", 110, 0)
    popup:EnableMouse(false)
    local popupCard = CreateFrame("Button", nil, popup,
        "AchievementTemplate")
    popupCard:SetPoint("TOPLEFT")
    popupCard:EnableMouse(false)
    popupCard.EasyAchievementPopup = true
    popupCard.GetElementData = function(self)
        return self.EasyAchievementElementData
    end
    local popupObjectives = CreateFrame("Frame", nil, popupCard,
        "AchievementFrameAchievementsObjectivesTemplate")
    popupCard.GetObjectiveFrame = function() return popupObjectives end
    if sample then
        popupCard.EasyAchievementElementData = { id = sample.id }
        popupCard:Init(popupCard.EasyAchievementElementData)
    end
    page.PopupPreview = popup
    page:HookScript("OnHide", function() popup:Hide() end)

    local launcher = page:CreateTexture(nil, "ARTWORK")
    launcher:SetPoint("CENTER", page, "CENTER", 110, 0)
    launcher:SetSize(64, 82)
    if not SetTextureAtlas(launcher,
        "UI-HUD-MicroMenu-Achievements-Up")
        and not SetTextureAtlas(launcher,
            "UI-HUD-MicroMenu-Achievements-Up-2x")
    then
        launcher:SetTexture("Interface\\AchievementFrame\\UI-Achievement-TinyShield")
    end
    page.LauncherPreview = launcher

    for index, option in ipairs(OPTIONS) do
        local row = CreateFrame("Button", nil, page)
        row:SetSize(212, 28)
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 4,
            -8 - (index - 1) * 30)
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetAllPoints()
        SetTextureAtlas(selected, "Options_List_Active")
        row.Selected = selected
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        SetTextureAtlas(hover, "Options_List_Hover")
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 12, 0)
        label:SetText(L[option.label])
        row.ActiveControls = CreateFrame("Frame", nil, page)
        row.ActiveControls:SetPoint("TOPLEFT", page, "TOPLEFT", 246, -18)
        row.ActiveControls:SetSize(300, 32)
        if option.controls then
            local controls = frame[option.controls]
            controls:SetParent(row.ActiveControls)
            controls:ClearAllPoints()
            controls:SetPoint("LEFT")
            row.Controls = controls
        elseif option.key == "screenIcon" or option.key == "minimap" then
            local check = CreateFrame("CheckButton", nil,
                row.ActiveControls, "UICheckButtonTemplate")
            check:SetPoint("LEFT")
            check:SetSize(24, 24)
            check:SetChecked(option.key == "minimap"
                and Addon:GetSetting("achievementShowMinimapIcon")
                or option.key == "screenIcon"
                    and IsScreenIconVisible())
            check:SetScript("OnClick", function(self)
                if option.key == "minimap" then
                    Addon:SetSetting("achievementShowMinimapIcon",
                        self:GetChecked() == true)
                else
                    local checked = self:GetChecked() == true
                    if checked and
                        (tonumber(Addon:GetSetting("achievementLauncherScale"))
                            or 1) <= 0
                    then
                        Addon:SetSetting("achievementLauncherScale", 1)
                    end
                    Addon:SetSetting("achievementLauncherHidden",
                        not checked)
                end
            end)
            row.Check = check
            if option.key == "screenIcon" then
                local hint = row.ActiveControls:CreateFontString(nil,
                    "OVERLAY", "GameFontHighlightSmall")
                hint:SetPoint("LEFT", check, "RIGHT", 8, 0)
                hint:SetWidth(340)
                hint:SetJustifyH("LEFT")
                hint:SetText(L.ACHIEVEMENT_LAUNCHER_REOPEN_HINT)
                row.Hint = hint
            end
        elseif option.key == "launcher" then
            local minus = CreateFrame("Button", nil,
                row.ActiveControls, "UIPanelButtonTemplate")
            minus:SetPoint("LEFT")
            minus:SetSize(24, 24)
            minus:SetText("-")
            local value = row.ActiveControls:CreateFontString(nil,
                "OVERLAY", "GameFontHighlight")
            value:SetPoint("LEFT", minus, "RIGHT", 12, 0)
            value:SetWidth(48)
            local plus = CreateFrame("Button", nil,
                row.ActiveControls, "UIPanelButtonTemplate")
            plus:SetPoint("LEFT", value, "RIGHT", 12, 0)
            plus:SetSize(24, 24)
            plus:SetText("+")
            local function UpdateValue()
                local scale = tonumber(Addon:GetSetting(
                    "achievementLauncherScale")) or 1
                value:SetText(string.format("%d%%", math.floor(
                    scale * 100 + 0.5)))
                launcher:SetSize(64 * scale, 82 * scale)
                minus:SetEnabled(scale > 0)
                plus:SetEnabled(scale < 1)
            end
            row.RefreshValue = UpdateValue
            row.ScaleMinus = minus
            row.ScalePlus = plus
            minus:SetScript("OnClick", function()
                Addon:SetSetting("achievementLauncherScale",
                    (tonumber(Addon:GetSetting(
                        "achievementLauncherScale")) or 1) - 0.05)
                UpdateValue()
            end)
            plus:SetScript("OnClick", function()
                Addon:SetSetting("achievementLauncherScale",
                    (tonumber(Addon:GetSetting(
                        "achievementLauncherScale")) or 1) + 0.05)
                UpdateValue()
            end)
            UpdateValue()
        end
        row:SetScript("OnClick", function()
            page.selectedKey = option.key
            RefreshPreview(frame)
        end)
        rows[option.key] = row
    end
    local gameVersion = page:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    gameVersion:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 16, 48)
    gameVersion:SetText(string.format(L.ACHIEVEMENT_GAME_VERSION,
        GetBuildInfo()))
    page.GameVersion = gameVersion
    local dataVersion = page:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    dataVersion:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 16, 30)
    dataVersion:SetText(string.format(L.ACHIEVEMENT_DATA_VERSION,
        Addon.AchievementRewardDatabase.build))
    page.DataVersion = dataVersion
    local addonVersion = page:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    addonVersion:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 16, 12)
    addonVersion:SetText(string.format(L.ACHIEVEMENT_ADDON_VERSION,
        C_AddOns.GetAddOnMetadata(addonName, "Version")))
    page.AddonVersion = addonVersion
    page.selectedKey = "card"
    page.SettingsRows = rows
    RefreshPreview(frame)
    return true
end

function ShowAchievementSettingsPage(frame)
    if not BuildSettingsPage(frame) then return end
    frame.settingsPageShown = true
    frame.ScrollFrame:Hide()
    frame.HorizontalScroll:Hide()
    frame.BackButton:Hide()
    frame.ForwardButton:Hide()
    frame.Breadcrumb:Hide()
    frame.TreeScaleControls:Hide()
    frame.IncompleteOnly:Hide()
    frame.IncompleteOnlyLabel:Hide()
    frame.FitButton:Hide()
    frame.Navigator:Hide()
    frame.ATTButton:Hide()
    if frame.AchievementCard then
        frame.AchievementCard:Hide()
        frame.AchievementCardHeader:Hide()
        frame.AchievementCardTreeButton:Hide()
        frame.AchievementCardBackButton:Hide()
        frame.AchievementCardForwardButton:Hide()
        frame.AchievementCardCategoryPosition:Hide()
        frame.AchievementCardCategoryReturnButton:Hide()
    end
    if frame.AchievementCardList then frame.AchievementCardList:Hide() end
    if frame.OfficialCategoryBrowser then
        frame.OfficialCategoryBrowser.pane:Hide()
        frame.OfficialCategoryBrowser.right:Hide()
        frame.OfficialCategoryBrowser.incompleteOnly:Hide()
    end
    if achievementRewardFrame then achievementRewardFrame:Hide() end
    frame.SettingsPanel:Show()
    RefreshPreview(frame)
    UpdateAchievementRewardCategoryRail(frame)
end

for _, key in ipairs({ "achievementCardScale",
    "achievementPopupScale", "achievementPopupAlpha",
    "achievementLauncherScale", "achievementLauncherHidden",
    "achievementShowMinimapIcon" }) do
    Addon:RegisterSettingCallback(key, function()
        if achievementTreeFrame and achievementTreeFrame.settingsPageShown then
            RefreshPreview(achievementTreeFrame)
        end
    end)
end

local callbacks = {}
local settings = {
    achievementCardScale = 1,
    achievementPopupScale = 1,
    achievementPopupAlpha = 1,
    achievementLauncherScale = 1,
}
local addon = { MapMarkers = { GetShortcutText = function()
    return "Alt"
end }, L = setmetatable({
    ACHIEVEMENT_LAUNCHER_REOPEN_HINT =
        "Click the minimap icon or type /eat to open the panel again",
    ACHIEVEMENT_GAME_VERSION = "Game version: %s",
    ACHIEVEMENT_DATA_VERSION = "Data version: %s",
    ACHIEVEMENT_ADDON_VERSION = "Addon version: V%s",
}, { __index = function(_, key)
    return key
end }), AchievementRewardDatabase = { build = "12.1.5.70575" } }
function addon:GetSetting(key) return settings[key] end
function addon:SetSetting(key, value)
    settings[key] = value
    for _, callback in ipairs(callbacks[key] or {}) do callback() end
end
function addon:RegisterSettingCallback(key, callback)
    callbacks[key] = callbacks[key] or {}
    table.insert(callbacks[key], callback)
end
assert(loadfile("EasyAchievement/Modules/AchievementUI.lua"))(
    "EasyAchievement", addon)
local ui = addon.AchievementUI
ui.L = addon.L
local achievementUILoaded = false
ui.GetAchievementData = function(id)
    return id == 6 and { id = 6 } or nil
end
ui.GetAchievementCardScale = function()
    return settings.achievementCardScale
end
ui.GetAchievementPopupScale = function()
    return settings.achievementPopupScale
end
ui.GetAchievementPopupAlpha = function()
    return settings.achievementPopupAlpha
end
ui.SetTextureAtlas = function(texture, atlas)
    texture.atlas = atlas
    return true
end
ui.SetAchievementShieldAtlas = function(texture, width)
    ui.SetTextureAtlas(texture, "UI-Achievement-Shield-Desaturated")
    texture:SetSize(width, width * 58 / 80)
    return true
end
ui.CreateAchievementShieldBrightness = function() end
ui.UpdateAchievementRewardCategoryRail = function() end
ui.LoadAchievementUI = function() return achievementUILoaded end

local methods = {}
local function Widget()
    return setmetatable({ shown = false, scripts = {} }, { __index = methods })
end
function methods:SetShown(shown) self.shown = shown end
function methods:Show() self.shown = true end
function methods:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback) self.scripts[event] = callback end
function methods:GetFrameLevel() return 1 end
function methods:Init(data)
    assert(achievementUILoaded, "native achievement template was not loaded")
    self.initializedID = data.id
end
function methods:CreateTexture() return Widget() end
function methods:CreateFontString() return Widget() end
function methods:SetPoint(...) self.point = { ... } end
function methods:SetSize(width, height)
    self.width, self.height = width, height
end
for _, name in ipairs({ "SetWidth", "SetHeight",
    "SetColorTexture", "SetAllPoints", "SetTextColor",
    "SetJustifyH", "SetWordWrap", "SetParent", "ClearAllPoints",
    "EnableMouse", "SetFrameStrata", "SetFrameLevel",
    "SetTexture" }) do
    methods[name] = function() end
end
function methods:EnableKeyboard(value) self.keyboard = value end
function methods:SetPropagateKeyboardInput() end
function methods:SetText(value) self.text = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetVertexColor(...) self.vertexColor = { ... } end
function methods:SetScale(scale) self.scale = scale end
function methods:SetAlpha(alpha) self.alpha = alpha end
ui.CreateFrame = function() return Widget() end
ui.UIParent = Widget()
local page = Widget()
GetBuildInfo = function() return "12.1.5", "70575" end
C_AddOns = { GetAddOnMetadata = function(name, key)
    assert(name == "EasyAchievement" and key == "Version")
    return "1.0.0"
end }
InCombatLockdown = function() return false end
IsAltKeyDown = function() return false end
IsControlKeyDown = function() return true end
IsShiftKeyDown = function() return false end
IsMetaKeyDown = function() return false end
local frame = { SettingsPanel = page, ScrollFrame = Widget(),
    GetFrameLevel = function() return 1 end }
for _, name in ipairs({ "HorizontalScroll", "BackButton", "ForwardButton",
    "Breadcrumb", "TreeScaleControls", "IncompleteOnly",
    "IncompleteOnlyLabel", "FitButton", "Navigator", "ATTButton" }) do
    frame[name] = Widget()
end
for _, name in ipairs({ "CardScaleControls", "PopupScaleControls",
    "PopupAlphaControls" }) do
    frame[name] = Widget()
end
ui.achievementTreeFrame = frame
assert(loadfile("EasyAchievement/Modules/Achievements/SettingsPage.lua"))(
    "EasyAchievement", addon)
ui.ShowAchievementSettingsPage(frame)
assert(not page.SettingsRows and not frame.settingsPageShown,
    "unavailable native templates must not leave a half-built settings page")
achievementUILoaded = true
ui.ShowAchievementSettingsPage(frame)
assert(frame.settingsPageShown and page.shown
    and page.SettingsRows.card.Selected.shown
    and page.CardPreview.shown and not page.PopupPreview.shown,
    "settings tab did not open the in-panel card preview")
assert(page.CardPreview.initializedID == 6,
    "settings card preview must initialize after native UI loading")
assert(page.LauncherPreview.atlas == "UI-HUD-MicroMenu-Achievements-Up",
    "launcher preview did not use the screen icon atlas")
assert(page.GameVersion.text == "Game version: 12.1.5.70575"
    and page.DataVersion.text == "Data version: |cff40d94012.1.5.70575|r"
    and page.AddonVersion.text == "Addon version: V1.0.0",
    "settings footer did not show the game and TOC versions")
addon.AchievementRewardDatabase.build = "12.1.5.70576"
page.SettingsRows = nil
ui.ShowAchievementSettingsPage(frame)
assert(page.DataVersion.text == "Data version: |cffff404012.1.5.70576|r",
    "outdated data version must be shown in red")
addon:SetSetting("achievementCardScale", 0.7)
assert(page.CardPreview.scale == 0.7,
    "card preview did not react to live scale changes")
page.SettingsRows.popupScale.scripts.OnClick()
assert(page.PopupPreview.shown and not page.CardPreview.shown,
    "popup-size setting did not show its topmost preview")
addon:SetSetting("achievementPopupScale", 0.8)
assert(page.PopupPreview.scale == 0.8,
    "popup preview did not react to scale changes")
page.SettingsRows.popupAlpha.scripts.OnClick()
addon:SetSetting("achievementPopupAlpha", 0.6)
assert(page.PopupPreview.alpha == 0.6,
    "popup preview did not react to opacity changes")
page.SettingsRows.launcher.scripts.OnClick()
assert(not page.SettingsRows.launcher.ScalePlus.enabled,
    "launcher scale plus must be disabled at 100%")
addon:SetSetting("achievementLauncherScale", 0.5)
assert(page.LauncherPreview.width == 32
    and page.LauncherPreview.height == 41
    and page.LauncherPreview.point[1] == "CENTER"
    and page.LauncherPreview.point[5] == 0
    and page.SettingsRows.launcher.ScalePlus.enabled,
    "launcher preview size changed without keeping its center anchor")
addon:SetSetting("achievementLauncherScale", 1)
assert(not page.SettingsRows.launcher.ScalePlus.enabled,
    "launcher scale plus did not gray out again at 100%")
addon:SetSetting("achievementLauncherScale", 0)
assert(not page.SettingsRows.launcher.ScaleMinus.enabled
    and not page.SettingsRows.screenIcon.Check.checked,
    "zero icon scale must disable minus and uncheck the effective visibility")
page.SettingsRows.screenIcon.scripts.OnClick()
assert(not page.SettingsRows.screenIcon.Check.checked
    and page.SettingsRows.screenIcon.Hint.text ==
        "Click the minimap icon or type /eat to open the panel again"
    and not page.LauncherPreview.shown and not page.MinimapPreview,
    "screen icon setting duplicated its preview or missed the reopen hint")
addon:SetSetting("achievementLauncherHidden", true)
assert(not page.SettingsRows.screenIcon.Check.checked,
    "the right-side checkbox did not reflect screen icon visibility")
page.SettingsRows.screenIcon.Check:SetChecked(true)
page.SettingsRows.screenIcon.Check.scripts.OnClick(
    page.SettingsRows.screenIcon.Check)
assert(not settings.achievementLauncherHidden,
    "the right-side checkbox did not restore the screen icon")
assert(settings.achievementLauncherScale == 1
    and page.SettingsRows.screenIcon.Check.checked,
    "restoring the screen icon did not reset zero scale")
page.SettingsRows.minimap.scripts.OnClick()
assert(not page.LauncherPreview.shown and not page.MinimapPreview,
    "minimap setting unexpectedly showed an icon preview")
page.SettingsRows.mapMarkerShortcut.scripts.OnClick()
local shortcutButton = page.SettingsRows.mapMarkerShortcut.ShortcutButton
shortcutButton.scripts.OnClick()
assert(shortcutButton.isCapturing and shortcutButton.keyboard,
    "map marker shortcut did not start capture")
shortcutButton.scripts.OnKeyDown(nil, "K")
assert(settings.achievementMapMarkerShortcut.ctrl
    and settings.achievementMapMarkerShortcut.key == "K"
    and not shortcutButton.keyboard,
    "map marker shortcut did not save the captured chord")
shortcutButton.scripts.OnClick()
shortcutButton.scripts.OnKeyDown(nil, "ESCAPE")
assert(settings.achievementMapMarkerShortcut.alt,
    "Escape did not restore the default map marker shortcut")
ui.HideAchievementSettingsPage(frame)
assert(not frame.settingsPageShown and not page.shown
    and not page.PopupPreview.shown,
    "settings preview did not close with its page")
print("settings page navigation and live previews: ok")

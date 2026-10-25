local addon = { AchievementUI = {} }
assert(loadfile("EasyAchievement/Modules/Achievements/Content.lua"))(
    "EasyAchievement", addon)

local calls = 0
addon.AchievementUI.LayoutAchievementTree = function()
    calls = calls + 1
end
local frame = {
    layoutNodes = { { id = 1 } },
    layoutEdges = {},
    layoutRoot = { id = 1 },
    settingsPageShown = true,
}
addon.AchievementContent.Relayout(frame)
assert(calls == 0,
    "resizing settings must not redraw the previous category or card")
frame.settingsPageShown = nil
addon.AchievementContent.Relayout(frame)
assert(calls == 1,
    "resizing after leaving settings must still relayout the active page")
print("settings resize keeps the previous page hidden: ok")

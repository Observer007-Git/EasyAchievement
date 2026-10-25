local addon = { AchievementUI = {} }
local ui = addon.AchievementUI
setmetatable(ui, { __index = _G })
ui.MIN_TREE_SCALE = 0.2
ui.MAX_TREE_SCALE = 1.5
ui.TREE_SCALE_STEP = 0.01
local saves = 0
ui.SaveAchievementTreeState = function() saves = saves + 1 end
assert(loadfile("EasyAchievement/Modules/Achievements/Tree.lua"))(
    "EasyAchievement", addon)

local value = 1
local frame = {
    layoutNodes = { {} },
    ScrollFrame = { IsShown = function() return true end },
    ScaleSlider = {
        GetValue = function() return value end,
        SetValue = function(_, nextValue) value = nextValue end,
    },
    IsShown = function() return true end,
}
ui.ZoomAchievementTreeWithWheel(frame, 1)
assert(math.abs(value - 1.05) < 0.000001 and saves == 1,
    "wheel up should zoom the tree in by five percent")
ui.ZoomAchievementTreeWithWheel(frame, -1)
assert(math.abs(value - 1) < 0.000001 and saves == 2,
    "wheel down should zoom the tree out")
value = 1.5
ui.ZoomAchievementTreeWithWheel(frame, 1)
assert(value == 1.5 and saves == 2,
    "wheel zoom must respect the maximum scale")
value = 0.2
ui.ZoomAchievementTreeWithWheel(frame, -1)
assert(value == 0.2 and saves == 2,
    "wheel zoom must respect the minimum scale")
frame.rewardCategoryMode = {}
ui.ZoomAchievementTreeWithWheel(frame, 1)
assert(value == 0.2 and saves == 2,
    "category pages must not zoom with the wheel")
frame.rewardCategoryMode = nil
frame.cardOnlyAchievementID = 10
ui.ZoomAchievementTreeWithWheel(frame, 1)
assert(value == 0.2 and saves == 2,
    "card pages must not zoom with the wheel")

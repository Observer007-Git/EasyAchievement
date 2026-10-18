local expectedUIModules = {
    "Modules/AchievementUI.lua",
    "Modules/Achievements/Core.lua",
    "Modules/Achievements/Tooltip.lua",
    "Modules/Achievements/RewardPanel.lua",
    "Modules/Achievements/Cards.lua",
    "Modules/Achievements/Favorites.lua",
    "Modules/Achievements/Window.lua",
    "Modules/Achievements/Navigator.lua",
    "Modules/Achievements/Tree.lua",
    "Modules/Achievements/Search.lua",
    "Modules/Achievements/Launcher.lua",
}

local toc = assert(io.open("EasyAchievement/EasyAchievement.toc", "r"))
local tocSource = toc:read("*a")
toc:close()

local rewardDatabasePosition = assert(tocSource:find(
    "Data/AchievementRewardDatabase.lua", 1, true),
    "generated achievement reward database is missing from the TOC")
local rewardModulePosition = assert(tocSource:find(
    "Modules/AchievementRewards.lua", 1, true),
    "achievement reward module is missing from the TOC")
assert(rewardDatabasePosition < rewardModulePosition,
    "achievement reward database must load before the reward module")

assert(not tocSource:find("Modules/Achievements%.lua"),
    "legacy monolithic achievement module is still loaded")
assert(io.open("EasyAchievement/Modules/Achievements.lua", "r") == nil,
    "legacy monolithic achievement module still exists")

local previousPosition = 0
for _, relativePath in ipairs(expectedUIModules) do
    local position = assert(tocSource:find(relativePath, 1, true),
        relativePath .. " is missing from the TOC")
    assert(position > previousPosition,
        relativePath .. " is loaded in the wrong order")
    previousPosition = position

    local path = "EasyAchievement/" .. relativePath
    local file = assert(io.open(path, "r"), path .. " does not exist")
    local source = file:read("*a")
    file:close()
    local _, lineCount = source:gsub("\n", "\n")
    assert(lineCount < 1500,
        path .. " is too large and should be split further")
end

local function ReadSource(relativePath)
    local file = assert(io.open("EasyAchievement/" .. relativePath, "r"))
    local source = file:read("*a")
    file:close()
    return source
end

local launcherSource = ReadSource("Modules/Achievements/Launcher.lua")
assert(launcherSource:find(
    'RegisterForClicks("LeftButtonUp", "RightButtonUp")', 1, true)
    and launcherSource:find("CreateAchievementFavoritesPanel(self)", 1,
        true),
    "launcher right click is not connected to favorites management")

local searchSource = ReadSource("Modules/Achievements/Search.lua")
assert(searchSource:find("OpenAchievementATTGuide(achievementID)", 1, true),
    "achievement context menu is not connected to the ATT guide")

local windowSource = ReadSource("Modules/Achievements/Window.lua")
assert(windowSource:find("OpenAchievementATTGuide(frame.sourceAchievementID)",
        1, true),
    "top-right ATT guide button is not connected")

local treeSource = ReadSource("Modules/Achievements/Tree.lua")
local cardsSource = ReadSource("Modules/Achievements/Cards.lua")
assert(treeSource:find("OpenAchievementContextMenu", 1, true),
    "achievement nodes do not expose the shared context menu")
assert(cardsSource:find("OpenAchievementContextMenu", 1, true),
    "achievement cards do not expose the shared context menu")

local rewardPanelSource = ReadSource("Modules/Achievements/RewardPanel.lua")
assert(rewardPanelSource:find('previewEntry.rewardType == "mount"', 1,
        true)
    and rewardPanelSource:find("and 240 or 54", 1, true),
    "mount model bottom offset is not 240 pixels")
assert(rewardPanelSource:find('description:SetJustifyH("CENTER")', 1,
        true)
    and rewardPanelSource:find("local headerLeft = -headerWidth / 2", 1,
        true)
    and rewardPanelSource:find("GetUnboundedStringWidth", 1, true),
    "reward header information is not horizontally centered")
assert(rewardPanelSource:find("collections-itemborder-collected", 1, true)
    and rewardPanelSource:find("PetJournal-BattleSlot-IconBorder", 1, true)
    and rewardPanelSource:find('rewardType == "mount"', 1, true)
    and rewardPanelSource:find('rewardType == "pet"', 1, true)
    and rewardPanelSource:find('rewardType == "decor"', 1, true)
    and rewardPanelSource:find('rewardType == "appearance"', 1, true),
    "collection rewards do not use native icon borders")
assert(rewardPanelSource:find("minimumHostWidth = showModel and 940", 1,
        true)
    and rewardPanelSource:find("hostFrame:GetWidth() * 0.46", 1, true)
    and rewardPanelSource:find('"TOPLEFT", 8, -118 - extraHeight', 1,
        true)
    and rewardPanelSource:find('"BOTTOMRIGHT", -8, modelBottomOffset', 1,
        true),
    "3D reward model area is not using the widened layout")

print("achievement UI module structure: ok")

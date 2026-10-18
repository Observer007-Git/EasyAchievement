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
assert(searchSource:find("local collapsedHeight = 32", 1, true)
    and searchSource:find(
        "search:SetMaxLetters(MAX_ACHIEVEMENT_SEARCH_CHARACTERS)", 1,
        true)
    and searchSource:find(
        "panel:SetWidth(GetAchievementSearchBoxWidth(search) + 8)", 1,
        true),
    "launcher search dimensions or input limit changed")
assert(searchSource:find(
        'local resultsBackground = panel:CreateTexture(nil, "BACKGROUND")',
        1, true)
    and searchSource:find(
        "resultsBackground:SetColorTexture(0.025, 0.025, 0.025, 0.96)",
        1, true)
    and searchSource:find("resultsBackground:Show()", 1, true)
    and searchSource:find("resultsBackground:Hide()", 1, true),
    "launcher search results do not have a managed background")

local coreSource = ReadSource("Modules/Achievements/Core.lua")
assert(coreSource:find("MAX_ACHIEVEMENT_SEARCH_CHARACTERS = 12", 1, true)
    and coreSource:find(
        'string.rep("汉", MAX_ACHIEVEMENT_SEARCH_CHARACTERS)', 1, true),
    "search width is not based on 12 Chinese characters")

local windowSource = ReadSource("Modules/Achievements/Window.lua")
assert(windowSource:find("OpenAchievementATTGuide(frame.sourceAchievementID)",
        1, true),
    "top-right ATT guide button is not connected")
assert(windowSource:find(
        "searchBox:SetMaxLetters(MAX_ACHIEVEMENT_SEARCH_CHARACTERS)", 1,
        true)
    and windowSource:find(
        "local searchBoxWidth = GetAchievementSearchBoxWidth(searchBox)",
        1, true)
    and windowSource:find("local breadcrumbArrowHeight = 34", 1, true)
    and windowSource:find(
        'backButton:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 70, -112)',
        1, true),
    "main search limit or breadcrumb navigation size changed")
assert(windowSource:find('"GM-icon-settings-pressed"', 1, true)
    and windowSource:find('"GM-icon-settings-hover"', 1, true)
    and windowSource:find("settingsButton:SetSize(28, 28)", 1, true)
    and windowSource:find(
        "CreateScaleControls(frame)",
        1, true)
    and windowSource:find(
        'treeScaleControls:SetPoint("RIGHT", fitButton, "LEFT", -8, 0)',
        1, true)
    and windowSource:find("popupAlphaPlus = CreateScaleControls(", 1,
        true)
    and windowSource:find("L.ACHIEVEMENT_POPUP_ALPHA", 1, true)
    and not windowSource:find("frame.StatsDivider", 1, true)
    and not windowSource:find("frame.ControlsDivider", 1, true)
    and windowSource:find("frame.TreeDivider = CreateGoldDivider(-80)",
        1, true)
    and windowSource:find(
        'scrollFrame:SetPoint("TOPLEFT", 24, -114)', 1, true),
    "compact settings layout changed")

local treeSource = ReadSource("Modules/Achievements/Tree.lua")
local cardsSource = ReadSource("Modules/Achievements/Cards.lua")
assert(treeSource:find("OpenAchievementContextMenu", 1, true),
    "achievement nodes do not expose the shared context menu")
assert(treeSource:find('"ConduitIconFrame-Corners"', 1, true)
    and treeSource:find(
        'CreateTexture(nil, "OVERLAY", nil, 3)', 1, true)
    and treeSource:find('local inset = 1', 1, true)
    and treeSource:find(
        'rewardBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)',
        1, true)
    and treeSource:find(
        'rewardBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)',
        1, true)
    and treeSource:find(
        "Addon.AchievementRewards.Has(node.id, node)", 1, true),
    "rewarded achievement icons do not use a scale-aware atlas border")
assert(cardsSource:find("OpenAchievementContextMenu", 1, true)
    and cardsSource:find('"duit_Arrows_Socketed"', 1, true)
    and cardsSource:find(
        'CreateTexture(nil, "OVERLAY", nil, 7)', 1, true)
    and cardsSource:find("rewardBorder:SetAllPoints(icon)", 1, true)
    and cardsSource:find(
        "Addon.AchievementRewards.Has(data.id, data)", 1, true),
    "achievement cards do not expose the shared context menu")

local rewardPanelSource = ReadSource("Modules/Achievements/RewardPanel.lua")
assert(rewardPanelSource:find('description:SetJustifyH("CENTER")', 1,
        true)
    and rewardPanelSource:find("20 + contentCenterOffset", 1, true)
    and rewardPanelSource:find("-20 + contentCenterOffset", 1, true)
    and rewardPanelSource:find(
        "local headerLeft = contentCenterOffset - headerWidth / 2", 1,
        true)
    and rewardPanelSource:find("GetUnboundedStringWidth", 1, true),
    "reward header information is not horizontally centered")
assert(rewardPanelSource:find(
        'rewardFrame:SetPoint("TOPRIGHT", hostFrame, "TOPRIGHT", -24, -115)',
        1, true),
    "reward panel did not expand into the compacted header space")
assert(rewardPanelSource:find("collections-itemborder-collected", 1, true)
    and rewardPanelSource:find("PetJournal-BattleSlot-IconBorder", 1, true)
    and rewardPanelSource:find('rewardType == "mount"', 1, true)
    and rewardPanelSource:find('rewardType == "pet"', 1, true)
    and rewardPanelSource:find('rewardType == "decor"', 1, true)
    and rewardPanelSource:find('rewardType == "appearance"', 1, true),
    "collection rewards do not use native icon borders")
assert(rewardPanelSource:find(
        "counterCenterOffset = showModel and -126 - extraHeight", 1,
        true)
    and rewardPanelSource:find(
        "local MODEL_SCENE_LEFT_OFFSET = -200", 1, true)
    and rewardPanelSource:find(
        "local MODEL_SCENE_RIGHT_OFFSET = 24", 1, true)
    and rewardPanelSource:find(
        "(MODEL_SCENE_LEFT_OFFSET + MODEL_SCENE_RIGHT_OFFSET) / 2",
        1, true)
    and rewardPanelSource:find(
        'rewardFrame.EntryCounter:SetPoint("CENTER", rewardFrame, "TOP"',
        1, true)
    and rewardPanelSource:find(
        "local modelTopOffset = hasMultipleEntries", 1, true)
    and rewardPanelSource:find(
        '"TOPLEFT", MODEL_SCENE_LEFT_OFFSET, modelTopOffset', 1,
        true)
    and rewardPanelSource:find(
        '"BOTTOMRIGHT", MODEL_SCENE_RIGHT_OFFSET, -20)', 1,
        true)
    and rewardPanelSource:find(
        'contentCenterOffset, counterCenterOffset', 1, true)
    and rewardPanelSource:find(
        'contentCenterOffset, 18)', 1, true)
    and rewardPanelSource:find(
        'local headerLeft = contentCenterOffset - headerWidth / 2', 1,
        true),
    "reward information and controls are not centered on the model viewport")
assert(rewardPanelSource:find("local function FitMountRewardModel", 1, true)
    and rewardPanelSource:find(
        "pcall(actor.GetActiveBoundingBox, actor)", 1, true)
    and rewardPanelSource:find(
        "actor:SetUseCenterForOrigin(true, true, true)", 1, true)
    and rewardPanelSource:find("camera:SetTarget(0, 0, 0)", 1, true)
    and rewardPanelSource:find("fitDistance * 1.2", 1, true)
    and rewardPanelSource:find("modelScene:OnMouseWheel(-1)", 1, true),
    "mount models are not centered and fitted to the reward viewport")

print("achievement UI module structure: ok")

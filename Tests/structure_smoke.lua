local expectedUIModules = {
    "Modules/AchievementUI.lua",
    "Modules/Achievements/Core.lua",
    "Modules/Achievements/Navigation.lua",
    "Modules/Achievements/Tooltip.lua",
    "Modules/Achievements/RewardPanel.lua",
    "Modules/Achievements/Cards.lua",
    "Modules/Achievements/Window.lua",
    "Modules/Achievements/Navigator.lua",
    "Modules/Achievements/Tree.lua",
    "Modules/Achievements/RewardCategories.lua",
    "Modules/Achievements/OfficialCategories.lua",
    "Modules/Achievements/Search.lua",
    "Modules/Achievements/Content.lua",
    "Modules/Achievements/Launcher.lua",
    "Modules/Achievements/SettingsPage.lua",
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
local rewardDatabaseAPIPosition = assert(tocSource:find(
    "Core/AchievementRewardDatabase.lua", 1, true),
    "achievement reward database API is missing from the TOC")
assert(rewardDatabasePosition < rewardDatabaseAPIPosition
    and rewardDatabaseAPIPosition < rewardModulePosition,
    "achievement reward database and API load order is invalid")
assert(tocSource:find("Modules/Achievements/Launcher.lua", 1, true)
        < tocSource:find("Modules/Achievements/SettingsPage.lua", 1, true),
    "settings preview callbacks must load after their settings are registered")

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

local rewardDatabaseSource = ReadSource(
    "Data/AchievementRewardDatabase.lua")
local navigationSource = ReadSource("Modules/Achievements/Navigation.lua")
assert(rewardDatabaseSource:find("schema=2", 1, true)
    and rewardDatabaseSource:find("rewards={", 1, true)
    and not rewardDatabaseSource:find("records={", 1, true)
    and not rewardDatabaseSource:find("categories={", 1, true),
    "generated achievement reward database is not using schema 2")
assert(rewardDatabaseSource:find("factions={", 1, true),
    "generated achievement faction metadata is missing")
local rewardDatabaseAPISource = ReadSource(
    "Core/AchievementRewardDatabase.lua")
assert(rewardDatabaseAPISource:find("function Database.GetReward", 1, true)
    and rewardDatabaseAPISource:find(
        "function Database.HasCategory", 1, true)
    and rewardDatabaseAPISource:find("function Database.GetFaction", 1, true),
    "reward database access is not isolated behind its API")

local launcherSource = ReadSource("Modules/Achievements/Launcher.lua")
local windowSource = ReadSource("Modules/Achievements/Window.lua")
assert(windowSource:find(
        "local function LayoutCurrentTree()\n        if frame.settingsPageShown then",
        1, true)
    and windowSource:find(
        "if not self.settingsPageShown and not self.updatingLayout",
        1, true),
    "resizing the settings page still schedules the previous tree layout")
assert(launcherSource:find(
    'RegisterForClicks("LeftButtonUp", "RightButtonUp")', 1, true)
    and launcherSource:find("CreateAchievementLauncherSettings(self)", 1,
        true)
    and launcherSource:find('"achievementLauncherScale"', 1, true)
    and launcherSource:find('"achievementLauncherHidden"', 1, true)
    and launcherSource:find('"achievementShowMinimapIcon"', 1, true)
    and launcherSource:find('_G.SLASH_EASYACHIEVEMENT1 = "/eat"', 1,
        true)
    and launcherSource:find("CreateAchievementMinimapButton()", 1, true)
    and launcherSource:find('border:SetPoint("TOPLEFT")', 1, true)
    and launcherSource:find('self:RegisterEvent("GLOBAL_MOUSE_DOWN")',
        1, true)
    and launcherSource:find('self:UnregisterEvent("GLOBAL_MOUSE_DOWN")',
        1, true)
    and launcherSource:find('not self:IsMouseOver()', 1, true)
    and launcherSource:find('not self.Owner:IsMouseOver()', 1, true)
    and launcherSource:find('hideLauncher.Label:GetStringWidth()',
        1, true)
    and not launcherSource:find("CreateAchievementFavoritesPanel(self)", 1,
        true),
    "launcher settings, slash command, or minimap entry is not configured")
assert(not launcherSource:find("enableAchievementEnhancement", 1, true)
    and not launcherSource:find("ApplyAchievementEnhancement", 1, true),
    "standalone addon retained the obsolete LiteTools enable switch")
assert(launcherSource:find('achievementLauncher:SetScale(scale)', 1, true)
    and launcherSource:find(
        'Addon.Anchors:Position(achievementLauncher,', 1, true),
    "launcher scale must restore its saved screen position")
assert(launcherSource:find('"UI-HUD-MicroMenu-Achievements-Up"', 1, true)
    and launcherSource:find(
        '"UI-HUD-MicroMenu-Achievements-Mouseover"', 1, true)
    and launcherSource:find('self.Icon:Hide()', 1, true)
    and launcherSource:find('self.Icon:Show()', 1, true),
    "screen launcher icon must use native up and mouseover atlases")

local searchSource = ReadSource("Modules/Achievements/Search.lua")
assert(searchSource:find("OpenAchievementATTGuide(achievementID)", 1, true),
    "achievement context menu is not connected to the ATT guide")
assert(searchSource:find(
        "if cardOnlyAchievementID == achievementID then", 1, true)
    and searchSource:find("nodes, edges = { root }, {}", 1, true),
    "card-only navigation still builds the full achievement tree")
assert(searchSource:find("SaveAchievementRewardCategoryState(frame)",
        1, true)
    and searchSource:find(
        'RecordAchievementNavigation(frame, replace)', 1, true),
    "category card navigation does not preserve its separate list history")
assert(searchSource:find("local collapsedHeight = 32", 1, true)
    and searchSource:find(
        "search:SetMaxLetters(MAX_ACHIEVEMENT_SEARCH_CHARACTERS)", 1,
        true)
    and searchSource:find(
        "panel:SetWidth(GetAchievementSearchBoxWidth(search) + 8)", 1,
        true),
    "launcher search dimensions or input limit changed")
assert(searchSource:find(
        'local searchBackground = search.Background',
        1, true)
    and searchSource:find('searchBackground:SetParent(anchor)', 1, true)
    and searchSource:find(
        "searchBackground:SetSize(inputOffsetX + panel:GetWidth()",
        1, true)
    and searchSource:find('panel:HookScript("OnHide", function()',
        1, true),
    "launcher search does not retain the rounded background around the icon")
assert(searchSource:find("CreateAchievementLauncherSearch(anchor, icon)",
    1, true) and searchSource:find(
        "local inputOffsetX = (anchor:GetWidth() + icon:GetWidth()) / 2 + 1",
        1, true) and searchSource:find(
        "search:SetTextInsets(0, 22, 0, 0)", 1,
    true) and searchSource:find("search.searchIcon:Hide()", 1, true),
    "launcher search input does not start one pixel beyond the icon")
assert(searchSource:find(
        'local resultsBackground = panel:CreateTexture(nil, "BACKGROUND")',
        1, true)
    and searchSource:find("ShowResults(true)", 1, true)
    and searchSource:find("ShowResults(false)", 1, true)
    and searchSource:find(
        'resultsBackground:SetPoint("TOPLEFT", search, "BOTTOMLEFT"',
        1, true)
    and searchSource:find(
        'resultsBackground:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)',
        1, true)
    and searchSource:find('roundedBottom:SetSize(inputOffsetX + panel:GetWidth(), anchorHeight)',
        1, true)
    and searchSource:find('SetTextureAtlas(roundedBottom, searchBackground:GetAtlas())',
        1, true)
    and searchSource:find('roundedBottom:SetTexCoord(searchBackground:GetTexCoord())',
        1, true)
    and searchSource:find('roundedBottom:SetShown(shown)', 1, true)
    and searchSource:find('edge:SetColorTexture(0.38, 0.35, 0.29, 0.9)',
        1, true)
    and searchSource:find('searchBackground:SetWidth(anchor:GetWidth()',
        1, true)
    and searchSource:find(
        'row:SetPoint("TOPLEFT", resultsBackground, "TOPLEFT"',
        1, true)
    and searchSource:find('separatorBase:SetPoint("TOPLEFT", row, "TOPLEFT")',
        1, true)
    and searchSource:find('separatorBase:SetPoint("TOPRIGHT", row, "TOPRIGHT")',
        1, true)
    and searchSource:find('separator:SetPoint("LEFT", row, "TOPLEFT")',
        1, true)
    and searchSource:find('separator:SetPoint("RIGHT", row, "TOPRIGHT")',
        1, true)
    and searchSource:find('SetTextureAtlas(separator, "AftLevelup-GlowLine")',
        1, true)
    and searchSource:find('highlight:SetAllPoints()', 1, true)
    and searchSource:find(
        'highlight:SetTexture("Interface\\\\QuestFrame\\\\UI-QuestTitleHighlight")',
        1, true)
    and searchSource:find('highlight:SetBlendMode("ADD")', 1, true)
    and searchSource:find('highlight:SetAlpha(0.75)', 1, true)
    and searchSource:find(
        'icon:SetPoint("LEFT", (anchor:GetWidth() - 20) / 2, 0)',
        1, true)
    and searchSource:find(
        'name:SetPoint("LEFT", row, "LEFT", inputOffsetX, 0)',
        1, true)
    and searchSource:find("and not anchor:IsMouseOver() and not overResults",
        1, true),
    "launcher search results are not aligned with the bar and icon")
assert(searchSource:find('messageRow:SetHeight(28)', 1, true)
    and searchSource:find('messageRow:EnableMouse(false)', 1, true)
    and searchSource:find('message:SetPoint("LEFT", messageRow, "LEFT", inputOffsetX, 0)', 1, true)
    and searchSource:find('messageSeparator:SetPoint("LEFT", messageRow, "TOPLEFT")', 1, true)
    and searchSource:find('messageRow:SetShown(shown == 0)', 1, true)
    and searchSource:find('math.max(shown, 1) * 28', 1, true),
    "launcher empty-search message must occupy one non-clickable result row")

local coreSource = ReadSource("Modules/Achievements/Core.lua")
assert(coreSource:find("MAX_ACHIEVEMENT_SEARCH_CHARACTERS = 12", 1, true)
    and coreSource:find(
        'string.rep("汉", MAX_ACHIEVEMENT_SEARCH_CHARACTERS)', 1, true),
    "search width is not based on 12 Chinese characters")
assert(coreSource:find("function ReleaseAchievementSearch(owner)", 1, true)
    and searchSource:find("ReleaseAchievementSearch(panel)", 1, true),
    "launcher search does not release the native search state")

local windowSource = ReadSource("Modules/Achievements/Window.lua")
assert(windowSource:find("OpenAchievementATTGuide(self.achievementID",
        1, true)
    and windowSource:find("or frame.sourceAchievementID)", 1, true),
    "ATT guide button is not connected to the displayed achievement")
assert(windowSource:find("ReleaseAchievementSearch(frame)", 1, true),
    "main search does not release the native search state")
assert(windowSource:find(
        "searchBox:SetMaxLetters(MAX_ACHIEVEMENT_SEARCH_CHARACTERS)", 1,
        true)
    and windowSource:find(
        "local searchBoxWidth = GetAchievementSearchBoxWidth(searchBox)",
        1, true)
    and windowSource:find("local breadcrumbArrowHeight = 34", 1, true)
    and windowSource:find(
        'backButton:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 24, -130)',
        1, true),
    "main search limit or breadcrumb navigation size changed")
assert(windowSource:find('closeButton:SetPoint("TOPRIGHT", 1, -1)',
        1, true)
    and windowSource:find("closeButton:SetSize(20, 20)", 1, true)
    and windowSource:find(
        'settingsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -135)',
        1, true)
    and windowSource:find(
        "CreateScaleControls(frame)",
        1, true)
    and windowSource:find(
        'treeScaleControls:SetPoint("RIGHT", frame, "TOPRIGHT", -24, -113)',
        1, true)
    and windowSource:find("popupAlphaPlus = CreateScaleControls(", 1,
        true)
    and windowSource:find("L.ACHIEVEMENT_POPUP_ALPHA", 1, true)
    and not windowSource:find("frame.ShowLauncher", 1, true)
    and not windowSource:find("frame.StatsDivider", 1, true)
    and not windowSource:find("frame.ControlsDivider", 1, true)
    and not windowSource:find("CreateGoldDivider", 1, true)
    and windowSource:find(
        'headerRow:SetFrameLevel(borderFrame:GetFrameLevel() + 3)',
        1, true)
    and windowSource:find(
        'portraitIconFrame:SetFrameLevel(borderFrame:GetFrameLevel())',
        1, true)
    and windowSource:find(
        'scrollFrame:SetPoint("TOPLEFT", 24, -135)', 1, true)
    and windowSource:find(
        'horizontalScroll:SetPoint("BOTTOMLEFT", 46, 6)', 1, true),
    "store-style header or settings layout changed")
assert(windowSource:find('portraitIcon:SetSize(58, 58)', 1, true)
    and windowSource:find(
        'portraitMask:SetPoint("TOPLEFT", portraitIcon, "TOPLEFT", 2, 0)',
        1, true)
    and windowSource:find(
        'background:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)', 1, true)
    and windowSource:find(
        'background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)',
        1, true)
    and not windowSource:find('portraitBackground:SetColorTexture(',
        1, true),
    "portrait art and inset panel background must remain inside the border")
assert(not windowSource:find("railToggle", 1, true)
    and not windowSource:find("allAchievementsButton", 1, true),
    "the old edge toggle or standalone achievements button remains")

local treeSource = ReadSource("Modules/Achievements/Tree.lua")
local cardsSource = ReadSource("Modules/Achievements/Cards.lua")
local tooltipSource = ReadSource("Modules/Achievements/Tooltip.lua")
local rewardCategoriesSource = ReadSource(
    "Modules/Achievements/RewardCategories.lua")
local searchSource = ReadSource("Modules/Achievements/Search.lua")
assert(treeSource:find(
        'frame.TreeScaleControls:SetPoint("RIGHT", frame.ATTButton,',
        1, true)
    and treeSource:find(
        'frame.ATTButton:SetPoint("RIGHT", frame, "TOPRIGHT", -24, -113)',
        1, true)
    and cardsSource:find('local actionButtons = {}', 1, true)
    and cardsSource:find(
        'ipairs({ categoryReturnButton, treeButton,', 1, true)
    and cardsSource:find('totalWidth = totalWidth + button:GetWidth()',
        1, true)
    and cardsSource:find('button:SetPoint("TOPLEFT", anchor, "BOTTOM",',
        1, true)
    and cardsSource:find('"RIGHT", gap, 0)', 1, true)
    and cardsSource:find('attButton.achievementID = data.id', 1, true),
    "ATT button must avoid tree scale and follow the displayed card")
assert(windowSource:find('fitButton:SetPoint("RIGHT", frame, "RIGHT", -4, 0)',
        1, true)
    and windowSource:find('fitButton:SetSize(52, 52)', 1, true)
    and windowSource:find('fitArrow:SetSize(48, 48)', 1, true)
    and windowSource:find('FitAchievementTreeToWindow(frame)', 1, true)
    and windowSource:find('"decor-controls-exit-active"', 1, true)
    and windowSource:find('breadcrumb:SetPoint("RIGHT", treeScaleControls',
        1, true)
    and treeSource:find('frame.FitButton:Hide()', 1, true)
    and treeSource:find('viewportWidth - calculatedLayout.requiredWidth',
        1, true)
    and treeSource:find('frame.FitButton.Arrow:SetRotation(hasExtraSpace and math.pi or 0)',
        1, true)
    and treeSource:find('frame.FitButton:SetShown(horizontalMaximum > 0.5 or hasExtraSpace)',
        1, true)
    and not windowSource:find('local fitBackground', 1, true)
    and not windowSource:find('local toggleBackground', 1, true)
    and not windowSource:find('local fitHighlight =', 1, true)
    and windowSource:find('fitMotion:SetLooping("REPEAT")', 1, true)
    and windowSource:find('self.HoverMotion:Play()', 1, true)
    and windowSource:find('self.HoverMotion:Stop()', 1, true)
    and not windowSource:find('local toggleHighlight =', 1, true),
    "fit control must indicate both horizontal overflow and excess space")
assert(rewardCategoriesSource:find(
        'bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -31)', 1, true)
    and rewardCategoriesSource:find('"shop-header-menu-selected-left"',
        1, true)
    and rewardCategoriesSource:find('"shop-header-menu-selected-right"',
        1, true)
    and rewardCategoriesSource:find('bar:SetHeight(32)', 1, true)
    and rewardCategoriesSource:find(
        'background:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, -4)',
        1, true)
    and rewardCategoriesSource:find(
        'background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, -4)',
        1, true)
    and windowSource:find(
        'borderFrame:SetFrameLevel(frame:GetFrameLevel() + 103)',
        1, true)
    and rewardCategoriesSource:find('background:SetHeight(46)', 1, true)
    and rewardCategoriesSource:find('button:SetHeight(32)', 1, true)
    and rewardCategoriesSource:find(
        'label:SetPoint("CENTER", button, "CENTER", 0, 2)', 1, true)
    and rewardCategoriesSource:find('content:SetSize(1, 38)', 1, true)
    and windowSource:find(
        'searchBox:SetPoint("RIGHT", frame, "TOPRIGHT", -24, -45)',
        1, true)
    and windowSource:find(
        'favoritesDivider:SetPoint("TOPLEFT", favoritesScroll, "BOTTOMLEFT",',
        1, true)
    and windowSource:find(
        'favoritesDivider:SetColorTexture(0.38, 0.27, 0.10, 0.85)',
        1, true)
    and not windowSource:find('frame.HeaderBackground', 1, true)
    and windowSource:find('title:SetPoint("CENTER", headerRow, "CENTER")',
        1, true),
    "top reward tabs do not use the store-style navigation")
assert(treeSource:find('frame.OfficialCategoryBrowser.pane:GetWidth()',
        1, true)
    and treeSource:find('and frame.IncompleteOnly or frame.TreeScaleControls',
        1, true)
    and searchSource:find('frame.breadcrumbLeftOffset or 82', 1, true),
    "breadcrumbs can overlap the expanded category pane or tree filter")
assert(not windowSource:find("frame.Legend", 1, true)
    and not treeSource:find("frame.Legend", 1, true)
    and not cardsSource:find("frame.Legend", 1, true),
    "obsolete tree legend must not be created or referenced")
assert(windowSource:find('scrollFrame:EnableMouseWheel(true)', 1, true)
    and windowSource:find('ZoomAchievementTreeWithWheel(frame, delta)',
        1, true)
    and treeSource:find('button:EnableMouseWheel(true)', 1, true)
    and treeSource:find('frame.rewardCategoryMode or frame.cardOnlyAchievementID',
        1, true),
    "tree wheel zoom must work on empty space and nodes, but not cards or lists")
assert(windowSource:find("CreateAchievementRewardCategoryRail(frame)",
        1, true)
    and rewardCategoriesSource:find('key = "all"', 1, true)
    and rewardCategoriesSource:find('key = "settings"', 1, true)
    and rewardCategoriesSource:find('ShowAchievementRewardCategory(tab.key)',
        1, true)
    and rewardCategoriesSource:find('ShowAchievementSettingsPage(frame)',
        1, true),
    "top tabs do not use the existing achievement and reward navigation")
assert(treeSource:find("OpenAchievementContextMenu", 1, true),
    "achievement nodes do not expose the shared context menu")
assert(treeSource:find('"SoulBinds_Collection_Charge_Pending"', 1, true)
    and treeSource:find(
        'CreateTexture(nil, "OVERLAY", nil, 7)', 1, true)
    and treeSource:find(
        'rewardMarker:SetPoint("CENTER", icon, "TOPRIGHT")',
        1, true)
    and treeSource:find("button.RewardMarker:SetSize(markerSize, markerSize)",
        1, true)
    and treeSource:find('"RIGHT", button.RewardMarker, "LEFT", 0, 0)',
        1, true)
    and treeSource:find(
        "Addon.AchievementRewards.Has(node.id, node.data)", 1, true),
    "rewarded achievement icons do not use a scale-aware corner marker")
assert(cardsSource:find("OpenAchievementContextMenu", 1, true)
    and cardsSource:find('"SoulBinds_Collection_Charge_Pending"', 1, true)
    and cardsSource:find(
        'CreateTexture(nil, "OVERLAY", nil, 7)', 1, true)
    and cardsSource:find(
        'rewardMarker:SetPoint("CENTER", icon, "TOPRIGHT")', 1, true)
    and cardsSource:find("rewardMarker:SetSize(12, 12)", 1, true)
    and cardsSource:find(
        "Addon.AchievementRewards.Has(data.id, data)", 1, true),
    "achievement cards do not expose the shared context menu")
for _, category in ipairs({ "mount", "pet", "toy", "decor", "title",
    "appearance", "other" })
do
    assert(rewardCategoriesSource:find('key = "' .. category .. '"',
            1, true),
        "reward category menu is missing " .. category)
end
assert(rewardCategoriesSource:find(
        "RewardDatabase.GetAchievementIDs()", 1, true)
    and rewardCategoriesSource:find(
        "RewardDatabase.HasCategory(achievementID", 1, true)
    and not rewardCategoriesSource:find(
        "Addon.AchievementRewards.Get(achievementID)", 1, true)
    and rewardCategoriesSource:find(
        "RecordAchievementNavigation(frame)", 1, true)
    and rewardCategoriesSource:find(
        'Addon:GetSetting("achievementRewardCategoryStates")', 1, true)
    and rewardCategoriesSource:find(
        "frame.pendingHorizontalScroll = state and state.horizontal or 0",
        1, true)
    and rewardCategoriesSource:find(
        "frame.pendingVerticalScroll = state and state.vertical or 0",
        1, true)
    and rewardCategoriesSource:find(
        "LayoutAchievementTree(nodes, {}, root", 1, true)
    and rewardCategoriesSource:find(
        "achievementIDs = orderedAchievementIDs", 1, true)
    and rewardCategoriesSource:find(
        "OpenAchievementRewardCategoryCard = function", 1, true)
    and rewardCategoriesSource:find(
        "NavigateAchievementRewardCategoryCard = function", 1, true)
    and rewardCategoriesSource:find(
        "ReturnToAchievementRewardCategory = function", 1, true)
    and treeSource:find("local categoryMode = frame.rewardCategoryMode",
        1, true)
    and treeSource:find("availableHeight = availableTreeHeight", 1, true),
    "reward categories do not use the dynamic draggable tree grid")
assert(cardsSource:find("frame.rewardCategoryCardContext", 1, true)
    and cardsSource:find(
        "NavigateAchievementRewardCategoryCard(frame, -1)", 1, true)
    and cardsSource:find(
        "NavigateAchievementRewardCategoryCard(frame, 1)", 1, true)
    and cardsSource:find(
        "L.ACHIEVEMENT_REWARD_CATEGORY_POSITION", 1, true)
    and cardsSource:find(
        "L.ACHIEVEMENT_REWARD_CATEGORY_RETURN", 1, true)
    and cardsSource:find("GetCurrentKeyBoardFocus", 1, true)
    and cardsSource:find(
        "ReturnToAchievementRewardCategory(frame)", 1, true),
    "category cards do not use their displayed order and return control")
assert(cardsSource:find('local CARD_LIST_ROW_HEIGHT = 26', 1, true)
    and cardsSource:find('row:SetShown(id ~= nil)', 1, true)
    and cardsSource:find('row.Selected:SetShown(index == active.index)',
        1, true)
    and cardsSource:find('self.index - active.index', 1, true)
    and cardsSource:find(
        'UpdateAchievementCardList(frame, categoryContext or treeContext, card)',
        1, true)
    and cardsSource:find('list:SetPoint("TOPRIGHT", frame, "TOPLEFT"',
        1, true)
    and treeSource:find('frame.AchievementCardList:Hide()', 1, true)
    and cardsSource:find('UpdateAchievementCardList(frame, categoryContext or treeContext, card)',
        1, true),
    "card list must follow category or tree selection and avoid narrow layouts")
assert(navigationSource:find('frame.treeCardContext = page.treeCardContext',
        1, true)
    and navigationSource:find('function NavigateAchievementTreeCard(frame, offset)',
        1, true)
    and cardsSource:find('NavigateAchievementTreeCard(frame, -1)', 1, true)
    and cardsSource:find('NavigateAchievementTreeCard(frame, 1)', 1, true),
    "tree card navigation does not retain its source tree list")
assert(cardsSource:find("frame:EnableKeyboard(true)", 1, true)
    and cardsSource:find('if key == "LEFT" then', 1, true)
    and cardsSource:find('elseif key == "RIGHT" then', 1, true)
    and cardsSource:find("self.SearchBox:HasFocus()", 1, true)
    and cardsSource:find("navigationButton:Click()", 1, true),
    "achievement cards do not support left/right keyboard navigation")
assert(tooltipSource:find(
        "local reward = Addon.AchievementRewards.Get(node.id)", 1, true)
    and tooltipSource:find(
        "GameTooltip:AddLine(rewardDescription, 1, 0.82, 0, true)",
        1, true),
    "achievement tooltips do not show the yellow reward description")

local rewardPanelSource = ReadSource("Modules/Achievements/RewardPanel.lua")
assert(rewardPanelSource:find('detailsButton:SetScript("OnClick"',
        1, true),
    "reward detail button does not open the expanded description")
assert(not rewardPanelSource:find("ItemType", 1, true),
    "reward panel still contains a reward-type prefix")
assert(not windowSource:find("RewardOpenParen", 1, true)
    and not windowSource:find("RewardSummary", 1, true)
    and not windowSource:find("RewardCloseParen", 1, true),
    "main panel still contains the parenthesized reward summary")
local rewardsSource = ReadSource("Modules/AchievementRewards.lua")
assert(rewardsSource:find(
        "local ACHIEVEMENT_MOUNT_SOURCE_TYPE = 5", 1, true)
    and rewardsSource:find(
        "sourceType == ACHIEVEMENT_MOUNT_SOURCE_TYPE", 1, true),
    "mount text fallback is not limited to achievement-source mounts")
assert(rewardPanelSource:find('local infoCard = CreateFrame("Frame", nil, frame)',
        1, true)
    and rewardPanelSource:find('"generic-frame-chamfered-12d-2o"',
        1, true)
    and rewardPanelSource:find('"GameFontNormalHuge3"', 1, true)
    and rewardPanelSource:find('"SystemFont_Small2"', 1, true)
    and rewardPanelSource:find('L.ACHIEVEMENT_REWARD_DETAILS', 1, true)
    and rewardPanelSource:find('infoCard:SetSize(224, 150)', 1, true)
    and rewardPanelSource:find('rewardFrame.ItemName:SetJustifyH("CENTER")',
        1, true)
    and not rewardPanelSource:find('local infoBackground', 1, true),
    "reward information does not use the shop-style detail card")
assert(rewardPanelSource:find(
        'rewardFrame:SetPoint("TOPRIGHT", hostFrame, "TOPRIGHT", -24, -135)',
        1, true),
    "reward panel is not aligned below the new header")
assert(not rewardPanelSource:find("ItemIcon", 1, true)
    and rewardPanelSource:find('itemName:SetTextColor(1, 1, 1)', 1, true)
    and rewardPanelSource:find('detailsText:SetWidth(200)', 1, true)
    and not rewardPanelSource:find('detailsScroll', 1, true),
    "reward info card must have a large white name and unscrolled details")
assert(rewardPanelSource:find(
        "local MODEL_SCENE_LEFT_OFFSET = -200", 1, true)
    and rewardPanelSource:find(
        "local MODEL_SCENE_RIGHT_OFFSET = 24", 1, true)
    and rewardPanelSource:find(
        "(MODEL_SCENE_LEFT_OFFSET + MODEL_SCENE_RIGHT_OFFSET) / 2",
        1, true)
    and not rewardPanelSource:find(
        '"ShadowOverlayTemplate"', 1, true)
    and rewardPanelSource:find(
        '"TOPLEFT", MODEL_SCENE_LEFT_OFFSET, -10', 1,
        true)
    and rewardPanelSource:find(
        '"BOTTOMRIGHT", MODEL_SCENE_RIGHT_OFFSET, 48)', 1,
        true)
    and rewardPanelSource:find(
        'contentCenterOffset, -6)', 1, true)
    and rewardPanelSource:find(
        'contentCenterOffset, 65)', 1, true),
    "reward selectors and model controls are not below the model")
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

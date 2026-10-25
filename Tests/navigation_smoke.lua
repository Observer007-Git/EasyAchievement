local settings = {}
local addon = {
    L = setmetatable({ ACHIEVEMENT_REWARD_CATEGORY_MOUNT = "Mounts",
        ACHIEVEMENT_REWARD_TAB = "Reward %s" },
        { __index = function(_, key) return key end }),
    Config = {
        Tree = { MinScale = 0.2, MaxScale = 1.5 },
        State = { MaxTreeStates = 50, MaxHistoryEntries = 100 },
    },
    RewardDatabase = {
        GetFaction = function() end,
        GetAchievementIDs = function()
            return { 101, 102, 103, 104, 105, 106, 107, 108, 109 }
        end,
        HasCategory = function(_, category) return category == "mount" end,
    },
}
function addon:GetSetting(key) return settings[key] end
function addon:SetSetting(key, value) settings[key] = value end
assert(loadfile("EasyAchievement/Core/AchievementData.lua"))("EasyAchievement", addon)
assert(loadfile("EasyAchievement/Modules/AchievementUI.lua"))("EasyAchievement", addon)
local ui = addon.AchievementUI
ui.L = addon.L
ui.AchievementData = addon.AchievementData
ui.RewardDatabase = addon.RewardDatabase
ui.MIN_TREE_SCALE, ui.MAX_TREE_SCALE = 0.2, 1.5
ui.INDEX_BUDGET_MILLISECONDS, ui.NODE_SIZE = 2, 20
ui.SanitizeAchievementID = addon.AchievementData.SanitizeID
ui.TrimAchievementTreeStates = addon.AchievementData.TrimTreeStates
ui.GetAchievementHistoryEntry = addon.AchievementData.GetHistoryEntry
ui.GetAchievementData = function(id)
    return { id = id, name = string.format("Achievement %03d", id), depth = 1 }
end
ui.GetAchievementTreeStats = function(nodes)
    return { incomplete = #nodes, total = #nodes, completed = 0 }
end
ui.BuildAchievementTree = function(id)
    local root = ui.GetAchievementData(id)
    local child, grandchild = ui.GetAchievementData(id + 1), ui.GetAchievementData(id + 2)
    return { root, child, grandchild }, {
        { parent = root, child = child }, { parent = child, child = grandchild },
    }, root
end
ui.FilterCollapsedTree = function(nodes, edges) return nodes, edges end
ui.FilterIncompleteTree = function(nodes, edges) return nodes, edges, nodes[1] end
ui.RefreshAchievementFavoritesBar = function() end
ui.RecordRecentAchievement = function() end
ui.PlayAchievementSound = function() end

local scroll = { x = 0, y = 0, width = 200, height = 90, shown = true }
function scroll:GetHorizontalScroll() return self.x end
function scroll:GetVerticalScroll() return self.y end
function scroll:GetWidth() return self.width end
function scroll:GetHeight() return self.height end
function scroll:IsShown() return self.shown end
local frame = {
    ScrollFrame = scroll,
    shown = true,
    IsShown = function(self) return self.shown end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    Raise = function() end,
    IncompleteOnly = { SetChecked = function() end },
    ScaleSlider = { SetValue = function() end },
    EmptyText = { SetText = function() end },
}
ui.achievementTreeFrame = frame
ui.CreateAchievementTreeFrame = function() return frame end
for _, name in ipairs({ "Navigation", "Window", "RewardCategories", "Search",
    "Content" }) do
    assert(loadfile("EasyAchievement/Modules/Achievements/" .. name .. ".lua"))(
        "EasyAchievement", addon)
end
ui.CreateAchievementTreeFrame = function() return frame end
frame.RewardCategoryRailButtons = {}
for _, key in ipairs({ "all", "mount", "pet", "toy", "decor", "title",
    "appearance", "other", "settings" }) do
    frame.RewardCategoryRailButtons[key] = {
        Selected = {
            SetShown = function(self, shown) self.shown = shown end,
        },
        SelectedBottom = {
            SetShown = function(self, shown) self.shown = shown end,
        },
    }
end
local updateBreadcrumb = ui.UpdateBreadcrumb
ui.UpdateBreadcrumb = function() end
local revealedID
ui.RevealAchievementNode = function(_, id) revealedID = id end
ui.LayoutAchievementTree = function(nodes, edges, root, preserve)
    frame.layoutNodes, frame.layoutEdges, frame.layoutRoot = nodes, edges, root
    if frame.cardOnlyAchievementID then
        scroll.shown, scroll.x, scroll.y = false, 0, 0
    else
        scroll.shown = true
        scroll.x = frame.pendingHorizontalScroll or (preserve and scroll.x) or 0
        scroll.y = frame.pendingVerticalScroll or (preserve and scroll.y) or 0
    end
    local rows = math.max(1, math.floor(scroll.height / 30))
    for index, node in ipairs(nodes) do
        node.navigatorX = math.floor((index - 1) / rows) * 120
        node.navigatorY = ((index - 1) % rows) * 30
        node.layoutWidth = 80
    end
    frame.pendingHorizontalScroll, frame.pendingVerticalScroll = nil, nil
    ui.SaveAchievementTreeState(frame)
end

ui.ShowAchievementTree(10)
assert(not frame.RewardCategoryRailButtons.mount.Selected.shown,
    "reward rail selected a category on a normal tree page")
scroll.x, scroll.y, frame.treeScale = 120, 30, 0.7
frame.collapsedNodes = { [12] = true }
ui.ShowAchievementRewardCategory("mount")
assert(#frame.history == 2 and frame.historyIndex == 2)
assert(frame.RewardCategoryRailButtons.mount.Selected.shown
    and not frame.RewardCategoryRailButtons.pet.Selected.shown,
    "reward rail did not highlight the active category")
scroll.x = 100
ui.OpenAchievementRewardCategoryCard(frame, 105)
assert(frame.RewardCategoryRailButtons.mount.Selected.shown,
    "reward rail lost the category while viewing its card")
assert(#frame.history == 3 and frame.historyIndex == 3,
    "entering a category card did not create a history entry")
assert(frame.history[2].viewState.horizontal == 100)
local savedContext = frame.history[3].categoryContext
ui.ShowAchievementTree(105, "refresh")
assert(frame.rewardCategoryCardContext.index == 5 and #frame.history == 3,
    "refresh discarded category navigation or appended history")
ui.NavigateAchievementRewardCategoryCard(frame, 1)
assert(frame.sourceAchievementID == 106 and #frame.history == 3,
    "category step appended history rather than replacing the current card")
assert(savedContext.index == 5 and frame.history[3].categoryContext.index == 6,
    "category navigation mutated an earlier snapshot")
ui.NavigateAchievementHistory(frame, -1)
assert(frame.rewardCategoryMode.key == "mount" and scroll.x == 100,
    "back skipped the source list or lost its scroll position")
assert(frame.rewardCategoryMode.selectedAchievementID == 106,
    "top back did not select the most recently viewed category achievement")
ui.NavigateAchievementHistory(frame, 1)
assert(frame.sourceAchievementID == 106 and frame.rewardCategoryCardContext.index == 6,
    "forward did not restore category card order and position")
ui.ReturnToAchievementRewardCategory(frame)
assert(frame.historyIndex == 2 and #frame.history == 3
    and frame.rewardCategoryMode.selectedAchievementID == 106,
    "return-to-list did not restore the original history entry and selection")
assert(scroll.x == 100 and revealedID == nil,
    "unchanged list layout unnecessarily moved the viewport")
ui.NavigateAchievementHistory(frame, 1)
scroll.height = 120
ui.ReturnToAchievementRewardCategory(frame)
assert(revealedID == 106, "resized category list did not reveal the selected achievement")
ui.NavigateAchievementHistory(frame, -1)
assert(frame.sourceAchievementID == 10 and frame.treeScale == 0.7
    and scroll.x == 120 and scroll.y == 30 and frame.collapsedNodes[12],
    "history did not restore the original tree view snapshot")
ui.OpenAchievementPathCard(frame, 12)
assert(table.concat(frame.breadcrumbIDs, ",") == "10,11,12",
    "tree-to-card breadcrumb omitted intermediate ancestors")
assert(#frame.history == 2, "new navigation did not truncate forward history")
ui.NavigateAchievementHistory(frame, -1)
ui.NavigateAchievementHistory(frame, 1)
assert(table.concat(frame.breadcrumbIDs, ",") == "10,11,12",
    "forward navigation lost the breadcrumb path")
ui.OpenAchievementPathCard(frame, 10)
ui.ShowAchievementTree(10)
assert(scroll.x == 120 and scroll.y == 30 and frame.treeScale == 0.7,
    "card for the same achievement overwrote its saved tree viewport")

local layout = addon.AchievementData.GetBreadcrumbLayout({ 100, 150, 200, 250 }, 300)
assert(#layout == 3 and layout[2].index == 0
    and layout[1].index == 1 and layout[3].index == 4)
local totalWidth = 0
for _, item in ipairs(layout) do totalWidth = totalWidth + item.width end
assert(totalWidth <= 300, "breadcrumb overflow exceeds its available width")

ui.ShowAchievementTree(202, nil, nil, true)
ui.ShowAchievementTree(203, nil, nil, true)
local previousIndex, previousCount = frame.historyIndex, #frame.history
local originalGet = ui.GetAchievementData
ui.GetAchievementData = function(id)
    if id ~= 202 then return originalGet(id) end
end
assert(ui.NavigateAchievementHistory(frame, -1) == false
    and frame.historyIndex == previousIndex and #frame.history == previousCount
    and frame.sourceAchievementID == 203,
    "unavailable history target changed the history cursor or visible page")
ui.GetAchievementData = originalGet
assert(ui.NavigateAchievementHistory(frame, -1)
    and frame.sourceAchievementID == 202,
    "history did not recover when the unavailable achievement loaded")
local originalShow = ui.ShowAchievementTree
ui.ShowAchievementTree = function() return false end
previousIndex = frame.historyIndex
assert(ui.NavigateAchievementHistory(frame, 1) == false
    and frame.historyIndex == previousIndex and frame.sourceAchievementID == 202,
    "failed page open did not roll back the history cursor")
ui.ShowAchievementTree = originalShow
ui.NavigateAchievementHistory(frame, 1)
assert(frame.sourceAchievementID == 203)

function addon:RegisterSetting() end
function addon:RegisterEvent() end
function addon.NumberSetting() return function(value) return value end end
function addon.BooleanSetting(value) return not not value end
assert(loadfile("EasyAchievement/Modules/Achievements/Launcher.lua"))(
    "EasyAchievement", addon)
local shield = {
    SetTexture = function(self, file) self.file = file end,
    SetTexCoord = function(self, ...) self.coords = { ... } end,
    SetSize = function(self, width, height)
        self.width, self.height = width, height
    end,
}
assert(ui.SetAchievementShieldAtlas(shield, 40)
    and shield.file == 4035524
    and shield.coords[1] == 811 / 1024
    and shield.coords[2] == 891 / 1024
    and shield.coords[3] == 36 / 1024
    and shield.coords[4] == 94 / 1024
    and shield.width == 40 and shield.height == 29,
    "launcher shield crop did not remove transparent atlas padding")
assert(not ui.SetAchievementShieldAtlas({
    SetTexture = function() error("texture unavailable") end,
}, 40), "launcher shield crop did not allow the atlas fallback")
local shine = {
    SetTexture = shield.SetTexture,
    SetTexCoord = shield.SetTexCoord,
    SetSize = shield.SetSize,
    SetAllPoints = function(self, target) self.anchor = target end,
    SetVertexColor = function(self, ...) self.color = { ... } end,
    SetBlendMode = function(self, mode) self.blend = mode end,
    SetAlpha = function(self, alpha) self.alpha = alpha end,
}
local iconParent = { CreateTexture = function() return shine end }
assert(ui.CreateAchievementShieldBrightness(iconParent, shield, 40)
    == shine and shine.anchor == shield and shine.file == 4035524
    and shine.color[2] == 0.95 and shine.blend == "ADD"
    and shine.alpha == 0.85,
    "launcher shield brightness overlay is not aligned with the icon")
ui.ShowAchievementRewardCategory("mount")
scroll.x = 100
previousIndex, previousCount = frame.historyIndex, #frame.history
frame:Hide()
ui.OpenAchievementPanel()
assert(frame:IsShown() and frame.rewardCategoryMode.key == "mount"
    and scroll.x == 100 and frame.historyIndex == previousIndex
    and #frame.history == previousCount,
    "reopening the panel discarded the category list or changed history")
ui.OpenAchievementRewardCategoryCard(frame, 105)
ui.NavigateAchievementRewardCategoryCard(frame, 1)
previousIndex, previousCount = frame.historyIndex, #frame.history
frame:Hide()
ui.OpenAchievementPanel()
assert(frame:IsShown() and frame.sourceAchievementID == 106
    and frame.rewardCategoryCardContext.index == 6
    and frame.breadcrumbCategory == "mount"
    and frame.historyIndex == previousIndex and #frame.history == previousCount,
    "reopening the panel discarded category card context or changed history")
ui.OpenAchievementPanel()
assert(frame.historyIndex == previousIndex and #frame.history == previousCount,
    "opening an already visible panel appended history")

-- Exercise real node click handlers and menus, with only drawing APIs mocked.
local function Widget()
    return setmetatable({ scripts = {}, shown = true }, { __index = function(_, key)
        if key == "SetScript" then
            return function(self, name, callback) self.scripts[name] = callback end
        elseif key == "IsShown" then
            return function(self) return self.shown end
        elseif key == "Hide" or key == "Show" then
            return function(self) self.shown = key == "Show" end
        elseif key == "GetFont" then
            return function() return "test", 12, "" end
        elseif key == "GetStringWidth" then
            return function() return 60 end
        elseif key == "GetWidth" then
            return function() return 900 end
        elseif key == "GetFrameLevel" then
            return function() return 1 end
        elseif key == "SetShown" then
            return function(self, shown) self.shown = shown end
        elseif key == "SetTexture" then
            return function(self, texture) self.texture = texture end
        elseif key:match("^Create") then
            return function() return Widget() end
        end
        return function() end
    end })
end
ui.CreateFrame = Widget
ui.GetAchievementSearchBoxWidth = function() return 180 end
ui.SetTextureAtlas = function(texture, atlas)
    texture.atlas = atlas
    return true
end
frame.GetFrameLevel = function() return 1 end
ui.CreateAchievementRewardCategoryRail(frame)
local railCount = 0
for _, button in pairs(frame.RewardCategoryRailButtons) do
    railCount = railCount + 1
    assert(button.scripts.OnClick, "reward category rail button has no action")
end
assert(railCount == 9 and frame.RewardCategoryRail,
    "top navigation omitted achievement, reward, or settings tabs")
frame.RewardCategoryRailButtons.toy.scripts.OnClick()
assert(frame.rewardCategoryMode.key == "toy"
    and frame.RewardCategoryRailButtons.toy.Selected.shown,
    "reward tab did not use the normal category navigation")
ui.IsShiftKeyDown = function() return false end
local layoutTree = ui.LayoutAchievementTree
assert(loadfile("EasyAchievement/Modules/Achievements/Tree.lua"))(
    "EasyAchievement", addon)
ui.LayoutAchievementTree = layoutTree
frame.nodeButtons = {}
local nodeButton = ui.AcquireNodeButton(frame, 1)
nodeButton.clickSerial = 0
local pendingClicks = {}
ui.C_Timer = { After = function(_, callback)
    pendingClicks[#pendingClicks + 1] = callback
end }
local function FlushClicks()
    local callbacks = pendingClicks
    pendingClicks = {}
    for _, callback in ipairs(callbacks) do callback() end
end
local menuActions = {}
ui.L.ACHIEVEMENT_CARD_VIEW = "card"
ui.MenuUtil = { CreateContextMenu = function(_, generator)
    menuActions = {}
    generator(nil, {
        CreateTitle = function() end,
        CreateButton = function(_, label, callback)
            if label then menuActions[label] = callback end
        end,
    })
end }
ui.IsAchievementFavorite = function() return false end
ui.IsAchievementTracked = function() return false end
ui.GetChildAchievementIDs = function() return {} end
ui.CanOpenAchievementATTGuide = function() return false end
ui.achievementPopupFrames = {}

ui.ShowAchievementRewardCategory("mount")
scroll.x = 100
nodeButton.node = ui.GetAchievementData(105)
nodeButton.scripts.OnClick(nodeButton, "RightButton")
menuActions.card()
assert(frame.sourceAchievementID == 105
    and frame.rewardCategoryCardContext.index == 5
    and frame.breadcrumbCategory == "mount",
    "category node context-menu card lost category navigation")
ui.ReturnToAchievementRewardCategory(frame)
assert(scroll.x == 100 and frame.rewardCategoryMode.selectedAchievementID == 105,
    "context-menu card did not return to the original category viewport")
nodeButton.scripts.OnClick(nodeButton, "LeftButton")
FlushClicks()
assert(frame.sourceAchievementID == 105
    and frame.rewardCategoryCardContext.index == 5,
    "normal delayed category click did not preserve category navigation")

ui.ShowAchievementTree(10)
nodeButton.node = ui.GetAchievementData(12)
nodeButton.scripts.OnClick(nodeButton, "RightButton")
menuActions.card()
assert(table.concat(frame.breadcrumbIDs, ",") == "10,11,12",
    "tree node context-menu card lost ancestor breadcrumbs")

ui.ShowAchievementTree(10)
nodeButton.node = ui.GetAchievementData(12)
nodeButton.scripts.OnClick(nodeButton, "LeftButton")
ui.ShowAchievementTree(20)
previousIndex = frame.historyIndex
FlushClicks()
assert(frame.sourceAchievementID == 20 and frame.historyIndex == previousIndex,
    "stale delayed click overwrote a newer page")
nodeButton.scripts.OnClick(nodeButton, "LeftButton")
frame:Hide()
FlushClicks()
assert(not frame:IsShown() and frame.sourceAchievementID == 20,
    "delayed click reopened a closed panel")
frame:Show()
nodeButton.scripts.OnClick(nodeButton, "LeftButton")
nodeButton.node = ui.GetAchievementData(22)
FlushClicks()
assert(frame.sourceAchievementID == 20,
    "a reused node button executed its old target")
nodeButton.scripts.OnClick(nodeButton, "LeftButton")
nodeButton.scripts.OnClick(nodeButton, "RightButton")
FlushClicks()
assert(frame.sourceAchievementID == 20,
    "opening the context menu did not cancel a pending left click")

ui.ShowAchievementRewardCategory("mount")
scroll.x = 100
ui.OpenAchievementRewardCategoryCard(frame, 105)
local listIndex = frame.historyIndex - 1
local frozenIDs = table.concat(frame.rewardCategoryCardContext.achievementIDs, ",")
ui.OpenAchievementPathCard(frame, 201)
assert(not frame.rewardCategoryCardContext and frame.rewardCategoryOrigin.index == 5,
    "category descendant lost its origin or inherited unrelated list numbering")
ui.ShowAchievementTree(201, "refresh")
ui.OpenAchievementPathCard(frame, 202)
ui.NavigateAchievementHistory(frame, -1)
ui.NavigateAchievementHistory(frame, 1)
ui.ReturnToAchievementRewardCategory(frame)
assert(frame.historyIndex == listIndex and scroll.x == 100
    and frame.rewardCategoryMode.selectedAchievementID == 105
    and table.concat(frame.rewardCategoryMode.achievementIDs, ",") == frozenIDs,
    "nested descendant return lost the original list order, viewport or selection")
ui.NavigateAchievementHistory(frame, 1)
assert(frame.sourceAchievementID == 105)
ui.NavigateAchievementRewardCategoryCard(frame, 1)
assert(frame.sourceAchievementID == 106 and #frame.history == frame.historyIndex,
    "category navigation after back retained the obsolete descendant branch")
assert(loadfile("EasyAchievement/Modules/Achievements/Cards.lua"))(
    "EasyAchievement", addon)
ui.IsAchievementValid = function() return true end
frame.AchievementCard = Widget()
local childButton = Widget()
childButton.id = 201
local objectives = { metas = { childButton } }
function objectives:GetParent() return frame.AchievementCard end
ui.ConfigureAchievementCardChildLinks(objectives)
childButton.scripts.OnClick(childButton, "RightButton")
menuActions.card()
assert(frame.sourceAchievementID == 201 and frame.rewardCategoryOrigin.index == 6
    and not frame.rewardCategoryCardContext,
    "child context-menu card lost its category origin or inherited list numbering")
frame:Hide()
ui.OpenAchievementPanel()
assert(frame.sourceAchievementID == 201 and frame.rewardCategoryOrigin.index == 6,
    "reopening a descendant card lost its category origin")
frame.Breadcrumb = Widget()
updateBreadcrumb(frame)
assert(frame.BreadcrumbButtons[1].Icon.texture
    == "Interface\\Icons\\MountJournalPortrait",
    "category breadcrumb did not use the category icon")
frame.breadcrumbCategory = "other"
updateBreadcrumb(frame)
assert(frame.BreadcrumbButtons[1].Icon.atlas
    == "decor-placement-list-default",
    "other-category breadcrumb did not use its atlas")
frame.breadcrumbCategory = "mount"
updateBreadcrumb(frame)
frame.BreadcrumbButtons[2].scripts.OnClick(frame.BreadcrumbButtons[2], "LeftButton")
assert(frame.sourceAchievementID == 106
    and frame.rewardCategoryCardContext.index == 6
    and not frame.rewardCategoryOrigin,
    "ancestor breadcrumb did not restore the original category card context")
ui.OpenAchievementPathCard(frame, 201)
updateBreadcrumb(frame)
frame.BreadcrumbButtons[1].scripts.OnClick(frame.BreadcrumbButtons[1], "LeftButton")
assert(frame.rewardCategoryMode.key == "mount"
    and frame.rewardCategoryMode.selectedAchievementID == 106,
    "descendant category breadcrumb did not restore its source list")
ui.OpenAchievementRewardCategoryCard(frame, 106)
ui.OpenAchievementPathCard(frame, 201)
ui.NavigateAchievementHistory(frame, -2)
assert(frame.rewardCategoryMode.key == "mount"
    and frame.rewardCategoryMode.selectedAchievementID == 106,
    "history back from a descendant lost its source-list selection")
ui.NavigateAchievementHistory(frame, 2)
local originIDs = table.concat(frame.rewardCategoryOrigin.achievementIDs, ",")
frame.history = { frame.history[frame.historyIndex] }
frame.historyIndex = 1
ui.ReturnToAchievementRewardCategory(frame)
assert(frame.rewardCategoryMode.selectedAchievementID == 106
    and table.concat(frame.rewardCategoryMode.achievementIDs, ",") == originIDs,
    "descendant return without an older list history lost the frozen snapshot")
ui.OpenAchievementRewardCategoryCard(frame, 106)
ui.OpenAchievementPathCard(frame, 201)
ui.ShowAchievementTree(999, nil, nil, true)
assert(not frame.rewardCategoryOrigin and not frame.rewardCategoryCardContext,
    "an unrelated entry inherited the previous category origin")
-- Separate visits to the same category must not overwrite one another.
ui.ShowAchievementRewardCategory("mount")
local firstVisit = frame.currentPage.category.visitID
scroll.x = 100
ui.OpenAchievementRewardCategoryCard(frame, 105)
ui.ShowAchievementRewardCategory("mount")
local secondVisit = frame.currentPage.category.visitID
assert(secondVisit ~= firstVisit)
scroll.x = 200
ui.OpenAchievementRewardCategoryCard(frame, 106)
local secondListIndex = frame.historyIndex - 1
ui.NavigateAchievementHistory(frame, -2)
assert(frame.sourceAchievementID == 105)
ui.NavigateAchievementHistory(frame, 1)
assert(frame.history[secondListIndex].viewState.horizontal == 200
    and frame.rewardCategoryMode.selectedAchievementID == 106
    and frame.rewardCategoryMode.visitID == secondVisit,
    "forward navigation replaced a separate category visit with the old source")

-- Same achievement, different entry path: keep both history meanings.
ui.ShowAchievementTree(900, nil, { 10, 900 }, true)
local pathHistoryIndex = frame.historyIndex
ui.Navigation.OpenCard(900)
assert(frame.historyIndex == pathHistoryIndex + 1)
ui.NavigateAchievementHistory(frame, -1)
assert(table.concat(frame.breadcrumbIDs, ",") == "10,900",
    "independent entry overwrote the existing breadcrumb history")
ui.NavigateAchievementHistory(frame, 1)
assert(table.concat(frame.breadcrumbIDs, ",") == "900")

-- Real right-click tree action must preserve the source category.
ui.L.ACHIEVEMENT_TREE_VIEW = "tree"
ui.GetChildAchievementIDs = function() return { 107 } end
ui.ShowAchievementRewardCategory("mount")
scroll.x = 100
local sourceVisit = frame.rewardCategoryMode.visitID
nodeButton.node = ui.GetAchievementData(106)
nodeButton.scripts.OnClick(nodeButton, "RightButton")
menuActions.tree()
assert(frame.currentPage.kind == "tree"
    and frame.rewardCategoryOrigin.visitID == sourceVisit)
ui.OpenAchievementPathCard(frame, 107)
assert(frame.rewardCategoryOrigin.visitID == sourceVisit
    and not frame.rewardCategoryCardContext)
ui.Navigation.OpenRelatedTree(frame, 107)
assert(table.concat(frame.breadcrumbIDs, ",") == "106,107")
ui.Navigation.OpenRelatedTree(frame, 100, 107)
assert(revealedID == 107 and frame.rewardCategoryOrigin.visitID == sourceVisit)
ui.ReturnToAchievementRewardCategory(frame)
assert(frame.rewardCategoryMode.visitID == sourceVisit
    and frame.rewardCategoryMode.selectedAchievementID == 106)

-- A refresh updates the node's data, keeping widgets, order and viewport.
local earned = false
ui.GetAchievementData = function(id)
    local data = originalGet(id)
    data.completed = earned
    return data
end
addon.AchievementRewards = {
    Has = function() return true end,
    CancelRequest = function() end,
}
ui.SetAchievementTextColor = function() end
ui.ShowAchievementRewardCategory("mount")
local nodesBefore = frame.layoutNodes
local nodeBefore = nodesBefore[1]
local dataBefore = nodeBefore.data
local rendered = Widget()
rendered.node = nodeBefore
for _, name in ipairs({ "Icon", "RewardMarker", "Label", "DisabledOverlay",
    "Border", "FavoriteStar", "CompletionAnimation" }) do
    rendered[name] = Widget()
end
rendered.Icon.SetDesaturated = function(self, value) self.desaturated = value end
nodeBefore.button = rendered
scroll.x = 200
local pageBefore, revisionBefore = frame.currentPage, frame.navigationRevision
local historyCountBefore = #frame.history
earned = true
ui.OnAchievementEarned("ACHIEVEMENT_EARNED", nodeBefore.id)
assert(frame.layoutNodes == nodesBefore and frame.layoutNodes[1] == nodeBefore
    and nodeBefore.button == rendered and nodeBefore.data ~= dataBefore
    and nodeBefore.completed and rendered.Icon.desaturated == false,
    "completion refresh rebuilt the category or failed to update its node")
assert(scroll.x == 200 and frame.currentPage == pageBefore
    and frame.navigationRevision == revisionBefore
    and #frame.history == historyCountBefore,
    "content refresh changed navigation, order or viewport")
assert(dataBefore.button == nil and dataBefore.depth == 1
    and dataBefore.navigatorX == nil,
    "layout state leaked into achievement data")
ui.Content.Refresh(frame, "favorite")
assert(frame.layoutNodes == nodesBefore and scroll.x == 200)
ui.GetAchievementData = originalGet
ui.ShowAchievementTree(50)
ui.OpenAchievementNodeCard(frame, 52)
local treeContext = frame.treeCardContext
assert(treeContext and treeContext.kind == "tree"
    and treeContext.rootID == 50 and treeContext.index == 3
    and table.concat(treeContext.achievementIDs, ",") == "50,51,52"
    and treeContext.parentByID[52] == 51,
    "tree node card did not retain its source tree order")
local treeCardHistoryIndex = frame.historyIndex
ui.NavigateAchievementTreeCard(frame, -1)
assert(frame.sourceAchievementID == 51
    and frame.treeCardContext.index == 2
    and frame.historyIndex == treeCardHistoryIndex
    and table.concat(frame.breadcrumbIDs, ",") == "50,51",
    "tree card step changed history or lost the tree path")
ui.NavigateAchievementHistory(frame, -1)
assert(frame.sourceAchievementID == 50 and not frame.treeCardContext,
    "back from a tree card did not restore the tree view")
ui.NavigateAchievementHistory(frame, 1)
assert(frame.sourceAchievementID == 51
    and frame.treeCardContext.index == 2,
    "forward did not restore the tree card list selection")
ui.Navigation.OpenCard(51)
assert(not frame.treeCardContext,
    "directly opened card inherited the tree card list")
ui.CaptureOfficialAchievementBrowser = function(target)
    return addon.AchievementData.CopyNavigationState(
        target.officialBrowserState)
end
ui.UpdateOfficialAchievementBrowser = function() end
ui.ShowOfficialAchievementCategory = function(categoryID, _, _, entry)
    ui.Navigation.ApplyPage(frame, { kind = "official-category",
        officialBrowser = entry.officialBrowser })
    frame:Show()
    return frame.officialBrowserState.categoryID == categoryID
end
local officialHistoryCount = #frame.history
ui.Navigation.ApplyPage(frame, { kind = "official-category",
    officialBrowser = { categoryID = 1, expanded = { [1] = true } } })
ui.RecordAchievementNavigation(frame)
ui.Navigation.ApplyPage(frame, { kind = "official-category",
    officialBrowser = { categoryID = 2, expanded = { [1] = true,
        [2] = true } } })
ui.RecordAchievementNavigation(frame)
assert(#frame.history == officialHistoryCount + 2,
    "different official categories collapsed into one history entry")
assert(ui.NavigateAchievementHistory(frame, -1)
    and frame.officialBrowserState.categoryID == 1
    and frame.officialBrowserState.expanded[1],
    "official category back did not restore its expansion state")
assert(ui.NavigateAchievementHistory(frame, 1)
    and frame.officialBrowserState.categoryID == 2,
    "official category forward did not restore its selection")
local reopenHistoryCount, reopenHistoryIndex = #frame.history, frame.historyIndex
frame:Hide()
ui.OpenAchievementPanel()
assert(frame:IsShown() and frame.currentPage.kind == "official-category"
    and frame.officialBrowserState.categoryID == 2
    and frame.officialBrowserState.expanded[2]
    and #frame.history == reopenHistoryCount
    and frame.historyIndex == reopenHistoryIndex,
    "reopening the panel lost official category position or changed history")
ui.ShowAchievementRewardCategory("mount")
frame.rewardCategoryMode.selectedAchievementID = 105
ui.SaveAchievementRewardCategoryState(frame)
scroll.width = scroll.width + 1
revealedID = nil
ui.ShowAchievementRewardCategory("mount")
assert(frame.rewardCategoryMode.selectedAchievementID == 105
    and revealedID == nil,
    "ordinary top-category switching replayed the old selection pulse")
print("navigation visits, snapshots, related trees and in-place refresh: ok")

local settings = {}
local addon = {
    L = { ACHIEVEMENT_REWARD_CATEGORY_MOUNT = "Mounts" },
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
    IsShown = function() return true end,
    IncompleteOnly = { SetChecked = function() end },
    ScaleSlider = { SetValue = function() end },
    EmptyText = { SetText = function() end },
}
ui.achievementTreeFrame = frame
ui.CreateAchievementTreeFrame = function() return frame end
for _, name in ipairs({ "Navigation", "Window", "RewardCategories", "Search" }) do
    assert(loadfile("EasyAchievement/Modules/Achievements/" .. name .. ".lua"))(
        "EasyAchievement", addon)
end
ui.CreateAchievementTreeFrame = function() return frame end
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
scroll.x, scroll.y, frame.treeScale = 120, 30, 0.7
frame.collapsedNodes = { [12] = true }
ui.ShowAchievementRewardCategory("mount")
assert(#frame.history == 2 and frame.historyIndex == 2)
scroll.x = 100
ui.OpenAchievementRewardCategoryCard(frame, 105)
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
print("navigation snapshots, category return, breadcrumb paths: ok")

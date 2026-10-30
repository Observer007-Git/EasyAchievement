local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

local addon = {
    AchievementData = { CopyNavigationState = Copy },
    AchievementRewards = { Has = function(id) return id == 202 end },
    L = {
        ACHIEVEMENT_ALL_CATEGORIES = "All achievements",
        ACHIEVEMENT_ALL_CATEGORIES_EMPTY = "Empty",
        ACHIEVEMENT_OVERVIEW = "Summary",
        ACHIEVEMENT_PROGRESS_OVERVIEW = "Progress Overview",
        ACHIEVEMENT_PROGRESS_OVERVIEW_POINTS =
            "Progress Overview (%s pts earned)",
        ACHIEVEMENT_OVERVIEW_EARNED = "Achievements Earned",
        ACHIEVEMENT_OVERVIEW_CATEGORY_POINTS = "%s (%s/%s pts)",
        ACHIEVEMENT_EARNED_PROGRESS = "Achievements Earned: %d/%d",
        ACHIEVEMENT_OVERVIEW_TOTALS = "%s/%s",
        ACHIEVEMENT_TREE_NO_INCOMPLETE = "No incomplete achievements",
        ACHIEVEMENT_REWARD_CATEGORY_STATS = "%d achievements",
    },
}
function addon:GetSetting() return false end

local ui = setmetatable({ L = addon.L }, { __index = _G })
addon.AchievementUI = ui
local function Widget()
    local widget = { shown = true, width = 300, height = 300,
        vertical = 0, scripts = {} }
    return setmetatable(widget, { __index = function(_, key)
        if key == "CreateTexture" or key == "CreateFontString" then
            return function(self)
                local child = Widget()
                child.parent = self
                return child
            end
        elseif key == "SetScript" then
            return function(self, event, callback)
                self.scripts[event] = callback
            end
        elseif key == "SetWidth" then
            return function(self, value) self.width = value end
        elseif key == "SetHeight" then
            return function(self, value) self.height = value end
        elseif key == "SetSize" then
            return function(self, width, height)
                self.width, self.height = width, height
            end
        elseif key == "SetMinMaxValues" then
            return function(self, minimum, maximum)
                self.minimum, self.maximum = minimum, maximum
            end
        elseif key == "SetValue" then
            return function(self, value) self.value = value end
        elseif key == "SetStatusBarColor" then
            return function(self, ...) self.barColor = { ... } end
        elseif key == "GetWidth" then
            return function(self) return self.width end
        elseif key == "GetHeight" then
            return function(self) return self.height end
        elseif key == "SetText" then
            return function(self, value) self.text = value end
        elseif key == "SetJustifyH" then
            return function(self, value) self.justifyH = value end
        elseif key == "GetStringWidth" then
            return function(self) return #(self.text or "") * 7 end
        elseif key == "GetStringHeight" then
            return function() return 14 end
        elseif key == "SetPoint" then
            return function(self, ...) self.point = { ... } end
        elseif key == "SetTextColor" then
            return function(self, ...) self.color = { ... } end
        elseif key == "SetChecked" then
            return function(self, checked) self.checked = checked end
        elseif key == "GetChecked" then
            return function(self) return self.checked end
        elseif key == "SetTexture" then
            return function(self, value) self.texture = value end
        elseif key == "AdjustPointsOffset" then
            return function(self, x, y)
                self.offsetX = (self.offsetX or 0) + x
                self.offsetY = (self.offsetY or 0) + y
            end
        elseif key == "SetScrollChild" then
            return function(self, child) self.child = child end
        elseif key == "SetVerticalScroll" then
            return function(self, value) self.vertical = value end
        elseif key == "GetVerticalScroll" then
            return function(self) return self.vertical end
        elseif key == "GetVerticalScrollRange" then
            return function(self)
                return math.max(0, (self.child and self.child.height or 0)
                    - self.height)
            end
        elseif key == "Show" or key == "Hide" then
            return function(self) self.shown = key == "Show" end
        elseif key == "SetShown" then
            return function(self, shown) self.shown = shown end
        elseif key == "IsShown" then
            return function(self) return self.shown end
        elseif key == "GetFrameLevel" then
            return function() return 1 end
        end
        if key:match("^Set") or key:match("^Get")
            or key:match("^Clear") or key:match("^Enable")
            or key:match("^Register") or key:match("^Lock")
            or key:match("^Unlock") or key == "Raise"
        then
            return function() end
        end
    end })
end

local categoryNames = { [1] = "Exploration", [2] = "Zones",
    [3] = "Dungeons" }
local categoryParents = { [1] = -1, [2] = 1, [3] = -1 }
local achievementIDs = { [1] = { 101 }, [2] = { 201, 202 },
    [3] = { 301 } }
local categoryByAchievement = { [101] = 1, [201] = 2,
    [202] = 2, [301] = 3 }
local completed = { [101] = true, [201] = true }
local points = { [101] = 10, [201] = 5, [202] = 15, [301] = 25 }
local categoryCalls = 0
ui.GetCategoryList = function()
    categoryCalls = categoryCalls + 1
    return { 1, 2, 3 }
end
ui.GetCategoryInfo = function(id)
    return categoryNames[id], categoryParents[id]
end
ui.GetCategoryNumAchievements = function(id)
    local ids = achievementIDs[id] or {}
    local done = 0
    for _, achievementID in ipairs(ids) do
        if completed[achievementID] then done = done + 1 end
    end
    return #ids, done
end
ui.GetAchievementInfo = function(categoryID, index)
    return achievementIDs[categoryID][index]
end
ui.GetAchievementCategory = function(id)
    return categoryByAchievement[id]
end
ui.GetAchievementData = function(id)
    return { id = id, name = "Achievement " .. id,
        description = "Description", icon = id, points = points[id],
        completed = completed[id] == true }
end
ui.CreateFrame = Widget
ui.SetTextureAtlas = function(texture, atlas, useAtlasSize)
    texture.atlas = atlas
    if useAtlasSize then texture:SetSize(20, 20) end
    return true
end
ui.SetAchievementTextColor = function(font, done, highlighted, brightness)
    local color = done and { 0.2, 1, 0.2 }
        or highlighted and { 1, 0.82, 0.15 }
        or { brightness, brightness, brightness }
    font:SetTextColor(color[1], color[2], color[3])
end
local tooltipID, contextID, contextCard
ui.ShowAchievementTooltip = function(row) tooltipID = row.node.id end
ui.OpenAchievementContextMenu = function(_, id, openCard)
    contextID, contextCard = id, openCard
end
ui.GameTooltip = { Hide = function() tooltipID = nil end }
ui.UIParent = { GetWidth = function() return 1400 end }

local frame = Widget()
frame.width = 900
for _, key in ipairs({ "RewardCategoryRail", "RewardCategoryRailToggle",
    "SettingsPanel", "ScrollFrame", "HorizontalScroll", "Navigator",
    "EmptyText", "CardScaleControls", "TreeScaleControls",
    "IncompleteOnly", "IncompleteOnlyLabel",
    "FitButton", "Breadcrumb", "ATTButton", "PortraitIcon",
    "BackButton", "ForwardButton", "Stats", "AllAchievementsButton" }) do
    frame[key] = Widget()
end
frame.ApplyRewardRailProgress = function(progress)
    frame.RewardCategoryRail:SetShown(progress > 0)
end
frame.history, frame.historyIndex = {}, 0
ui.CreateAchievementTreeFrame = function() return frame end
ui.UpdateAchievementRewardHeader = function() end
ui.LayoutAchievementHeader = function() end
ui.UpdateAchievementHeader = function(_, title, stats)
    frame.title, frame.stats = title, stats
end
ui.SaveCurrentAchievementNavigation = function() end
ui.RecordAchievementNavigation = function()
    frame.historyIndex = frame.historyIndex + 1
    frame.history[frame.historyIndex] = {
        kind = frame.currentPage.kind,
        officialBrowser = Copy(frame.officialBrowserState),
    }
end
ui.Navigation = { ApplyPage = function(target, page)
    target.currentPage = page
    target.officialBrowserState = page.officialBrowser
    target.officialContext = page.officialContext
    ui.UpdateOfficialAchievementBrowser(target)
end }
ui.ShowAchievementTree = function(id, _, _, _, _, entry)
    ui.Navigation.ApplyPage(frame, {
        kind = "card", achievementID = id,
        officialBrowser = entry.officialBrowser,
        officialContext = entry.officialContext,
    })
    frame.sourceAchievementID = id
    return true
end
ui.NavigateAchievementHistory = function(_, offset)
    frame.historyIndex = frame.historyIndex + offset
    local entry = frame.history[frame.historyIndex]
    ui.ShowOfficialAchievementCategory(entry.officialBrowser.categoryID,
        false, "history", entry)
end

assert(loadfile("EasyAchievement/Modules/Achievements/OfficialCategories.lua"))(
    "EasyAchievement", addon)
assert(ui.ShowOfficialAchievementCategory(1))
assert(categoryCalls == 1 and frame.title == "Exploration"
    and frame.OfficialCategoryBrowser.rightIDs[1] == 101,
    "official categories were not read live from the game API")
assert(frame.width == 900 and frame.RewardCategoryRail.shown,
    "official browser changed the panel width or hid top navigation")
assert(frame.PortraitIcon.width == 58
    and frame.PortraitIcon.height == 58,
    "all-achievements portrait must fit inside the circular frame")
assert(frame.OfficialCategoryBrowser.leftRows[2].Count.text
        == "3(|cff33cc332|r/|cff9999991|r)",
    "parent category counts must include child achievements")
assert(frame.OfficialCategoryBrowser.leftRows[3].Count.shown
    and frame.OfficialCategoryBrowser.leftRows[3].Count.text
        == "2(|cff33cc331|r/|cff9999991|r)"
    and frame.OfficialCategoryBrowser.leftRows[5].Count.shown
    and frame.OfficialCategoryBrowser.leftRows[5].Count.text
        == "1(|cff33cc330|r/|cff9999991|r)",
    "leaf category counts must appear before selection")
assert(frame.OfficialCategoryBrowser.leftRows[2].CategoryBackground.atlas
        == "common-button-list-collapseExpand"
    and frame.OfficialCategoryBrowser.leftRows[2].CollapseIcon.atlas
        == "common-button-list-minus"
    and frame.OfficialCategoryBrowser.leftRows[2].CollapseIcon.height
        == 20
    and frame.OfficialCategoryBrowser.leftRows[2].CollapseIcon.point[2]
        == frame.OfficialCategoryBrowser.leftRows[2].Label
    and frame.OfficialCategoryBrowser.leftRows[2].CategoryBackground.point[5]
        == 2
    and frame.OfficialCategoryBrowser.leftRows[2].CategoryBackground.point[4]
        == -1
    and frame.OfficialCategoryBrowser.leftRows[5].CollapseIcon.atlas
        == "common-button-list-plus"
    and frame.OfficialCategoryBrowser.leftRows[5].CollapseIcon.height
        == frame.OfficialCategoryBrowser.leftRows[5].Label:GetStringHeight(),
    "category headers must center native minus art, size plus art and keep spacing")
assert(ui.ShowOfficialAchievementCategory(2, true))
local browser = frame.OfficialCategoryBrowser
assert(frame.title == "Zones" and #browser.rightIDs == 2
    and browser.leftEntries[3].categoryID == 2,
    "selecting a child category did not show its achievement list")
assert(browser.leftRows[3].CollapseIcon.atlas == "common-button-list-minus"
    and browser.leftRows[3].Count.shown
    and browser.leftRows[3].Count.text
        == "2(|cff33cc331|r/|cff9999991|r)"
    and browser.leftScroll.Content.width == 210
    and browser.leftRows[3].width == 210
    and browser.leftRows[4].OptionsSelected.atlas == "Options_List_Active"
    and browser.leftRows[4].OptionsHover.atlas == "Options_List_Hover"
    and browser.leftRows[4].OptionsSelected.point[4] == -1
    and browser.leftRows[4].OptionsHover.point[4] == -1
    and not browser.leftRows[4].CategoryBackground.shown
    and not browser.leftRows[4].CollapseIcon.shown,
    "achievement rows must use options-list hover and selection art")
assert(browser.leftRows[5].Label.color[1] == 0.55
    and browser.leftRows[5].Label.color[2] == 0.55,
    "unfinished achievements in the left list must be gray")
browser.leftRows[3].scripts.OnMouseDown(browser.leftRows[3])
assert(browser.leftRows[3].CollapseIcon.offsetX == 1
    and browser.leftRows[3].Label.offsetY == -1,
    "pressed category header must offset its icon and text")
browser.leftRows[3].scripts.OnMouseUp(browser.leftRows[3])
assert(browser.leftRows[3].CollapseIcon.offsetX == 0
    and browser.leftRows[3].Label.offsetY == 0,
    "released category header must restore its icon and text")
assert(browser.rightRows[1].Name.color[2] == 1
    and browser.leftRows[4].Label.color[2] == 1
    and browser.leftRows[5].RewardMarker.shown
    and not browser.rightRows[1].RewardMarker.shown
    and browser.rightRows[2].RewardMarker.shown
    and browser.rightRows[2].RewardMarker.point[2]
        == browser.rightRows[2].Icon
    and browser.rightRows[2].Border.texture
        == "Interface\\AchievementFrame\\UI-Achievement-IconFrame"
    and browser.rightRows[2].Points == nil
    and browser.rightRows[2].Check == nil
    and browser.rightRows[2].Description == nil
    and browser.rightRows[2].RewardMarker.atlas
        == "SoulBinds_Collection_Charge_Pending",
    "completed achievements or reward badges were not rendered")
browser.rightRows[2].scripts.OnEnter(browser.rightRows[2])
assert(tooltipID == 202, "right grid hover lost the achievement tooltip")
browser.rightRows[2].scripts.OnLeave(browser.rightRows[2])
assert(tooltipID == nil, "right grid tooltip was not dismissed")
browser.rightRows[2].scripts.OnClick(browser.rightRows[2], "RightButton")
assert(contextID == 202 and type(contextCard) == "function",
    "right grid lost the achievement context menu")
browser.rightScroll.width = 700
ui.RefreshOfficialAchievementBrowser(frame)
assert(browser.rightColumns == 3
    and browser.rightRows[1].point[5] == 0
    and browser.rightRows[2].point[5] == 0
    and browser.rightRows[2].point[4] > 0,
    "right grid did not distribute achievements across columns")
browser.incompleteOnly:SetChecked(true)
browser.incompleteOnly.scripts.OnClick(browser.incompleteOnly)
assert(#browser.rightIDs == 1 and browser.rightIDs[1] == 202
    and browser.leftEntries[4].achievementID == 202
    and frame.stats == "1 achievements"
    and frame.officialBrowserState.incompleteOnly,
    "incomplete filter did not update both official lists")
completed[202] = true
ui.RefreshOfficialAchievementBrowser(frame, "earned")
assert(browser.leftRows[2].Count.text
        == "3(|cff33cc333|r/|cff9999990|r)"
    and #browser.rightIDs == 0
    and browser.empty.text == "No incomplete achievements",
    "earned achievements did not refresh parent totals and filtered rows")
completed[202] = nil
ui.RefreshOfficialAchievementBrowser(frame, "earned")
assert(ui.OpenOfficialAchievementCard(202)
    and frame.sourceAchievementID == 202
    and frame.officialBrowserState.selectedAchievementID == 202
    and frame.officialContext.index == 1
    and not browser.right.shown,
    "opening a category achievement lost the list focus")
ui.ReturnToOfficialAchievementCategory(frame)
assert(frame.currentPage.kind == "official-category"
    and frame.title == "Zones" and browser.right.shown
    and browser.incompleteOnly.checked and #browser.rightIDs == 1,
    "return did not restore the selected official category and filter")
assert(ui.ShowOfficialAchievementCategory(2, true)
    and not frame.officialBrowserState.expanded[2],
    "clicking the selected category did not collapse it")
assert(ui.ShowOfficialAchievementCategory(2, true)
    and frame.officialBrowserState.expanded[2]
    and browser.leftEntries[4].achievementID == 202,
    "clicking a collapsed category did not expand it again")
browser.leftRows[2].scripts.OnClick(browser.leftRows[2])
assert(not frame.officialBrowserState.expanded[1]
    and browser.leftEntries[3].categoryID == 3,
    "clicking an expanded parent while its child is selected did not collapse it")
browser.leftRows[2].scripts.OnClick(browser.leftRows[2])
assert(frame.officialBrowserState.expanded[1]
    and browser.leftEntries[3].categoryID == 2,
    "collapsed parent could not expand again")
assert(ui.ShowOfficialAchievementCategory(0)
    and frame.title == "Summary"
    and browser.leftEntries[1].overview
    and browser.leftRows[1].Count.text
        == "4(|cff33cc332|r/|cff9999992|r)"
    and browser.leftRows[1].Selected.shown
    and not browser.leftRows[1].CollapseIcon.shown
    and browser.overview.shown and not browser.rightScroll.shown
    and not browser.incompleteOnly.shown
    and browser.overviewCount.text == "|cff33cc332|r/4"
    and browser.overviewTitle.text
        == "Progress Overview (|cff33cc3315|r pts earned)"
    and browser.overviewLabel.text
        == "Achievements Earned (|cff33cc3315|r/55 pts)"
    and browser.overviewLabel.justifyH == "LEFT"
    and browser.overviewLabel.parent == browser.overviewBar
    and browser.overviewCount.parent == browser.overviewBar
    and browser.overviewRows[1].Label.text
        == "Exploration (|cff33cc3315|r/30 pts)"
    and browser.overviewRows[2].Label.text
        == "Dungeons (|cff33cc330|r/25 pts)"
    and browser.overviewRows[1].Count.text == "|cff33cc332|r/3"
    and browser.overviewRows[2].Count.text == "|cff33cc330|r/1"
    and browser.overviewRows[1].Label.justifyH == "LEFT"
    and browser.overviewRows[1].Label.parent == browser.overviewRows[1].Bar
    and browser.overviewRows[1].Count.parent == browser.overviewRows[1].Bar
    and browser.overviewBar.barColor[2] == 0.6
    and browser.overviewRows[1].Bar.barColor[2] == 0.6
    and browser.overviewRows[1].Hover.atlas == "Options_List_Hover"
    and browser.overviewBar.value == 2,
    "overview did not show live root-category progress")
assert(browser.overviewRows[1].point[4] == 8
    and browser.overviewRows[2].point[4]
        > browser.overviewRows[1].point[4]
    and browser.overviewRows[1].point[5]
        == browser.overviewRows[2].point[5],
    "overview root categories should share a two-column row")
browser.roots[3] = { id = 103, name = "Extra", children = {} }
browser.overviewRows[3] = Widget()
browser.overviewRows[3].Label = Widget()
browser.overviewRows[3].Count = Widget()
browser.overviewRows[3].Bar = Widget()
browser.right.scripts.OnSizeChanged()
assert(browser.overviewRows[3].point[4]
    > browser.overviewRows[1].point[4]
    and browser.overviewRows[3].point[4]
        < browser.overviewRows[2].point[4],
    "an unmatched last category should be centered")
browser.roots[3] = nil
browser.overviewRows[3] = nil
for index = 3, 14 do
    browser.roots[index] = { id = 100 + index,
        name = "Extra " .. index, children = {} }
    browser.overviewRows[index] = Widget()
    browser.overviewRows[index].Label = Widget()
    browser.overviewRows[index].Count = Widget()
    browser.overviewRows[index].Bar = Widget()
end
browser.overview.height = 240
browser.right.scripts.OnSizeChanged()
assert(browser.overview.Content.height <= browser.overview.height
    and browser.overviewRows[14].point[5]
        < browser.overviewRows[2].point[5]
    and browser.overview:GetVerticalScrollRange() == 0,
    "two-column overview should fit all root categories without scrolling")
for index = 3, 14 do
    browser.roots[index] = nil
    browser.overviewRows[index] = nil
end
browser.overview.height = 300
browser.right.scripts.OnSizeChanged()
completed[202] = true
ui.RefreshOfficialAchievementBrowser(frame, "earned")
assert(browser.overviewCount.text == "|cff33cc333|r/4"
    and browser.overviewTitle.text
        == "Progress Overview (|cff33cc3330|r pts earned)"
    and browser.overviewLabel.text
        == "Achievements Earned (|cff33cc3330|r/55 pts)"
    and browser.leftRows[1].Count.text
        == "4(|cff33cc333|r/|cff9999991|r)"
    and browser.overviewRows[1].Count.text == "|cff33cc333|r/3"
    and browser.overviewRows[1].Label.text
        == "Exploration (|cff33cc3330|r/30 pts)",
    "overview did not refresh after an achievement was earned")
completed[202] = nil
local overviewSnapshot = { officialBrowser =
    ui.CaptureOfficialAchievementBrowser(frame) }
browser.overviewRows[2].scripts.OnClick(browser.overviewRows[2])
assert(frame.title == "Dungeons" and not browser.overview.shown
    and browser.rightScroll.shown,
    "overview category bar did not open its category")
assert(ui.ShowOfficialAchievementCategory(0, false, "history",
    overviewSnapshot)
    and frame.title == "Summary" and browser.overview.shown,
    "history did not restore the overview")
browser.leftRows[1].scripts.OnClick(browser.leftRows[1])
assert(frame.title == "Summary" and browser.overview.shown,
    "left summary entry did not restore the overview")
local selectedFaction = "Horde"
local pointsOnly = false
addon.L.ACHIEVEMENT_FACTION_HORDE = "Horde"
addon.L.ACHIEVEMENT_FACTION_ALLIANCE = "Alliance"
addon.L.ACHIEVEMENT_POINTS_ONLY = "Points only"
addon.L.ACHIEVEMENT_CATALOG_OVERVIEW = "Character achievement catalog"
local factionCategory = { id = 1010, parent = -1, order = 1,
    name = "Faction category", count = 2, points = 20, children = {} }
addon.AchievementCatalog = {
    GetCategories = function()
        return { [1010] = factionCategory }, { factionCategory }
    end,
    GetCategoryIDs = function() return { 101, 102 } end,
    GetSelectedFaction = function() return selectedFaction end,
    SetSelectedFaction = function(faction) selectedFaction = faction end,
    GetPointsOnly = function() return pointsOnly end,
    SetPointsOnly = function(enabled) pointsOnly = enabled end,
    IsVisible = function(id)
        return (selectedFaction == "Horde" and id == 101)
            or (selectedFaction == "Alliance" and id == 102)
    end,
    GetDirectTotals = function()
        return 1, selectedFaction == "Horde" and 10 or 20
    end,
    GetCompleted = function() return 1 end,
    GetCompletedPoints = function()
        return selectedFaction == "Horde" and 10 or 20
    end,
    IsProgressReady = function() return true end,
    StartProgressScan = function(callback) callback() end,
    IsCompleted = function() return true end,
}
frame.OfficialCategoryBrowser = nil
frame.officialBrowserState = nil
frame.currentPage = nil
frame.history, frame.historyIndex = {}, 0
assert(loadfile("EasyAchievement/Modules/Achievements/OfficialCategories.lua"))(
    "EasyAchievement", addon)
assert(ui.ShowOfficialAchievementCategory(0))
local factionBrowser = frame.OfficialCategoryBrowser
assert(factionBrowser.factionButtons.Horde.shown
    and factionBrowser.factionButtons.Horde.checked
    and not factionBrowser.factionButtons.Alliance.checked
    and factionBrowser.pointsOnly.shown
    and not factionBrowser.pointsOnly.checked
    and factionBrowser.pointsOnly.point[4] == -24
    and factionBrowser.overviewLabel.text
        == "Character achievement catalog (|cff33cc3310|r/10 pts)"
    and factionBrowser.overviewTitle.text
        == "Progress Overview (|cff33cc3310|r pts earned)"
    and factionBrowser.overviewCount.text == "|cff33cc331|r/1",
    "player faction must be selected by default")
factionBrowser.pointsOnly:SetChecked(true)
factionBrowser.pointsOnly.scripts.OnClick(factionBrowser.pointsOnly)
assert(pointsOnly and factionBrowser.pointsOnly.checked
    and factionBrowser.factionButtons.Horde.checked,
    "points checkbox must not change the selected faction")
factionBrowser.pointsOnly:SetChecked(false)
factionBrowser.pointsOnly.scripts.OnClick(factionBrowser.pointsOnly)
assert(not pointsOnly and not factionBrowser.pointsOnly.checked)
factionBrowser.factionButtons.Alliance.scripts.OnClick()
assert(selectedFaction == "Alliance"
    and not factionBrowser.factionButtons.Horde.checked
    and factionBrowser.factionButtons.Alliance.checked
    and factionBrowser.overviewLabel.text
        == "Character achievement catalog (|cff33cc3320|r/20 pts)"
    and factionBrowser.overviewCount.text == "|cff33cc331|r/1",
    "switching faction must update totals and keep exactly one checked")
factionBrowser.factionButtons.Alliance.scripts.OnClick()
assert(factionBrowser.factionButtons.Alliance.checked,
    "clicking the selected faction cannot clear both options")
factionBrowser.factionButtons.Horde.scripts.OnClick()
assert(selectedFaction == "Horde" and factionBrowser.overviewLabel.text
        == "Character achievement catalog (|cff33cc3310|r/10 pts)"
    and factionBrowser.overviewCount.text == "|cff33cc331|r/1",
    "switching back must restore the overview")
assert(ui.ShowOfficialAchievementCategory(1010)
    and #factionBrowser.rightIDs == 1
    and factionBrowser.rightIDs[1] == 101,
    "opposite-faction achievements must be hidden from the category list")
factionBrowser.incompleteOnly:SetChecked(true)
factionBrowser.incompleteOnly.scripts.OnClick(factionBrowser.incompleteOnly)
assert(#factionBrowser.rightIDs == 0
    and frame.officialBrowserState.incompleteOnly,
    "completed achievements remained visible after filtering")
factionBrowser.incompleteOnly:SetChecked(false)
factionBrowser.incompleteOnly.scripts.OnClick(factionBrowser.incompleteOnly)
assert(#factionBrowser.rightIDs == 1
    and factionBrowser.rightIDs[1] == 101
    and not frame.officialBrowserState.incompleteOnly,
    "achievement list did not return after clearing incomplete filter")
assert(ui.OpenOfficialAchievementCard(101)
    and #frame.officialContext.achievementIDs == 1,
    "card navigation must use the filtered category order")
ui.ReturnToOfficialAchievementCategory(frame)
factionBrowser.factionButtons.Alliance.scripts.OnClick()
assert(#factionBrowser.rightIDs == 1
    and factionBrowser.rightIDs[1] == 102,
    "switching faction must replace category list entries")
assert(ui.OpenOfficialAchievementCard(102)
    and #frame.officialContext.achievementIDs == 1)
factionBrowser.factionButtons.Horde.scripts.OnClick()
assert(frame.currentPage.kind == "official-category"
    and #factionBrowser.rightIDs == 1
    and factionBrowser.rightIDs[1] == 101,
    "switching faction must return from a now-hidden card")
print("official category hierarchy, card focus and return: ok")

local settingCallback
local settingValue = false
local settingSanitizers = {}
local menuCount = 0
local menuActions = {}

local Addon = {
    L = {
        ACHIEVEMENT_ATT_OPEN = "att",
        ACHIEVEMENT_CARD_VIEW = "card",
        ACHIEVEMENT_FAVORITE_ADD = "favorite",
        ACHIEVEMENT_FAVORITE_REMOVE = "unfavorite",
        ACHIEVEMENT_POPUP_SHOW = "popup",
        ACHIEVEMENT_TRACK = "track",
        ACHIEVEMENT_TREE_VIEW = "tree",
        ACHIEVEMENT_UNTRACK = "untrack",
        ACHIEVEMENT_REWARD_CATEGORY_POSITION = "%d / %d",
        ACHIEVEMENT_REWARD_CATEGORY_RETURN = "Back to %s list",
    },
    Config = {
        Frame = {
            DefaultWidth = 900,
            DefaultHeight = 650,
            MinWidth = 860,
            MinHeight = 420,
            MaxWidth = 1500,
            MaxHeight = 1000,
        },
        Tree = {
            NodeSize = 20,
            NodeIconSize = 17,
            BranchGap = 1,
            LevelGap = 8,
            LabelLeftGap = 4,
            Padding = 10,
            MinScale = 0.2,
            MaxScale = 1.5,
            ScaleStep = 0.01,
        },
        Card = { MinScale = 0.5, MaxScale = 2, ScaleStep = 0.01 },
        Search = { MaxResults = 8 },
        ModelScene = { DressUpSceneID = 596 },
        Performance = {
            IndexBudgetMilliseconds = 2,
            ResizeLayoutInterval = 0.05,
            CriteriaRefreshDelay = 0.05,
        },
        State = { MaxTreeStates = 50, MaxHistoryEntries = 100 },
    },
}

function Addon.BooleanSetting(value)
    return not not value
end

function Addon.NumberSetting()
    return function(value)
        return value
    end
end

function Addon:RegisterSetting(key, _, sanitizer, callback)
    settingSanitizers[key] = sanitizer
    if key == "enableAchievementEnhancement" then
        settingCallback = callback
    end
end

function Addon:RegisterEvent()
end

function Addon:GetSetting(key)
    if key == "enableAchievementEnhancement" then
        return settingValue
    elseif key == "achievementPopupIDs" then
        return {}
    end
end

C_AddOns = {
    IsAddOnLoaded = function()
        return true
    end,
}

C_AchievementInfo = {
    IsValidAchievement = function()
        return true
    end,
}

function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123, "Reward", false
end

AchievementTemplateMixin = {
    OnLoad = function() end,
    OnEnter = function() end,
    Init = function() end,
}

function hooksecurefunc(target, method, hook)
    local original = target[method]
    target[method] = function(...)
        original(...)
        hook(...)
    end
end

MenuUtil = {
    CreateContextMenu = function(_, generator)
        menuCount = menuCount + 1
        generator(nil, {
            CreateTitle = function() end,
            CreateButton = function(_, label, callback)
                menuActions[label] = callback
            end,
        })
    end,
}

function GetAchievementNumCriteria()
    return 0
end

local button = {
    scripts = {},
    originalClicks = 0,
}

function button:RegisterForClicks(...)
    self.registeredClicks = { ... }
end

function button:GetScript(script)
    return self.scripts[script]
end

function button:SetScript(script, callback)
    self.scripts[script] = callback
end

function button:GetElementData()
    return { id = 12345 }
end

button.scripts.OnClick = function(self)
    self.originalClicks = self.originalClicks + 1
end

AchievementFrameAchievements = {
    ScrollBox = {
        ForEachFrame = function(_, callback)
            callback(button)
        end,
    },
}

assert(loadfile("EasyAchievement/Data/AchievementRewardDatabase.lua"))(
    "EasyAchievement", Addon)
assert(loadfile("EasyAchievement/Core/AchievementRewardDatabase.lua"))(
    "EasyAchievement", Addon)
assert(loadfile("EasyAchievement/Core/AchievementData.lua"))(
    "EasyAchievement", Addon)
assert(loadfile("EasyAchievement/Modules/AchievementTreeData.lua"))(
    "EasyAchievement", Addon)
assert(loadfile("EasyAchievement/Modules/AchievementRewards.lua"))(
    "EasyAchievement", Addon)
assert(loadfile("EasyAchievement/Modules/AchievementTreeLayout.lua"))(
    "EasyAchievement", Addon)
assert(loadfile("EasyAchievement/Modules/AchievementUI.lua"))(
    "EasyAchievement", Addon)
local achievementUIModules = {
    "Core.lua",
    "Tooltip.lua",
    "RewardPanel.lua",
    "Cards.lua",
    "Favorites.lua",
    "Window.lua",
    "Navigator.lua",
    "Tree.lua",
    "RewardCategories.lua",
    "Search.lua",
    "Launcher.lua",
}
for _, moduleName in ipairs(achievementUIModules) do
    assert(loadfile("EasyAchievement/Modules/Achievements/" .. moduleName))(
        "EasyAchievement", Addon)
end
assert(settingCallback)
assert(settingSanitizers.achievementTreeStates,
    "tree-state sanitizer was not registered")
assert(settingSanitizers.achievementRewardCategoryStates,
    "reward-category state sanitizer was not registered")

assert(Addon.RewardDatabase.GetFaction(10355) == 0
    and Addon.RewardDatabase.GetFaction(10356) == 1,
    "generated faction metadata is missing the Horde/Alliance Reins Lord pair")
local originalUnitFactionGroup = UnitFactionGroup
UnitFactionGroup = function() return "Horde" end
assert(Addon.AchievementData.Get(10355)
    and not Addon.AchievementData.Get(10356),
    "Horde characters did not filter the Alliance Reins Lord achievement")
UnitFactionGroup = function() return "Alliance" end
assert(not Addon.AchievementData.Get(10355)
    and Addon.AchievementData.Get(10356),
    "Alliance characters did not filter the Horde Reins Lord achievement")
UnitFactionGroup = originalUnitFactionGroup

local oversizedStates = {}
for id = 1, 75 do
    oversizedStates[tostring(id)] = {
        scale = 1,
        horizontal = id,
        vertical = id,
        lastUsed = id,
    }
end
local sanitizedStates = settingSanitizers.achievementTreeStates(
    oversizedStates)
local sanitizedStateCount = 0
for _ in pairs(sanitizedStates) do
    sanitizedStateCount = sanitizedStateCount + 1
end
assert(sanitizedStateCount == 50,
    "tree-state sanitizer did not cap automatic saved state")
assert(sanitizedStates["75"] and not sanitizedStates["1"],
    "tree-state sanitizer did not retain the most recent state")
local categoryStates = settingSanitizers.achievementRewardCategoryStates({
    mount = { scale = 9, horizontal = 320, vertical = 45 },
    invalid = { scale = 1, horizontal = 1, vertical = 1 },
})
assert(categoryStates.mount
    and categoryStates.mount.scale == Addon.Config.Tree.MaxScale
    and categoryStates.mount.horizontal == 320
    and categoryStates.mount.vertical == 45
    and categoryStates.invalid == nil,
    "reward-category view state was not sanitized")

local BuildAchievementTree = Addon.AchievementTreeData.Build
local AchievementUI = assert(Addon.AchievementUI,
    "achievement UI namespace was not created")
local atlasTexture = {
    SetAtlas = function(self, atlas, useAtlasSize)
        self.atlas = atlas
        self.useAtlasSize = useAtlasSize
    end,
}
C_Texture = {
    GetAtlasInfo = function()
        error("unable to find mixin or metatable (Vector2DMixin)")
    end,
}
assert(AchievementUI.SetTextureAtlas(atlasTexture, "test-atlas", true)
    and atlasTexture.atlas == "test-atlas"
    and atlasTexture.useAtlasSize == true,
    "texture atlas helper did not bypass unsafe atlas metadata lookup")
assert(not AchievementUI.SetTextureAtlas({
    SetAtlas = function()
        error("invalid atlas")
    end,
}, "invalid-atlas"),
    "texture atlas helper did not allow callers to use their fallback")
C_Texture = nil
local openedATTQuery
AllTheThings = {
    CreatePopoutForSearch = function(query)
        openedATTQuery = query
    end,
}
assert(AchievementUI.CanOpenAchievementATTGuide(),
    "ATT guide availability was not detected")
assert(AchievementUI.OpenAchievementATTGuide(2468)
    and openedATTQuery == "achievementID:2468",
    "ATT guide did not open the requested achievement")
AchievementUI.OpenAchievementContextMenu(button, 2468)
assert(type(menuActions.att) == "function",
    "achievement context menu did not include the ATT guide")
openedATTQuery = nil
menuActions.att()
assert(openedATTQuery == "achievementID:2468",
    "achievement context menu opened the wrong ATT guide")
AllTheThings = nil
assert(not AchievementUI.CanOpenAchievementATTGuide(),
    "ATT guide remained available after ATT was removed")
menuCount = 0
local GetAchievementHistoryEntry = Addon.AchievementData.GetHistoryEntry
local historyID, historyCardOnly, historyCategory = GetAchievementHistoryEntry({
    achievementID = 2468,
    showCardOnly = true,
})
assert(historyID == 2468 and historyCardOnly == true
    and historyCategory == nil,
    "achievement card view was not preserved in history")
historyID, historyCardOnly, historyCategory = GetAchievementHistoryEntry({
    rewardCategory = "mount",
})
assert(historyID == nil and historyCardOnly == false
    and historyCategory == "mount",
    "reward category was not preserved in history")
historyID, historyCardOnly, historyCategory = GetAchievementHistoryEntry(1357)
assert(historyID == 1357 and historyCardOnly == false,
    "legacy achievement history was not preserved")
local cappedHistory = {}
for id = 1, 125 do
    Addon.AchievementData.AppendHistory(cappedHistory, {
        achievementID = id,
    })
end
assert(#cappedHistory == 100 and cappedHistory[1].achievementID == 26
    and cappedHistory[100].achievementID == 125,
    "achievement history did not retain the newest 100 entries")
local NavigateAchievementHistory = AchievementUI.NavigateAchievementHistory
assert(NavigateAchievementHistory,
    "achievement history navigation was not reachable")
local originalHistoryShowAchievementTree = AchievementUI.ShowAchievementTree
local navigatedID
local navigatedCardOnly
AchievementUI.ShowAchievementTree = function(id, mode, _, showCardOnly)
        navigatedID = id
        navigatedCardOnly = showCardOnly
        assert(mode == "history", "history navigation used the wrong mode")
    end
local historyFrame = {
    historyIndex = 2,
    history = {
        { achievementID = 111, showCardOnly = true },
        { achievementID = 222, showCardOnly = false },
    },
}
NavigateAchievementHistory(historyFrame, -1)
assert(navigatedID == 111 and navigatedCardOnly == true,
    "back navigation did not restore the previous achievement card")
NavigateAchievementHistory(historyFrame, 1)
assert(navigatedID == 222 and navigatedCardOnly == false,
    "forward navigation did not restore the previous achievement tree")
local originalHistoryShowRewardCategory =
    AchievementUI.ShowAchievementRewardCategory
local navigatedCategory
AchievementUI.ShowAchievementRewardCategory = function(category, mode)
    navigatedCategory = category
    assert(mode == "history",
        "reward-category history used the wrong navigation mode")
end
historyFrame.historyIndex = 2
historyFrame.history = {
    { rewardCategory = "mount" },
    { achievementID = 333, showCardOnly = true },
}
NavigateAchievementHistory(historyFrame, -1)
assert(navigatedCategory == "mount",
    "back navigation did not restore the reward category")
AchievementUI.ShowAchievementRewardCategory =
    originalHistoryShowRewardCategory
AchievementUI.ShowAchievementTree = originalHistoryShowAchievementTree

local originalCategoryShowAchievementTree = AchievementUI.ShowAchievementTree
local categoryNavigation
AchievementUI.ShowAchievementTree = function(id, mode, _, showCardOnly,
    context)
    categoryNavigation = {
        id = id,
        mode = mode,
        showCardOnly = showCardOnly,
        context = context,
    }
end
local categoryFrame = {
    rewardCategoryMode = {
        key = "mount",
        label = "Mounts",
        achievementIDs = { 101, 202, 303 },
    },
}
AchievementUI.OpenAchievementRewardCategoryCard(categoryFrame, 202)
assert(categoryNavigation.id == 202
    and categoryNavigation.mode == "category"
    and categoryNavigation.showCardOnly == true
    and categoryNavigation.context.index == 2,
    "category card did not preserve its displayed grid position")
categoryFrame.rewardCategoryCardContext = categoryNavigation.context
AchievementUI.NavigateAchievementRewardCategoryCard(categoryFrame, -1)
assert(categoryNavigation.id == 101
    and categoryNavigation.context.index == 1,
    "category card previous navigation used the wrong achievement")
AchievementUI.NavigateAchievementRewardCategoryCard(categoryFrame, 1)
assert(categoryNavigation.id == 202
    and categoryNavigation.context.index == 2,
    "category card next navigation used the wrong achievement")
AchievementUI.ShowAchievementTree = originalCategoryShowAchievementTree

local originalCategoryReturn = AchievementUI.ShowAchievementRewardCategory
local returnedCategory
local returnMode
AchievementUI.ShowAchievementRewardCategory = function(category, mode)
    returnedCategory = category
    returnMode = mode
end
AchievementUI.ReturnToAchievementRewardCategory(categoryFrame)
assert(returnedCategory == "mount" and returnMode == "return",
    "category card return did not reopen the saved category list")
AchievementUI.ShowAchievementRewardCategory = originalCategoryReturn

local FilterIncompleteTree = Addon.AchievementTreeData.FilterIncomplete
CRITERIA_TYPE_ACHIEVEMENT = 8
local childMap = { [1] = { 2, 3 }, [2] = { 4 } }
function GetAchievementNumCriteria(id)
    return #(childMap[id] or {})
end
function GetAchievementCriteriaInfo(id, index)
    return "criterion", CRITERIA_TYPE_ACHIEVEMENT, false,
        0, 1, nil, 0, childMap[id][index]
end
function GetPreviousAchievement()
    return nil
end
local recursiveNodes = BuildAchievementTree(1)
assert(#recursiveNodes == 4, "tree recursion stopped before grandchildren")

local cardOnlyStats = Addon.AchievementTreeData.GetStats({
    { id = 19458, completed = false },
})
assert(cardOnlyStats.levels == 1 and cardOnlyStats.total == 1
    and cardOnlyStats.completed == 0 and cardOnlyStats.incomplete == 1,
    "card-only achievement stats require a precomputed tree depth")

local GetTopmostAchievementIDs = Addon.AchievementTreeData.GetTopmostIDs
childMap = { [100] = { 50 }, [200] = { 50 } }
BuildAchievementTree(100)
BuildAchievementTree(200)
local topmostIDs = GetTopmostAchievementIDs(50)
assert(#topmostIDs == 2 and topmostIDs[1] == 100
    and topmostIDs[2] == 200,
    "multiple final achievement roots were not preserved")

childMap = {}
for id = 1, 349 do
    childMap[id] = { id + 1 }
end
local uncappedNodes = BuildAchievementTree(1)
assert(#uncappedNodes == 350, "tree builder still truncates large trees")

local filterRoot = { id = 10, completed = true, depth = 1 }
local filterChild = { id = 11, completed = false, depth = 2 }
local filterMiddle = { id = 12, completed = true, depth = 3 }
local filterGrandchild = { id = 13, completed = false, depth = 4 }
local filteredNodes, filteredEdges, filteredRoot = FilterIncompleteTree({
    filterRoot, filterChild, filterMiddle, filterGrandchild,
}, {
    { parent = filterRoot, child = filterChild },
    { parent = filterChild, child = filterMiddle },
    { parent = filterMiddle, child = filterGrandchild },
})
assert(#filteredNodes == 2, "completed achievements remained visible")
assert(#filteredEdges == 1, "filtered branches were not reconnected")
assert(filteredEdges[1].parent == filterChild
    and filteredEdges[1].child == filterGrandchild,
    "filtered branch used the wrong nearest incomplete ancestor")
assert(filteredRoot == filterChild and filterChild.depth == 1
    and filterGrandchild.depth == 2,
    "filtered depths were not rebuilt")

local layoutRoot = { id = 21, layoutWidth = 50 }
local layoutChildA = { id = 22, layoutWidth = 40 }
local layoutChildB = { id = 23, layoutWidth = 40 }
local layoutNodes = { layoutRoot, layoutChildA, layoutChildB }
local layoutEdges = {
    { parent = layoutRoot, child = layoutChildA },
    { parent = layoutRoot, child = layoutChildB },
}
local calculatedLayout = Addon.AchievementTreeLayout.Calculate(
    layoutNodes, layoutEdges, layoutRoot, {
        availableHeight = 100,
        branchGap = 1,
        levelGap = 8,
        nodeRowPitch = 21,
        leftPadding = 10,
        padding = 10,
        viewportWidth = 300,
        viewportHeight = 200,
    })
assert(calculatedLayout.horizontalPositions[21] == 10
    and calculatedLayout.horizontalPositions[22] == 68
    and calculatedLayout.horizontalPositions[23] == 68,
    "tree layout changed parent/child horizontal placement")
assert(calculatedLayout.verticalPositions[22]
    < calculatedLayout.verticalPositions[23],
    "tree layout did not vertically pack sibling nodes")
assert(calculatedLayout.contentWidth == 300
    and calculatedLayout.contentHeight == 200,
    "tree layout did not preserve the viewport minimum size")

local gridNodes = {}
for id = 1, 10 do
    gridNodes[id] = { id = 1000 + id, layoutWidth = 50 }
end
local gridLayout = Addon.AchievementTreeLayout.Calculate(
    gridNodes, {}, gridNodes[1], {
        availableHeight = 65,
        branchGap = 1,
        levelGap = 8,
        nodeRowPitch = 21,
        leftPadding = 10,
        padding = 10,
        viewportWidth = 120,
        viewportHeight = 85,
    })
assert(gridLayout.horizontalPositions[1001]
        == gridLayout.horizontalPositions[1003]
    and gridLayout.horizontalPositions[1004]
        > gridLayout.horizontalPositions[1003]
    and gridLayout.horizontalPositions[1010]
        > gridLayout.horizontalPositions[1007],
    "independent achievements were not packed by maximum rows into columns")
assert(gridLayout.contentWidth > 120,
    "overflowing achievement columns did not create a draggable grid")

local GetAchievementRewardData = Addon.AchievementRewards.Get
local HasAchievementReward = Addon.AchievementRewards.Has
local kiklakItemID, kiklakInferred =
    Addon.RewardDatabase.GetReward(63633, 1)
assert(kiklakItemID == 279921 and kiklakInferred,
    "generated reward database is missing Kiklak")
local directItemID, directInferred =
    Addon.RewardDatabase.GetReward(20501, 1)
local decorItemID, decorInferred =
    Addon.RewardDatabase.GetReward(20501, 2)
assert(directItemID == 217612 and not directInferred
    and decorItemID == 248125 and decorInferred,
    "generated reward database lost a direct plus decor reward")
assert(Addon.RewardDatabase.HasCategory(20501, "mount")
    and Addon.RewardDatabase.HasCategory(20501, "decor")
    and Addon.RewardDatabase.HasCategory(63633, "pet"),
    "generated reward categories lost multi-reward or pet evidence")

local originalGetAchievementInfo = GetAchievementInfo
local originalGetRewardItemID = C_AchievementInfo.GetRewardItemID
GetAchievementInfo = function(id)
    local rewardText = id == 700002 and "Reward" or ""
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123, rewardText, false
end
C_AchievementInfo.GetRewardItemID = function(id)
    return id == 700003 and 99003 or nil
end
Addon.AchievementRewardDatabase.rewards[700001] = { 64, 0 }
assert(HasAchievementReward(700001),
    "database reward was not detected")
assert(HasAchievementReward(700002),
    "reward text was not detected")
assert(HasAchievementReward(700003),
    "runtime reward item was not detected")
assert(not HasAchievementReward(700004),
    "achievement without a reward was detected")
Addon.AchievementRewardDatabase.rewards[700001] = nil
C_AchievementInfo.GetRewardItemID = originalGetRewardItemID
GetAchievementInfo = originalGetAchievementInfo

local ConfigureAchievementCardChildLinks =
    AchievementUI.ConfigureAchievementCardChildLinks
assert(ConfigureAchievementCardChildLinks,
    "achievement card child-link configurator was not reachable")
local childButton = { id = 4321, scripts = {} }
function childButton:RegisterForClicks(...)
    self.registeredClicks = { ... }
end
function childButton:SetScript(script, callback)
    self.scripts[script] = callback
end
local originalShowAchievementTree = AchievementUI.ShowAchievementTree
local openedChildID
AchievementUI.ShowAchievementTree = function(id, _, _, showCardOnly)
        openedChildID = id
        assert(showCardOnly == true,
            "achievement child did not request card-only display")
    end
function IsShiftKeyDown() return false end
ConfigureAchievementCardChildLinks({ metas = { childButton } })
assert(childButton.registeredClicks[1] == "LeftButtonUp"
    and childButton.registeredClicks[2] == "RightButtonUp",
    "achievement child did not register card navigation clicks")
childButton.scripts.OnClick(childButton, "LeftButton")
assert(openedChildID == 4321,
    "achievement child did not open its achievement card")
AchievementUI.ShowAchievementTree = originalShowAchievementTree

Addon.AchievementRewardDatabase.rewards[1] = { 64, 9101, -9102 }
C_AchievementInfo.GetRewardItemID = function()
    error("runtime reward API should not run after a database hit")
end
C_Item = {
    GetItemNameByID = function() return "Database Reward" end,
    GetItemIconByID = function() return 321 end,
    RequestLoadItemDataByID = function() end,
}
local databaseReward = GetAchievementRewardData(1)
assert(databaseReward and #databaseReward.entries == 2
    and databaseReward.entries[1].itemID == 9101
    and databaseReward.entries[2].itemID == 9102,
    "generated reward database was not used before runtime fallback")
Addon.AchievementRewardDatabase.rewards[1] = nil

C_AchievementInfo.GetRewardItemID = function()
    return 9001
end
C_Item = {
    GetItemNameByID = function() return "Reward Item" end,
    GetItemIconByID = function() return 456 end,
    RequestLoadItemDataByID = function() end,
}
C_MountJournal = {
    GetMountFromItem = function() return 77 end,
    GetMountInfoByID = function() return "Reward Mount", nil, 789 end,
    GetMountInfoExtraByID = function()
        return 321, "Mount details", nil, false, nil, 444
    end,
}
local reward = GetAchievementRewardData(1)
local rewardEntry = reward and reward.entries and reward.entries[1]
assert(rewardEntry and rewardEntry.itemID == 9001
    and rewardEntry.displayID == 321
    and rewardEntry.previewType == "model"
    and rewardEntry.rewardType == "mount",
    "mount reward was not resolved")
C_MountJournal.GetMountFromItem = function() return nil end
C_PetJournal = {
    GetPetInfoByItemID = function()
        return "Reward Pet", 654, nil, 111, nil, "Pet details",
            nil, nil, nil, nil, nil, 222, 333
    end,
    GetPetModelSceneInfoBySpeciesID = function() return 555 end,
}
reward = GetAchievementRewardData(1)
rewardEntry = reward.entries[1]
assert(rewardEntry.name == "Reward Pet" and rewardEntry.displayID == 222
    and rewardEntry.previewType == "model", "pet reward was not resolved")
C_PetJournal.GetPetInfoByItemID = function() end
C_ToyBox = {
    GetToyInfo = function() return 9001, "Reward Toy", 987 end,
}
C_TooltipInfo = {
    GetToyByItemID = function()
        return { lines = { { leftText = "Toy details" } } }
    end,
}
reward = GetAchievementRewardData(1)
rewardEntry = reward.entries[1]
assert(rewardEntry.name == "Reward Toy" and rewardEntry.icon == 987
    and rewardEntry.description == "Toy details"
    and rewardEntry.previewType == "icon", "toy reward was not resolved")

C_ToyBox.GetToyInfo = function() end
C_TransmogCollection = {
    GetItemInfo = function() return 7001, 8001 end,
}
reward = GetAchievementRewardData(1)
rewardEntry = reward.entries[1]
assert(rewardEntry.rewardType == "appearance"
    and rewardEntry.previewType == "appearance"
    and rewardEntry.appearanceSourceIDs[1] == 8001,
    "appearance reward was not resolved")

C_AchievementInfo.GetRewardItemID = function() return nil end
reward = GetAchievementRewardData(1)
assert(reward and #reward.entries == 0,
    "title-only reward unexpectedly created a preview")
C_AchievementInfo.GetRewardItemID = function() return 0 end
reward = GetAchievementRewardData(1)
assert(reward and #reward.entries == 0,
    "zero runtime reward item ID created a preview")

C_MountJournal.GetMountIDs = function() return { 1614, 1690 } end
C_MountJournal.GetMountInfoByID = function(mountID)
    if mountID == 1690 then
        return "Whelp", nil, 790, nil, nil, -1
    end
    return "Direct Reward Mount", nil, 789, nil, nil, 5
end
C_MountJournal.GetMountInfoExtraByID = function()
    return 321, "Direct mount details", nil, false, nil, 444
end
function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123, "Mount: Direct Reward Mount", false
end
reward = GetAchievementRewardData(1)
rewardEntry = reward.entries[1]
assert(rewardEntry and rewardEntry.mountID == 1614
    and rewardEntry.previewType == "model",
    "direct mount reward text was not resolved")

function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123, "Title: Whelp Caretaker", false
end
reward = GetAchievementRewardData(1)
assert(reward and #reward.entries == 0,
    "non-achievement mount source created a false reward match")

function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123, "Mount: Direct Reward Mount", false
end

C_AchievementInfo.GetRewardItemID = function() return 9002 end
C_Item.GetItemNameByID = function() return nil end
C_Item.GetItemIconByID = function() return nil end
C_Item.GetItemInfoInstant = function()
    return 9002, nil, nil, nil, nil, 15, 5
end
Enum = {
    ItemClass = { Miscellaneous = 15 },
    ItemMiscellaneousSubclass = { Mount = 5 },
}
C_TransmogCollection.GetItemInfo = function() return nil end
reward = GetAchievementRewardData(1)
rewardEntry = reward.entries[1]
assert(#reward.entries == 1 and rewardEntry.mountID == 1614
    and rewardEntry.itemID == 9002,
    "unloaded mount reward item was duplicated by text resolution")
C_AchievementInfo.GetRewardItemID = function() return nil end

C_TransmogSets = {
    GetAllSets = function()
        return {
            {
                setID = 5282,
                name = "Sargerei Commander's Lightbound Regalia",
                validForCharacter = true,
            },
        }
    end,
    GetAllSourceIDs = function()
        return { 8101, 8102, 8103 }
    end,
}
C_TransmogCollection.GetSourceIcon = function() return 999 end
function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123,
        "Appearance: Sargerei Commander's Lightbound Regalia", false
end
reward = GetAchievementRewardData(1)
rewardEntry = reward.entries[1]
assert(rewardEntry and rewardEntry.rewardType == "appearance"
    and rewardEntry.transmogSetID == 5282
    and #rewardEntry.appearanceSourceIDs == 3,
    "direct transmog set reward text was not resolved")

function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123, "Reward", false
end

C_AchievementInfo.GetRewardItemID = function() return 9001 end
C_Item.IsDecorItem = function() return true end
C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function()
        return {
            itemID = 9001,
            name = "Reward Decor",
            iconTexture = 246,
            asset = 1357,
            uiModelSceneID = 2468,
            sourceText = "Achievement: Achievement 1",
        }
    end,
}
reward = GetAchievementRewardData(1)
rewardEntry = reward.entries[1]
assert(rewardEntry and rewardEntry.rewardType == "decor"
    and rewardEntry.asset == 1357 and rewardEntry.previewType == "model",
    "housing decor reward was not resolved")

C_Item.IsDecorItem = function() return false end
GetLocale = function() return "enUS" end
local searchCallback
local searcher = {
    SetOwnedOnly = function() end,
    SetCollected = function() end,
    SetUncollected = function() end,
    SetFirstAcquisitionBonusOnly = function() end,
    SetSearchText = function() end,
    SetResultsUpdatedCallback = function(_, callback)
        searchCallback = callback
    end,
    GetCatalogSearchResults = function()
        return {
            { recordID = 2 },
            { recordID = 3 },
            { recordID = 4 },
            { recordID = 5 },
        }
    end,
    RunSearch = function()
        searchCallback()
    end,
}
C_HousingCatalog = {
    CreateCatalogSearcher = function() return searcher end,
    GetCatalogEntryInfo = function(entryID)
        local decorNames = {
            [2] = "Second Reward Decor",
            [3] = "Prized Orb of Azeroth",
            [4] = "Framed Horde Pride",
            [5] = "Framed Alliance Pride",
        }
        local recordID = entryID.recordID
        return {
            entryID = { recordID = recordID },
            itemID = 9000 + recordID,
            name = decorNames[recordID],
            iconTexture = 357,
            asset = 2468 + recordID,
            uiModelSceneID = 1357,
            placementCost = 0,
            sourceText = recordID == 2
                and "Achievement: Achievement 1" or "Vendor: Richmond",
        }
    end,
}
reward = GetAchievementRewardData(1)
assert(#reward.entries == 2
    and reward.entries[2].rewardType == "decor"
    and reward.entries[2].name == "Second Reward Decor",
    "multiple achievement rewards were not combined")

C_AchievementInfo.GetRewardItemID = function() return nil end
function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123,
        "Decor rewards: Prized Orb of Azeroth, Framed Horde Pride, "
            .. "Framed Alliance Pride",
        false
end
reward = GetAchievementRewardData(1)
assert(reward and #reward.entries == 4,
    "decor names in reward text were not resolved")

function GetAchievementInfo(id)
    return id, "Achievement " .. id, 10, false, nil, nil, nil,
        "Description", 0, 123, nil, false
end
reward = GetAchievementRewardData(1)
assert(reward and #reward.entries == 1
    and reward.entries[1].name == "Second Reward Decor",
    "decor rewards disappeared when reward text was empty")

settingValue = true
settingCallback(true)
button.scripts.OnClick(button, "LeftButton", false)
assert(button.originalClicks == 1, "left click was not preserved")
button.scripts.OnClick(button, "RightButton", false)
assert(button.originalClicks == 2, "right click was modified")
assert(menuCount == 0, "native achievement received a context menu")
assert(button.registeredClicks == nil,
    "native achievement click registration was modified")

settingValue = false
settingCallback(false)
button.scripts.OnClick(button, "RightButton", false)
assert(button.originalClicks == 3, "native click changed after disabling")

print("native achievement UI untouched: ok")

local methods = {}
local function Widget()
    return setmetatable({ width = 380, height = 48, shown = true,
        text = "", points = {} }, { __index = methods })
end
function methods:SetPoint(point, ...) self.points[point] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetWidth(value) self.width = value end
function methods:GetWidth() return self.width end
function methods:SetHeight(value) self.height = value end
function methods:GetHeight() return self.height end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetShown(value) self.shown = value end
function methods:IsShown() return self.shown end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetText(value) self.text = value end
function methods:GetStringWidth() return #self.text * 8 end
function methods:GetStringHeight()
    return math.ceil(#self.text * 8 / self.width) * 18
end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:GetFrameStrata() return "DIALOG" end
function methods:GetFrameLevel() return 1 end
function methods:GetActorByTag() return self.actor end
function methods:GetPlayerActor() return self.actor end
for _, name in ipairs({ "SetTexture", "SetTexCoord", "SetAtlas",
    "SetEnabled", "SetJustifyV", "SetParent", "SetFrameStrata",
    "SetFrameLevel", "ClearScene", "TransitionToModelSceneID",
    "Raise", "UpdateLayout" }) do
    methods[name] = function() end
end
function methods:ClearScene()
    self.clears = (self.clears or 0) + 1
end

local reward, lookups
local addon = { AchievementRewards = {
    Request = function() lookups = lookups + 1; return reward end,
    SetIndexReadyCallback = function() end,
} }
assert(loadfile("EasyAchievement/Modules/AchievementUI.lua"))("EasyAchievement", addon)
local ui = addon.AchievementUI
ui.L = {}
ui.SetupPlayerForModelScene = function() end
ui.DRESS_UP_FRAME_MODEL_SCENE_ID = 1
assert(loadfile("EasyAchievement/Modules/Achievements/Window.lua"))(
    "EasyAchievement", addon)
assert(loadfile("EasyAchievement/Modules/Achievements/RewardPanel.lua"))(
    "EasyAchievement", addon)
local host, panel = Widget(), Widget()
host.width = 900
host.Title, host.Stats, host.HeaderRow = Widget(), Widget(), Widget()
for _, name in ipairs({ "ItemIcon", "CollectionBorder", "PetBorder",
    "ToyButton", "ItemName", "Description", "ModelScene", "ModelControls",
    "PreviousReward", "NextReward", "EntryCounter" }) do
    panel[name] = Widget()
end
panel.ToyButton.Icon = Widget()
panel.Description:SetJustifyH("CENTER")
panel.entryIndex = 1
ui.achievementRewardFrame = panel

for _, kind in ipairs({ "mount", "pet", "toy", "decor", "appearance", "item" }) do
    local model = kind == "mount" or kind == "pet" or kind == "decor"
        or kind == "appearance"
    reward = { text = "Reward summary", entries = {
        { name = string.rep("Long reward name ", 8), description = "Reward description",
            rewardType = kind, icon = 123, itemID = 456,
            previewType = kind == "appearance" and "appearance"
                or model and "model" or "icon", modelSceneID = 1,
            appearanceSourceIDs = { 1 },
            displayID = 2, asset = 3 },
        { name = "Second reward", rewardType = "item", previewType = "icon" },
    } }
    lookups = 0
    ui.UpdateAchievementHeader(host, "Achievement", "Statistics")
    ui.UpdateAchievementRewardHeader(host, 123)
    assert(lookups == 0 and not host.RewardSummary,
        "removed header summary still queries or displays rewards")
    assert(ui.UpdateAchievementRewardPanel(host, 123))
    assert(panel.ItemType == nil and panel.ItemName.justifyH == "CENTER"
        and panel.Description.justifyH == "CENTER",
        "reward layout restored the removed type prefix or lost name alignment")
    local namePoint = panel.ItemName.points.TOP
    local descriptionPoint = panel.Description.points.TOPLEFT
    local iconPoint = panel.ItemIcon.points.TOP
    assert(namePoint[3] == iconPoint[3]
        and descriptionPoint[4] < namePoint[4] - panel.ItemName.height
        and iconPoint[4] < descriptionPoint[4] - panel.Description.height,
        "reward text is not centered above the icon or overlaps it")
    assert(panel.ItemName.height > 18 and panel.EntryCounter.shown
        and panel.NextReward.shown,
        "wrapped names or multiple-reward controls were lost")
    if model then
        assert(panel.ModelScene.points.TOPLEFT[4] < iconPoint[4] - 48,
            "model viewport overlaps the relocated reward information")
    end
end

-- Scene replacement must follow model identity, not every UI refresh.
local actor = { loads = 0, rotation = 0 }
local camera = { zoom = 0 }
function camera:SetTarget() end
function camera:SetZoomDistance(value) self.zoom = value end
function actor:IsLoaded() return true end
function actor:GetActiveBoundingBox() return -2, -2, -2, 2, 2, 2 end
function actor:SetOnModelLoadedCallback(callback) self.onLoaded = callback end
function actor:SetModelByCreatureDisplayID()
    self.loads = self.loads + 1
    self.rotation = 0
end
function actor:SetAnimation() end
function actor:Show() end
panel.ModelScene.actor = actor
panel.ModelScene.GetActiveCamera = function() return camera end
panel.ModelScene.OnMouseWheel = function(_, delta) camera.zoom = camera.zoom - delta end
reward = { state = "ready", entries = {
    { uniqueKey = "mount:1", rewardType = "mount", previewType = "model",
        modelSceneID = 1, displayID = 100, name = "Mount", icon = 123 },
    { uniqueKey = "item:2", rewardType = "item", previewType = "icon",
        name = "Item", icon = 456 },
} }
ui.UpdateAchievementRewardPanel(host, 987)
local clears = panel.ModelScene.clears
actor.rotation = 1.5
camera.zoom = 25
host.width = 1000
reward.entries[1].description = "New text"
ui.UpdateAchievementRewardPanel(host, 987)
assert(panel.ModelScene.clears == clears and actor.loads == 1
    and actor.rotation == 1.5 and camera.zoom == 25
    and panel.Description.text == "New text",
    "text or layout refresh reset an unchanged model")
table.insert(reward.entries, 1,
    { uniqueKey = "item:3", rewardType = "item", previewType = "icon" })
ui.UpdateAchievementRewardPanel(host, 987)
assert(panel.entryIndex == 2 and panel.entryKey == "mount:1"
    and actor.rotation == 1.5,
    "an asynchronously inserted reward changed the selected model")
local oldModelCallback = actor.onLoaded
reward.entries[2].displayID = 101
ui.UpdateAchievementRewardPanel(host, 987)
assert(actor.loads == 2, "changed model data did not rebuild the scene")
camera.zoom = 30
oldModelCallback(actor)
assert(camera.zoom == 30, "stale model callback refitted a newer model")
panel.entryIndex, panel.entryKey = 3, nil
ui.UpdateAchievementRewardPanel(host, 987)
assert(not panel.ModelScene:IsShown() and panel.modelKey == nil,
    "switching to an icon reward left the old model active")
panel.entryIndex, panel.entryKey = 2, nil
panel.ModelScene.actor = nil
ui.UpdateAchievementRewardPanel(host, 987)
assert(panel.pendingModelRefresh, "missing scene actor was not marked pending")
panel.ModelScene.actor = actor
ui.UpdateAchievementRewardPanel(host, 987)
assert(not panel.pendingModelRefresh and actor.loads == 3,
    "late scene actor did not recover")
print("reward layout, selection identity and model view preservation: ok")

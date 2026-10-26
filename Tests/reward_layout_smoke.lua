local methods = {}
local function Widget()
    return setmetatable({ width = 380, height = 48, shown = true,
        text = "", points = {} }, { __index = methods })
end
function methods:SetPoint(point, ...) self.points[point] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetParent(parent) self.parent = parent end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:GetVerticalScrollRange()
    return math.max(0, self.scrollContent.height - self.height)
end
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
function methods:GetText() return self.text end
function methods:GetStringWidth() return #self.text * 8 end
function methods:GetStringHeight()
    if self.wordWrap == false then return self.text ~= "" and 18 or 0 end
    return math.ceil(#self.text * 8 / self.width) * 18
end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:SetWordWrap(value) self.wordWrap = value end
function methods:GetFrameStrata() return "DIALOG" end
function methods:GetFrameLevel() return 1 end
function methods:GetActorByTag() return self.actor end
function methods:GetPlayerActor() return self.actor end
for _, name in ipairs({ "SetTexture", "SetTexCoord", "SetAtlas",
    "SetEnabled", "SetJustifyV", "SetFrameStrata",
    "SetFrameLevel", "ClearScene", "TransitionToModelSceneID",
    "Raise", "UpdateLayout" }) do
    methods[name] = function() end
end
function methods:ClearScene()
    self.clears = (self.clears or 0) + 1
end

local reward, lookups
local categories = {}
local addon = { AchievementRewards = {
    Request = function() lookups = lookups + 1; return reward end,
    SetIndexReadyCallback = function() end,
    Has = function(_, data) return data and data.hasReward or false end,
} }
assert(loadfile("EasyAchievement/Modules/AchievementUI.lua"))("EasyAchievement", addon)
local ui = addon.AchievementUI
ui.L = {}
ui.RewardDatabase = {
    HasCategory = function(achievementID, category)
        return categories[achievementID] == category
    end,
}
local appearanceAutoDress
ui.SetupPlayerForModelScene = function(_, _, _, _, autoDress)
    appearanceAutoDress = autoDress
end
ui.DRESS_UP_FRAME_MODEL_SCENE_ID = 1
assert(loadfile("EasyAchievement/Modules/Achievements/Window.lua"))(
    "EasyAchievement", addon)
assert(loadfile("EasyAchievement/Modules/Achievements/RewardPanel.lua"))(
    "EasyAchievement", addon)
local host, panel = Widget(), Widget()
host.width = 900
host.Title, host.Stats, host.HeaderRow = Widget(), Widget(), Widget()
host.StatsRuler = Widget()
host.Stats:SetText("Achievements Earned: 3023/6562")
ui.LayoutAchievementHeader(host)
assert(host.Stats.width > 125
    and host.HeaderRow.width == host.width - 76,
    "header stats must fit their text inside the top border")
for _, name in ipairs({ "ItemName", "Description",
    "ModelScene", "ModelControls",
    "PreviousReward", "NextReward", "EntryCounter", "InfoCard",
    "RewardTypeText", "DetailsButton", "DetailsPanel", "RewardSelector",
    "TextPreview" }) do
    panel[name] = Widget()
end
panel.DetailsPanel.DetailsText = Widget()
panel.TextPreview.ToyButton = Widget()
panel.TextPreview.ToyIcon = Widget()
panel.TextPreview.Text = Widget()
panel.Description:SetJustifyH("CENTER")
panel.entryIndex = 1
ui.achievementRewardFrame = panel
panel:Hide()
local rewardOffset = -(ui.GetAchievementRewardPanelWidth(host) / 2 + 6)
assert(ui.GetAchievementCardRewardOffset(host, 123,
        { hasReward = true }) == rewardOffset
    and ui.GetAchievementCardRewardOffset(host, 124,
        { hasReward = false }) == rewardOffset,
    "all cards must keep the reward-panel position")
host.officialBrowserState = {}
host.officialContext = { categoryID = 1 }
assert(ui.GetAchievementCardRewardOffset(host, 123,
        { hasReward = true }) == rewardOffset + 108
    and ui.GetAchievementCardRewardOffset(host, 124,
        { hasReward = false }) == rewardOffset + 108,
    "official list cards must keep the same offset with or without rewards")
host.officialBrowserState = nil
host.officialContext = nil
panel:Show()

for _, kind in ipairs({ "mount", "pet", "toy", "decor", "appearance", "item" }) do
    local model = kind == "mount" or kind == "pet" or kind == "decor"
        or kind == "appearance"
    reward = { text = "Reward summary", entries = {
        { name = string.rep("Long reward name ", 8),
            description = kind == "decor"
                and ("Achievement: Example\nCategory: Decor\nPrice: 1 ")
                    .. string.rep("Detailed reward information ", 12)
                or "Reward description",
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
    assert(panel.ItemName.justifyH == "CENTER"
        and panel.Description.justifyH == "CENTER"
        and panel.ItemName.points.TOP[1] == panel.InfoCard
        and panel.Description.points.TOPLEFT[1] == panel.InfoCard,
        "reward name, type, and summary are not in the shop-style info card")
    assert(panel.TextPreview.shown == (kind == "toy")
        and panel.InfoCard.shown == (kind ~= "toy")
        and (kind ~= "mount" and kind ~= "pet"
            or not panel.DetailsButton.shown),
        "reward type did not use the requested display mode")
    if kind == "toy" then
        assert(panel.TextPreview.ToyButton.shown
            and panel.TextPreview.ToyButton.itemID == 456
            and panel.TextPreview.Text.text == "Reward description",
            "toy icon or usage text was not centered in reward area")
    end
    if kind == "decor" then
        assert(panel.Description.wordWrap == true
            and not panel.Description.text:find("\n", 1, true)
            and panel.DetailsButton.shown
            and panel.DetailsPanel.DetailsText.text:find("\n", 1, true)
            and panel.DetailsPanel.height ==
                panel.DetailsPanel.DetailsText:GetStringHeight() + 24,
            "decor summary or complete details were lost")
    else
        assert(panel.Description.wordWrap == true,
            "another reward type lost wrapped summary text")
    end
    assert(panel.ItemName.height > 18 and panel.EntryCounter.shown
        and panel.NextReward.shown,
        "wrapped names or multiple-reward controls were lost")
    if model then
        assert(panel.ModelScene.points.TOPLEFT[4] == -10
            and panel.RewardSelector.points.TOP[4] == -6
            and panel.ModelControls.points.BOTTOM[4] == 65,
            "reward selector must sit above the model without moving its controls")
    end
end

for _, kind in ipairs({ "mount", "pet" }) do
    reward = { entries = {
        { name = "Long description", rewardType = kind,
            description = string.rep("Reward details ", 12),
            previewType = "icon" },
    } }
    ui.UpdateAchievementRewardPanel(host, kind == "mount" and 457 or 458)
    assert(not panel.DetailsButton.shown,
        "mount and pet rewards must never show the details button")
end

categories[789] = "title"
reward = { text = "Title reward: Whelpling Caretaker", entries = {} }
assert(ui.UpdateAchievementRewardPanel(host, 789)
    and panel.TextPreview.shown and not panel.InfoCard.shown
    and panel.TextPreview.Text.text == reward.text,
    "title rewards without item IDs must show centered reward text")
categories[790] = "other"
reward = { text = "Other reward information", entries = {} }
assert(ui.UpdateAchievementRewardPanel(host, 790)
    and panel.TextPreview.shown and not panel.InfoCard.shown
    and panel.TextPreview.Text.text == reward.text,
    "other text-only rewards must show centered reward text")
categories[791] = "other"
reward = { text = "Other item reward", entries = {
    { name = "Other item", rewardType = "item", previewType = "icon" },
} }
assert(ui.UpdateAchievementRewardPanel(host, 791)
    and panel.TextPreview.shown
    and panel.TextPreview.Text.text == reward.text,
    "other item rewards must show reward text in the centered area")
categories[792] = "title"
reward = { text = "Title and item reward", entries = {
    { name = "Reward item", rewardType = "item", previewType = "icon" },
} }
assert(ui.UpdateAchievementRewardPanel(host, 792)
    and panel.entryCount == 2 and panel.InfoCard.shown,
    "a title reward must not replace a separate item reward")
panel.entryIndex = 2
assert(ui.UpdateAchievementRewardPanel(host, 792)
    and panel.TextPreview.shown
    and panel.TextPreview.Text.text == reward.text,
    "title text must be reachable as the second reward")

reward = { entries = {
    { name = "Single mount", description = "Single reward description",
        rewardType = "mount", icon = 123, previewType = "model",
        modelSceneID = 1, displayID = 2 },
} }
ui.UpdateAchievementRewardPanel(host, 456)
assert(not panel.EntryCounter.shown
    and not panel.PreviousReward.shown and not panel.NextReward.shown
    and panel.ModelScene.points.TOPLEFT[4] == -10,
    "single model reward retained a multiple-reward selector")

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
function actor:SetModelByFileID() end
function actor:Undress() self.undressCount = (self.undressCount or 0) + 1 end
function actor:SetAnimation() end
function actor:Show() end
panel.ModelScene.actor = actor
panel.ModelScene.GetActiveCamera = function() return camera end
panel.ModelScene.OnMouseWheel = function(self, delta)
    self.wheelCount = (self.wheelCount or 0) + 1
    camera.zoom = camera.zoom - delta
end
reward = { state = "ready", entries = {
    { uniqueKey = "mount:1", rewardType = "mount", previewType = "model",
        modelSceneID = 1, displayID = 100, name = "Mount", icon = 123 },
    { uniqueKey = "item:2", rewardType = "item", previewType = "icon",
        name = "Item", icon = 456 },
} }
ui.UpdateAchievementRewardPanel(host, 987)
local clears = panel.ModelScene.clears
local initialWheelCount = panel.ModelScene.wheelCount
assert(initialWheelCount == 2,
    "mount initial view is not two native zoom-out steps from the fitted view")
actor.rotation = 1.5
camera.zoom = 25
host.width = 1000
reward.entries[1].description = "New text"
ui.UpdateAchievementRewardPanel(host, 987)
assert(panel.ModelScene.clears == clears and actor.loads == 1
    and panel.ModelScene.wheelCount == initialWheelCount
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
reward = { entries = {
    { uniqueKey = "decor:1", rewardType = "decor",
        previewType = "model", modelSceneID = 1, asset = 10,
        name = "Decor" },
} }
ui.UpdateAchievementRewardPanel(host, 990)
assert(actor.undressCount == 1,
    "decor scenes with a character actor must remove its current outfit")
reward = { entries = {
    { uniqueKey = "appearance:1", rewardType = "appearance",
        previewType = "appearance", appearanceSourceIDs = { 555 },
        name = "Appearance" },
} }
ui.UpdateAchievementRewardPanel(host, 989)
assert(appearanceAutoDress == false,
    "character preview must start without the player's equipped outfit")
reward = { entries = {
    { uniqueKey = "pet:1", rewardType = "pet", previewType = "model",
        modelSceneID = 1, displayID = 200, name = "Pet" },
} }
local beforePetWheelCount = panel.ModelScene.wheelCount
ui.UpdateAchievementRewardPanel(host, 988)
assert(panel.ModelScene.wheelCount == beforePetWheelCount + 1,
    "non-mount model did not start one native zoom-out step smaller")
print("reward layout, selection identity and model view preservation: ok")

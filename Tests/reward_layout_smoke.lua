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
function methods:GetActorByTag() return nil end
function methods:GetPlayerActor() return nil end
for _, name in ipairs({ "SetTexture", "SetTexCoord", "SetAtlas",
    "SetEnabled", "SetJustifyV", "SetParent", "SetFrameStrata",
    "SetFrameLevel", "ClearScene", "TransitionToModelSceneID",
    "Raise", "UpdateLayout" }) do
    methods[name] = function() end
end

local reward, lookups
local addon = { AchievementRewards = {
    Get = function() lookups = lookups + 1; return reward end,
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
panel.entryIndex, panel.infoRetryCount = 1, 0
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
print("reward header removal and vertically centered reward information: ok")

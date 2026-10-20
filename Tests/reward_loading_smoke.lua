local now, ready, pending = 0, false, {}
local textByID = { [1] = "Mount: Test Mount", [2] = "Title: Example" }
local addon = {
    L = {},
    Config = { Performance = { IndexBudgetMilliseconds = 2 } },
    AchievementData = {
        Get = function(id)
            return { id = id, name = "Achievement " .. id,
                rewardText = textByID[id] }
        end,
    },
    RewardDatabase = { HasReward = function() return false end },
}
local env = setmetatable({
    C_AchievementInfo = false, C_HousingCatalog = false,
    C_TransmogSets = false,
    GetTime = function() return now end,
    C_Timer = { After = function(delay, callback)
        pending[#pending + 1] = { delay = delay, callback = callback }
    end },
    C_MountJournal = {
        GetMountIDs = function() return { 1 } end,
        GetMountInfoByID = function()
            return "Test Mount", nil, 123, nil, nil, 5
        end,
        GetMountInfoExtraByID = function()
            if ready then return 100, "Description", nil, false, nil, 4 end
        end,
    },
}, { __index = _G })
assert(loadfile("EasyAchievement/Modules/AchievementRewards.lua", "t", env))(
    "EasyAchievement", addon)
local rewards = addon.AchievementRewards
local notifications, latest = {}, nil
rewards.SetIndexReadyCallback(function(id)
    notifications[#notifications + 1] = id
    latest = rewards.Request(id)
end)
local function Tick()
    local callbacks = pending
    pending = {}
    for _, timer in ipairs(callbacks) do
        now = now + timer.delay
        timer.callback()
    end
end

assert(rewards.Get(1).state == "pending" and #pending == 0,
    "ordinary reward reads scheduled UI retries")
assert(rewards.Get(2).state == "unmatched")
rewards.Request(1)
rewards.Request(1)
assert(#pending == 1, "visible reward requests scheduled duplicate retries")
ready = true
Tick()
assert(#notifications == 1 and latest.state == "ready"
    and latest.entries[1].previewType == "model" and #pending == 0,
    "delayed model metadata did not upgrade the visible reward")

ready = false
rewards.InvalidateCollectionIndexes()
rewards.CancelRequest()
rewards.Request(1)
rewards.Request(2)
local count = #notifications
Tick()
assert(#notifications == count, "old reward retry notified after navigation")
rewards.Request(1)
rewards.CancelRequest()
Tick()
assert(#notifications == count, "closed panel still received a reward retry")

rewards.Request(1)
for _ = 1, 4 do Tick() end
assert(#notifications == count + 3 and #pending == 0,
    "pending data retried without a bound")
ready = true
assert(rewards.Request(1).state == "ready",
    "retry limit permanently prevented later recovery")
print("reward loading states, bounded retries and cancellation: ok")

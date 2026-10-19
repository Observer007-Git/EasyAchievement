local _, Addon = ...

local raw = assert(Addon.AchievementRewardDatabase,
    "EasyAchievement reward database was not loaded")
assert(raw.schema == 2,
    "EasyAchievement reward database schema is not supported")

local Database = {}
Addon.RewardDatabase = Database

local CATEGORY_BITS = {
    mount = 1,
    pet = 2,
    toy = 4,
    decor = 8,
    title = 16,
    appearance = 32,
    other = 64,
}
local function HasBit(mask, value)
    return mask % (value * 2) >= value
end

function Database.GetBuild()
    return raw.build
end

function Database.HasReward(achievementID)
    return raw.rewards[achievementID] ~= nil
end

function Database.GetReward(achievementID, index)
    local values = raw.rewards[achievementID]
    local encoded = values and values[index + 1]
    if encoded == nil then
        return nil
    end
    if encoded < 0 then
        return -encoded, true
    end
    return encoded, false
end

function Database.GetAchievementIDs()
    local achievementIDs = {}
    for achievementID in pairs(raw.rewards) do
        achievementIDs[#achievementIDs + 1] = achievementID
    end
    return achievementIDs
end

function Database.HasCategory(achievementID, category)
    local values = raw.rewards[achievementID]
    local categoryBit = CATEGORY_BITS[category]
    return values ~= nil and categoryBit ~= nil
        and HasBit(values[1], categoryBit)
end

function Database.GetFaction(achievementID)
    return raw.factions[achievementID]
end

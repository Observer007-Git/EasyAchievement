local _, Addon = ...
local UI = assert(Addon.AchievementUI,
    "EasyAchievement achievement UI environment was not loaded")

-- WoW uses Lua 5.1 semantics; local development uses newer Lua.
-- Both branches bind this chunk to the same addon-private environment.
if setfenv then
    setfenv(1, UI)
else
    _ENV = UI
end

function SetTextureAtlas(texture, atlas, useAtlasSize)
    if not texture or type(texture.SetAtlas) ~= "function" then
        return false
    end
    return pcall(texture.SetAtlas, texture, atlas, useAtlasSize == true)
end

function GetCharacterReputationProgress(factionID)
    if type(factionID) ~= "number" or factionID <= 0 then
        return nil
    end

    local factionData = C_Reputation and C_Reputation.GetFactionDataByID
        and C_Reputation.GetFactionDataByID(factionID)
    local factionName = factionData and factionData.name
    local isMajorFaction = C_Reputation and C_Reputation.IsMajorFaction
        and C_Reputation.IsMajorFaction(factionID)
    local majorFactionData = isMajorFaction and C_MajorFactions
        and C_MajorFactions.GetMajorFactionData
        and C_MajorFactions.GetMajorFactionData(factionID)
    if majorFactionData and type(majorFactionData.renownLevel) == "number"
    then
        factionName = majorFactionData.name or factionName
            or tostring(factionID)
        local current = majorFactionData.renownReputationEarned
        local maximum = majorFactionData.renownLevelThreshold
        if type(current) == "number" and type(maximum) == "number"
            and maximum > 0
        then
            return string.format(L.ACHIEVEMENT_CURRENT_RENOWN,
                factionName, majorFactionData.renownLevel,
                current, maximum)
        end
        return string.format(L.ACHIEVEMENT_CURRENT_RENOWN_LEVEL,
            factionName, majorFactionData.renownLevel)
    end

    if not factionData or type(factionData.reaction) ~= "number" then
        return nil
    end
    factionName = factionName or tostring(factionID)
    local standingLabel = GetText
        and GetText("FACTION_STANDING_LABEL" .. factionData.reaction,
            UnitSex and UnitSex("player") or 2)
        or _G["FACTION_STANDING_LABEL" .. factionData.reaction]
        or tostring(factionData.reaction)
    local currentStanding = factionData.currentStanding
    local lower = factionData.currentReactionThreshold
    local upper = factionData.nextReactionThreshold
    if type(currentStanding) == "number" and type(lower) == "number"
        and type(upper) == "number" and upper > lower
    then
        return string.format(L.ACHIEVEMENT_CURRENT_REPUTATION,
            factionName, standingLabel, currentStanding - lower,
            upper - lower)
    end
    return string.format(L.ACHIEVEMENT_CURRENT_REPUTATION_LEVEL,
        factionName, standingLabel)
end

function ShowAchievementTooltip(button)
    local node = button.node
    if not node then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddDoubleLine(node.name, tostring(node.points or 0),
        1, 0.82, 0, 1, 0.82, 0)
    if node.description and node.description ~= "" then
        GameTooltip:AddLine(node.description, 1, 1, 1, true)
    end
    if Addon.AchievementCatalog
        and Addon.AchievementCatalog.GetRecord(node.id)
    then
        local record = Addon.AchievementCatalog.GetRecord(node.id)
        if record[3] == 0 or record[3] == 1 then
            local faction = record[3] == 0 and "Horde" or "Alliance"
            if UnitFactionGroup and UnitFactionGroup("player") ~= faction then
                GameTooltip:AddLine(L.ACHIEVEMENT_CATALOG_OTHER_FACTION,
                    1, 0.65, 0.25)
            end
        end
        if node.catalogOnly then
            GameTooltip:AddLine(L.ACHIEVEMENT_CATALOG_OFFLINE,
                1, 0.65, 0.25)
        end
    end
    local criteria = {}
    local reputationProgress = {}
    local seenFactions = {}
    for index = 1, GetAchievementNumCriteria(node.id) or 0 do
        local text, criteriaType, completed, quantity, required, _, flags,
            assetID, quantityText = GetAchievementCriteriaInfo(
                node.id, index, true)
        if criteriaType == 46 and type(assetID) == "number"
            and not seenFactions[assetID]
        then
            seenFactions[assetID] = true
            local progress = GetCharacterReputationProgress(assetID)
            if progress then
                reputationProgress[#reputationProgress + 1] = progress
            end
        end
        local progressFlag = EVALUATION_TREE_FLAG_PROGRESS_BAR
            or ACHIEVEMENT_CRITERIA_PROGRESS_BAR or 1
        local hasProgressFlag = type(flags) == "number"
            and bit.band(flags, progressFlag) == progressFlag
        local hasQuantityTarget = type(quantity) == "number"
            and type(required) == "number" and required > 1
        local isProgress = hasProgressFlag or hasQuantityTarget
        local progress
        if isProgress then
            if hasQuantityTarget then
                local currentText = BreakUpLargeNumbers
                    and BreakUpLargeNumbers(quantity) or tostring(quantity)
                local requiredText = BreakUpLargeNumbers
                    and BreakUpLargeNumbers(required) or tostring(required)
                progress = currentText .. "/" .. requiredText
            elseif quantityText and quantityText ~= "" then
                progress = quantityText
            end
        end
        if text and text ~= "" then
            if progress and progress ~= "" then
                text = string.format("%s  (%s)", text, progress)
            elseif completed then
                local checkmark = CreateAtlasMarkup
                    and CreateAtlasMarkup("common-icon-checkmark-yellow", 12, 12)
                    or "|cff20ff20✓|r"
                text = string.format("%s  %s", text, checkmark)
            end
        elseif progress and progress ~= "" then
            text = string.format(L.ACHIEVEMENT_CRITERIA_PROGRESS, progress)
        end
        if text and text ~= "" then
            criteria[#criteria + 1] = {
                text = text,
                red = completed and 0.2 or 0.55,
                green = completed and 1 or 0.55,
                blue = completed and 0.2 or 0.55,
            }
        end
    end
    if #criteria > 8 then
        local rows = math.ceil(#criteria / 2)
        for row = 1, rows do
            local left = criteria[row]
            local right = criteria[row + rows]
            if right then
                GameTooltip:AddDoubleLine(left.text, right.text,
                    left.red, left.green, left.blue,
                    right.red, right.green, right.blue)
            else
                GameTooltip:AddLine(left.text,
                    left.red, left.green, left.blue, true)
            end
        end
    else
        for _, entry in ipairs(criteria) do
            GameTooltip:AddLine(entry.text,
                entry.red, entry.green, entry.blue, true)
        end
    end
    if #reputationProgress > 0 then
        GameTooltip:AddLine(" ")
        for _, progress in ipairs(reputationProgress) do
            GameTooltip:AddLine(progress, 0.35, 0.82, 1, true)
        end
    end
    local reward = Addon.AchievementRewards.Get(node.id, true)
    local rewardDescription = reward and reward.text or ""
    if reward and rewardDescription == "" then
        local names = {}
        local seenNames = {}
        for _, entry in ipairs(reward.entries or {}) do
            if entry.name and entry.name ~= "" and not seenNames[entry.name]
            then
                seenNames[entry.name] = true
                names[#names + 1] = entry.name
            end
        end
        if #names > 0 then
            rewardDescription = string.format(
                L.ACHIEVEMENT_TOOLTIP_REWARD,
                table.concat(names, L.ACHIEVEMENT_TOOLTIP_REWARD_SEPARATOR))
        end
    end
    if rewardDescription ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(rewardDescription, 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

function LoadAchievementUI()
    if C_AddOns and not C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
        C_AddOns.LoadAddOn("Blizzard_AchievementUI")
    end
    return AchievementTemplateMixin ~= nil
end

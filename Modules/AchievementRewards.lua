local _, Addon = ...

local Rewards = {}
Addon.AchievementRewards = Rewards

local L = Addon.L
local Data = assert(Addon.AchievementData,
    "EasyAchievement achievement data service was not loaded")
local RewardDatabase = assert(Addon.RewardDatabase,
    "EasyAchievement reward database API was not loaded")
local INDEX_BUDGET_MILLISECONDS =
    Addon.Config.Performance.IndexBudgetMilliseconds
local ACHIEVEMENT_MOUNT_SOURCE_TYPE = 5
local COLLECTION_INDEX_RETRY_SECONDS = 2

local housingRewardIndex = {}
local housingRewardNameIndex = {}
local housingRewardTextCache = {}
local housingRewardIndexState
local housingRewardSearcher
local housingRewardIndexGeneration = 0
local mountRewardIndex
local mountRewardIndexRetryAt
local mountRewardTextCache = {}
local transmogSetRewardIndex
local transmogSetRewardIndexRetryAt
local transmogSetRewardTextCache = {}
local indexReadyCallback
local requestID
local requestGeneration = 0
local requestRetryCount = 0
local requestRetryPending = false

function Rewards.SetIndexReadyCallback(callback)
    assert(callback == nil or type(callback) == "function",
        "Invalid achievement reward-index callback")
    indexReadyCallback = callback
end

function Rewards.InvalidateCollectionIndexes(rewardType)
    Rewards.CancelRequest()
    if rewardType == nil or rewardType == "mount" then
        mountRewardIndex = nil
        mountRewardIndexRetryAt = nil
        mountRewardTextCache = {}
    end
    if rewardType == nil or rewardType == "appearance" then
        transmogSetRewardIndex = nil
        transmogSetRewardIndexRetryAt = nil
        transmogSetRewardTextCache = {}
    end
end

function Rewards.CancelRequest()
    requestID = nil
    requestGeneration = requestGeneration + 1
    requestRetryCount = 0
    requestRetryPending = false
end

local HOUSING_ACHIEVEMENT_LABELS = {
    deDE = "Erfolg:",
    enUS = "Achievement:",
    esES = "Logro:",
    esMX = "Logro:",
    frFR = "Haut fait :",
    itIT = "Impresa:",
    koKR = "업적:",
    ptBR = "Conquista:",
    ruRU = "Достижение:",
    zhCN = "成就：",
}

local function GetDecorSourceAchievementName(sourceText)
    if type(sourceText) ~= "string" or sourceText == "" then
        return nil
    end
    local plainText = sourceText
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1")
    local label = HOUSING_ACHIEVEMENT_LABELS[GetLocale() or "enUS"]
        or HOUSING_ACHIEVEMENT_LABELS.enUS
    local startAt = plainText:find(label, 1, true)
    if not startAt then
        return nil
    end
    local name = plainText:sub(startAt + #label):match("^%s*([^\r\n]+)")
    name = name and name:match("^%s*(.-)%s*$")
    return name ~= "" and name or nil
end

local function StartHousingRewardIndex()
    if housingRewardIndexState or not C_HousingCatalog
        or not C_HousingCatalog.CreateCatalogSearcher
    then
        return
    end
    housingRewardIndexState = "loading"
    housingRewardSearcher = C_HousingCatalog.CreateCatalogSearcher()
    housingRewardSearcher:SetOwnedOnly(false)
    housingRewardSearcher:SetCollected(true)
    housingRewardSearcher:SetUncollected(true)
    if housingRewardSearcher.SetFirstAcquisitionBonusOnly then
        housingRewardSearcher:SetFirstAcquisitionBonusOnly(false)
    end
    if housingRewardSearcher.SetEditorModeContext and Enum
        and Enum.HouseEditorMode
    then
        housingRewardSearcher:SetEditorModeContext(
            Enum.HouseEditorMode.BasicDecor)
    end
    housingRewardSearcher:SetResultsUpdatedCallback(function()
        housingRewardIndexGeneration = housingRewardIndexGeneration + 1
        local generation = housingRewardIndexGeneration
        housingRewardIndexState = "processing"
        housingRewardIndex = {}
        housingRewardNameIndex = {}
        housingRewardTextCache = {}
        local entries = housingRewardSearcher:GetCatalogSearchResults() or {}
        local index = 1
        local function ProcessChunk()
            if generation ~= housingRewardIndexGeneration then
                return
            end
            local startedAt = debugprofilestop and debugprofilestop() or nil
            local processed = 0
            local function HasBudget()
                if startedAt then
                    return processed == 0
                        or debugprofilestop() - startedAt
                            < INDEX_BUDGET_MILLISECONDS
                end
                return processed < 75
            end
            while index <= #entries and HasBudget() do
                local entryID = entries[index]
                index = index + 1
                processed = processed + 1
                if not Enum or not Enum.HousingCatalogEntryType
                    or entryID.entryType
                        == Enum.HousingCatalogEntryType.Decor
                then
                    local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
                    if info and info.name and info.name ~= "" then
                        local namedRewards = housingRewardNameIndex[info.name]
                        if not namedRewards then
                            namedRewards = {}
                            housingRewardNameIndex[info.name] = namedRewards
                        end
                        namedRewards[#namedRewards + 1] = entryID
                    end
                    local achievementName = info
                        and GetDecorSourceAchievementName(info.sourceText)
                    if achievementName then
                        local rewards = housingRewardIndex[achievementName]
                        if not rewards then
                            rewards = {}
                            housingRewardIndex[achievementName] = rewards
                        end
                        rewards[#rewards + 1] = entryID
                    end
                end
            end
            if index <= #entries then
                C_Timer.After(0, ProcessChunk)
            else
                housingRewardIndexState = "ready"
                if indexReadyCallback then
                    indexReadyCallback()
                end
            end
        end
        ProcessChunk()
    end)
    if housingRewardSearcher.SetSearchText then
        housingRewardSearcher:SetSearchText()
    end
    housingRewardSearcher:RunSearch()
end

local function GetRewardTooltipText(itemID, isToy, itemName)
    if not C_TooltipInfo then
        return nil
    end
    local tooltipData
    if isToy and C_TooltipInfo.GetToyByItemID then
        tooltipData = C_TooltipInfo.GetToyByItemID(itemID)
    elseif C_TooltipInfo.GetItemByID then
        tooltipData = C_TooltipInfo.GetItemByID(itemID)
    end
    if not tooltipData or type(tooltipData.lines) ~= "table" then
        return nil
    end

    local text = {}
    local seen = {}
    local toyTypes
    if Enum and Enum.TooltipDataLineType then
        toyTypes = {}
        for _, key in ipairs({ "ToyText", "ToyEffect", "ToyDuration",
            "ToyDescription" })
        do
            local lineType = Enum.TooltipDataLineType[key]
            if lineType then
                toyTypes[lineType] = true
            end
        end
        if not next(toyTypes) then
            toyTypes = nil
        end
    end
    for _, line in ipairs(tooltipData.lines) do
        local include = not isToy or not toyTypes or toyTypes[line.type]
        local lineText = type(line.leftText) == "string" and line.leftText
            or nil
        if include and lineText and lineText ~= "" and lineText ~= itemName
            and not seen[lineText]
        then
            seen[lineText] = true
            text[#text + 1] = lineText
            if #text >= 6 then
                break
            end
        end
    end
    return #text > 0 and table.concat(text, "\n") or nil
end

local function GetHousingModelSceneID(info)
    return info and (info.uiModelSceneID
        or Constants and Constants.HousingCatalogConsts
            and Constants.HousingCatalogConsts
                .HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT)
end

local function BuildDecorRewardEntry(info, itemID, entryID)
    if not info then
        return nil
    end
    itemID = itemID or info.itemID
    local name = info.name
    local icon = info.iconTexture
    if C_Item and itemID then
        name = name or C_Item.GetItemNameByID
            and C_Item.GetItemNameByID(itemID)
        icon = icon or C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(itemID)
    end
    local details = {}
    local tooltipText = itemID
        and GetRewardTooltipText(itemID, false, name)
    if tooltipText then
        details[#details + 1] = tooltipText
    end
    if info.sourceText and info.sourceText ~= "" then
        details[#details + 1] = info.sourceText
    end
    if info.placementCost and info.placementCost > 0 then
        details[#details + 1] = string.format(
            L.ACHIEVEMENT_REWARD_DECOR_COST, info.placementCost)
    end
    local modelSceneID = GetHousingModelSceneID(info)
    return {
        itemID = itemID,
        name = name or L.ACHIEVEMENT_REWARD_DECOR,
        icon = icon,
        iconAtlas = info.iconAtlas,
        description = #details > 0 and table.concat(details, "\n") or nil,
        rewardType = "decor",
        previewType = info.asset and modelSceneID and "model" or "icon",
        modelSceneID = modelSceneID,
        asset = info.asset,
        uniqueKey = "decor:" .. tostring(itemID
            or entryID and entryID.recordID or info.recordID
            or info.asset or name),
    }
end

local function BuildMountRewardEntry(mountID, itemID, fallbackName,
    fallbackIcon)
    if not mountID or not C_MountJournal
        or not C_MountJournal.GetMountInfoByID
        or not C_MountJournal.GetMountInfoExtraByID
    then
        return nil
    end
    local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
    local displayID, description, _, isSelfMount, _, modelSceneID =
        C_MountJournal.GetMountInfoExtraByID(mountID)
    if not name and not displayID then
        return nil
    end
    return {
        itemID = itemID,
        mountID = mountID,
        name = name or fallbackName,
        icon = icon or fallbackIcon,
        description = description,
        displayID = displayID,
        modelSceneID = modelSceneID,
        isSelfMount = isSelfMount,
        rewardType = "mount",
        previewType = displayID and modelSceneID and "model" or "icon",
        uniqueKey = "mount:" .. tostring(mountID),
    }
end

local function FindMountRewardByText(rewardText)
    if type(rewardText) ~= "string" or rewardText == ""
        or not C_MountJournal or not C_MountJournal.GetMountIDs
    then
        return nil
    end
    local cached = mountRewardTextCache[rewardText]
    if cached ~= nil then
        return cached or nil
    end
    if not mountRewardIndex or mountRewardIndexRetryAt
        and GetTime() >= mountRewardIndexRetryAt
    then
        mountRewardIndex = {}
        mountRewardTextCache = {}
        local mountIDs = C_MountJournal.GetMountIDs() or {}
        local complete = #mountIDs > 0
        if C_MountJournal.GetMountInfoByID then
            for _, mountID in ipairs(mountIDs) do
                local name, _, _, _, _, sourceType =
                    C_MountJournal.GetMountInfoByID(mountID)
                if not name or name == "" or sourceType == nil then
                    complete = false
                end
                if sourceType == ACHIEVEMENT_MOUNT_SOURCE_TYPE
                    and name and name ~= ""
                then
                    mountRewardIndex[name] = mountID
                end
            end
        else
            complete = false
        end
        mountRewardIndexRetryAt = not complete
            and GetTime() + COLLECTION_INDEX_RETRY_SECONDS or nil
    end
    local matchedName
    local matchedMountID
    for name, mountID in pairs(mountRewardIndex) do
        if rewardText:find(name, 1, true)
            and (not matchedName or #name > #matchedName)
        then
            matchedName = name
            matchedMountID = mountID
        end
    end
    local entry = BuildMountRewardEntry(matchedMountID, nil, matchedName)
    if entry and entry.previewType == "model"
        and not mountRewardIndexRetryAt
    then
        mountRewardTextCache[rewardText] = entry
    elseif not matchedMountID and not mountRewardIndexRetryAt then
        mountRewardTextCache[rewardText] = false
    end
    return entry, mountRewardIndexRetryAt ~= nil
        or matchedMountID ~= nil and (not entry or entry.previewType ~= "model")
end

local function BuildTransmogSetRewardEntry(setInfo)
    if not setInfo or not setInfo.setID or not C_TransmogSets
        or not C_TransmogSets.GetAllSourceIDs
    then
        return nil
    end
    local sourceIDs = C_TransmogSets.GetAllSourceIDs(setInfo.setID) or {}
    if #sourceIDs == 0 then
        return nil
    end
    local icon = C_TransmogCollection
        and C_TransmogCollection.GetSourceIcon
        and C_TransmogCollection.GetSourceIcon(sourceIDs[1])
    return {
        name = setInfo.name,
        icon = icon,
        description = setInfo.description or setInfo.label,
        rewardType = "appearance",
        previewType = "appearance",
        appearanceSourceIDs = sourceIDs,
        transmogSetID = setInfo.setID,
        uniqueKey = "appearance-set:" .. tostring(setInfo.setID),
    }
end

local function FindTransmogSetRewardByText(rewardText)
    if type(rewardText) ~= "string" or rewardText == ""
        or not C_TransmogSets or not C_TransmogSets.GetAllSets
    then
        return nil
    end
    local cached = transmogSetRewardTextCache[rewardText]
    if cached ~= nil then
        return cached or nil
    end
    if not transmogSetRewardIndex or transmogSetRewardIndexRetryAt
        and GetTime() >= transmogSetRewardIndexRetryAt
    then
        local sets = C_TransmogSets.GetAllSets() or {}
        transmogSetRewardIndex = {}
        transmogSetRewardTextCache = {}
        local complete = #sets > 0
        for _, setInfo in ipairs(sets) do
            local name = setInfo.name
            if not name or name == "" or not setInfo.setID then
                complete = false
            end
            local indexed = name and transmogSetRewardIndex[name]
            if name and name ~= "" and (not indexed
                or setInfo.validForCharacter and not indexed.validForCharacter)
            then
                transmogSetRewardIndex[name] = setInfo
            end
        end
        transmogSetRewardIndexRetryAt = not complete
            and GetTime() + COLLECTION_INDEX_RETRY_SECONDS or nil
    end
    local matchedName
    local matchedSetInfo
    for name, setInfo in pairs(transmogSetRewardIndex) do
        if rewardText:find(name, 1, true)
            and (not matchedName or #name > #matchedName)
        then
            matchedName = name
            matchedSetInfo = setInfo
        end
    end
    local entry = BuildTransmogSetRewardEntry(matchedSetInfo)
    if entry and not transmogSetRewardIndexRetryAt then
        transmogSetRewardTextCache[rewardText] = entry
    elseif not matchedSetInfo and not transmogSetRewardIndexRetryAt then
        transmogSetRewardTextCache[rewardText] = false
    end
    return entry, transmogSetRewardIndexRetryAt ~= nil
        or matchedSetInfo ~= nil and entry == nil
end

local function BuildItemRewardEntry(itemID)
    local databaseMountID = RewardDatabase.GetMountID(itemID)
    if databaseMountID then
        local mountEntry = BuildMountRewardEntry(databaseMountID, itemID)
        if mountEntry then
            return mountEntry
        end
    end
    local entry = {
        itemID = itemID,
        uniqueKey = "item:" .. tostring(itemID),
    }
    if C_Item then
        entry.name = C_Item.GetItemNameByID
            and C_Item.GetItemNameByID(itemID)
        entry.icon = C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(itemID)
        if C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
        if C_Item.GetItemInfoInstant and Enum and Enum.ItemClass
            and Enum.ItemMiscellaneousSubclass
        then
            local _, _, _, _, _, classID, subclassID =
                C_Item.GetItemInfoInstant(itemID)
            entry.isMountItem = classID == Enum.ItemClass.Miscellaneous
                and subclassID == Enum.ItemMiscellaneousSubclass.Mount
        end
    end

    local decorID, decorAsset, decorSceneID =
        RewardDatabase.GetDecorInfo(itemID)
    if decorID or C_Item and C_Item.IsDecorItem
        and C_Item.IsDecorItem(itemID)
    then
        local decorInfo = C_HousingCatalog
            and C_HousingCatalog.GetCatalogEntryInfoByItem
            and C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)
        if decorID then
            -- Keep catalog data intact; fill missing fields from the DB2 tables.
            local info = {}
            for key, value in pairs(decorInfo or {}) do
                info[key] = value
            end
            info.recordID = info.recordID or decorID
            info.name = info.name or entry.name
            info.iconTexture = info.iconTexture or entry.icon
            info.asset = info.asset or decorAsset > 0 and decorAsset or nil
            info.uiModelSceneID = info.uiModelSceneID
                or decorSceneID > 0 and decorSceneID or nil
            decorInfo = info
        end
        local decorEntry = BuildDecorRewardEntry(decorInfo, itemID)
        if decorEntry then
            decorEntry.pendingInfo = not (decorInfo.name and decorInfo.asset)
            return decorEntry
        end
    end

    local mountID = C_MountJournal and C_MountJournal.GetMountFromItem
        and C_MountJournal.GetMountFromItem(itemID)
    if mountID then
        return BuildMountRewardEntry(mountID, itemID, entry.name,
            entry.icon) or entry
    end

    local databaseSpeciesID, databaseDisplayID, databaseSceneID,
        databaseIcon = RewardDatabase.GetPetInfo(itemID)
    if databaseSpeciesID or C_PetJournal and C_PetJournal.GetPetInfoByItemID
    then
        local name, icon, creatureID, description, displayID, speciesID
        if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
            name, icon, _, creatureID, _, description, _, _, _, _, _,
                displayID, speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
        end
        speciesID = speciesID or databaseSpeciesID
        if not name and speciesID and C_PetJournal
            and C_PetJournal.GetPetInfoBySpeciesID
        then
            name, icon = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        end
        if name or databaseSpeciesID then
            entry.name = name or entry.name
            entry.icon = icon or entry.icon
                or databaseIcon and databaseIcon > 0 and databaseIcon or nil
            entry.description = description
            entry.creatureID = creatureID
            displayID = displayID or databaseDisplayID
                and databaseDisplayID > 0 and databaseDisplayID or nil
            entry.displayID = displayID
            entry.speciesID = speciesID
            entry.rewardType = "pet"
            if speciesID and C_PetJournal
                and C_PetJournal.GetPetModelSceneInfoBySpeciesID then
                entry.modelSceneID =
                    C_PetJournal.GetPetModelSceneInfoBySpeciesID(speciesID)
            end
            entry.modelSceneID = entry.modelSceneID or databaseSceneID
                and databaseSceneID > 0 and databaseSceneID or nil
            entry.pendingInfo = not (entry.name and displayID
                and entry.modelSceneID)
            entry.previewType = displayID and entry.modelSceneID
                and "model" or "icon"
            return entry
        end
    end

    if RewardDatabase.IsToy(itemID) or C_ToyBox and C_ToyBox.GetToyInfo then
        local toyItemID, toyName, toyIcon
        if C_ToyBox and C_ToyBox.GetToyInfo then
            toyItemID, toyName, toyIcon = C_ToyBox.GetToyInfo(itemID)
        end
        if toyItemID or RewardDatabase.IsToy(itemID) then
            entry.name = toyName or entry.name
            entry.icon = toyIcon or entry.icon
            entry.description = GetRewardTooltipText(itemID, true,
                entry.name)
            entry.rewardType = "toy"
            entry.previewType = "icon"
            entry.pendingInfo = not entry.name
            return entry
        end
    end

    local appearanceSourceIDs = {}
    local transmogSetID = C_Item and C_Item.GetItemLearnTransmogSet
        and C_Item.GetItemLearnTransmogSet(itemID)
    if transmogSetID and C_TransmogSets
        and C_TransmogSets.GetAllSourceIDs
    then
        appearanceSourceIDs = C_TransmogSets.GetAllSourceIDs(
            transmogSetID) or {}
    end
    if #appearanceSourceIDs == 0 and C_TransmogCollection
        and C_TransmogCollection.GetItemInfo
    then
        local _, itemModifiedAppearanceID =
            C_TransmogCollection.GetItemInfo(itemID)
        if itemModifiedAppearanceID and itemModifiedAppearanceID > 0 then
            appearanceSourceIDs[1] = itemModifiedAppearanceID
        end
    end
    if #appearanceSourceIDs == 0 then
        local sourceID = RewardDatabase.GetAppearanceSourceID(itemID)
        if sourceID then
            appearanceSourceIDs[1] = sourceID
        end
    end
    if #appearanceSourceIDs > 0 then
        entry.description = GetRewardTooltipText(itemID, false, entry.name)
        entry.rewardType = "appearance"
        entry.previewType = "appearance"
        entry.appearanceSourceIDs = appearanceSourceIDs
        entry.pendingInfo = not entry.name
        entry.transmogSetID = transmogSetID
        if transmogSetID then
            entry.uniqueKey = "appearance-set:" .. tostring(transmogSetID)
        else
            entry.uniqueKey = "appearance-source:"
                .. tostring(appearanceSourceIDs[1])
        end
        return entry
    end

    entry.description = GetRewardTooltipText(itemID, false, entry.name)
    entry.rewardType = "item"
    entry.previewType = "icon"
    entry.pendingInfo = not entry.name
    return entry
end

local function AddRewardEntry(reward, entry, seen)
    if not entry then
        return
    end
    local existingIndex = entry.itemID and seen.items[entry.itemID]
    if existingIndex then
        if entry.rewardType == "decor"
            and reward.entries[existingIndex].rewardType ~= "decor"
        then
            reward.entries[existingIndex] = entry
        end
        return
    end
    local key = entry.uniqueKey or "entry:" .. tostring(#reward.entries + 1)
    if seen.keys[key] then
        return
    end
    seen.keys[key] = true
    reward.entries[#reward.entries + 1] = entry
    if entry.itemID then
        seen.items[entry.itemID] = #reward.entries
    end
end

local function AddDatabaseRewardEntries(reward, achievementID, seen)
    if not RewardDatabase.HasReward(achievementID) then
        return false
    end
    local foundItemID = false
    local index = 1
    while true do
        local itemID = RewardDatabase.GetReward(achievementID, index)
        if itemID == nil then
            break
        end
        if itemID > 0 then
            foundItemID = true
            AddRewardEntry(reward, BuildItemRewardEntry(itemID), seen)
        end
        index = index + 1
    end
    return foundItemID
end

function Rewards.Has(achievementID, achievement)
    achievement = achievement or Data.Get(achievementID)
    if not achievement then
        return false
    end
    if achievement.rewardText and achievement.rewardText ~= "" then
        return true
    end
    if RewardDatabase.HasReward(achievement.id) then
        return true
    end
    if C_AchievementInfo and C_AchievementInfo.GetRewardItemID then
        local itemID = C_AchievementInfo.GetRewardItemID(achievement.id)
        return type(itemID) == "number" and itemID > 0
    end
    return false
end

function Rewards.Get(achievementID, skipHousingDiscovery)
    local achievement = Data.Get(achievementID)
    if not achievement then
        return nil
    end

    local reward = {
        text = achievement.rewardText or "",
        entries = {},
    }
    local pending = false
    local seen = { keys = {}, items = {} }
    local foundDatabaseItem = AddDatabaseRewardEntries(reward,
        achievement.id, seen)
    if not foundDatabaseItem and C_AchievementInfo
        and C_AchievementInfo.GetRewardItemID
    then
        local itemID = C_AchievementInfo.GetRewardItemID(achievement.id)
        if type(itemID) == "number" and itemID > 0 then
            AddRewardEntry(reward, BuildItemRewardEntry(itemID), seen)
        end
    end
    local hasMountReward = false
    for _, entry in ipairs(reward.entries) do
        if entry.rewardType == "mount" then
            hasMountReward = true
            break
        end
    end
    if not hasMountReward then
        local mountEntry, mountPending = FindMountRewardByText(reward.text)
        pending = pending or mountPending
        if mountEntry then
            local itemEntry = #reward.entries == 1
                and reward.entries[1] or nil
            if itemEntry and itemEntry.rewardType == "item"
                and (itemEntry.isMountItem
                    or itemEntry.name == mountEntry.name)
            then
                mountEntry.itemID = itemEntry.itemID
                reward.entries[1] = mountEntry
            else
                AddRewardEntry(reward, mountEntry, seen)
            end
        end
    end

    local hasAppearanceReward = false
    for _, entry in ipairs(reward.entries) do
        if entry.rewardType == "appearance" then
            hasAppearanceReward = true
            break
        end
    end
    if not hasAppearanceReward then
        local appearanceEntry, appearancePending =
            FindTransmogSetRewardByText(reward.text)
        pending = pending or appearancePending
        AddRewardEntry(reward, appearanceEntry, seen)
    end

    if not skipHousingDiscovery then
        StartHousingRewardIndex()
    end
    if housingRewardIndexState == "ready" and C_HousingCatalog
        and C_HousingCatalog.GetCatalogEntryInfo
    then
        for _, entryID in ipairs(
            housingRewardIndex[achievement.name] or {})
        do
            local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
            AddRewardEntry(reward,
                BuildDecorRewardEntry(info, nil, entryID), seen)
        end
        if reward.text ~= "" then
            local matchingEntries = housingRewardTextCache[reward.text]
            if not matchingEntries then
                matchingEntries = {}
                for decorName, entryIDs in pairs(housingRewardNameIndex) do
                    if reward.text:find(decorName, 1, true) then
                        for _, entryID in ipairs(entryIDs) do
                            matchingEntries[#matchingEntries + 1] = entryID
                        end
                    end
                end
                housingRewardTextCache[reward.text] = matchingEntries
            end
            for _, entryID in ipairs(matchingEntries) do
                local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
                AddRewardEntry(reward,
                    BuildDecorRewardEntry(info, nil, entryID), seen)
            end
        end
    end
    for _, entry in ipairs(reward.entries) do
        pending = pending or entry.pendingInfo
            or entry.rewardType == "mount" and entry.previewType ~= "model"
    end
    pending = pending or housingRewardIndexState == "loading"
        or housingRewardIndexState == "processing"
    reward.state = pending and "pending"
        or #reward.entries > 0 and "ready" or "unmatched"
    return (reward.text ~= "" or #reward.entries > 0) and reward or nil
end

-- Only the visible reward consumer requests retries; ordinary queries stay cheap.
function Rewards.Request(achievementID)
    if requestID ~= achievementID then
        Rewards.CancelRequest()
        requestID = achievementID
    end
    local reward = Rewards.Get(achievementID)
    if reward and reward.state == "pending" and not requestRetryPending
        and requestRetryCount < 3 and C_Timer and C_Timer.After
    then
        requestRetryCount = requestRetryCount + 1
        requestRetryPending = true
        local generation = requestGeneration
        C_Timer.After(COLLECTION_INDEX_RETRY_SECONDS, function()
            if generation ~= requestGeneration then return end
            requestRetryPending = false
            if indexReadyCallback then indexReadyCallback(achievementID) end
        end)
    end
    return reward
end


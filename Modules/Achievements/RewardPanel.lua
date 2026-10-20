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

AchievementRewards = assert(Addon.AchievementRewards,
    "EasyAchievement achievement reward service was not loaded")
GetAchievementRewardData = AchievementRewards.Request

local MODEL_SCENE_LEFT_OFFSET = -200
local MODEL_SCENE_RIGHT_OFFSET = 24
local MODEL_SCENE_CENTER_OFFSET =
    (MODEL_SCENE_LEFT_OFFSET + MODEL_SCENE_RIGHT_OFFSET) / 2

local function FitMountRewardModel(modelScene, actor)
    if not modelScene or not actor or not actor.IsLoaded
        or not actor:IsLoaded() or not actor.GetActiveBoundingBox
    then
        return false
    end

    if actor.UpdateScale then
        actor:UpdateScale()
    end
    if actor.SetUseCenterForOrigin then
        actor:SetUseCenterForOrigin(true, true, true)
    end
    if actor.SetPosition then
        actor:SetPosition(0, 0, 0)
    end

    local ok, bottomX, bottomY, bottomZ, topX, topY, topZ =
        pcall(actor.GetActiveBoundingBox, actor)
    if not ok or type(bottomX) ~= "number"
        or type(bottomY) ~= "number" or type(bottomZ) ~= "number"
        or type(topX) ~= "number" or type(topY) ~= "number"
        or type(topZ) ~= "number"
    then
        return false
    end

    local width = topX - bottomX
    local depth = topY - bottomY
    local height = topZ - bottomZ
    local scale = actor.GetScale and actor:GetScale() or 1
    local radius = math.sqrt(width * width + depth * depth
        + height * height) * math.abs(scale) / 2
    if radius <= 0 then
        return false
    end

    local camera = modelScene.GetActiveCamera
        and modelScene:GetActiveCamera()
    if not camera or not camera.SetTarget
        or not camera.SetZoomDistance
    then
        return false
    end

    local fieldOfView = modelScene.GetCameraFieldOfView
        and modelScene:GetCameraFieldOfView() or 0.65
    if type(fieldOfView) ~= "number" or fieldOfView <= 0 then
        fieldOfView = 0.65
    end
    local fitDistance = radius
        / math.sin(math.min(fieldOfView / 2, math.pi * 0.45)) * 1.08
    local minimumDistance = camera.GetMinZoomDistance
        and camera:GetMinZoomDistance() or 0
    fitDistance = math.max(minimumDistance, fitDistance)
    local maximumDistance = camera.GetMaxZoomDistance
        and camera:GetMaxZoomDistance() or 0
    maximumDistance = math.max(maximumDistance, fitDistance * 1.2)

    if modelScene.SetViewTranslation then
        modelScene:SetViewTranslation(0, 0)
    end
    camera:SetTarget(0, 0, 0)
    if camera.SetTargetSpline then
        camera:SetTargetSpline(nil)
    end
    if camera.SetZoomSpline then
        camera:SetZoomSpline(nil)
    end
    if camera.SetMaxZoomDistance then
        camera:SetMaxZoomDistance(maximumDistance)
    end
    camera:SetZoomDistance(fitDistance)
    modelScene:OnMouseWheel(-1)
    if camera.SnapAllInterpolatedValues then
        camera:SnapAllInterpolatedValues()
    end
    if camera.SynchronizeCamera then
        camera:SynchronizeCamera()
    end
    return true
end

AchievementRewards.SetIndexReadyCallback(function(achievementID)
    local frame = achievementTreeFrame
    if not frame or not frame:IsShown() or not frame.sourceAchievementID
        or achievementID and achievementID ~= frame.sourceAchievementID
        or not UpdateAchievementRewardHeader
    then
        return
    end
    UpdateAchievementRewardHeader(frame, frame.sourceAchievementID)
    if frame.AchievementCard and frame.AchievementCard:IsShown() then
        local shown = UpdateAchievementRewardPanel(frame,
            frame.sourceAchievementID)
        local offsetX = shown and
            -(achievementRewardFrame:GetWidth() / 2 + 6) or 0
        frame.AchievementCard:ClearAllPoints()
        frame.AchievementCard:SetPoint("CENTER", frame, "CENTER",
            offsetX, -45)
        frame.AchievementCardHeader:ClearAllPoints()
        frame.AchievementCardHeader:SetPoint("BOTTOM",
            frame.AchievementCard, "TOP", 0, 10)
        LayoutAchievementHeader(frame)
    end
end)

function CreateAchievementRewardFrame()
    if achievementRewardFrame then
        return achievementRewardFrame
    end

    local frame = CreateFrame("Frame", "EasyAchievementRewardFrame",
        UIParent)
    frame:SetSize(380, 250)
    frame:EnableMouse(true)

    local itemIcon = frame:CreateTexture(nil, "ARTWORK")
    itemIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -10)
    itemIcon:SetSize(48, 48)
    itemIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    frame.ItemIcon = itemIcon

    local collectionBorder = frame:CreateTexture(nil, "OVERLAY")
    collectionBorder:SetPoint("CENTER", itemIcon, "CENTER")
    collectionBorder:SetSize(56, 56)
    if not SetTextureAtlas(collectionBorder,
        "collections-itemborder-collected")
    then
        collectionBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    end
    collectionBorder:Hide()
    frame.CollectionBorder = collectionBorder

    local petBorder = frame:CreateTexture(nil, "OVERLAY")
    petBorder:SetPoint("CENTER", itemIcon, "CENTER")
    petBorder:SetSize(56, 56)
    if not SetTextureAtlas(petBorder,
        "PetJournal-BattleSlot-IconBorder")
    then
        petBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    end
    petBorder:Hide()
    frame.PetBorder = petBorder

    local toyButton = CreateFrame("Button", nil, frame)
    toyButton:SetPoint("CENTER", itemIcon, "CENTER", 0, 0)
    toyButton:SetSize(56, 56)
    local toyIcon = toyButton:CreateTexture(nil, "ARTWORK")
    toyIcon:SetPoint("CENTER", toyButton, "CENTER", 0, 1)
    toyIcon:SetSize(42, 42)
    toyIcon:SetTexCoord(0.04347826, 0.95652173,
        0.04347826, 0.95652173)
    toyButton.Icon = toyIcon
    local toyBorder = toyButton:CreateTexture(nil, "OVERLAY")
    toyBorder:SetPoint("CENTER")
    toyBorder:SetSize(56, 56)
    toyBorder:SetAtlas("collections-itemborder-collected", false)
    toyButton.Border = toyBorder
    local toyHighlight = toyButton:CreateTexture(nil, "HIGHLIGHT")
    toyHighlight:SetPoint("CENTER", toyButton, "CENTER", 0, 2)
    toyHighlight:SetSize(48, 48)
    toyHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    toyHighlight:SetBlendMode("ADD")
    local function ShowToyRewardTooltip(self)
        if not self.itemID then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local shown
        if GameTooltip.SetToyByItemID then
            shown = GameTooltip:SetToyByItemID(self.itemID)
        elseif GameTooltip.SetItemByID then
            shown = GameTooltip:SetItemByID(self.itemID)
        end
        GameTooltip:Show()
        self.UpdateTooltip = shown and ShowToyRewardTooltip or nil
    end
    toyButton:SetScript("OnEnter", ShowToyRewardTooltip)
    toyButton:SetScript("OnLeave", function(self)
        self.UpdateTooltip = nil
        GameTooltip:Hide()
    end)
    toyButton:Hide()
    frame.ToyButton = toyButton

    local itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemName:SetPoint("TOPLEFT", itemIcon, "TOPRIGHT", 10, -2)
    itemName:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetJustifyV("TOP")
    itemName:SetWordWrap(true)
    itemName:SetHeight(18)
    frame.ItemName = itemName

    local description = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -65)
    description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -65)
    description:SetHeight(88)
    description:SetJustifyH("CENTER")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    frame.Description = description

    local modelScene = CreateFrame("ModelScene", nil, frame,
        "ModelSceneMixinTemplate")
    modelScene:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -118)
    modelScene:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 54)
    modelScene:EnableMouse(true)
    modelScene:EnableMouseWheel(true)
    modelScene:SetResetCallback(function(scene)
        if scene.rewardType == "mount" then
            FitMountRewardModel(scene, scene:GetActorByTag("unwrapped"))
        end
    end)
    frame:RegisterEvent("UI_MODEL_SCENE_INFO_UPDATED")
    frame:SetScript("OnEvent", function(self, event)
        if event ~= "UI_MODEL_SCENE_INFO_UPDATED"
            or not self.pendingModelRefresh or not self:IsShown()
            or not achievementTreeFrame
            or not achievementTreeFrame:IsShown()
            or not UpdateAchievementRewardPanel
        then
            return
        end
        UpdateAchievementRewardPanel(achievementTreeFrame,
            self.achievementID)
    end)
    frame.ModelScene = modelScene

    local modelControls = CreateFrame("Frame", nil, modelScene,
        "ModelSceneControlFrameTemplate")
    modelControls:SetPoint("BOTTOM", frame, "BOTTOM", 0, 18)
    modelControls:SetFrameLevel(modelScene:GetFrameLevel() + 10)
    modelControls:SetModelScene(modelScene)
    modelControls:Show()
    frame.ModelControls = modelControls

    local function SelectAdjacentReward(self, direction)
        local rewardFrame = self:GetParent()
        local entryCount = rewardFrame.entryCount or 0
        local entryIndex = math.max(1, math.min(entryCount,
            (rewardFrame.entryIndex or 1) + direction))
        if entryIndex == rewardFrame.entryIndex or entryCount < 2
            or not achievementTreeFrame or not UpdateAchievementRewardPanel
        then
            return
        end
        rewardFrame.entryIndex = entryIndex
        rewardFrame.entryKey = nil
        UpdateAchievementRewardPanel(achievementTreeFrame,
            rewardFrame.achievementID)
    end

    local previousButton = CreateFrame("Button", nil, frame)
    previousButton:SetSize(24, 24)
    previousButton:SetFrameLevel(modelScene:GetFrameLevel() + 20)
    previousButton:SetNormalTexture(
        "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    previousButton:SetPushedTexture(
        "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    previousButton:SetDisabledTexture(
        "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    previousButton:SetHighlightTexture(
        "Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    previousButton:SetScript("OnClick", function(self)
        SelectAdjacentReward(self, -1)
    end)
    previousButton:Hide()
    frame.PreviousReward = previousButton

    local nextButton = CreateFrame("Button", nil, frame)
    nextButton:SetSize(24, 24)
    nextButton:SetFrameLevel(modelScene:GetFrameLevel() + 20)
    nextButton:SetNormalTexture(
        "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    nextButton:SetPushedTexture(
        "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    nextButton:SetDisabledTexture(
        "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    nextButton:SetHighlightTexture(
        "Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    nextButton:SetScript("OnClick", function(self)
        SelectAdjacentReward(self, 1)
    end)
    nextButton:Hide()
    frame.NextReward = nextButton

    local entryCounter = frame:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    entryCounter:SetPoint("BOTTOM", frame, "BOTTOM", 0, 54)
    entryCounter:Hide()
    frame.EntryCounter = entryCounter
    previousButton:SetPoint("RIGHT", entryCounter, "LEFT", -4, 0)
    nextButton:SetPoint("LEFT", entryCounter, "RIGHT", 4, 0)

    frame:Hide()
    achievementRewardFrame = frame
    return frame
end

function GetAchievementRewardPanelWidth(hostFrame)
    if hostFrame:GetWidth() < 860 then
        hostFrame:SetWidth(860)
    end
    return math.max(300, math.min(460, hostFrame:GetWidth() * 0.42))
end

function ConfigureAchievementRewardFrame(rewardFrame, hostFrame)
    rewardFrame:ClearAllPoints()
    rewardFrame:SetParent(hostFrame)
    rewardFrame:SetFrameStrata(hostFrame:GetFrameStrata())
    rewardFrame:SetFrameLevel(hostFrame:GetFrameLevel() + 20)
    rewardFrame:SetWidth(GetAchievementRewardPanelWidth(hostFrame))
    rewardFrame:SetPoint("TOPRIGHT", hostFrame, "TOPRIGHT", -24, -115)
    rewardFrame:SetPoint("BOTTOMRIGHT", hostFrame,
        "BOTTOMRIGHT", -24, 26)
end

local function RewardEntryKey(entry)
    return entry.itemID and "item:" .. entry.itemID or entry.uniqueKey
end

local function ModelKey(achievementID, entry)
    return table.concat({
        tostring(achievementID), tostring(RewardEntryKey(entry)),
        tostring(entry.rewardType), tostring(entry.previewType),
        tostring(entry.modelSceneID), tostring(entry.displayID),
        tostring(entry.asset), tostring(entry.isSelfMount),
        table.concat(entry.appearanceSourceIDs or {}, ","),
    }, ":")
end

local function ConfigureRewardModel(rewardFrame, entry, showAppearance, modelKey)
    local scene = rewardFrame.ModelScene
    local modelSceneID = showAppearance and DRESS_UP_FRAME_MODEL_SCENE_ID
        or entry.modelSceneID
    if showAppearance then
        if scene.SetViewInsets then scene:SetViewInsets(0, 0, 0, 0) end
        if scene.ReleaseAllActors then scene:ReleaseAllActors() end
    end
    if scene.TransitionToModelSceneID then
        scene:TransitionToModelSceneID(modelSceneID,
            CAMERA_TRANSITION_TYPE_IMMEDIATE or 1,
            CAMERA_MODIFICATION_TYPE_DISCARD or 1, true)
    else
        scene:SetFromModelSceneID(modelSceneID, true)
    end
    if showAppearance then
        local useNativeForm = true
        if C_PlayerInfo and C_PlayerInfo.GetAlternateFormInfo then
            local _, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo()
            useNativeForm = not inAlternateForm
        end
        SetupPlayerForModelScene(scene, nil, entry.appearanceSourceIDs,
            false, true, false, useNativeForm)
    end
    local actor
    if showAppearance then
        actor = scene:GetPlayerActor()
    else
        actor = scene:GetActorByTag(entry.rewardType == "decor"
            and "decor" or "unwrapped")
    end
    if not actor then
        rewardFrame.pendingModelRefresh = true
        return
    end
    local isMount = entry.rewardType == "mount"
    scene.rewardType = entry.rewardType
    if actor.SetOnModelLoadedCallback then
        actor:SetOnModelLoadedCallback(isMount and function(loadedActor)
            if rewardFrame.modelKey == modelKey then
                FitMountRewardModel(scene, loadedActor)
            end
        end or nil)
    end
    if not showAppearance and actor.SetPreferModelCollisionBounds then
        actor:SetPreferModelCollisionBounds(entry.rewardType == "decor")
    end
    if not showAppearance then
        if entry.rewardType == "decor" then
            actor:SetModelByFileID(entry.asset)
        else
            actor:SetModelByCreatureDisplayID(entry.displayID, true)
            if actor.SetAnimationBlendOperation and Enum and Enum.ModelBlendOperation then
                actor:SetAnimationBlendOperation(entry.isSelfMount
                    and Enum.ModelBlendOperation.None or Enum.ModelBlendOperation.Anim)
            end
            actor:SetAnimation(entry.isSelfMount and 618 or 0)
        end
    end
    actor:Show()
    if isMount then FitMountRewardModel(scene, actor) end
end

UpdateAchievementRewardPanel = function(frame, achievementID)
    local reward = GetAchievementRewardData(achievementID)
    if not frame or not reward or #reward.entries == 0
    then
        if achievementRewardFrame then
            achievementRewardFrame:Hide()
        end
        return false
    end

    local rewardFrame = CreateAchievementRewardFrame()
    local entries = reward.entries or {}
    if rewardFrame.achievementID ~= achievementID then
        rewardFrame.entryIndex = 1
        rewardFrame.entryKey = nil
    end
    rewardFrame.entryCount = #entries
    if rewardFrame.entryKey then
        for index, entry in ipairs(entries) do
            if RewardEntryKey(entry) == rewardFrame.entryKey then
                rewardFrame.entryIndex = index
                break
            end
        end
    end
    rewardFrame.entryIndex = math.max(1,
        math.min(#entries, rewardFrame.entryIndex or 1))
    local primaryEntry = entries[rewardFrame.entryIndex]
    rewardFrame.entryKey = RewardEntryKey(primaryEntry)
    local previewEntry = primaryEntry
    local rewardNames = primaryEntry and primaryEntry.name
        and primaryEntry.name ~= "" and { primaryEntry.name } or {}
    local rewardDescriptions = primaryEntry and primaryEntry.description
        and primaryEntry.description ~= "" and {
            primaryEntry.description,
        } or {}
    local rewardItemIDs = {}
    for _, entry in ipairs(entries) do
        if entry.itemID then
            rewardItemIDs[entry.itemID] = true
        end
    end
    rewardFrame.achievementID = achievementID
    rewardFrame.rewardItemIDs = rewardItemIDs
    local showToy = primaryEntry ~= nil
        and primaryEntry.rewardType == "toy"
    rewardFrame.ItemIcon:SetTexture(nil)
    if primaryEntry and primaryEntry.iconAtlas then
        rewardFrame.ItemIcon:SetAtlas(primaryEntry.iconAtlas, false)
    elseif primaryEntry then
        rewardFrame.ItemIcon:SetTexture(primaryEntry.icon)
        rewardFrame.ItemIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    end
    rewardFrame.ItemIcon:SetShown(primaryEntry ~= nil
        and not showToy
        and (primaryEntry.icon ~= nil or primaryEntry.iconAtlas ~= nil))
    local rewardType = primaryEntry and primaryEntry.rewardType
    rewardFrame.CollectionBorder:SetShown(rewardFrame.ItemIcon:IsShown()
        and (rewardType == "mount" or rewardType == "decor"
            or rewardType == "appearance"))
    rewardFrame.PetBorder:SetShown(rewardFrame.ItemIcon:IsShown()
        and rewardType == "pet")
    rewardFrame.ToyButton.itemID = showToy and primaryEntry.itemID or nil
    rewardFrame.ToyButton.Icon:SetTexture(showToy and primaryEntry.icon
        or nil)
    rewardFrame.ToyButton:SetShown(showToy and primaryEntry.icon ~= nil)
    rewardFrame.ItemName:SetText(table.concat(rewardNames, "  +  "))
    rewardFrame.ItemName:SetHeight(18)
    rewardFrame.ItemName:SetShown(#rewardNames > 0)
    rewardFrame.Description:SetText(table.concat(rewardDescriptions, "\n\n"))
    rewardFrame.Description:SetShown(#rewardDescriptions > 0)
    local showAppearance = previewEntry
        and previewEntry.previewType == "appearance"
        and #(previewEntry.appearanceSourceIDs or {}) > 0
        and SetupPlayerForModelScene ~= nil
    local showModel = showAppearance or previewEntry
        and previewEntry.previewType == "model"
        and previewEntry.modelSceneID
        and (previewEntry.displayID or previewEntry.asset)
    local modelKey = showModel and ModelKey(achievementID, previewEntry) or nil
    local resetModel = rewardFrame.modelKey ~= modelKey
        or rewardFrame.pendingModelRefresh or showModel and not rewardFrame.modelKey
    if resetModel then
        rewardFrame.pendingModelRefresh = nil
        rewardFrame.modelKey = modelKey
        rewardFrame.ModelScene:ClearScene()
    end
    local contentCenterOffset = showModel and MODEL_SCENE_CENTER_OFFSET or 0
    ConfigureAchievementRewardFrame(rewardFrame, frame)
    local textWidth = math.max(1, rewardFrame:GetWidth() - 40)
    rewardFrame.ItemName:ClearAllPoints()
    rewardFrame.ItemName:SetWidth(textWidth)
    rewardFrame.ItemName:SetHeight(0)
    rewardFrame.ItemName:SetJustifyH("CENTER")
    rewardFrame.ItemName:SetJustifyV("TOP")
    rewardFrame.ItemName:SetPoint("TOP", rewardFrame, "TOP",
        contentCenterOffset, -10)
    local nameHeight = #rewardNames > 0
        and math.max(18, rewardFrame.ItemName:GetStringHeight()) or 0
    rewardFrame.ItemName:SetHeight(nameHeight)
    local descriptionTop = 10 + nameHeight + (nameHeight > 0 and 6 or 0)
    rewardFrame.Description:ClearAllPoints()
    rewardFrame.Description:SetPoint("TOPLEFT", rewardFrame, "TOPLEFT",
        20 + contentCenterOffset, -descriptionTop)
    rewardFrame.Description:SetPoint("TOPRIGHT", rewardFrame, "TOPRIGHT",
        -20 + contentCenterOffset, -descriptionTop)
    rewardFrame.Description:SetHeight(0)
    local descriptionHeight = #rewardDescriptions > 0
        and rewardFrame.Description:GetStringHeight() or 0
    rewardFrame.Description:SetHeight(descriptionHeight)
    local iconTop = descriptionTop + descriptionHeight + 8
    rewardFrame.ItemIcon:ClearAllPoints()
    rewardFrame.ItemIcon:SetPoint("TOP", rewardFrame, "TOP",
        contentCenterOffset, -iconTop)
    local extraHeight = math.max(0, iconTop + 48 - 108)
    local hasMultipleEntries = #entries > 1
    rewardFrame.PreviousReward:SetShown(hasMultipleEntries)
    rewardFrame.PreviousReward:SetEnabled(rewardFrame.entryIndex > 1)
    rewardFrame.NextReward:SetShown(hasMultipleEntries)
    rewardFrame.NextReward:SetEnabled(rewardFrame.entryIndex < #entries)
    rewardFrame.EntryCounter:SetShown(hasMultipleEntries)
    rewardFrame.EntryCounter:SetText(string.format("%d / %d",
        rewardFrame.entryIndex, #entries))
    rewardFrame.EntryCounter:ClearAllPoints()
    local counterCenterOffset = showModel and -126 - extraHeight
        or -170 - extraHeight
    rewardFrame.EntryCounter:SetPoint("CENTER", rewardFrame, "TOP",
        contentCenterOffset, counterCenterOffset)
    if showModel then
        rewardFrame:SetSize(460, 540 + extraHeight)
        rewardFrame.ModelScene:ClearAllPoints()
        local modelTopOffset = hasMultipleEntries
            and -146 - extraHeight or -118 - extraHeight
        rewardFrame.ModelScene:SetPoint("TOPLEFT", rewardFrame,
            "TOPLEFT", MODEL_SCENE_LEFT_OFFSET, modelTopOffset)
        rewardFrame.ModelScene:SetPoint("BOTTOMRIGHT", rewardFrame,
            "BOTTOMRIGHT", MODEL_SCENE_RIGHT_OFFSET, -20)
        rewardFrame.ModelScene:Show()
        if resetModel then
            ConfigureRewardModel(rewardFrame, previewEntry, showAppearance, modelKey)
        end
        rewardFrame.ModelControls:Show()
        rewardFrame.ModelControls:ClearAllPoints()
        rewardFrame.ModelControls:SetPoint("BOTTOM", rewardFrame, "BOTTOM",
            contentCenterOffset, 18)
        rewardFrame.ModelControls:UpdateLayout()
    else
        rewardFrame:SetSize(380, primaryEntry and 250 + extraHeight or 180)
        rewardFrame.ModelControls:Hide()
        rewardFrame.ModelScene:Hide()
    end
    ConfigureAchievementRewardFrame(rewardFrame, frame)
    rewardFrame:Show()
    rewardFrame:Raise()
    return true
end

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
GetAchievementRewardData = AchievementRewards.Get

local MODEL_SCENE_LEFT_OFFSET = -200
local MODEL_SCENE_RIGHT_OFFSET = 24
local MODEL_SCENE_CENTER_OFFSET =
    (MODEL_SCENE_LEFT_OFFSET + MODEL_SCENE_RIGHT_OFFSET) / 2

local REWARD_TYPE_LABEL_KEYS = {
    mount = "ACHIEVEMENT_REWARD_TYPE_MOUNT",
    pet = "ACHIEVEMENT_REWARD_TYPE_PET",
    toy = "ACHIEVEMENT_REWARD_TYPE_TOY",
    decor = "ACHIEVEMENT_REWARD_TYPE_DECOR",
    appearance = "ACHIEVEMENT_REWARD_TYPE_APPEARANCE",
    item = "ACHIEVEMENT_REWARD_TYPE_ITEM",
}

local function GetRewardTypeLabel(entry)
    if not entry then
        return nil
    end
    local labelKey = REWARD_TYPE_LABEL_KEYS[entry.rewardType]
        or "ACHIEVEMENT_REWARD_TYPE_OTHER"
    return string.format(L.ACHIEVEMENT_REWARD_TYPE_LABEL, L[labelKey])
end

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

AchievementRewards.SetIndexReadyCallback(function()
    local frame = achievementTreeFrame
    if not frame or not frame:IsShown() or not frame.sourceAchievementID
        or not UpdateAchievementRewardHeader
    then
        return
    end
    frame.rewardLookupAchievementID = nil
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

    local itemType = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemType:SetJustifyH("RIGHT")
    itemType:SetJustifyV("MIDDLE")
    itemType:SetWordWrap(false)
    itemType:SetHeight(48)
    frame.ItemType = itemType

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
        self.pendingModelRefresh = nil
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
        rewardFrame.infoRetryCount = 0
    end
    rewardFrame.entryCount = #entries
    rewardFrame.entryIndex = math.max(1,
        math.min(#entries, rewardFrame.entryIndex or 1))
    local primaryEntry = entries[rewardFrame.entryIndex]
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
    local pendingInfo = false
    for _, entry in ipairs(entries) do
        pendingInfo = pendingInfo or entry.pendingInfo
    end
    if pendingInfo and not rewardFrame.infoRetryPending
        and (rewardFrame.infoRetryCount or 0) < 3
    then
        rewardFrame.infoRetryCount = (rewardFrame.infoRetryCount or 0) + 1
        rewardFrame.infoRetryPending = true
        C_Timer.After(0.5, function()
            rewardFrame.infoRetryPending = nil
            local currentID = rewardFrame.achievementID
            if rewardFrame:IsShown() and frame:IsShown()
                and currentID and frame.sourceAchievementID == currentID
            then
                frame.rewardLookupAchievementID = nil
                UpdateAchievementRewardHeader(frame, currentID)
                UpdateAchievementRewardPanel(frame, currentID)
            end
        end)
    end
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
    local rewardTypeLabel = GetRewardTypeLabel(primaryEntry)
    rewardFrame.ItemType:SetText(rewardTypeLabel or "")
    rewardFrame.ItemType:SetShown(rewardTypeLabel ~= nil)
    rewardFrame.ItemName:SetText(table.concat(rewardNames, "  +  "))
    rewardFrame.ItemName:SetHeight(18)
    rewardFrame.ItemName:SetShown(#rewardNames > 0)
    rewardFrame.Description:SetText(table.concat(rewardDescriptions, "\n\n"))
    rewardFrame.Description:SetShown(#rewardDescriptions > 0)
    rewardFrame.pendingModelRefresh = nil
    rewardFrame.ModelScene:ClearScene()
    local showAppearance = previewEntry
        and previewEntry.previewType == "appearance"
        and #(previewEntry.appearanceSourceIDs or {}) > 0
        and SetupPlayerForModelScene ~= nil
    local showModel = showAppearance or previewEntry
        and previewEntry.previewType == "model"
        and previewEntry.modelSceneID
        and (previewEntry.displayID or previewEntry.asset)
    local contentCenterOffset = showModel and MODEL_SCENE_CENTER_OFFSET or 0
    rewardFrame.Description:ClearAllPoints()
    rewardFrame.Description:SetPoint("TOPLEFT", rewardFrame, "TOPLEFT",
        20 + contentCenterOffset, -65)
    rewardFrame.Description:SetPoint("TOPRIGHT", rewardFrame, "TOPRIGHT",
        -20 + contentCenterOffset, -65)
    local nameExtraHeight = math.max(0,
        rewardFrame.ItemName:GetHeight() - 18)
    local extraHeight = nameExtraHeight
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
        rewardFrame.Description:SetHeight(44 + extraHeight)
        rewardFrame.ModelScene:ClearAllPoints()
        local modelTopOffset = hasMultipleEntries
            and -146 - extraHeight or -118 - extraHeight
        rewardFrame.ModelScene:SetPoint("TOPLEFT", rewardFrame,
            "TOPLEFT", MODEL_SCENE_LEFT_OFFSET, modelTopOffset)
        rewardFrame.ModelScene:SetPoint("BOTTOMRIGHT", rewardFrame,
            "BOTTOMRIGHT", MODEL_SCENE_RIGHT_OFFSET, -20)
        rewardFrame.ModelScene:Show()
        local modelSceneID = showAppearance
            and DRESS_UP_FRAME_MODEL_SCENE_ID
            or previewEntry.modelSceneID
        if showAppearance then
            if rewardFrame.ModelScene.SetViewInsets then
                rewardFrame.ModelScene:SetViewInsets(0, 0, 0, 0)
            end
            if rewardFrame.ModelScene.ReleaseAllActors then
                rewardFrame.ModelScene:ReleaseAllActors()
            end
        end
        if rewardFrame.ModelScene.TransitionToModelSceneID then
            rewardFrame.ModelScene:TransitionToModelSceneID(
                modelSceneID,
                CAMERA_TRANSITION_TYPE_IMMEDIATE or 1,
                CAMERA_MODIFICATION_TYPE_DISCARD or 1, true)
        else
            rewardFrame.ModelScene:SetFromModelSceneID(
                modelSceneID, true)
        end
        if showAppearance then
            local useNativeForm = true
            if C_PlayerInfo and C_PlayerInfo.GetAlternateFormInfo then
                local _, inAlternateForm =
                    C_PlayerInfo.GetAlternateFormInfo()
                useNativeForm = not inAlternateForm
            end
            SetupPlayerForModelScene(rewardFrame.ModelScene, nil,
                previewEntry.appearanceSourceIDs, false, true, false,
                useNativeForm)
        end
        local actor
        if showAppearance then
            actor = rewardFrame.ModelScene:GetPlayerActor()
        else
            actor = rewardFrame.ModelScene:GetActorByTag(
                previewEntry.rewardType == "decor" and "decor"
                    or "unwrapped")
        end
        if actor then
            local isMount = previewEntry.rewardType == "mount"
            rewardFrame.ModelScene.rewardType = previewEntry.rewardType
            if actor.SetOnModelLoadedCallback then
                actor:SetOnModelLoadedCallback(isMount and function(loadedActor)
                    if rewardFrame.ModelScene.rewardType == "mount" then
                        FitMountRewardModel(rewardFrame.ModelScene,
                            loadedActor)
                    end
                end or nil)
            end
            if not showAppearance and actor.SetPreferModelCollisionBounds then
                actor:SetPreferModelCollisionBounds(
                    previewEntry.rewardType == "decor")
            end
            if showAppearance then
                actor:Show()
            elseif previewEntry.rewardType == "decor" then
                actor:SetModelByFileID(previewEntry.asset)
            else
                actor:SetModelByCreatureDisplayID(
                    previewEntry.displayID, true)
                if actor.SetAnimationBlendOperation
                    and Enum and Enum.ModelBlendOperation
                then
                    actor:SetAnimationBlendOperation(
                        previewEntry.isSelfMount
                            and Enum.ModelBlendOperation.None
                            or Enum.ModelBlendOperation.Anim)
                end
                actor:SetAnimation(previewEntry.isSelfMount and 618 or 0)
            end
            if not showAppearance then
                actor:Show()
            end
            if isMount then
                FitMountRewardModel(rewardFrame.ModelScene, actor)
            end
        else
            rewardFrame.pendingModelRefresh = true
        end
        rewardFrame.ModelControls:Show()
        rewardFrame.ModelControls:ClearAllPoints()
        rewardFrame.ModelControls:SetPoint("BOTTOM", rewardFrame, "BOTTOM",
            contentCenterOffset, 18)
        rewardFrame.ModelControls:UpdateLayout()
    else
        rewardFrame.Description:SetHeight(88 + extraHeight)
        rewardFrame:SetSize(380, primaryEntry and 250 + extraHeight or 180)
        rewardFrame.ModelControls:Hide()
        rewardFrame.ModelScene:Hide()
    end
    ConfigureAchievementRewardFrame(rewardFrame, frame)
    local hasRewardIcon = rewardFrame.ItemIcon:IsShown()
        or rewardFrame.ToyButton:IsShown()
    local hasRewardType = rewardFrame.ItemType:IsShown()
    local hasRewardName = rewardFrame.ItemName:IsShown()
    local hasNativeIconBorder = rewardFrame.CollectionBorder:IsShown()
        or rewardFrame.PetBorder:IsShown()
        or rewardFrame.ToyButton:IsShown()
    local iconWidth = hasRewardIcon
        and (hasNativeIconBorder and 56 or 48) or 0
    local typeWidth = hasRewardType
        and math.ceil(rewardFrame.ItemType:GetStringWidth()) or 0
    local typeGap = hasRewardType and (hasRewardIcon or hasRewardName)
        and 6 or 0
    local nameGap = hasRewardIcon and hasRewardName and 10 or 0
    local maximumNameWidth = math.max(1,
        rewardFrame:GetWidth() - typeWidth - typeGap - iconWidth
            - nameGap - 40)
    local unboundedNameWidth = rewardFrame.ItemName.GetUnboundedStringWidth
        and rewardFrame.ItemName:GetUnboundedStringWidth()
        or rewardFrame.ItemName:GetStringWidth()
    local rewardNameWidth = hasRewardName
        and math.min(maximumNameWidth, unboundedNameWidth) or 0
    local headerWidth = typeWidth + typeGap + iconWidth + nameGap
        + rewardNameWidth
    local headerLeft = contentCenterOffset - headerWidth / 2
    rewardFrame.ItemType:ClearAllPoints()
    rewardFrame.ItemType:SetWidth(math.max(1, typeWidth))
    rewardFrame.ItemType:SetPoint("LEFT", rewardFrame, "TOP",
        headerLeft, -34)
    rewardFrame.ItemIcon:ClearAllPoints()
    rewardFrame.ItemIcon:SetPoint("TOP", rewardFrame, "TOP",
        headerLeft + typeWidth + typeGap + iconWidth / 2, -10)
    rewardFrame.ItemName:ClearAllPoints()
    rewardFrame.ItemName:SetWidth(math.max(1, rewardNameWidth))
    rewardFrame.ItemName:SetHeight(48)
    rewardFrame.ItemName:SetJustifyH("CENTER")
    rewardFrame.ItemName:SetJustifyV("MIDDLE")
    if hasRewardIcon or hasRewardType then
        rewardFrame.ItemName:SetPoint("LEFT", rewardFrame, "TOP",
            headerLeft + typeWidth + typeGap + iconWidth + nameGap, -34)
    else
        rewardFrame.ItemName:SetPoint("TOP", rewardFrame, "TOP",
            contentCenterOffset, -10)
    end
    rewardFrame:Show()
    rewardFrame:Raise()
    return true
end

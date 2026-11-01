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

function GetAchievementCardRewardOffset(frame, achievementID, data)
    return -(GetAchievementRewardPanelWidth(frame) / 2 + 6)
        + (frame.officialBrowserState and 108 or 0)
end

local MODEL_SCENE_LEFT_OFFSET = -200
local MODEL_SCENE_RIGHT_OFFSET = 24
local MODEL_SCENE_CENTER_OFFSET =
    (MODEL_SCENE_LEFT_OFFSET + MODEL_SCENE_RIGHT_OFFSET) / 2

local function OpenRewardInCollections(entry)
    local tab = entry.rewardType == "mount" and 1 or 2
    if not CollectionsJournal or not CollectionsJournal:IsShown() then
        ToggleCollectionsJournal(tab)
    else
        CollectionsJournal_SetTab(CollectionsJournal, tab)
    end
    if not CollectionsJournal or not CollectionsJournal:IsShown() then
        return
    end
    RaiseAchievementExternalWindow(CollectionsJournal)
    if tab == 1 then
        local mountID = entry.mountID or entry.itemID
            and C_MountJournal and C_MountJournal.GetMountFromItem
            and C_MountJournal.GetMountFromItem(entry.itemID)
        if mountID and MountJournal_SelectByMountID then
            MountJournal_SelectByMountID(mountID)
        end
    elseif entry.speciesID and PetJournal_SelectSpecies then
        PetJournal_SelectSpecies(PetJournal, entry.speciesID)
    end
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
        UpdateAchievementRewardPanel(frame, frame.sourceAchievementID)
        frame.AchievementCard:ClearAllPoints()
        frame.AchievementCard:SetPoint("CENTER", frame, "CENTER",
            GetAchievementCardRewardOffset(frame, frame.sourceAchievementID),
            -45)
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

    local infoCard = CreateFrame("Frame", nil, frame)
    infoCard:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 12)
    infoCard:SetSize(224, 150)
    infoCard:SetFrameLevel(frame:GetFrameLevel() + 15)
    local infoBorder = infoCard:CreateTexture(nil, "BORDER")
    infoBorder:SetAllPoints()
    SetTextureAtlas(infoBorder, "generic-frame-chamfered-12d-2o")
    frame.InfoCard = infoCard

    local itemName = infoCard:CreateFontString(nil, "OVERLAY",
        "GameFontNormalHuge3")
    itemName:SetPoint("TOP", infoCard, "TOP", 0, -14)
    itemName:SetWidth(204)
    itemName:SetJustifyH("CENTER")
    itemName:SetJustifyV("TOP")
    itemName:SetWordWrap(true)
    itemName:SetHeight(18)
    itemName:SetTextColor(1, 1, 1)
    frame.ItemName = itemName

    local rewardTypeText = infoCard:CreateFontString(nil, "OVERLAY",
        "SystemFont_Small2")
    rewardTypeText:SetPoint("TOP", infoCard, "TOP", 0, -48)
    rewardTypeText:SetJustifyH("CENTER")
    rewardTypeText:SetTextColor(1, 0.82, 0)
    frame.RewardTypeText = rewardTypeText

    local description = infoCard:CreateFontString(nil, "OVERLAY",
        "SystemFont_Small2")
    description:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 10, -68)
    description:SetPoint("TOPRIGHT", infoCard, "TOPRIGHT", -10, -68)
    description:SetHeight(40)
    description:SetTextColor(1, 0.82, 0)
    description:SetJustifyH("CENTER")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    frame.Description = description

    local shopButtonCoords = {
        up = {
            left = { 0.30859375, 0.35937500, 0.85156250, 0.88281250 },
            middle = { 0.73925781, 0.81152344, 0.41992188, 0.45117188 },
            right = { 0.98242188, 0.99902344, 0.15917969, 0.19042969 },
        },
        down = {
            left = { 0.31738281, 0.36816406, 0.89160156, 0.92285156 },
            middle = { 0.18457031, 0.25683594, 0.93164063, 0.96289063 },
            right = { 0.98046875, 0.99707031, 0.33300781, 0.36425781 },
        },
    }
    local function CreateShopButton(label)
        local button = CreateFrame("Button", nil, infoCard)
        button:SetPoint("BOTTOM", infoCard, "BOTTOM", 0, 8)
        button:SetSize(146, 35)
        local parts = {}
        for _, part in ipairs({ "left", "middle", "right" }) do
            local texture = button:CreateTexture(nil, "BACKGROUND")
            parts[part] = texture
            texture:SetTexture("Interface\\Store\\Store-Main")
        end
        parts.left:SetPoint("TOPLEFT")
        parts.left:SetPoint("BOTTOMLEFT")
        parts.left:SetWidth(57)
        parts.right:SetPoint("TOPRIGHT")
        parts.right:SetPoint("BOTTOMRIGHT")
        parts.right:SetWidth(19)
        parts.middle:SetPoint("TOPLEFT", parts.left, "TOPRIGHT")
        parts.middle:SetPoint("BOTTOMRIGHT", parts.right, "BOTTOMLEFT")
        local buttonText = button:CreateFontString(nil, "OVERLAY",
            "GameFontNormalMed2")
        buttonText:SetPoint("CENTER")
        button:SetFontString(buttonText)
        button:SetNormalFontObject(GameFontNormalMed2)
        button:SetHighlightFontObject(GameFontHighlightMed2)
        button:SetDisabledFontObject(GameFontDisableMed2)
        button:SetText(label)
        buttonText:ClearAllPoints()
        buttonText:SetPoint("CENTER", button, "CENTER", 0, 3)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        highlight:SetTexCoord(0, 0.625, 0, 0.6875)
        highlight:SetBlendMode("ADD")
        button:SetHighlightTexture(highlight)
        local function SetButtonState(state)
            for part, texture in pairs(parts) do
                local coords = shopButtonCoords[state][part]
                texture:SetTexCoord(coords[1], coords[2],
                    coords[3], coords[4])
            end
        end
        SetButtonState("up")
        button:SetScript("OnShow", function() SetButtonState("up") end)
        button:SetScript("OnMouseDown", function() SetButtonState("down") end)
        button:SetScript("OnMouseUp", function() SetButtonState("up") end)
        return button
    end

    local detailsButton = CreateShopButton(L.ACHIEVEMENT_REWARD_DETAILS)
    frame.DetailsButton = detailsButton

    local officialButton = CreateShopButton(
        L.ACHIEVEMENT_REWARD_OFFICIAL_UI)
    officialButton:SetScript("OnClick", function(self)
        if self.entry then
            OpenRewardInCollections(self.entry)
        end
    end)
    frame.OfficialButton = officialButton

    local details = CreateFrame("Frame", nil, frame)
    details:SetPoint("BOTTOMRIGHT", infoCard, "TOPRIGHT", 0, 4)
    details:SetSize(224, 150)
    details:SetFrameLevel(infoCard:GetFrameLevel() + 5)
    local detailsBorder = details:CreateTexture(nil, "BORDER")
    detailsBorder:SetAllPoints()
    SetTextureAtlas(detailsBorder, "generic-frame-chamfered-12d-2o")
    local detailsText = details:CreateFontString(nil, "OVERLAY",
        "SystemFont_Small2")
    detailsText:SetPoint("TOPLEFT", details, "TOPLEFT", 12, -12)
    detailsText:SetWidth(200)
    detailsText:SetJustifyH("LEFT")
    detailsText:SetWordWrap(true)
    detailsText:SetTextColor(1, 0.82, 0)
    details.DetailsText = detailsText
    details:Hide()
    frame.DetailsPanel = details
    detailsButton:SetScript("OnClick", function()
        details:SetShown(not details:IsShown())
    end)

    local textPreview = CreateFrame("Frame", nil, frame)
    textPreview:SetSize(300, 100)
    textPreview:SetPoint("CENTER", frame, "CENTER")
    local toyButton = CreateFrame("Button", nil, textPreview)
    toyButton:SetPoint("TOP", textPreview, "TOP")
    toyButton:SetSize(72, 72)
    local toyIcon = toyButton:CreateTexture(nil, "ARTWORK")
    toyIcon:SetAllPoints()
    local toyBorder = toyButton:CreateTexture(nil, "OVERLAY")
    toyBorder:SetPoint("CENTER", toyIcon, "CENTER", -1, 1)
    toyBorder:SetSize(98, 98)
    toyBorder:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    toyBorder:SetTexCoord(0, 0.5625, 0, 0.5625)
    toyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemID then
            GameTooltip:SetToyByItemID(self.itemID)
        else
            GameTooltip:SetText(self.itemName or "")
            if self.description and self.description ~= "" then
                GameTooltip:AddLine(self.description, 1, 0.82, 0, true)
            end
        end
        GameTooltip:Show()
    end)
    toyButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    textPreview.ToyButton = toyButton
    textPreview.ToyIcon = toyIcon
    local previewText = textPreview:CreateFontString(nil, "OVERLAY",
        "GameFontNormalLarge")
    previewText:SetPoint("TOP", toyIcon, "BOTTOM", 0, -12)
    previewText:SetWidth(300)
    previewText:SetJustifyH("CENTER")
    previewText:SetWordWrap(true)
    textPreview.Text = previewText
    textPreview:Hide()
    frame.TextPreview = textPreview

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
    modelControls:SetPoint("BOTTOM", frame, "BOTTOM", 0, 65)
    modelControls:SetFrameLevel(modelScene:GetFrameLevel() + 10)
    modelControls:SetModelScene(modelScene)
    modelControls:Show()
    frame.ModelControls = modelControls

    local rewardSelector = CreateFrame("Frame", nil, frame)
    rewardSelector:SetSize(110, 24)
    rewardSelector:SetPoint("TOP", frame, "TOP", 0, -6)
    rewardSelector:SetFrameLevel(modelScene:GetFrameLevel() + 20)
    frame.RewardSelector = rewardSelector

    local function SelectAdjacentReward(self, direction)
        local rewardFrame = self:GetParent():GetParent()
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

    local previousButton = CreateFrame("Button", nil, rewardSelector)
    previousButton:SetSize(24, 24)
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

    local nextButton = CreateFrame("Button", nil, rewardSelector)
    nextButton:SetSize(24, 24)
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

    local entryCounter = rewardSelector:CreateFontString(nil, "OVERLAY",
        "GameFontHighlightSmall")
    entryCounter:SetPoint("CENTER")
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
    rewardFrame.InfoCard:SetFrameLevel(rewardFrame:GetFrameLevel() + 25)
    rewardFrame.DetailsPanel:SetFrameLevel(
        rewardFrame.InfoCard:GetFrameLevel() + 5)
    rewardFrame:SetWidth(GetAchievementRewardPanelWidth(hostFrame))
    rewardFrame:SetPoint("TOPRIGHT", hostFrame, "TOPRIGHT", -24, -135)
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
            false, false, false, useNativeForm)
    elseif entry.rewardType == "decor" and scene.GetPlayerActor then
        local playerActor = scene:GetPlayerActor()
        if playerActor and playerActor.Undress then
            playerActor:Undress()
        end
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
    if isMount then
        FitMountRewardModel(scene, actor)
    else
        scene:OnMouseWheel(-1)
    end
end

UpdateAchievementRewardPanel = function(frame, achievementID)
    local reward = GetAchievementRewardData(achievementID)
    if not frame or not reward then
        if achievementRewardFrame then
            achievementRewardFrame:Hide()
        end
        return false
    end

    local entries = reward.entries or {}
    local textRewardType
    if reward.text and reward.text ~= "" then
        if RewardDatabase.HasCategory(achievementID, "title") then
            textRewardType = "title"
        elseif #entries == 0 and RewardDatabase.HasCategory(achievementID,
            "other")
        then
            textRewardType = "other"
        end
    end
    if textRewardType then
        local withText = {}
        for index, entry in ipairs(entries) do
            withText[index] = entry
        end
        withText[#withText + 1] = {
            name = reward.text,
            rewardType = textRewardType,
            previewType = "text",
            uniqueKey = "text:" .. textRewardType,
        }
        entries = withText
    end
    if #entries == 0 then
        if achievementRewardFrame then
            achievementRewardFrame:Hide()
        end
        return false
    end

    local rewardFrame = CreateAchievementRewardFrame()
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
    rewardFrame.ItemName:SetText(table.concat(rewardNames, "  +  "))
    rewardFrame.ItemName:SetShown(#rewardNames > 0)
    local fullDescription = table.concat(rewardDescriptions, "\n\n")
    local summary = fullDescription:match("([^\r\n]+)") or ""
    rewardFrame.Description:SetText(summary)
    rewardFrame.Description:SetShown(#rewardDescriptions > 0)
    rewardFrame.Description:SetWordWrap(true)
    local rewardTypeKey = "ACHIEVEMENT_REWARD_TYPE_"
        .. string.upper(primaryEntry.rewardType or "other")
    rewardFrame.RewardTypeText:SetText(L[rewardTypeKey]
        or L.ACHIEVEMENT_REWARD_TYPE_OTHER)
    local hasDetails = fullDescription ~= ""
        and (fullDescription ~= summary or #fullDescription > 100)
    local rewardType = primaryEntry.rewardType
    local textOnly = rewardType == "title" or rewardType == "other"
        or rewardType == "item" and RewardDatabase.HasCategory(
            achievementID, "other")
    local centeredPreview = rewardType == "toy" or textOnly
    local showDetails = hasDetails
        and rewardType ~= "mount" and rewardType ~= "pet"
        and not centeredPreview
    rewardFrame.DetailsButton:SetShown(showDetails)
    local showOfficial = rewardType == "mount" or rewardType == "pet"
    rewardFrame.OfficialButton:SetShown(showOfficial)
    rewardFrame.OfficialButton.entry = showOfficial and primaryEntry or nil
    rewardFrame.DetailsPanel:Hide()
    rewardFrame.DetailsPanel.DetailsText:SetText(fullDescription)
    rewardFrame.DetailsPanel:SetHeight(math.max(40,
        rewardFrame.DetailsPanel.DetailsText:GetStringHeight() + 24))
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
    rewardFrame.InfoCard:SetShown(not centeredPreview)
    rewardFrame.TextPreview:SetShown(centeredPreview)
    if centeredPreview then
        local preview = rewardFrame.TextPreview
        local showToyIcon = rewardType == "toy"
            and (primaryEntry.icon or primaryEntry.iconAtlas)
        preview.ToyButton:SetShown(not not showToyIcon)
        if showToyIcon then
            preview.ToyButton.itemID = primaryEntry.itemID
            preview.ToyButton.itemName = primaryEntry.name
            preview.ToyButton.description = primaryEntry.description
            if not primaryEntry.iconAtlas
                or not SetTextureAtlas(preview.ToyIcon,
                    primaryEntry.iconAtlas)
            then
                preview.ToyIcon:SetTexture(primaryEntry.icon)
                preview.ToyIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            end
        end
        if rewardType == "toy" then
            preview.Text:SetText(primaryEntry.description or reward.text
                or "")
        else
            preview.Text:SetText(reward.text or primaryEntry.description
                or primaryEntry.name or "")
        end
        preview.Text:ClearAllPoints()
        if showToyIcon then
            preview.Text:SetPoint("TOP", preview.ToyButton, "BOTTOM",
                0, -12)
        else
            preview.Text:SetPoint("TOP", preview, "TOP")
        end
        preview.Text:SetHeight(0)
        local textHeight = math.max(20, preview.Text:GetStringHeight())
        preview.Text:SetHeight(textHeight)
        preview:SetHeight(textHeight + (showToyIcon and 84 or 0))
    end
    local hasMultipleEntries = #entries > 1
    rewardFrame.ItemName:ClearAllPoints()
    rewardFrame.ItemName:SetPoint("TOP", rewardFrame.InfoCard,
        "TOP", 0, -14)
    rewardFrame.ItemName:SetWidth(204)
    rewardFrame.ItemName:SetHeight(0)
    local nameHeight = math.max(28, rewardFrame.ItemName:GetStringHeight())
    rewardFrame.ItemName:SetHeight(nameHeight)
    rewardFrame.ItemName:SetJustifyH("CENTER")
    rewardFrame.RewardTypeText:ClearAllPoints()
    rewardFrame.RewardTypeText:SetPoint("TOP", rewardFrame.InfoCard,
        "TOP", 0, -(14 + nameHeight + 6))
    rewardFrame.Description:ClearAllPoints()
    local summaryTop = math.max(68, 14 + nameHeight + 24)
    rewardFrame.Description:SetPoint("TOPLEFT", rewardFrame.InfoCard,
        "TOPLEFT", 10, -summaryTop)
    rewardFrame.Description:SetPoint("TOPRIGHT", rewardFrame.InfoCard,
        "TOPRIGHT", -10, -summaryTop)
    rewardFrame.Description:SetHeight(40)
    local hasCardButton = showOfficial or showDetails
    rewardFrame.InfoCard:SetHeight(math.max(hasCardButton and 163 or 120,
        summaryTop + 40 + (hasCardButton and 55 or 12)))
    rewardFrame.PreviousReward:SetShown(hasMultipleEntries)
    rewardFrame.PreviousReward:SetEnabled(rewardFrame.entryIndex > 1)
    rewardFrame.NextReward:SetShown(hasMultipleEntries)
    rewardFrame.NextReward:SetEnabled(rewardFrame.entryIndex < #entries)
    rewardFrame.EntryCounter:SetShown(hasMultipleEntries)
    rewardFrame.EntryCounter:SetText(string.format("%d / %d",
        rewardFrame.entryIndex, #entries))
    rewardFrame.RewardSelector:ClearAllPoints()
    rewardFrame.RewardSelector:SetPoint("TOP", rewardFrame, "TOP",
        contentCenterOffset, -6)
    if showModel then
        rewardFrame:SetSize(460, 540)
        rewardFrame.ModelScene:ClearAllPoints()
        rewardFrame.ModelScene:SetPoint("TOPLEFT", rewardFrame,
            "TOPLEFT", MODEL_SCENE_LEFT_OFFSET, -10)
        rewardFrame.ModelScene:SetPoint("BOTTOMRIGHT", rewardFrame,
            "BOTTOMRIGHT", MODEL_SCENE_RIGHT_OFFSET, 48)
        rewardFrame.ModelScene:Show()
        if resetModel then
            ConfigureRewardModel(rewardFrame, previewEntry, showAppearance, modelKey)
        end
        rewardFrame.ModelControls:Show()
        rewardFrame.ModelControls:ClearAllPoints()
        rewardFrame.ModelControls:SetPoint("BOTTOM", rewardFrame, "BOTTOM",
            contentCenterOffset, 65)
        rewardFrame.ModelControls:UpdateLayout()
    else
        rewardFrame:SetSize(380, 250)
        rewardFrame.ModelControls:Hide()
        rewardFrame.ModelScene:Hide()
    end
    ConfigureAchievementRewardFrame(rewardFrame, frame)
    rewardFrame:Show()
    rewardFrame:Raise()
    return true
end

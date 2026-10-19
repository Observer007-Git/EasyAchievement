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


L = Addon.L
Config = Addon.Config
DEFAULT_FRAME_WIDTH = Config.Frame.DefaultWidth
DEFAULT_FRAME_HEIGHT = Config.Frame.DefaultHeight
MIN_FRAME_WIDTH = Config.Frame.MinWidth
MIN_FRAME_HEIGHT = Config.Frame.MinHeight
MAX_FRAME_WIDTH = Config.Frame.MaxWidth
MAX_FRAME_HEIGHT = Config.Frame.MaxHeight
NODE_SIZE = Config.Tree.NodeSize
NODE_ICON_SIZE = Config.Tree.NodeIconSize
BRANCH_GAP = Config.Tree.BranchGap
LEVEL_GAP = Config.Tree.LevelGap
LABEL_LEFT_GAP = Config.Tree.LabelLeftGap
TREE_PADDING = Config.Tree.Padding
MIN_TREE_SCALE = Config.Tree.MinScale
MAX_TREE_SCALE = Config.Tree.MaxScale
TREE_SCALE_STEP = Config.Tree.ScaleStep
MIN_ACHIEVEMENT_CARD_SCALE = Config.Card.MinScale
MAX_ACHIEVEMENT_CARD_SCALE = Config.Card.MaxScale
ACHIEVEMENT_CARD_SCALE_STEP = Config.Card.ScaleStep
MIN_ACHIEVEMENT_POPUP_ALPHA = 0.2
MAX_ACHIEVEMENT_POPUP_ALPHA = 1
ACHIEVEMENT_POPUP_ALPHA_STEP = 0.05
MAX_ACHIEVEMENT_SEARCH_RESULTS = Config.Search.MaxResults
MAX_ACHIEVEMENT_SEARCH_CHARACTERS = 12
DRESS_UP_FRAME_MODEL_SCENE_ID = Config.ModelScene.DressUpSceneID
INDEX_BUDGET_MILLISECONDS = Config.Performance.IndexBudgetMilliseconds
RESIZE_LAYOUT_INTERVAL = Config.Performance.ResizeLayoutInterval
CRITERIA_REFRESH_DELAY = Config.Performance.CriteriaRefreshDelay

function GetAchievementSearchBoxWidth(editBox)
    local ruler = editBox.EasyAchievementWidthRuler
    if not ruler then
        ruler = editBox:CreateFontString(nil, "ARTWORK")
        local fontFile, fontHeight, fontFlags = editBox:GetFont()
        if fontFile then
            ruler:SetFont(fontFile, fontHeight, fontFlags)
        else
            ruler:SetFontObject(GameFontHighlightSmall)
        end
        ruler:Hide()
        editBox.EasyAchievementWidthRuler = ruler
    end
    ruler:SetText(string.rep("汉", MAX_ACHIEVEMENT_SEARCH_CHARACTERS))
    return math.ceil(ruler:GetStringWidth()) + 44
end

function SetOwnedAchievementSearch(owner, query)
    achievementSearchOwner = owner
    return SetAchievementSearchString(query)
end

function ReleaseAchievementSearch(owner)
    if achievementSearchOwner ~= owner then
        return
    end
    achievementSearchOwner = nil
    if SetAchievementSearchString then
        SetAchievementSearchString("")
    end
end

function PlayAchievementSound(soundKit)
    if PlaySound and soundKit then
        PlaySound(soundKit)
    end
end

function GetAchievementATTApp()
    local app = _G.AllTheThings or _G.ATTC
    if not app then
        return nil
    end
    if app.CreatePopoutForSearch
        or app.SearchForObject and app.CreateMiniListForGroup
    then
        return app
    end
    return nil
end

function CanOpenAchievementATTGuide()
    return GetAchievementATTApp() ~= nil
end

function OpenAchievementATTGuide(achievementID)
    local app = GetAchievementATTApp()
    if not app or not IsAchievementValid(achievementID) then
        return false
    end
    if app.CreatePopoutForSearch then
        app.CreatePopoutForSearch("achievementID:" .. achievementID)
        return true
    end
    local group = app.SearchForObject("achievementID", achievementID, "key")
        or app.SearchForObject("achievementID", achievementID, "field")
    if not group then
        return false
    end
    app:CreateMiniListForGroup(group)
    return true
end

achievementPopupFrames = {}
achievementPopupPool = {}
achievementPopupFrameSerial = 0

function NavigateAchievementHistory(frame, offset)
    local targetIndex = (frame.historyIndex or 0) + offset
    if targetIndex < 1 or targetIndex > #(frame.history or {}) then
        return
    end
    frame.historyIndex = targetIndex
    local achievementID, showCardOnly, rewardCategory =
        GetAchievementHistoryEntry(
        frame.history[targetIndex])
    if rewardCategory and ShowAchievementRewardCategory then
        ShowAchievementRewardCategory(rewardCategory, "history")
    else
        ShowAchievementTree(achievementID, "history", nil, showCardOnly)
    end
end


function GetAchievementCardScale()
    return math.max(MIN_ACHIEVEMENT_CARD_SCALE,
        math.min(MAX_ACHIEVEMENT_CARD_SCALE,
            tonumber(Addon:GetSetting("achievementCardScale")) or 1))
end

function GetAchievementPopupScale()
    return math.max(MIN_ACHIEVEMENT_CARD_SCALE,
        math.min(MAX_ACHIEVEMENT_CARD_SCALE,
            tonumber(Addon:GetSetting("achievementPopupScale")) or 1))
end

function GetAchievementPopupAlpha()
    return math.max(MIN_ACHIEVEMENT_POPUP_ALPHA,
        math.min(MAX_ACHIEVEMENT_POPUP_ALPHA,
            tonumber(Addon:GetSetting("achievementPopupAlpha")) or 1))
end

function ApplyAchievementCardScale(value)
    local scale = tonumber(value) or GetAchievementCardScale()
    scale = math.max(MIN_ACHIEVEMENT_CARD_SCALE,
        math.min(MAX_ACHIEVEMENT_CARD_SCALE, scale))
    if achievementTreeFrame and achievementTreeFrame.AchievementCard then
        achievementTreeFrame.AchievementCard:SetScale(scale)
    end
    if achievementTreeFrame and achievementTreeFrame.CardScaleValue then
        achievementTreeFrame.CardScaleValue:SetText(string.format("%d%%",
            math.floor(scale * 100 + 0.5)))
        achievementTreeFrame.CardScaleMinus:SetEnabled(
            scale > MIN_ACHIEVEMENT_CARD_SCALE)
        achievementTreeFrame.CardScalePlus:SetEnabled(
            scale < MAX_ACHIEVEMENT_CARD_SCALE)
    end
end

function ApplyAchievementPopupScale(value)
    local scale = tonumber(value) or GetAchievementPopupScale()
    scale = math.max(MIN_ACHIEVEMENT_CARD_SCALE,
        math.min(MAX_ACHIEVEMENT_CARD_SCALE, scale))
    for _, frame in ipairs(achievementPopupFrames) do
        local card = frame.Card
        card:SetScale(scale)
        frame:SetSize(card:GetWidth() * scale,
            card:GetHeight() * scale)
    end
    if ReflowAchievementPopups then
        ReflowAchievementPopups()
    end
    if achievementTreeFrame and achievementTreeFrame.PopupScaleValue then
        achievementTreeFrame.PopupScaleValue:SetText(string.format("%d%%",
            math.floor(scale * 100 + 0.5)))
        achievementTreeFrame.PopupScaleMinus:SetEnabled(
            scale > MIN_ACHIEVEMENT_CARD_SCALE)
        achievementTreeFrame.PopupScalePlus:SetEnabled(
            scale < MAX_ACHIEVEMENT_CARD_SCALE)
    end
end

function ApplyAchievementPopupAlpha(value)
    local alpha = tonumber(value) or GetAchievementPopupAlpha()
    alpha = math.max(MIN_ACHIEVEMENT_POPUP_ALPHA,
        math.min(MAX_ACHIEVEMENT_POPUP_ALPHA, alpha))
    for _, popup in ipairs(achievementPopupFrames) do
        popup:SetAlpha(alpha)
    end
    if achievementTreeFrame and achievementTreeFrame.PopupAlphaValue then
        achievementTreeFrame.PopupAlphaValue:SetText(string.format("%d%%",
            math.floor(alpha * 100 + 0.5)))
        achievementTreeFrame.PopupAlphaMinus:SetEnabled(
            alpha > MIN_ACHIEVEMENT_POPUP_ALPHA)
        achievementTreeFrame.PopupAlphaPlus:SetEnabled(
            alpha < MAX_ACHIEVEMENT_POPUP_ALPHA)
    end
end

AchievementData = assert(Addon.AchievementData,
    "EasyAchievement achievement data service was not loaded")
IsAchievementValid = AchievementData.IsValid
SanitizeAchievementID = AchievementData.SanitizeID
SanitizeAchievementFavorites = AchievementData.SanitizeIDList
SanitizeAchievementTreeStates = AchievementData.SanitizeTreeStates
TrimAchievementTreeStates = AchievementData.TrimTreeStates
GetAchievementHistoryEntry = AchievementData.GetHistoryEntry
GetAchievementData = AchievementData.Get
GetAchievementProgress = AchievementData.GetProgress

function GetAchievementFavorites()
    local favorites = Addon:GetSetting("achievementFavorites")
    return type(favorites) == "table" and favorites or {}
end

function GetAchievementRecent()
    local recent = Addon:GetSetting("achievementRecent")
    return type(recent) == "table" and recent or {}
end

function IsAchievementFavorite(achievementID)
    for _, favoriteID in ipairs(GetAchievementFavorites()) do
        if favoriteID == achievementID then
            return true
        end
    end
    return false
end

function SetAchievementTextColor(fontString, completed, highlighted,
    normalBrightness)
    if completed then
        fontString:SetTextColor(0.2, 1, 0.2)
    elseif highlighted then
        fontString:SetTextColor(1, 0.82, 0.15)
    else
        local brightness = normalBrightness or 0.55
        fontString:SetTextColor(brightness, brightness, brightness)
    end
end

function ToggleAchievementFavorite(achievementID)
    local favorites = {}
    local removed = false
    for _, favoriteID in ipairs(GetAchievementFavorites()) do
        if favoriteID == achievementID then
            removed = true
        else
            favorites[#favorites + 1] = favoriteID
        end
    end
    if not removed then
        favorites[#favorites + 1] = achievementID
    end
    Addon:SetSetting("achievementFavorites", favorites)
    if RefreshAchievementFavoritesBar and achievementTreeFrame then
        RefreshAchievementFavoritesBar(achievementTreeFrame)
    end
    if achievementTreeFrame and achievementTreeFrame:IsShown()
        and achievementTreeFrame.sourceAchievementID and ShowAchievementTree
    then
        ShowAchievementTree(achievementTreeFrame.sourceAchievementID,
            "refresh")
    elseif achievementTreeFrame and achievementTreeFrame:IsShown()
        and achievementTreeFrame.rewardCategoryMode
        and achievementTreeFrame.layoutNodes and LayoutAchievementTree
    then
        LayoutAchievementTree(achievementTreeFrame.layoutNodes,
            achievementTreeFrame.layoutEdges,
            achievementTreeFrame.layoutRoot, true,
            achievementTreeFrame.layoutStats,
            achievementTreeFrame.layoutTitleRoot)
    end
end

RefreshAchievementFavoritesBar = function(frame)
    if not frame or not frame.FavoritesContent then
        return
    end

    frame.FavoriteButtons = frame.FavoriteButtons or {}
    local favorites = GetAchievementFavorites()
    local offset = 0
    local shown = 0
    for _, achievementID in ipairs(favorites) do
        local data = GetAchievementData(achievementID)
        if data then
            shown = shown + 1
            local button = frame.FavoriteButtons[shown]
            if not button then
                button = CreateFrame("Button", nil, frame.FavoritesContent)
                button:SetSize(116, 24)
                button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                local glow = button:CreateTexture(nil, "HIGHLIGHT")
                glow:SetAllPoints()
                glow:SetTexture(
                    "Interface\\QuestFrame\\UI-QuestTitleHighlight")
                glow:SetBlendMode("ADD")
                glow:SetAlpha(0.75)
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetPoint("LEFT", 2, 1)
                icon:SetSize(17, 17)
                icon:SetTexCoord(0, 1, 0, 1)
                button.Icon = icon
                local border = button:CreateTexture(nil, "OVERLAY")
                border:SetPoint("CENTER", icon, "CENTER", -0.33, 0.67)
                border:SetSize(24, 24)
                border:SetTexture(
                    "Interface\\AchievementFrame\\UI-Achievement-IconFrame")
                border:SetTexCoord(0, 0.5625, 0, 0.5625)
                button.Border = border
                local name = button:CreateFontString(nil, "OVERLAY",
                    "GameFontHighlightSmall")
                name:SetPoint("LEFT", icon, "RIGHT", 3, 0)
                name:SetPoint("RIGHT", -1, 0)
                name:SetJustifyH("LEFT")
                name:SetWordWrap(false)
                button.Name = name
                button:SetScript("OnClick", function(self, mouseButton)
                    if not self.achievementID then
                        return
                    end
                    if mouseButton == "RightButton" then
                        OpenAchievementContextMenu(self,
                            self.achievementID)
                    elseif IsShiftKeyDown() then
                        InsertAchievementLink(self.achievementID)
                    else
                        ShowAchievementTree(self.achievementID,
                            nil, nil, true)
                    end
                end)
                button:SetScript("OnEnter", function(self)
                    if self.achievementID then
                        local achievement = GetAchievementData(
                            self.achievementID)
                        SetAchievementTextColor(self.Name,
                            achievement and achievement.completed, true, 0.72)
                        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                        GameTooltip:SetText(achievement and achievement.name
                            or tostring(self.achievementID))
                        GameTooltip:Show()
                    end
                end)
                button:SetScript("OnLeave", function(self)
                    SetAchievementTextColor(self.Name, self.completed,
                        false, 0.72)
                    GameTooltip:Hide()
                end)
                frame.FavoriteButtons[shown] = button
            end
            button:ClearAllPoints()
            button:SetPoint("LEFT", frame.FavoritesContent, "LEFT",
                offset, 0)
            button.achievementID = achievementID
            button.completed = data.completed
            button.Icon:SetTexture(data.icon)
            button.Icon:SetDesaturated(not data.completed)
            button.Border:SetDesaturated(not data.completed)
            button.Border:SetAlpha(data.completed and 1 or 0.72)
            button.Name:SetText(data.name)
            button:SetWidth(math.max(64, math.min(116,
                27 + math.ceil(button.Name:GetStringWidth()))))
            SetAchievementTextColor(button.Name, data.completed, false, 0.72)
            button:Show()
            offset = offset + button:GetWidth() + 1
        end
    end
    for index = shown + 1, #frame.FavoriteButtons do
        frame.FavoriteButtons[index]:Hide()
        frame.FavoriteButtons[index].achievementID = nil
    end
    frame.FavoritesEmpty:SetShown(shown == 0)
    frame.FavoritesContent:SetWidth(math.max(1, offset))
    local maximum = math.max(0,
        offset - frame.FavoritesScroll:GetWidth())
    frame.FavoritesScroll:SetHorizontalScroll(math.min(
        frame.FavoritesScroll:GetHorizontalScroll(), maximum))
end

function RecordRecentAchievement(achievementID)
    if GetAchievementRecent()[1] == achievementID then
        return
    end
    local recent = { achievementID }
    for _, recentID in ipairs(GetAchievementRecent()) do
        if recentID ~= achievementID and #recent < 20 then
            recent[#recent + 1] = recentID
        end
    end
    Addon:SetSetting("achievementRecent", recent)
end

AchievementTreeData = assert(Addon.AchievementTreeData,
    "EasyAchievement achievement tree data service was not loaded")
GetTopmostAchievementIDs = AchievementTreeData.GetTopmostIDs
StartAchievementParentIndex = AchievementTreeData.StartParentIndex
GetChildAchievementIDs = AchievementTreeData.GetChildIDs
BuildAchievementTree = AchievementTreeData.Build
GetAchievementTreeStats = AchievementTreeData.GetStats
FilterIncompleteTree = AchievementTreeData.FilterIncomplete
FilterCollapsedTree = AchievementTreeData.FilterCollapsed
AchievementTreeLayout = assert(Addon.AchievementTreeLayout,
    "EasyAchievement achievement tree layout service was not loaded")

AchievementTreeData.SetIndexReadyCallback(function()
    local frame = achievementTreeFrame
    if frame and frame:IsShown() and frame.sourceAchievementID
        and frame.ScrollFrame:IsShown() and ShowAchievementTree
    then
        local fitAchievementID = frame.fitAfterParentIndexID
        frame.fitAfterParentIndexID = nil
        ShowAchievementTree(frame.sourceAchievementID, "refresh")
        if fitAchievementID == frame.sourceAchievementID
            and FitAchievementTreeToWindow
        then
            FitAchievementTreeToWindow(frame)
        end
    end
end)

local _, Addon = ...
local UI = assert(Addon.AchievementUI)
local Content = {}
Addon.AchievementContent = Content
UI.Content = Content

function Content.Relayout(frame)
    if not frame or not frame.layoutNodes then return end
    UI.LayoutAchievementTree(frame.layoutNodes, frame.layoutEdges,
        frame.layoutRoot, true, frame.layoutStats, frame.layoutTitleRoot)
end

function Content.Refresh(frame, reason, achievementID)
    if not frame or not frame:IsShown() then return end
    if frame.rewardCategoryMode then
        -- Keep the frozen order and node/widget identities while data changes.
        for _, node in ipairs(frame.layoutNodes or {}) do
            local data = UI.GetAchievementData(node.id)
            if data then
                node.data = data
                UI.RefreshAchievementNodeAppearance(frame, node)
                if node.id == achievementID and node.button
                    and node.button.CompletionAnimation
                then
                    node.button.CompletionAnimation:Stop()
                    node.button.CompletionAnimation:Play()
                end
            end
        end
        frame.layoutStats = UI.GetAchievementTreeStats(frame.layoutNodes or {})
    elseif frame.sourceAchievementID then
        if reason == "earned" then
            UI.RefreshAchievementTreePage(frame)
            for _, node in ipairs(frame.layoutNodes or {}) do
                if node.id == achievementID and node.button
                    and node.button.CompletionAnimation
                then
                    node.button.CompletionAnimation:Stop()
                    node.button.CompletionAnimation:Play()
                end
            end
        elseif reason == "favorite" then
            for _, node in ipairs(frame.layoutNodes or {}) do
                UI.RefreshAchievementNodeAppearance(frame, node)
            end
        elseif frame.AchievementCard and frame.AchievementCard:IsShown() then
            local header = frame.AchievementCardHeader
            if header and header.node then
                UI.ShowAchievementCardInTree(frame, header.node.id, true)
            end
        end
    end
end

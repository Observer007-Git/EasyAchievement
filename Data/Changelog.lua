local _, Addon = ...

-- Add new releases at the top and update Version in EasyAchievement.toc.
-- Each entry needs a version and notes in both languages; date is optional.
Addon.Changelog = {
    {
        version = "1.0.2",
        enUS = [[You can drag beyond the screen, add options with achievement points and without achievement points, and adjust some styles.]],
        zhCN = [[可以拖动超出屏幕，添加有成就点数和无成就点数选项，调整一些样式。]],
    },
    {
        version = "1.0.0",
        enUS = [[EasyAchievement provides achievement browsing, reward previews, search, favorites, and an In Progress list.]],
        zhCN = [[EasyAchievement 提供成就浏览、奖励预览、搜索、收藏和正在做列表。]],
    },
}

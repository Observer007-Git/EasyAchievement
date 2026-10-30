local addon = { Config = { Performance = {
    IndexBudgetMilliseconds = 2 } }, L = {
    ACHIEVEMENT_CATALOG_CATEGORY_ID = "分类 #%d",
    ACHIEVEMENT_CATALOG_ACHIEVEMENT_ID = "成就 #%d",
} }
local infoCalls = {}
local newlyCompleted = false
local env = setmetatable({
    GetLocale = function() return "frFR" end,
    UnitFactionGroup = function() return "Horde" end,
    GetCategoryInfo = function(id)
        if id == 14808 then return "Classique" end
    end,
    GetAchievementInfo = function(id)
        infoCalls[id] = (infoCalls[id] or 0) + 1
        if id == 456 then
            return id, "Zero-point feat", 0, true
        end
        if id == 1356 and newlyCompleted then
            return id, "Horde achievement", 10, true
        end
        if id == 15915 or id == 33 then
            return id, id == 33 and "Alliance achievement"
                or "Les rivages de l’Éveil : bronze", 10, true,
                nil, nil, nil, "A description-only phrase"
        end
        return nil
    end,
}, { __index = _G })

assert(loadfile("EasyAchievement/Data/AchievementCatalogData.lua",
    "t", env))("EasyAchievement", addon)
assert(loadfile("EasyAchievement/Core/AchievementCatalog.lua",
    "t", env))("EasyAchievement", addon)

local catalog = addon.AchievementCatalog
local categories, roots = catalog.GetCategories()
assert(catalog.GetBuild() == "12.1.5.70575")
assert(#roots == 15 and categories[14808].name == "Classique")
assert(not categories[1] and not categories[15076])
assert(not catalog.GetRecord(49) and not catalog.GetRecord(4860),
    "statistics and guild records must be absent from the catalog")
assert(categories[14808].count == 26 and categories[14808].points == 250)
assert(catalog.GetRecord(628)[1] == 14808)
assert(not catalog.GetRecord(1231),
    "statistic subcategory achievements must be excluded")
assert(catalog.GetRecord(15915)[1] == 15462)
assert(#catalog.GetIDs() == 11526)
assert(catalog.IsOppositeFaction(33)
    and not catalog.IsOppositeFaction(1356))
local directCount, directPoints = catalog.GetDirectTotals(14863)
assert(directCount == 25 and directPoints == 170)
assert(catalog.GetSelectedFaction() == "Horde"
    and catalog.IsVisible(1356) and not catalog.IsVisible(33))
assert(catalog.IsVisible(456))
catalog.SetPointsOnly(true)
assert(catalog.GetPointsOnly() and not catalog.IsVisible(456)
    and catalog.IsVisible(1356)
    and select(1, catalog.GetDirectTotals(81)) == 0)
catalog.SetPointsOnly(false)
catalog.SetSelectedFaction("Alliance")
assert(catalog.IsVisible(33) and not catalog.IsVisible(1356))
directCount, directPoints = catalog.GetDirectTotals(14863)
assert(directCount == 25 and directPoints == 170)
catalog.SetSelectedFaction("Horde")
local assigned, points, categoryCount = 0, 0, 0
for id in pairs(categories) do
    categoryCount = categoryCount + 1
    assigned = assigned + #catalog.GetCategoryIDs(id)
    points = points + categories[id].points
end
assert(categoryCount == 170 and assigned == #catalog.GetIDs()
    and points == 62635,
    "overview must contain only non-guild achievements and points")
assert(catalog.GetData(628).name == "成就 #628")
assert(catalog.GetData(628).catalogOnly)
catalog.GetData(628)
assert(infoCalls[628] == 1, "details must be cached per session")
assert(catalog.GetData(15915).completed)
assert(catalog.GetData(15915).name
    == "Les rivages de l’Éveil : bronze")

local found = catalog.Search("rivages de l’Éveil")
assert(#found > 0 and found[1] == 15915)
assert(#catalog.Search("description-only") == 0
    and #catalog.Search("15915") == 0
    and #catalog.Search("Bronze Shores") == 0
    and #catalog.Search("成就 #628") == 0,
    "achievement search must use only localized game names")
assert(#catalog.GetCategoryIDs(14808) == 26)

local ready = false
catalog.StartProgressScan(function() ready = true end)
assert(ready and catalog.IsProgressReady())
assert(catalog.GetCompleted(15462) == 1)
assert(catalog.GetCompletedPoints(15462) == 10)
assert(catalog.GetCompleted(81) == 1)
catalog.SetPointsOnly(true)
assert(catalog.GetCompleted(81) == 0)
catalog.SetPointsOnly(false)
assert(catalog.GetCompleted(14863) == 0)
assert(catalog.GetCompletedPoints(14863) == 0)
catalog.SetSelectedFaction("Alliance")
assert(catalog.GetCompleted(14863) == 1)
assert(catalog.GetCompletedPoints(14863) == 10)
catalog.SetSelectedFaction("Horde")
newlyCompleted = true
catalog.RefreshCompletion(1356)
catalog.RefreshCompletion(1356)
assert(catalog.GetCompleted(14863) == 1
    and catalog.GetCompletedPoints(14863) == 10,
    "new achievement points must be added only once")
local queued = {}
local searchDone = false
local deferredAddon = {
    Config = addon.Config,
    L = addon.L,
    AchievementCatalogData = {
        schema = 2, build = "test",
        categories = { [1] = { -1, 1, 2, 20 } },
        achievements = {
            [101] = { 1, 10, -1, 1, 123 },
            [102] = { 1, 10, -1, 2, 124 },
        },
    },
}
local deferredEnv = setmetatable({
    GetCategoryInfo = function() return "Test" end,
    GetAchievementInfo = function(id)
        return id, id == 101 and "Bonjour" or "Bonsoir", 10, false
    end,
    C_Timer = { After = function(_, callback)
        queued[#queued + 1] = callback
    end },
}, { __index = _G })
assert(loadfile("EasyAchievement/Core/AchievementCatalog.lua",
    "t", deferredEnv))("EasyAchievement", deferredAddon)
local deferred = deferredAddon.AchievementCatalog
assert(#deferred.Search("bonjour", function() searchDone = true end) == 0)
assert(not searchDone and #queued == 1,
    "first text search must defer the full client lookup")
while #queued > 0 do table.remove(queued, 1)() end
assert(searchDone and deferred.IsSearchReady()
    and deferred.Search("bonjour")[1] == 101,
    "deferred search must refresh with localized game results")
print("versioned achievement catalog, fallback and search: ok")

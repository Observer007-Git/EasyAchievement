local function LoadLocale(path, locale)
    local previousGetLocale = GetLocale
    GetLocale = function()
        return locale
    end

    local addon = { L = {} }
    local chunk = assert(loadfile(path))
    chunk("EasyAchievement", addon)
    GetLocale = previousGetLocale
    return addon.L
end

local function GetFormatTypes(text)
    local types = {}
    local index = 1
    while index <= #text do
        if text:sub(index, index) ~= "%" then
            index = index + 1
        elseif text:sub(index + 1, index + 1) == "%" then
            index = index + 2
        else
            local cursor = index + 1
            while cursor <= #text
                and text:sub(cursor, cursor):match("[-+ #0-9%.]")
            do
                cursor = cursor + 1
            end
            local conversion = text:sub(cursor, cursor)
            assert(conversion ~= "",
                "incomplete format placeholder in: " .. text)
            types[#types + 1] = conversion
            index = cursor + 1
        end
    end
    return table.concat(types, ",")
end

local function AssertCompatible(reference, candidate, label, complete)
    for key, referenceText in pairs(reference) do
        local candidateText = candidate[key]
        if complete then
            assert(type(candidateText) == "string",
                label .. " is missing locale key " .. key)
        end
        if candidateText ~= nil then
            assert(type(candidateText) == "string",
                label .. " locale key is not text: " .. key)
            assert(GetFormatTypes(referenceText) == GetFormatTypes(candidateText),
                label .. " format placeholders differ for " .. key)
        end
    end
    for key in pairs(candidate) do
        assert(reference[key] ~= nil,
            label .. " defines unknown locale key " .. key)
    end
end

local english = LoadLocale("EasyAchievement/Locales/enUS.lua", "enUS")
local simplifiedChinese = LoadLocale(
    "EasyAchievement/Locales/zhCN.lua", "zhCN")

AssertCompatible(english, simplifiedChinese, "zhCN", true)
assert(simplifiedChinese.ACHIEVEMENT_LAUNCHER_HIDE
        == "隐藏屏幕图标（/eat 或小地图再次启用）"
    and english.ACHIEVEMENT_LAUNCHER_HIDE:find("/eat", 1, true),
    "launcher hide option must explain how to reopen it in both locales")

local toc = assert(io.open("EasyAchievement/EasyAchievement.toc", "r"))
local runtimePaths = {}
for line in toc:lines() do
    local path = line:match("^%s*([^#].-%.lua)%s*$")
    if path then
        runtimePaths[#runtimePaths + 1] = "EasyAchievement/" .. path
    end
end
toc:close()

local localePaths = {}
for _, path in ipairs(runtimePaths) do
    if path:find("/Locales/", 1, true) then
        localePaths[#localePaths + 1] = path
    end
end
assert(#localePaths == 2
    and localePaths[1] == "EasyAchievement/Locales/enUS.lua"
    and localePaths[2] == "EasyAchievement/Locales/zhCN.lua",
    "runtime should load only English and simplified Chinese locales")

for _, path in ipairs(runtimePaths) do
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    for key in source:gmatch("L%.([A-Z][A-Z0-9_]*)") do
        assert(english[key] ~= nil,
            path .. " references unknown locale key " .. key)
    end
end

print("core locales and localization references: ok")

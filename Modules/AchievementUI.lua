local _, Addon = ...

local UI = Addon.AchievementUI or {}
Addon.AchievementUI = UI

local metatable = getmetatable(UI)
if not metatable then
    setmetatable(UI, { __index = _G })
elseif metatable.__index == nil then
    metatable.__index = _G
end

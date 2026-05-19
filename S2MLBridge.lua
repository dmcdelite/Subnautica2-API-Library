--[[
  S2MLBridge — optional require() shim for child mods.

  Install: ue4ss/Mods/shared/S2MLBridge.lua

  Usage in your mod's main.lua:
    local S2 = require("S2MLBridge")
    S2.RequireVersion("3.0.0")
    S2.Player.WhenReady(function(PC) ... end)
]]

local Bridge = {}

function Bridge.IsReady()
    return type(S2ML) == "table" and type(S2ML.Version) == "string"
end

function Bridge.RequireVersion(minVer)
    if not Bridge.IsReady() then
        error("S2ML is not loaded. Enable S2ML in mods.txt before this mod.", 2)
    end
    S2ML.RequireVersion(minVer)
    return S2ML
end

function Bridge.Get()
    if not Bridge.IsReady() then
        error("S2ML is not loaded. Enable S2ML in mods.txt.", 2)
    end
    return S2ML
end

setmetatable(Bridge, {
    __index = function(_, key)
        if Bridge.IsReady() then
            return S2ML[key]
        end
        return nil
    end,
})

return Bridge

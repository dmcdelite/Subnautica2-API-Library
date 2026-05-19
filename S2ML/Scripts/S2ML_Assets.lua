-- S2ML_Assets.lua
-- Asset loading and object lookup wrappers.

S2ML.Assets = S2ML.Assets or {}

local _cache = {}

function S2ML.Assets.Load(path)
    if _cache[path] then
        local ok = false
        pcall(function() _cache[path]:GetClass(); ok = true end)
        if ok then return _cache[path] end
        _cache[path] = nil
    end

    local asset = nil
    if type(LoadAsset) == "function" then
        S2ML.SafeCall(function() asset = LoadAsset(path) end)
    end
    if not asset or not asset:IsValid() then
        S2ML.SafeCall(function() asset = StaticFindObject(path) end)
    end
    if not asset or not asset:IsValid() then
        S2ML.SafeCall(function() asset = FindFirstOf(path) end)
    end

    if asset and asset:IsValid() then
        _cache[path] = asset
        S2ML.Log("Assets.Load: '" .. path .. "'", "DEBUG")
        return asset
    end

    S2ML.Log("Assets.Load: failed for '" .. path .. "'", "WARN")
    return nil
end

function S2ML.Assets.Find(pathOrName)
    return S2ML.Assets.Load(pathOrName)
end

function S2ML.Assets.FindS2Class(shortName)
    return S2ML.Engine.FindS2Class(shortName)
end

function S2ML.Assets.GetCDO(className)
    if S2ML.Items then return S2ML.Items.GetCDO(className) end
    return S2ML.Engine.StaticFind(S2ML.KnownClasses.FullClass(className))
end

function S2ML.Assets.InvalidateCache()
    _cache = {}
end

S2ML.Log("S2ML_Assets loaded.", "DEBUG")

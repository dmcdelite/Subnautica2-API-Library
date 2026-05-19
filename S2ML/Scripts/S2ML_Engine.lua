-- S2ML_Engine.lua
-- Unreal Engine / UE4SS helper wrappers (GameplayStatics, Kismet, world context).

S2ML.Engine = S2ML.Engine or {}

local _cache = {}

local function cacheGet(key, fullPath)
    if _cache[key] then
        local ok = false
        pcall(function() _cache[key]:GetClass(); ok = true end)
        if ok then return _cache[key] end
        _cache[key] = nil
    end
    local obj = nil
    S2ML.SafeCall(function() obj = StaticFindObject(fullPath) end)
    if not obj then
        S2ML.SafeCall(function() obj = FindFirstOf(key) end)
    end
    if obj and obj:IsValid() then
        _cache[key] = obj
        return obj
    end
    return nil
end

function S2ML.Engine.GetGameplayStatics()
    return cacheGet("GameplayStatics", "/Script/Engine.Default__GameplayStatics")
end

function S2ML.Engine.GetKismetSystemLibrary()
    return cacheGet("KismetSystemLibrary", "/Script/Engine.Default__KismetSystemLibrary")
end

function S2ML.Engine.GetKismetMathLibrary()
    return cacheGet("KismetMathLibrary", "/Script/Engine.Default__KismetMathLibrary")
end

function S2ML.Engine.GetGameEngine()
    return cacheGet("GameEngine", "/Script/Engine.Default__GameEngine")
end

function S2ML.Engine.StaticFind(classPath)
    local obj = nil
    S2ML.SafeCall(function() obj = StaticFindObject(classPath) end)
    if obj and obj:IsValid() then return obj end
    return nil
end

function S2ML.Engine.FindS2Class(shortName)
    return S2ML.Engine.StaticFind(S2ML.KnownClasses.FullClass(shortName))
end

function S2ML.Engine.GetWorld()
    local PC = S2ML.GetPC()
    if not PC then return nil end
    local world = nil
    S2ML.SafeCall(function() world = PC:GetWorld() end)
    if world and world:IsValid() then return world end
    S2ML.SafeCall(function() world = FindFirstOf("World") end)
    return (world and world:IsValid()) and world or nil
end

function S2ML.Engine.GetWorldContext()
    return S2ML.GetPC() or S2ML.Engine.GetWorld()
end

-- Print a colored string to screen + console via KismetSystemLibrary.
function S2ML.Engine.PrintString(text, color, duration, key)
    duration = duration or 4.0
    key = key or "s2ml_msg"
    color = color or { R = 0.2, G = 0.75, B = 1.0, A = 1.0 }

    local PC = S2ML.GetPC()
    local KSL = S2ML.Engine.GetKismetSystemLibrary()
    if PC and KSL then
        local ok = pcall(function()
            KSL:PrintString(PC, tostring(text), true, false, color, duration, key)
        end)
        if ok then return true end
    end
    print("[S2ML] " .. tostring(text))
    return false
end

function S2ML.Engine.InvalidateCache()
    _cache = {}
end

S2ML.Log("S2ML_Engine loaded.", "DEBUG")

-- S2ML_Core.lua
-- =============================================================================
-- Subnautica 2 Modding Library - Core
-- =============================================================================
-- CHANGELOG:
--   v3.1.0  Reliability + utility expansion pass
--   v3.0.0  Full API library - Player, Inventory, Save, Assets, Interact, Time
--   v2.0.0  UE4SS 3.0.1 / UE 5.6 EA - complete rewrite
--   v1.0.0  Initial prototype
-- =============================================================================

S2ML = S2ML or {}
S2ML.Version   = "3.1.0"
S2ML.DebugMode = false
S2ML._Injected = false
S2ML._Ready    = false

S2ML.LogLevels = {
    TRACE = 0,
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}
S2ML.LogLevel = S2ML.LogLevels.INFO

local _pcRef = nil
local _warnedOnce = {}
local _requiredApiStatus = nil

local function parseVer(v)
    local a, b, c = tostring(v or ""):match("(%d+)%.(%d+)%.(%d+)")
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

do
    local f = io.open("ue4ss/Mods/S2ML/S2ML_debug.flag", "r")
    if f then
        f:close()
        S2ML.DebugMode = true
        S2ML.LogLevel = S2ML.LogLevels.DEBUG
        print("[S2ML] Debug flag detected - verbose logging enabled.")
    end
end

function S2ML.SetLogLevel(level)
    if type(level) == "string" then
        local upper = level:upper()
        if S2ML.LogLevels[upper] ~= nil then
            S2ML.LogLevel = S2ML.LogLevels[upper]
            return true
        end
        return false
    end
    if type(level) == "number" then
        S2ML.LogLevel = level
        return true
    end
    return false
end

function S2ML.Log(message, level)
    level = (level or "INFO"):upper()
    local lvl = S2ML.LogLevels[level] or S2ML.LogLevels.INFO
    if level == "DEBUG" and S2ML.DebugMode then
        lvl = S2ML.LogLevels.DEBUG
    end
    if lvl < S2ML.LogLevel then return end
    local stamp = os.date("%H:%M:%S")
    print(string.format("[S2ML:%s][%s] %s", level, stamp, tostring(message)))
end

function S2ML.WarnOnce(key, message)
    if _warnedOnce[key] then return end
    _warnedOnce[key] = true
    S2ML.Log(message, "WARN")
end

function S2ML.SafeCall(fn, ...)
    if type(fn) ~= "function" then
        S2ML.Log("SafeCall expected function, got " .. type(fn), "WARN")
        return false, "SafeCall expected function"
    end
    local args = { ... }
    local results = { pcall(function() return fn(table.unpack(args)) end) }
    local ok = results[1]
    if not ok then
        S2ML.Log("SafeCall error: " .. tostring(results[2]), "WARN")
        return false, results[2]
    end
    return table.unpack(results)
end

function S2ML.IsValid(obj)
    if not obj then return false end
    local ok, valid = pcall(function()
        if type(obj.IsValid) == "function" then
            return obj:IsValid()
        end
        obj:GetClass()
        return true
    end)
    return ok and valid == true
end

function S2ML.DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[S2ML.DeepCopy(k, seen)] = S2ML.DeepCopy(v, seen)
    end
    return out
end

function S2ML.MergeTables(a, b)
    local out = S2ML.DeepCopy(a or {})
    for k, v in pairs(b or {}) do
        if type(v) == "table" and type(out[k]) == "table" then
            out[k] = S2ML.MergeTables(out[k], v)
        else
            out[k] = S2ML.DeepCopy(v)
        end
    end
    return out
end

function S2ML.Clamp(v, minVal, maxVal)
    v = tonumber(v) or 0
    minVal = tonumber(minVal) or v
    maxVal = tonumber(maxVal) or v
    if v < minVal then return minVal end
    if v > maxVal then return maxVal end
    return v
end

function S2ML.WrapContext(maybeWrapped)
    if not maybeWrapped then return nil end
    local out = maybeWrapped
    pcall(function()
        if maybeWrapped.get then out = maybeWrapped:get() end
    end)
    return out
end

function S2ML.GetPC(forceRefresh)
    if not forceRefresh and _pcRef and S2ML.IsValid(_pcRef) then
        return _pcRef
    end
    _pcRef = nil
    S2ML.SafeCall(function() _pcRef = FindFirstOf("PlayerController") end)
    if S2ML.IsValid(_pcRef) then return _pcRef end
    return nil
end

function S2ML.GetRequiredAPIs()
    local missing = {}
    if type(FindFirstOf)                  ~= "function" then table.insert(missing, "FindFirstOf") end
    if type(FindAllOf)                    ~= "function" then table.insert(missing, "FindAllOf") end
    if type(RegisterHook)                 ~= "function" then table.insert(missing, "RegisterHook") end
    if type(ExecuteInGameThreadWithDelay) ~= "function" then table.insert(missing, "ExecuteInGameThreadWithDelay") end
    return missing
end

function S2ML.CheckRequiredAPIs(forceRefresh)
    if _requiredApiStatus and not forceRefresh then
        return _requiredApiStatus.ok, _requiredApiStatus.missing
    end
    local missing = S2ML.GetRequiredAPIs()
    local ok = #missing == 0
    _requiredApiStatus = { ok = ok, missing = missing }
    return ok, missing
end

function S2ML.Init()
    S2ML.Log("Initializing Subnautica 2 Modding Library v" .. S2ML.Version)
    local ok, missing = S2ML.CheckRequiredAPIs(true)
    if not ok then
        S2ML.Log("Missing UE4SS APIs: " .. table.concat(missing, ", "), "WARN")
    else
        S2ML.Log("UE4SS API check passed.", "DEBUG")
    end
    S2ML._Ready = true
end

function S2ML.IsReady()
    return S2ML._Ready == true
end

function S2ML.CompareVersion(a, b)
    local aMaj, aMin, aPat = parseVer(a)
    local bMaj, bMin, bPat = parseVer(b)
    if aMaj ~= bMaj then return (aMaj > bMaj) and 1 or -1 end
    if aMin ~= bMin then return (aMin > bMin) and 1 or -1 end
    if aPat ~= bPat then return (aPat > bPat) and 1 or -1 end
    return 0
end

function S2ML.RequireVersion(minVer)
    if S2ML.CompareVersion(S2ML.Version, minVer) < 0 then
        error(string.format("S2ML requires >= %s but got %s", minVer, S2ML.Version), 2)
    end
end

function S2ML.Reset()
    S2ML._Injected = false
    _pcRef = nil
    _warnedOnce = {}
    if type(S2ML.Events) == "table" then
        S2ML.Events.Listeners = {}
        if S2ML.Events.ListenerIds then S2ML.Events.ListenerIds = {} end
    end
    if type(S2ML.Time) == "table" and S2ML.Time.CancelAll then
        S2ML.Time.CancelAll()
    end
    if type(S2ML.Engine) == "table" and S2ML.Engine.InvalidateCache then
        S2ML.Engine.InvalidateCache()
    end
    if type(S2ML.Assets) == "table" and S2ML.Assets.InvalidateCache then
        S2ML.Assets.InvalidateCache()
    end
    if type(S2ML.Config) == "table" and S2ML.Config.Invalidate then
        S2ML.Config.Invalidate()
    end
    S2ML.Log("S2ML.Reset() - session state cleared.")
end

function S2ML.GetModules()
    local modules = {}
    for name, val in pairs(S2ML) do
        if type(val) == "table" and name:match("^[A-Z]") then
            table.insert(modules, name)
        end
    end
    table.sort(modules)
    return modules
end

function S2ML.NewId(prefix)
    prefix = prefix or "id"
    local stamp = tostring(os.time())
    local rand = tostring(math.random(100000, 999999))
    return prefix .. "_" .. stamp .. "_" .. rand
end

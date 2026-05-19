-- S2ML_Core.lua
-- =============================================================================
-- Subnautica 2 Modding Library — Core
-- =============================================================================
-- CHANGELOG:
--   v3.0.0  Full API library — Player, Inventory, Save, Assets, Interact, Time
--   v2.0.0  UE4SS 3.0.1 / UE 5.6 EA — complete rewrite
--   v1.0.0  Initial prototype
-- =============================================================================

S2ML = S2ML or {}
S2ML.Version   = "3.0.0"
S2ML.DebugMode = false    -- set true for verbose output; or drop S2ML_debug.flag
S2ML._Injected = false

-- #7: auto-detect debug mode via flag file
do
    local f = io.open("ue4ss/Mods/S2ML/S2ML_debug.flag", "r")
    if f then f:close(); S2ML.DebugMode = true; print("[S2ML] Debug flag detected — verbose ON.") end
end

function S2ML.Log(message, level)
    level = level or "INFO"
    if level == "DEBUG" and not S2ML.DebugMode then return end
    print(string.format("[S2ML:%s] %s", level, message))
end

-- #6: SafeCall now forwards fn's return values to the caller
function S2ML.SafeCall(fn, ...)
    local args = { ... }
    local results = { pcall(function() return fn(table.unpack(args)) end) }
    local ok = results[1]
    if not ok then
        S2ML.Log("SafeCall error: " .. tostring(results[2]), "WARN")
        return false, results[2]
    end
    -- unpack: ok=true, then all return values
    return table.unpack(results)
end

-- #8: centralized PlayerController access with validity cache
local _pcRef = nil
function S2ML.GetPC()
    if _pcRef then
        local ok = false
        pcall(function() _pcRef:GetClass(); ok = true end)
        if ok then return _pcRef end
        _pcRef = nil
    end
    pcall(function() _pcRef = FindFirstOf("PlayerController") end)
    return _pcRef
end

-- #9: Init() validates UE4SS APIs are present
function S2ML.Init()
    S2ML.Log("Initializing Subnautica 2 Modding Library v" .. S2ML.Version)
    local missing = {}
    if type(FindFirstOf)                  ~= "function" then table.insert(missing, "FindFirstOf") end
    if type(FindAllOf)                    ~= "function" then table.insert(missing, "FindAllOf") end
    if type(RegisterHook)                 ~= "function" then table.insert(missing, "RegisterHook") end
    if type(ExecuteInGameThreadWithDelay) ~= "function" then table.insert(missing, "ExecuteInGameThreadWithDelay") end
    if #missing > 0 then
        S2ML.Log("Missing UE4SS APIs: " .. table.concat(missing, ", "), "WARN")
    else
        S2ML.Log("UE4SS API check passed.", "DEBUG")
    end
end

-- #18: version gate for dependent mods — throws if S2ML is too old
function S2ML.RequireVersion(minVer)
    local function parseVer(v)
        local a, b, c = v:match("(%d+)%.(%d+)%.(%d+)")
        return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
    end
    local cMaj, cMin, cPat = parseVer(S2ML.Version)
    local rMaj, rMin, rPat = parseVer(minVer)
    if cMaj < rMaj or (cMaj == rMaj and cMin < rMin) or
       (cMaj == rMaj and cMin == rMin and cPat < rPat) then
        error(string.format("S2ML requires >= %s but got %s", minVer, S2ML.Version), 2)
    end
end

-- #19: Reset all session state (call before hot-reload or on new session)
function S2ML.Reset()
    S2ML._Injected = false
    _pcRef         = nil
    if type(S2ML.Events) == "table" then
        S2ML.Events.Listeners = {}
    end
    if type(S2ML.Engine) == "table" and S2ML.Engine.InvalidateCache then
        S2ML.Engine.InvalidateCache()
    end
    if type(S2ML.Assets) == "table" and S2ML.Assets.InvalidateCache then
        S2ML.Assets.InvalidateCache()
    end
    S2ML.Log("S2ML.Reset() — session state cleared.")
end

-- List all loaded API modules (for diagnostics)
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

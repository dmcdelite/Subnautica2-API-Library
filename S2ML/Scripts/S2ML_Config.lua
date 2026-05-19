-- S2ML_Config.lua
-- Simple key=value config file loader/saver for mod configs.

S2ML.Config = S2ML.Config or {}

local _cache = {}
local function parseValue(val)
    val = tostring(val or ""):match("^%s*(.-)%s*$")
    local num = tonumber(val)
    if num ~= nil then return num end
    local lower = val:lower()
    if lower == "true" then return true end
    if lower == "false" then return false end
    if lower == "nil" then return nil end
    if (val:sub(1, 1) == "\"" and val:sub(-1) == "\"") or (val:sub(1, 1) == "'" and val:sub(-1) == "'") then
        return val:sub(2, -2)
    end
    return val
end

function S2ML.Config.Load(path, defaults)
    defaults = defaults or {}
    if _cache[path] then return _cache[path] end

    local cfg = {}
    for k, v in pairs(defaults) do cfg[k] = v end

    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" and not trimmed:match("^[%#%;]") then
                local key, val = trimmed:match("^([%w_%.%-]+)%s*=%s*(.+)$")
                if key and val then
                    cfg[key] = parseValue(val)
                end
            end
        end
        f:close()
    end

    _cache[path] = cfg
    return cfg
end

function S2ML.Config.Save(path, cfg)
    _cache[path] = S2ML.DeepCopy(cfg)
    local f = io.open(path, "w")
    if not f then
        S2ML.Log("Config.Save: could not write " .. path, "WARN")
        return false
    end
    f:write("# S2ML config — " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    local keys = {}
    for k in pairs(cfg) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        f:write(string.format("%s = %s\n", k, tostring(cfg[k])))
    end
    f:close()
    return true
end

function S2ML.Config.Get(path, key, default)
    local cfg = S2ML.Config.Load(path, { [key] = default })
    if cfg[key] == nil then return default end
    return cfg[key]
end

function S2ML.Config.Set(path, key, value, defaults)
    local cfg = S2ML.Config.Load(path, defaults or {})
    cfg[key] = value
    return S2ML.Config.Save(path, cfg)
end

function S2ML.Config.GetNumber(path, key, default, minVal, maxVal)
    local v = tonumber(S2ML.Config.Get(path, key, default))
    if v == nil then return default end
    if minVal ~= nil or maxVal ~= nil then
        return S2ML.Clamp(v, minVal or v, maxVal or v)
    end
    return v
end

function S2ML.Config.GetBool(path, key, default)
    local v = S2ML.Config.Get(path, key, default)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local lower = v:lower()
        if lower == "true" or lower == "1" or lower == "yes" then return true end
        if lower == "false" or lower == "0" or lower == "no" then return false end
    end
    return default == true
end

function S2ML.Config.GetString(path, key, default)
    local v = S2ML.Config.Get(path, key, default)
    if v == nil then return default end
    return tostring(v)
end

function S2ML.Config.Delete(path, key)
    local cfg = S2ML.Config.Load(path, {})
    if cfg[key] == nil then return false end
    cfg[key] = nil
    return S2ML.Config.Save(path, cfg)
end

function S2ML.Config.Has(path, key)
    local cfg = S2ML.Config.Load(path, {})
    return cfg[key] ~= nil
end

function S2ML.Config.Keys(path)
    local cfg = S2ML.Config.Load(path, {})
    local keys = {}
    for k in pairs(cfg) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

function S2ML.Config.LoadOrCreate(path, defaults)
    local cfg = S2ML.Config.Load(path, defaults or {})
    local f = io.open(path, "r")
    if f then
        f:close()
        return cfg
    end
    S2ML.Config.Save(path, cfg)
    return cfg
end

function S2ML.Config.Invalidate(path)
    if path then _cache[path] = nil else _cache = {} end
end

S2ML.Log("S2ML_Config loaded.", "DEBUG")

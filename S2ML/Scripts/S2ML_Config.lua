-- S2ML_Config.lua
-- Simple key=value config file loader/saver for mod configs.

S2ML.Config = S2ML.Config or {}

local _cache = {}

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
                    val = val:match("^%s*(.-)%s*$")
                    local num = tonumber(val)
                    if num then
                        cfg[key] = num
                    elseif val:lower() == "true" then
                        cfg[key] = true
                    elseif val:lower() == "false" then
                        cfg[key] = false
                    else
                        cfg[key] = val
                    end
                end
            end
        end
        f:close()
    end

    _cache[path] = cfg
    return cfg
end

function S2ML.Config.Save(path, cfg)
    _cache[path] = cfg
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

function S2ML.Config.Invalidate(path)
    if path then _cache[path] = nil else _cache = {} end
end

S2ML.Log("S2ML_Config loaded.", "DEBUG")

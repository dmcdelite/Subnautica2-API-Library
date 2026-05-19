-- S2ML_Player.lua
-- Local player access: pawn, location, rotation, survival stats, teleport.

S2ML.Player = S2ML.Player or {}

-- =============================================
-- VECTOR HELPERS
-- =============================================

function S2ML.Player.NormalizeVector(v)
    if not v then return nil end
    if type(v) == "table" then
        local x = v.X or v.x or v[1]
        local y = v.Y or v.y or v[2]
        local z = v.Z or v.z or v[3]
        if x and y and z then
            return { X = x + 0.0, Y = y + 0.0, Z = z + 0.0 }
        end
        return nil
    end
    local ok, x = pcall(function() return v.X end)
    local ok2, y = pcall(function() return v.Y end)
    local ok3, z = pcall(function() return v.Z end)
    if ok and ok2 and ok3 and x and y and z then
        return { X = x + 0.0, Y = y + 0.0, Z = z + 0.0 }
    end
    return nil
end

function S2ML.Player.Distance(a, b)
    a = S2ML.Player.NormalizeVector(a)
    b = S2ML.Player.NormalizeVector(b)
    if not a or not b then return nil end
    local dx = a.X - b.X
    local dy = a.Y - b.Y
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- =============================================
-- PLAYER ACCESS
-- =============================================

function S2ML.Player.GetPC()
    return S2ML.GetPC()
end

function S2ML.Player.GetPawn(PC)
    PC = PC or S2ML.GetPC()
    if not PC or not PC:IsValid() then return nil end
    local pawn = nil
    S2ML.SafeCall(function() pawn = PC.Pawn end)
    if not pawn then
        S2ML.SafeCall(function() pawn = PC:GetPawn() end)
    end
    if not pawn then
        S2ML.SafeCall(function() pawn = PC.AcknowledgedPawn end)
    end
    if pawn and pawn:IsValid() then return pawn end
    return nil
end

function S2ML.Player.IsInGame(PC)
    return S2ML.Player.GetPawn(PC) ~= nil
end

function S2ML.Player.GetLocation(PC)
    local pawn = S2ML.Player.GetPawn(PC)
    if not pawn then return nil end
    local loc = nil
    S2ML.SafeCall(function() loc = pawn:K2_GetActorLocation() end)
    return S2ML.Player.NormalizeVector(loc)
end

function S2ML.Player.GetRotation(PC)
    local pawn = S2ML.Player.GetPawn(PC)
    if not pawn then return nil end
    local rot = nil
    S2ML.SafeCall(function() rot = pawn:K2_GetActorRotation() end)
    if not rot then return nil end
    return {
        Pitch = rot.Pitch or rot.pitch or 0,
        Yaw   = rot.Yaw   or rot.yaw   or 0,
        Roll  = rot.Roll  or rot.roll  or 0,
    }
end

function S2ML.Player.GetForwardVector(PC)
    local rot = S2ML.Player.GetRotation(PC)
    if not rot then return nil end
    local yawRad = math.rad(rot.Yaw or 0)
    local pitchRad = math.rad(rot.Pitch or 0)
    return {
        X = math.cos(pitchRad) * math.cos(yawRad),
        Y = math.cos(pitchRad) * math.sin(yawRad),
        Z = math.sin(pitchRad),
    }
end

function S2ML.Player.GetWorld(PC)
    PC = PC or S2ML.GetPC()
    if not PC then return S2ML.Engine.GetWorld() end
    local world = nil
    S2ML.SafeCall(function() world = PC:GetWorld() end)
    if world and world:IsValid() then return world end
    return S2ML.Engine.GetWorld()
end

-- =============================================
-- SURVIVAL STATS (discovery-based)
-- =============================================

local function readProperty(obj, names)
    for _, name in ipairs(names) do
        local val = nil
        local ok = pcall(function() val = obj[name] end)
        if ok and val ~= nil and type(val) ~= "userdata" then
            return val, name
        end
        ok = pcall(function()
            if obj[name] then val = obj[name](obj) end
        end)
        if ok and val ~= nil then return val, name end
    end
    return nil
end

function S2ML.Player.GetStat(statName, PC)
    local pawn = S2ML.Player.GetPawn(PC)
    if not pawn then return nil end

    local getters = S2ML.KnownClasses.Fns.Player.StatGetters
    local ok, val, fn = S2ML.KnownClasses.TryCall(pawn, getters)
    if ok and val ~= nil then return val, fn end

    local propNames = {
        oxygen  = { "Oxygen", "OxygenLevel", "CurrentOxygen", "Air" },
        health  = { "Health", "CurrentHealth", "HP", "HealthPercent" },
        depth   = { "Depth", "CurrentDepth", "DepthMeters", "SubDepth" },
        hunger  = { "Hunger", "Food", "Calories" },
        thirst  = { "Thirst", "Water", "Hydration" },
        stamina = { "Stamina", "Energy" },
    }
    local names = propNames[statName:lower()]
    if names then
        return readProperty(pawn, names)
    end
    return readProperty(pawn, { statName })
end

function S2ML.Player.GetDepth(PC)
    local depth = S2ML.Player.GetStat("depth", PC)
    if depth then return depth end
    local loc = S2ML.Player.GetLocation(PC)
    if loc then return -(loc.Z or 0) / 100 end  -- rough meters estimate (UE cm)
    return nil
end

-- =============================================
-- TELEPORT
-- =============================================

function S2ML.Player.Teleport(location, PC, sweep)
    local pawn = S2ML.Player.GetPawn(PC)
    if not pawn then return false end
    location = S2ML.Player.NormalizeVector(location)
    if not location then return false end
    sweep = sweep ~= false
    return pcall(function()
        pawn:K2_SetActorLocation(location, sweep, {}, true)
    end)
end

function S2ML.Player.TeleportOffset(offset, PC)
    local loc = S2ML.Player.GetLocation(PC)
    if not loc then return false end
    offset = S2ML.Player.NormalizeVector(offset) or { X = 0, Y = 0, Z = 0 }
    return S2ML.Player.Teleport({
        X = loc.X + offset.X,
        Y = loc.Y + offset.Y,
        Z = loc.Z + offset.Z,
    }, PC)
end

-- =============================================
-- READY CALLBACK (lobby-safe)
-- =============================================

function S2ML.Player.WhenReady(callback)
    if type(callback) ~= "function" then return end
    if S2ML.Player.IsInGame() then
        pcall(callback, S2ML.GetPC())
        return
    end
    S2ML.Events.Once("OnPlayerSpawned", callback)
end

S2ML.Log("S2ML_Player loaded.", "DEBUG")

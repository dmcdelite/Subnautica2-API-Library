-- S2ML_World.lua
-- World actor spawning, placement, distance queries, and scene helpers.
--
-- USAGE (from another mod):
--   local actor = S2ML.World.SpawnAtPlayer("Titanium_Pickup")
--   S2ML.World.TeleportTo(actor, { X = 100, Y = 200, Z = -50 })
--   local nearby = S2ML.World.GetActorsInRadius("StorageContainer", playerLoc, 500)

S2ML.World = S2ML.World or {}

-- =============================================
-- INTERNAL HELPERS
-- =============================================

local function GetPlayerPawnAndLocation()
    local PC = FindFirstOf("PlayerController")
    if not PC or not PC:IsValid() then return nil, nil end
    local Pawn = nil
    S2ML.SafeCall(function() Pawn = PC.Pawn end)
    if not Pawn or not Pawn:IsValid() then return nil, nil end
    local loc = nil
    S2ML.SafeCall(function() loc = Pawn:K2_GetActorLocation() end)
    return Pawn, loc
end

local function VecDistance(a, b)
    local dx = (a.X or 0) - (b.X or 0)
    local dy = (a.Y or 0) - (b.Y or 0)
    local dz = (a.Z or 0) - (b.Z or 0)
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- =============================================
-- SPAWNING
-- =============================================

-- Spawn an actor at a world location.
-- location : FVector table  { X =, Y =, Z = }  (required)
-- rotation : FRotator table { Pitch =, Yaw =, Roll = }  (optional, defaults to zero)
-- Returns the spawned actor on success, nil on failure.
function S2ML.World.SpawnActor(className, location, rotation)
    rotation = rotation or { Pitch = 0, Yaw = 0, Roll = 0 }
    local spawned = nil

    -- UE4SS pattern: SpawnActorOfClass via GameplayStatics CDO
    S2ML.SafeCall(function()
        local GS = FindFirstOf("GameplayStatics")
        if GS and GS:IsValid() then
            spawned = GS:SpawnActorOfClass(className, location, rotation)
        end
    end)

    if spawned and spawned:IsValid() then
        S2ML.Log("World.SpawnActor: '" .. className .. "' spawned.", "DEBUG")
    else
        S2ML.Log("World.SpawnActor: failed to spawn '" .. className ..
                 "'. Verify the class name with Ctrl+P probe.", "WARN")
        spawned = nil
    end
    return spawned
end

-- Spawn an actor directly at the local player's position, offset upward.
-- offsetZ : units to raise above the player's Z (default 60)
function S2ML.World.SpawnAtPlayer(className, offsetZ)
    offsetZ = offsetZ or 60
    local _, loc = GetPlayerPawnAndLocation()
    if not loc then
        S2ML.Log("World.SpawnAtPlayer: no player location available.", "WARN")
        return nil
    end
    loc.Z = (loc.Z or 0) + offsetZ
    return S2ML.World.SpawnActor(className, loc)
end

-- =============================================
-- ACTOR QUERIES
-- =============================================

-- Return all live actors of a class within radius of an origin FVector.
-- Results are sorted nearest-first.
-- Returns a list of { actor, distance } pairs.
function S2ML.World.GetActorsInRadius(className, origin, radius)
    local result = {}
    local actors = nil
    S2ML.SafeCall(function() actors = FindAllOf(className) end)
    if not actors then return result end

    for _, actor in pairs(actors) do
        if actor and actor:IsValid() then
            local loc = nil
            S2ML.SafeCall(function() loc = actor:K2_GetActorLocation() end)
            if loc then
                local dist = VecDistance(loc, origin)
                if dist <= radius then
                    table.insert(result, { actor = actor, distance = dist })
                end
            end
        end
    end

    table.sort(result, function(a, b) return a.distance < b.distance end)
    return result
end

-- Find the single nearest actor of a class to an origin point.
-- Returns actor, distance  or  nil, nil.
function S2ML.World.FindNearest(className, origin)
    local results = S2ML.World.GetActorsInRadius(className, origin, math.huge)
    if #results > 0 then
        return results[1].actor, results[1].distance
    end
    return nil, nil
end

-- =============================================
-- TELEPORTATION & PLACEMENT
-- =============================================

-- Teleport an actor to an FVector location (no sweep).
function S2ML.World.TeleportTo(actor, location)
    if not actor or not actor:IsValid() then
        S2ML.Log("World.TeleportTo: invalid actor.", "WARN")
        return false
    end
    -- bSweep = false, FHitResult = {} (output param), bTeleport = false
    local ok = pcall(function()
        actor:K2_SetActorLocation(location, false, {}, false)
    end)
    return ok
end

-- Teleport an actor to the player's current position.
function S2ML.World.TeleportToPlayer(actor, offsetZ)
    offsetZ = offsetZ or 0
    local _, loc = GetPlayerPawnAndLocation()
    if not loc then return false end
    loc.Z = (loc.Z or 0) + offsetZ
    return S2ML.World.TeleportTo(actor, loc)
end

-- =============================================
-- DESTRUCTION
-- =============================================

-- Destroy a single actor safely.
function S2ML.World.DestroyActor(actor)
    if not actor or not actor:IsValid() then return false end
    return pcall(function() actor:K2_DestroyActor() end)
end

-- Destroy all live actors of a given class. Returns count destroyed.
function S2ML.World.DestroyAllOfClass(className)
    local count = 0
    local actors = nil
    S2ML.SafeCall(function() actors = FindAllOf(className) end)
    if not actors then return 0 end
    for _, actor in pairs(actors) do
        if actor and actor:IsValid() then
            if pcall(function() actor:K2_DestroyActor() end) then
                count = count + 1
            end
        end
    end
    S2ML.Log(string.format("World.DestroyAllOfClass: destroyed %d '%s'.", count, className))
    return count
end

S2ML.Log("S2ML_World loaded.", "DEBUG")

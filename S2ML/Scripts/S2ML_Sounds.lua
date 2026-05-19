-- S2ML_Sounds.lua
-- Audio playback helpers wrapping UE5's UAudioComponent and UGameplayStatics.
-- STUB: Sound cue asset paths not verified for S2 EA build. Use S2ML.Probe.Run()
--       (audio category) to discover actual asset names.  -- #16
--
-- USAGE (from another mod):
--   S2ML.Sounds.Play2D("WaterAmbience_Cue")          -- non-spatialized UI sound
--   S2ML.Sounds.PlayAtLocation("Explosion_Cue", loc)  -- world-space sound
--   S2ML.Sounds.PlayAttached("Engine_Cue", myActor)   -- follows an actor

S2ML.Sounds = S2ML.Sounds or {}

-- Internal: get GameplayStatics CDO (cached)
local _GS = nil
local function GetGS()
    if _GS and _GS:IsValid() then return _GS end
    S2ML.SafeCall(function()
        _GS = FindFirstOf("GameplayStatics")
    end)
    return (_GS and _GS:IsValid()) and _GS or nil
end

-- =============================================
-- 2D (non-spatialized) playback
-- =============================================

-- Play a sound by SoundBase asset name anywhere in the world (UI/ambient 2D).
-- soundName       : short class name or asset base name (e.g. "Pickup_Cue")
-- volumeMultiplier: 0.0 – 1.0+  (default 1.0)
-- pitchMultiplier : 0.5 – 2.0   (default 1.0)
function S2ML.Sounds.Play2D(soundName, volumeMultiplier, pitchMultiplier)
    volumeMultiplier = volumeMultiplier or 1.0
    pitchMultiplier  = pitchMultiplier  or 1.0

    local GS = GetGS()
    if not GS then
        S2ML.Log("Sounds.Play2D: GameplayStatics not found.", "WARN")
        return false
    end

    local sound = nil
    S2ML.SafeCall(function() sound = FindFirstOf(soundName) end)
    if not sound or not sound:IsValid() then
        S2ML.Log("Sounds.Play2D: sound '" .. soundName .. "' not found.", "WARN")
        return false
    end

    local ok = pcall(function()
        GS:PlaySound2D(sound, volumeMultiplier, pitchMultiplier, 0.0, nil, nil, true)
    end)

    if ok then
        S2ML.Log("Sounds.Play2D: '" .. soundName .. "'", "DEBUG")
    end
    return ok
end

-- =============================================
-- Spatialized (3D world) playback
-- =============================================

-- Play a spatialized sound at a specific world FVector location.
-- location : { X =, Y =, Z = }
function S2ML.Sounds.PlayAtLocation(soundName, location, volumeMultiplier, pitchMultiplier)
    volumeMultiplier = volumeMultiplier or 1.0
    pitchMultiplier  = pitchMultiplier  or 1.0

    local GS = GetGS()
    if not GS then
        S2ML.Log("Sounds.PlayAtLocation: GameplayStatics not found.", "WARN")
        return false
    end

    local sound = nil
    S2ML.SafeCall(function() sound = FindFirstOf(soundName) end)
    if not sound or not sound:IsValid() then
        S2ML.Log("Sounds.PlayAtLocation: sound '" .. soundName .. "' not found.", "WARN")
        return false
    end

    local ok = pcall(function()
        GS:PlaySoundAtLocation(sound, location, volumeMultiplier, pitchMultiplier, 0.0, nil, nil)
    end)

    if ok then
        S2ML.Log("Sounds.PlayAtLocation: '" .. soundName .. "'", "DEBUG")
    end
    return ok
end

-- Play a sound that follows and moves with an actor.
-- attachPoint : bone/socket name (default "None" = actor root)
function S2ML.Sounds.PlayAttached(soundName, actor, attachPoint)
    attachPoint = attachPoint or "None"

    if not actor or not actor:IsValid() then
        S2ML.Log("Sounds.PlayAttached: invalid actor.", "WARN")
        return false
    end

    local GS = GetGS()
    if not GS then
        S2ML.Log("Sounds.PlayAttached: GameplayStatics not found.", "WARN")
        return false
    end

    local sound = nil
    S2ML.SafeCall(function() sound = FindFirstOf(soundName) end)
    if not sound or not sound:IsValid() then
        S2ML.Log("Sounds.PlayAttached: sound '" .. soundName .. "' not found.", "WARN")
        return false
    end

    -- SpawnSoundAttached(Sound, Component, AttachPointName, Location, Rotation,
    --                    LocationType, bStopWhenDetached, VolumeMultiplier,
    --                    PitchMultiplier, StartTime, AttenuationSettings, ConcurrencySettings, bAutoDestroy)
    local ok = pcall(function()
        local rootComp = actor:GetRootComponent()
        if rootComp and rootComp:IsValid() then
            GS:SpawnSoundAttached(sound, rootComp, attachPoint,
                {}, {}, 0, true, 1.0, 1.0, 0.0, nil, nil, true)
        end
    end)

    if ok then
        S2ML.Log("Sounds.PlayAttached: '" .. soundName .. "' on actor", "DEBUG")
    end
    return ok
end

-- =============================================
-- PLAYER-RELATIVE HELPERS
-- =============================================

-- Play a sound at the local player's current world position.
function S2ML.Sounds.PlayAtPlayer(soundName, volumeMultiplier, pitchMultiplier)
    local PC = FindFirstOf("PlayerController")
    if not PC or not PC:IsValid() then return false end
    local Pawn = nil
    S2ML.SafeCall(function() Pawn = PC.Pawn end)
    if not Pawn or not Pawn:IsValid() then return false end
    local loc = nil
    S2ML.SafeCall(function() loc = Pawn:K2_GetActorLocation() end)
    if not loc then return false end
    return S2ML.Sounds.PlayAtLocation(soundName, loc, volumeMultiplier, pitchMultiplier)
end

S2ML.Log("S2ML_Sounds loaded.", "DEBUG")

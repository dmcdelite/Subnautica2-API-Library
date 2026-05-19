-- S2ML_Events.lua
S2ML.Events = S2ML.Events or {}
S2ML.Events.Listeners = {}
S2ML.Events.ListenerIds = {}
S2ML.Events._nextListenerId = S2ML.Events._nextListenerId or 1

local function _ensure(eventName)
    if not S2ML.Events.Listeners[eventName] then
        S2ML.Events.Listeners[eventName] = {}
    end
    if not S2ML.Events.ListenerIds[eventName] then
        S2ML.Events.ListenerIds[eventName] = {}
    end
end

function S2ML.Events.Subscribe(EventName, Callback)
    if type(Callback) ~= "function" then
        S2ML.Log("Subscribe ignored non-function callback for " .. tostring(EventName), "WARN")
        return nil
    end
    _ensure(EventName)
    local id = S2ML.Events._nextListenerId
    S2ML.Events._nextListenerId = id + 1
    table.insert(S2ML.Events.Listeners[EventName], Callback)
    table.insert(S2ML.Events.ListenerIds[EventName], id)
    S2ML.Log("Subscribed to event: " .. EventName, "DEBUG")
    return id
end

-- #5: Remove a specific callback from an event
function S2ML.Events.Unsubscribe(EventName, Callback)
    local listeners = S2ML.Events.Listeners[EventName]
    local ids = S2ML.Events.ListenerIds[EventName]
    if not listeners then return end
    for i = #listeners, 1, -1 do
        if listeners[i] == Callback then
            table.remove(listeners, i)
            if ids then table.remove(ids, i) end
            S2ML.Log("Unsubscribed from: " .. EventName, "DEBUG")
        end
    end
end

function S2ML.Events.UnsubscribeById(EventName, listenerId)
    local listeners = S2ML.Events.Listeners[EventName]
    local ids = S2ML.Events.ListenerIds[EventName]
    if not listeners or not ids then return false end
    for i = #ids, 1, -1 do
        if ids[i] == listenerId then
            table.remove(ids, i)
            table.remove(listeners, i)
            return true
        end
    end
    return false
end

-- #11: Remove ALL listeners for an event
function S2ML.Events.Clear(EventName)
    S2ML.Events.Listeners[EventName] = {}
    S2ML.Events.ListenerIds[EventName] = {}
    S2ML.Log("Cleared event: " .. EventName, "DEBUG")
end

function S2ML.Events.ClearAll()
    S2ML.Events.Listeners = {}
    S2ML.Events.ListenerIds = {}
    S2ML.Log("Cleared all events.", "DEBUG")
end

-- #12: One-shot subscription — auto-unsubscribes after first fire
function S2ML.Events.Once(EventName, Callback)
    local wrapper
    local listenerId = nil
    wrapper = function(...)
        if listenerId then
            S2ML.Events.UnsubscribeById(EventName, listenerId)
        else
            S2ML.Events.Unsubscribe(EventName, wrapper)
        end
        pcall(Callback, ...)
    end
    listenerId = S2ML.Events.Subscribe(EventName, wrapper)
    return listenerId
end

function S2ML.Events.WaitFor(EventName, callback, timeoutMs)
    timeoutMs = timeoutMs or 5000
    local fired = false
    local id = nil
    id = S2ML.Events.Subscribe(EventName, function(...)
        fired = true
        if id then S2ML.Events.UnsubscribeById(EventName, id) end
        S2ML.SafeCall(callback, true, ...)
    end)
    if timeoutMs > 0 then
        ExecuteInGameThreadWithDelay(timeoutMs, function()
            if fired then return end
            if id then S2ML.Events.UnsubscribeById(EventName, id) end
            S2ML.SafeCall(callback, false, "timeout")
        end)
    end
    return id
end

function S2ML.Events.Count(EventName)
    local listeners = S2ML.Events.Listeners[EventName]
    return listeners and #listeners or 0
end

function S2ML.Events.GetEventNames()
    local names = {}
    for name in pairs(S2ML.Events.Listeners) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function S2ML.Events.Trigger(EventName, ...)
    local listeners = S2ML.Events.Listeners[EventName]
    if listeners then
        local snapshot = {}
        for i = 1, #listeners do snapshot[i] = listeners[i] end
        for _, callback in ipairs(snapshot) do
            local ok, err = pcall(callback, ...)
            if not ok then
                S2ML.Log("Event callback error for " .. EventName .. ": " .. tostring(err), "WARN")
            end
        end
    end
end

-- #4: Lobby guard — only fire OnPlayerSpawned when Pawn is valid
-- #3: Reset _Injected on every ClientRestart so re-loading a save re-injects
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context)
    local PC = nil
    pcall(function() PC = S2ML.WrapContext(Context) end)
    -- #3: reset per-session injection flag
    S2ML._Injected = false
    if not PC then return end
    S2ML.Events.Trigger("OnClientRestart", PC)

    local function tryFire()
        local pawnOk = false
        pcall(function()
            local p = PC.Pawn
            if p then p:GetClass(); pawnOk = true end
        end)
        if pawnOk then
            S2ML.Events.Trigger("OnPlayerSpawned", PC)
        end
    end

    -- Check immediately; if lobby (no pawn yet), retry in 1s
    local pawnOk = false
    pcall(function()
        local p = PC.Pawn; if p then p:GetClass(); pawnOk = true end
    end)
    if pawnOk then
        S2ML.Events.Trigger("OnPlayerSpawned", PC)
    else
        ExecuteInGameThreadWithDelay(1000, function()
            pcall(function()
                local pc2 = FindFirstOf("PlayerController")
                if not pc2 then return end
                local ok2 = false
                pcall(function() local p = pc2.Pawn; if p then p:GetClass(); ok2=true end end)
                if ok2 then S2ML.Events.Trigger("OnPlayerSpawned", pc2) end
            end)
        end)
    end
end)

-- #13: Helper: attempt hook on a candidate CraftingStation path
-- #20: Logs discovered class names when hook fails
local function TryCraftingHook(classPath)
    local ok, err = pcall(function()
        RegisterHook(classPath, function(Context, Player)
            S2ML.Events.Trigger("OnFabricatorOpened", S2ML.WrapContext(Context), S2ML.WrapContext(Player))
        end)
    end)
    if ok then
        S2ML.Log("CraftingStation hook OK: " .. classPath)
        return true
    end
    S2ML.Log("Hook failed for " .. classPath .. ": " .. tostring(err), "WARN")
    return false
end

-- #1: CraftingStation hook wrapped in pcall; #14: FindAllOf fallback scan
local _craftHooked = false
if not TryCraftingHook("/Script/Subnautica2.CraftingStation:OnInteract") then
    -- #14: scan all UObjects for classes containing "Craft" in /Script/Subnautica2
    S2ML.Log("Primary CraftingStation hook failed — scanning for alternates...", "WARN")
    pcall(function()
        local found = {}
        ForEachUObject(function(obj)
            local name = ""
            pcall(function() name = obj:GetFullName() end)
            if name:find("^Class /Script/Subnautica2") and name:lower():find("craft") then
                table.insert(found, name)
            end
        end)
        if #found > 0 then
            S2ML.Log(#found .. " Craft-related class(es) found:")
            for _, n in ipairs(found) do
                S2ML.Log("  " .. n)
                if not _craftHooked then
                    local path = n:match("Class (.+)")
                    if path and TryCraftingHook(path .. ":OnInteract") then
                        _craftHooked = true
                    end
                end
            end
        else
            S2ML.Log("No Craft-related classes found in UObject scan.", "WARN")
        end
    end)
else
    _craftHooked = true
end

-- =============================================
-- DEATH DETECTION (pawn valid → invalid transition)
-- =============================================

local _lastPawnOk = false
local _deathPollActive = false
local _lastLoc = nil

local function startDeathPoll()
    if _deathPollActive then return end
    _deathPollActive = true

    local function poll()
        local PC = S2ML.GetPC()
        local inGame = false
        local pawnOk = false
        local loc = nil

        if PC and PC:IsValid() then
            inGame = S2ML.Player and S2ML.Player.IsInGame(PC) or false
            pawnOk = inGame
            if S2ML.Player then
                loc = S2ML.Player.GetLocation(PC)
                if loc then _lastLoc = loc end
            end
        end

        if _lastPawnOk and not pawnOk then
            S2ML.Events.Trigger("OnPlayerDeath", PC, _lastLoc or loc)
            S2ML.Log("OnPlayerDeath triggered.", "DEBUG")
        end

        _lastPawnOk = pawnOk
        ExecuteInGameThreadWithDelay(500, poll)
    end

    ExecuteInGameThreadWithDelay(500, poll)
end

S2ML.Events.Subscribe("OnPlayerSpawned", function()
    _lastPawnOk = true
    startDeathPoll()
end)

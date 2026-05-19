-- S2ML_Events.lua
S2ML.Events = S2ML.Events or {}
S2ML.Events.Listeners = {}

function S2ML.Events.Subscribe(EventName, Callback)
    if not S2ML.Events.Listeners[EventName] then
        S2ML.Events.Listeners[EventName] = {}
    end
    table.insert(S2ML.Events.Listeners[EventName], Callback)
    S2ML.Log("Subscribed to event: " .. EventName, "DEBUG")
end

-- #5: Remove a specific callback from an event
function S2ML.Events.Unsubscribe(EventName, Callback)
    local listeners = S2ML.Events.Listeners[EventName]
    if not listeners then return end
    for i = #listeners, 1, -1 do
        if listeners[i] == Callback then
            table.remove(listeners, i)
            S2ML.Log("Unsubscribed from: " .. EventName, "DEBUG")
        end
    end
end

-- #11: Remove ALL listeners for an event
function S2ML.Events.Clear(EventName)
    S2ML.Events.Listeners[EventName] = {}
    S2ML.Log("Cleared event: " .. EventName, "DEBUG")
end

-- #12: One-shot subscription — auto-unsubscribes after first fire
function S2ML.Events.Once(EventName, Callback)
    local wrapper
    wrapper = function(...)
        S2ML.Events.Unsubscribe(EventName, wrapper)
        pcall(Callback, ...)
    end
    S2ML.Events.Subscribe(EventName, wrapper)
end

function S2ML.Events.Trigger(EventName, ...)
    if S2ML.Events.Listeners[EventName] then
        for _, callback in ipairs(S2ML.Events.Listeners[EventName]) do
            pcall(callback, ...)
        end
    end
end

-- #4: Lobby guard — only fire OnPlayerSpawned when Pawn is valid
-- #3: Reset _Injected on every ClientRestart so re-loading a save re-injects
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context)
    local PC = nil
    pcall(function() PC = Context:get() end)
    -- #3: reset per-session injection flag
    S2ML._Injected = false
    if not PC then return end

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
            S2ML.Events.Trigger("OnFabricatorOpened", Context:get(), Player:get())
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
            end
        end

        if inGame and _lastPawnOk and not pawnOk then
            S2ML.Events.Trigger("OnPlayerDeath", PC, loc)
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

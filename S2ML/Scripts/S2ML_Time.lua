-- S2ML_Time.lua
-- Timers, delayed execution, and game-thread scheduling helpers.

S2ML.Time = S2ML.Time or {}

local _timers = {}
local _nextId = 1

function S2ML.Time.Delay(ms, fn)
    if type(fn) ~= "function" then return end
    ExecuteInGameThreadWithDelay(ms, function()
        S2ML.SafeCall(fn)
    end)
end

function S2ML.Time.Repeat(intervalMs, fn, maxRuns)
    if type(fn) ~= "function" then return nil end
    local id = _nextId
    _nextId = _nextId + 1
    local runs = 0

    local function tick()
        if _timers[id] == false then return end
        runs = runs + 1
        S2ML.SafeCall(fn, runs)
        if maxRuns and runs >= maxRuns then
            _timers[id] = false
            return
        end
        ExecuteInGameThreadWithDelay(intervalMs, tick)
    end

    _timers[id] = true
    ExecuteInGameThreadWithDelay(intervalMs, tick)
    return id
end

function S2ML.Time.Cancel(timerId)
    _timers[timerId] = false
end

function S2ML.Time.OnGameThread(fn)
    if type(fn) ~= "function" then return end
    ExecuteInGameThread(function()
        S2ML.SafeCall(fn)
    end)
end

function S2ML.Time.Now()
    return os.time()
end

function S2ML.Time.GameSeconds()
    local world = S2ML.Engine.GetWorld()
    if not world then return nil end
    local seconds = nil
    S2ML.SafeCall(function()
        if world.GetTimeSeconds then
            seconds = world:GetTimeSeconds()
        end
    end)
    return seconds
end

S2ML.Log("S2ML_Time loaded.", "DEBUG")

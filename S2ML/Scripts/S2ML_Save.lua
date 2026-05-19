-- S2ML_Save.lua
-- Save/load helpers with discovery-based function fallbacks.

S2ML.Save = S2ML.Save or {}

local Fns = S2ML.KnownClasses.Fns.Save

local function findSaveManager()
    local mgr = S2ML.KnownClasses.FindFirst({
        "SaveGameManager", "SaveManager", "GameSaveManager",
        "PersistenceManager", "SaveSystem", "SubnauticaSaveManager",
    })
    if mgr then return mgr end
    return S2ML.Engine.GetWorld()
end

function S2ML.Save.Save(slotName)
    slotName = slotName or ""

    -- Console command fallback (proven in AutoSaver mod)
    if type(ConsoleCommand) == "function" then
        local ok = pcall(function() ConsoleCommand("saveGame") end)
        if ok then
            S2ML.Events.Trigger("OnGameSaved", slotName)
            S2ML.Log("Save.Save: via ConsoleCommand('saveGame')")
            return true
        end
    end

    local targets = { findSaveManager(), S2ML.GetPC(), S2ML.Engine.GetGameEngine() }
    for _, target in ipairs(targets) do
        if target and target:IsValid() then
            local ok = S2ML.KnownClasses.TryCall(target, Fns.SaveGame, slotName)
            if ok then
                S2ML.Events.Trigger("OnGameSaved", slotName)
                S2ML.Log("Save.Save: native API succeeded.", "DEBUG")
                return true
            end
        end
    end

    S2ML.Log("Save.Save: no save API found. Run SaveFunctionFinder (savescan).", "WARN")
    return false
end

function S2ML.Save.Load(slotName)
    slotName = slotName or ""
    local targets = { findSaveManager(), S2ML.GetPC(), S2ML.Engine.GetGameEngine() }
    for _, target in ipairs(targets) do
        if target and target:IsValid() then
            local ok = S2ML.KnownClasses.TryCall(target, Fns.LoadGame, slotName)
            if ok then
                S2ML.Events.Trigger("OnGameLoaded", slotName)
                return true
            end
        end
    end
    S2ML.Log("Save.Load: no load API found.", "WARN")
    return false
end

function S2ML.Save.AutoSave(intervalSeconds)
    intervalSeconds = intervalSeconds or 300
    local function tick()
        if S2ML.Player.IsInGame() then
            S2ML.Save.Save("autosave")
        end
        ExecuteInGameThreadWithDelay(intervalSeconds * 1000, tick)
    end
    ExecuteInGameThreadWithDelay(intervalSeconds * 1000, tick)
    S2ML.Log("Save.AutoSave: every " .. intervalSeconds .. "s")
end

S2ML.Log("S2ML_Save loaded.", "DEBUG")

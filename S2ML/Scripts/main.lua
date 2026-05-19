-- main.lua
-- S2ML — Subnautica 2 Modding Library (Nautilus-style API for UE4SS Lua mods)
-- Load order matters: Core → KnownClasses → Engine → feature modules → Init

local function SafeRequire(modName)
    local ok, err = pcall(require, modName)
    if not ok then
        print("[S2ML] ERROR loading " .. modName .. ": " .. tostring(err))
    end
    return ok
end

local MODULES = {
    "S2ML_Core",
    "S2ML_KnownClasses",
    "S2ML_Engine",
    "S2ML_Config",
    "S2ML_Events",
    "S2ML_Player",
    "S2ML_Inventory",
    "S2ML_Items",
    "S2ML_Recipes",
    "S2ML_Tech",
    "S2ML_World",
    "S2ML_Sounds",
    "S2ML_Notify",
    "S2ML_Save",
    "S2ML_Assets",
    "S2ML_Interact",
    "S2ML_Time",
    "S2ML_Probe",
}

for _, mod in ipairs(MODULES) do
    SafeRequire(mod)
end

if type(S2ML) ~= "table" then
    print("[S2ML] FATAL: S2ML_Core failed — aborting S2ML startup.")
    return
end

S2ML.Init()

-- Post-world-load injection (runs once after first player spawn)
S2ML.Events.Subscribe("OnPlayerSpawned", function(PC)
    if S2ML._Injected then return end
    S2ML._Injected = true
    ExecuteInGameThreadWithDelay(1500, function()
        if S2ML.Items and S2ML.Items._InjectAll then
            S2ML.Items._InjectAll()
        end
        S2ML.Log("Post-load injection pass complete.")
    end)
end)

-- Console commands via ConsoleHelper (chains with Probe's handler)
if type(ConsoleHelper) == "table" then
    local _origExec = ConsoleHelper.ExecuteCmd
    function ConsoleHelper.ExecuteCmd(cmd)
        local parts = {}
        for w in tostring(cmd):gmatch("%S+") do table.insert(parts, w) end
        if parts[1] and parts[1]:lower() == "s2ml" then
            local sub = (parts[2] or ""):lower()
            if sub == "version" then
                S2ML.Log("S2ML v" .. S2ML.Version)
            elseif sub == "modules" then
                for _, m in ipairs(S2ML.GetModules()) do
                    S2ML.Log("  " .. m)
                end
            elseif sub == "give" and parts[3] then
                S2ML.Inventory.Give(parts[3], tonumber(parts[4]) or 1)
            elseif sub == "save" then
                S2ML.Save.Save()
            elseif sub == "tp" and parts[3] and parts[4] and parts[5] then
                S2ML.Player.Teleport({
                    X = tonumber(parts[3]), Y = tonumber(parts[4]), Z = tonumber(parts[5])
                })
            elseif sub == "depth" then
                S2ML.Log("Depth: " .. tostring(S2ML.Player.GetDepth()))
            elseif sub == "probe" and S2ML.Probe then
                S2ML.Probe.Run()
            elseif sub == "inspect" and S2ML.Probe then
                S2ML.Probe.InspectNearest(parts[3] or "Actor")
            elseif sub == "inv" and S2ML.Probe then
                S2ML.Probe.DumpPlayerInventory()
            elseif sub == "reset" then
                S2ML.Reset()
            else
                S2ML.Log("S2ML: version | modules | give | save | tp | depth | probe | inspect | inv | reset")
            end
            return
        end
        if _origExec then _origExec(cmd) end
    end
end

S2ML.Log("Subnautica 2 Modding Library v" .. S2ML.Version .. " ready.")
S2ML.Log("Ctrl+P=probe  Ctrl+I=inspect  Ctrl+U=inventory  |  Console: s2ml help")

-- S2ML_Interact.lua
-- Interaction hooks for crafting stations, storage, and custom interactables.

S2ML.Interact = S2ML.Interact or {}

local _hooked = {}

local function registerHookOnce(path, handler)
    if _hooked[path] then return true end
    local ok, err = pcall(function()
        RegisterHook(path, handler)
    end)
    if ok then
        _hooked[path] = true
        S2ML.Log("Interact: hooked " .. path, "DEBUG")
        return true
    end
    S2ML.Log("Interact: hook failed " .. path .. " — " .. tostring(err), "WARN")
    return false
end

local function unwrap(ctx)
    if not ctx then return nil end
    local obj = nil
    pcall(function()
        if ctx.get then obj = ctx:get() else obj = ctx end
    end)
    return obj
end

function S2ML.Interact.RegisterCraftingHook(eventName)
    eventName = eventName or "OnFabricatorOpened"
    local paths = {
        "/Script/Subnautica2.CraftingStation:OnInteract",
        "/Script/Subnautica2.CraftingStation:Interact",
        "/Script/Subnautica2.CraftingStation:BP_OnInteract",
    }
    for _, path in ipairs(paths) do
        registerHookOnce(path, function(Context, Player)
            S2ML.Events.Trigger(eventName, unwrap(Context), unwrap(Player))
        end)
    end
end

function S2ML.Interact.RegisterStorageHook(eventName)
    eventName = eventName or "OnStorageOpened"
    local paths = {
        "/Script/Subnautica2.StorageContainer:OnInteract",
        "/Script/Subnautica2.StorageContainer:Interact",
        "/Script/Subnautica2.StorageContainer:BP_OnInteract",
    }
    for _, path in ipairs(paths) do
        registerHookOnce(path, function(Context, Player)
            S2ML.Events.Trigger(eventName, unwrap(Context), unwrap(Player))
        end)
    end
end

function S2ML.Interact.RegisterAll()
    S2ML.Interact.RegisterCraftingHook()
    S2ML.Interact.RegisterStorageHook()
end

-- Auto-register storage hooks (crafting handled by S2ML_Events)
S2ML.Interact.RegisterStorageHook()

S2ML.Log("S2ML_Interact loaded.", "DEBUG")

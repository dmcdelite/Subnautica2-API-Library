-- S2ML_KnownClasses.lua
-- Central registry of Subnautica 2 class paths and function name candidates.
-- Update entries after running S2ML.Probe.Run() in-game.

S2ML.KnownClasses = S2ML.KnownClasses or {}

local KC = S2ML.KnownClasses

-- =============================================
-- CONFIRMED / HIGH-CONFIDENCE PATHS
-- =============================================

KC.Module = "/Script/Subnautica2"

KC.Classes = {
    CraftingStation   = "CraftingStation",
    StorageContainer  = "StorageContainer",
    InventoryComponent = "InventoryComponent",
    PlayerController  = "PlayerController",
    Character         = "Character",
    HUD               = "HUD",
    GameEngine        = "GameEngine",
    GameplayStatics   = "GameplayStatics",
    KismetSystemLibrary = "KismetSystemLibrary",
}

KC.Hooks = {
    ClientRestart     = "/Script/Engine.PlayerController:ClientRestart",
    CraftingInteract  = "/Script/Subnautica2.CraftingStation:OnInteract",
    StorageInteract   = "/Script/Subnautica2.StorageContainer:OnInteract",
}

-- =============================================
-- FUNCTION NAME CANDIDATES (discovery fallback)
-- =============================================

KC.Fns = {
    Inventory = {
        GetComponent = { "InventoryComponent", "PlayerInventory", "ItemInventory" },
        Give         = { "GiveItem", "AddItem", "K2_AddItem", "AddItemToInventory",
                         "GrantItem", "PickupItem", "K2_GiveItem" },
        Remove       = { "RemoveItem", "ConsumeItem", "K2_ConsumeItem", "DropItem",
                         "K2_RemoveItem" },
        GetCount     = { "GetItemCount", "K2_GetItemQuantity", "GetItemQuantity",
                         "GetQuantity", "HasItem" },
        GetAll       = { "GetAllItems", "GetItems", "K2_GetItems", "GetContents", "GetItemList" },
        OnAdded      = { "OnItemAdded", "K2_OnItemAdded", "OnPickup", "ItemPickedUp" },
    },
    Crafting = {
        AddRecipe    = { "AddRecipe", "RegisterRecipe", "InjectRecipe",
                         "K2_AddRecipe", "AddCraftingRecipe", "AppendRecipe" },
        Components   = { "RecipeComponent", "RecipeList", "CraftingComponent",
                         "RecipeDatabase", "RecipesComponent", "ItemCraftingComponent",
                         "FabricatorComponent", "CraftingManager" },
    },
    Tech = {
        Managers     = { "TechTreeManager", "ResearchManager", "TechManager",
                         "UnlockManager", "KnowledgeManager", "PDAManager" },
        IsUnlocked   = { "IsUnlocked", "IsTechUnlocked", "HasTech",
                         "IsResearched", "K2_IsUnlocked" },
        Unlock       = { "UnlockTech", "Unlock", "GrantTech",
                         "ResearchTech", "K2_UnlockTech", "AddKnowledge" },
    },
    Save = {
        SaveGame     = { "SaveGame", "QuickSave", "RequestSave", "SaveToSlot",
                         "K2_SaveGame", "SaveCurrentGame" },
        LoadGame     = { "LoadGame", "LoadFromSlot", "K2_LoadGame" },
    },
    Notify = {
        Managers     = { "NotificationManager", "HUDNotificationManager",
                         "UINotificationManager", "MessageManager" },
        Show         = { "ShowNotification", "AddNotification", "QueueNotification",
                         "DisplayMessage", "ShowMessage" },
    },
    Player = {
        Stats        = { "Oxygen", "Health", "Hunger", "Thirst", "Depth", "Pressure",
                         "CurrentDepth", "MaxDepth", "Stamina", "Energy" },
        StatGetters  = { "GetOxygen", "GetHealth", "GetDepth", "GetCurrentDepth",
                         "GetOxygenLevel", "GetHealthPercent" },
    },
}

-- =============================================
-- HELPERS
-- =============================================

function KC.FullClass(shortName)
    return KC.Module .. "." .. shortName
end

function KC.CDO(shortName)
    return "/Script/Subnautica2.Default__" .. shortName
end

function KC.TryCall(obj, fnList, ...)
    if not obj or type(fnList) ~= "table" then return false end
    local args = { ... }
    for _, fn in ipairs(fnList) do
        local ok, result = pcall(function()
            return obj[fn](obj, table.unpack(args))
        end)
        if ok then return true, result, fn end
    end
    return false
end

function KC.FindFirst(classNames)
    if type(classNames) == "string" then classNames = { classNames } end
    for _, name in ipairs(classNames) do
        local obj = nil
        S2ML.SafeCall(function() obj = FindFirstOf(name) end)
        if S2ML.IsValid(obj) then return obj, name end
    end
    return nil
end

function KC.FindComponent(owner, compNames)
    if not S2ML.IsValid(owner) then return nil end
    if type(compNames) == "string" then compNames = { compNames } end
    for _, name in ipairs(compNames) do
        local comp = nil
        S2ML.SafeCall(function()
            local c = owner[name]
            if S2ML.IsValid(c) then comp = c end
        end)
        if comp then return comp, name end
    end
    return nil
end

function KC.FindAny(classes)
    if type(classes) ~= "table" then return nil end
    for _, cls in ipairs(classes) do
        local obj = nil
        S2ML.SafeCall(function() obj = FindFirstOf(cls) end)
        if S2ML.IsValid(obj) then return obj, cls end
    end
    return nil
end

function KC.TryProperty(obj, names)
    if not obj or type(names) ~= "table" then return nil end
    for _, name in ipairs(names) do
        local value = nil
        local ok = pcall(function() value = obj[name] end)
        if ok and value ~= nil then return value, name end
    end
    return nil
end

function KC.CallAny(obj, names, ...)
    if not obj or type(names) ~= "table" then return false end
    local args = { ... }
    for _, name in ipairs(names) do
        local ok, val = pcall(function() return obj[name](obj, table.unpack(args)) end)
        if ok then return true, val, name end
    end
    return false
end

function KC.GetHookPath(classShortName, fnName)
    return string.format("%s.%s:%s", KC.Module, classShortName, fnName)
end

S2ML.Log("S2ML_KnownClasses loaded.", "DEBUG")

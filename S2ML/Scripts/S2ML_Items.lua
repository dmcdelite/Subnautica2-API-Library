-- S2ML_Items.lua
-- Item registration, CDO property patching, and inventory injection.
--
-- USAGE (from another mod):
--   S2ML.Items.Register({
--       id          = "com.author.mymod.superbattery",
--       displayName = "Super Battery",
--       baseClass   = "Battery",          -- clone defaults from this game class
--       properties  = { Charge = 500 },   -- override CDO properties
--       onPickup    = function(pc) S2ML.Notify.Message("Super Battery picked up!") end,
--   })

S2ML.Items = S2ML.Items or {}

local Registry  = {}   -- id -> itemDef
local CDOCache  = {}   -- className -> CDO UObject

-- =============================================
-- REGISTRATION
-- =============================================

-- Register a custom item definition.
-- Injection into the game world happens automatically on first player spawn.
--
-- itemDef fields:
--   id           (string, required)  reverse-DNS unique id
--   displayName  (string)
--   description  (string)
--   baseClass    (string)  existing /Script/Subnautica2 class to clone from
--   techType     (string)  tech tree id required to unlock this item
--   stackSize    (integer, default 1)
--   isEquipment  (bool,    default false)
--   equipSlot    (string)  "Hand" | "Body" | "Head" | "Tank" | "Module"
--   craftingTime (number,  default 2.0)  seconds
--   properties   (table)   CDO property overrides { PropertyName = value }
--   onPickup     (function(playerController))
--   onDrop       (function(playerController))
--   onUse        (function(playerController))
--   onLoad       (function(itemDef))  fires after injection pass
function S2ML.Items.Register(itemDef)
    if type(itemDef) ~= "table" or not itemDef.id then
        S2ML.Log("Items.Register: itemDef.id is required.", "WARN")
        return false
    end
    if Registry[itemDef.id] then
        S2ML.Log("Items.Register: '" .. itemDef.id .. "' already registered.", "WARN")
        return false
    end
    itemDef.stackSize    = itemDef.stackSize    or 1
    itemDef.craftingTime = itemDef.craftingTime or 2.0
    itemDef.isEquipment  = itemDef.isEquipment  or false
    itemDef.properties   = itemDef.properties   or {}
    Registry[itemDef.id] = itemDef
    S2ML.Log("Items.Register: '" .. itemDef.id .. "'", "DEBUG")
    return true
end

function S2ML.Items.Get(id)       return Registry[id] end
function S2ML.Items.IsRegistered(id) return Registry[id] ~= nil end

-- Iterate all registered items: callback(id, itemDef)
function S2ML.Items.ForEach(fn)
    for id, def in pairs(Registry) do S2ML.SafeCall(fn, id, def) end
end

-- =============================================
-- CDO ACCESS
-- =============================================

-- Get the Class Default Object for a Subnautica 2 class (cached).
-- Modifying the CDO changes default property values on every new instance.
function S2ML.Items.GetCDO(className)
    if CDOCache[className] then return CDOCache[className] end

    local cdo = nil

    -- Try full Subnautica2 module path first
    S2ML.SafeCall(function()
        cdo = StaticFindObject("/Script/Subnautica2." .. className)
    end)

    if not cdo or not cdo:IsValid() then
        -- Fall back to short-name search across all modules
        S2ML.SafeCall(function() cdo = FindFirstOf(className) end)
    end

    if cdo and cdo:IsValid() then
        CDOCache[className] = cdo
        S2ML.Log("Items.GetCDO: '" .. className .. "' found.", "DEBUG")
    else
        S2ML.Log("Items.GetCDO: '" .. className .. "' not found. Run Ctrl+P probe to find the correct class name.", "WARN")
    end
    return cdo
end

-- Apply a property override table to any valid UObject (CDO or instance).
-- Returns the number of properties successfully applied.
function S2ML.Items.ApplyProperties(obj, properties)
    if not obj or not obj:IsValid() then return 0 end
    local count = 0
    for k, v in pairs(properties) do
        local ok = pcall(function() obj[k] = v end)
        if ok then
            count = count + 1
            S2ML.Log("Items.ApplyProperties: set " .. k .. " = " .. tostring(v), "DEBUG")
        else
            S2ML.Log("Items.ApplyProperties: could not set '" .. k .. "' — property may not exist on this class.", "WARN")
        end
    end
    return count
end

-- =============================================
-- GIVE ITEM TO PLAYER
-- =============================================

-- Give an item to the local player by registered id or raw game class name.
-- Tries PlayerController, Pawn, and InventoryComponent function signatures.
-- count defaults to 1.
function S2ML.Items.Give(itemIdOrClass, count)
    if S2ML.Inventory and S2ML.Inventory.Give then
        return S2ML.Inventory.Give(itemIdOrClass, count)
    end
    S2ML.Log("Items.Give: S2ML.Inventory not loaded.", "WARN")
    return false
end

-- Spawn a physical pickup actor at the player's feet (fallback for Give).
function S2ML.Items.SpawnPickupAtPlayer(className, offsetZ)
    offsetZ = offsetZ or 60
    local PC = FindFirstOf("PlayerController")
    if not PC or not PC:IsValid() then return false end
    local Pawn = nil
    S2ML.SafeCall(function() Pawn = PC.Pawn end)
    if not Pawn or not Pawn:IsValid() then return false end

    local loc = nil
    S2ML.SafeCall(function() loc = Pawn:K2_GetActorLocation() end)
    if not loc then return false end
    loc.Z = (loc.Z or 0) + offsetZ

    return S2ML.World.SpawnActor(className, loc)
end

-- =============================================
-- PICKUP HOOK DISPATCHER
-- =============================================

-- Internal: fire the onPickup callback when the player picks up a registered item.
-- Hooked via the InventoryComponent add path.
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context)
    local PC = Context:get()
    if not PC or not PC:IsValid() then return end

    -- Re-apply GameState overrides for items that patch defaults
    S2ML.SafeCall(function()
        local Pawn = PC.Pawn
        if not Pawn or not Pawn:IsValid() then return end
        local IC = Pawn.InventoryComponent
        if not IC or not IC:IsValid() then return end

        -- Hook item-added events if the function exists
        local addHookFns = { "OnItemAdded", "K2_OnItemAdded", "OnPickup", "ItemPickedUp" }
        for _, fn in ipairs(addHookFns) do
            local hookPath = "/Script/Subnautica2.InventoryComponent:" .. fn
            pcall(function()
                RegisterHook(hookPath, function(HookCtx, itemClass)
                    local cls = tostring(itemClass)
                    for id, def in pairs(Registry) do
                        if def.baseClass == cls and def.onPickup then
                            S2ML.SafeCall(def.onPickup, PC)
                        end
                    end
                end)
            end)
        end
    end)
end)

-- =============================================
-- INJECTION PASS (called from main.lua on world load)
-- =============================================

function S2ML.Items._InjectAll()
    local count = 0
    for id, itemDef in pairs(Registry) do
        if itemDef.baseClass then
            local cdo = S2ML.Items.GetCDO(itemDef.baseClass)
            if cdo and next(itemDef.properties) then
                local applied = S2ML.Items.ApplyProperties(cdo, itemDef.properties)
                S2ML.Log(string.format("Items._InjectAll: '%s' — %d properties patched on CDO.", id, applied))
            end
        end
        if itemDef.onLoad then S2ML.SafeCall(itemDef.onLoad, itemDef) end
        count = count + 1
    end
    S2ML.Log(string.format("Items._InjectAll: %d item definitions processed.", count))
end

S2ML.Log("S2ML_Items loaded.", "DEBUG")

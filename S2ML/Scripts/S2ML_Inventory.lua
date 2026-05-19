-- S2ML_Inventory.lua
-- Player and container inventory API with discovery-based function fallbacks.

S2ML.Inventory = S2ML.Inventory or {}

local Fns = S2ML.KnownClasses.Fns.Inventory

local function resolveClassName(itemIdOrClass)
    local className = itemIdOrClass
    if S2ML.Items and S2ML.Items.Get(itemIdOrClass) then
        local def = S2ML.Items.Get(itemIdOrClass)
        if def and def.baseClass then className = def.baseClass end
    end
    return className
end

-- =============================================
-- COMPONENT ACCESS
-- =============================================

function S2ML.Inventory.GetComponent(actorOrPC)
    if not actorOrPC then
        actorOrPC = S2ML.Player.GetPawn()
    end
    if not S2ML.IsValid(actorOrPC) then return nil end

    local IC = S2ML.KnownClasses.FindComponent(actorOrPC, Fns.GetComponent)
    if IC then return IC end

    S2ML.SafeCall(function()
        local c = actorOrPC.InventoryComponent
        if c and c:IsValid() then IC = c end
    end)
    return IC
end

function S2ML.Inventory.GetPlayerComponent(PC)
    return S2ML.Inventory.GetComponent(S2ML.Player.GetPawn(PC))
end

-- =============================================
-- ITEM OPERATIONS
-- =============================================

function S2ML.Inventory.Give(itemIdOrClass, count, target)
    count = math.max(1, math.floor(tonumber(count) or 1))
    target = target or S2ML.Inventory.GetPlayerComponent()
    if not target then
        S2ML.Log("Inventory.Give: no inventory component.", "WARN")
        return false
    end

    local className = resolveClassName(itemIdOrClass)

    local ok, _, fn = S2ML.KnownClasses.TryCall(target, Fns.Give, className, count)
    if ok then
        S2ML.Log("Inventory.Give: " .. fn .. "(" .. className .. ")", "DEBUG")
        return true
    end

    -- Fallback: try PC and Pawn directly
    local PC = S2ML.GetPC()
    local pawn = S2ML.Player.GetPawn(PC)
    for _, obj in ipairs({ PC, pawn }) do
        if S2ML.IsValid(obj) then
            ok = S2ML.KnownClasses.TryCall(obj, Fns.Give, className, count)
            if ok then return true end
        end
    end

    if S2ML.Items then
        return S2ML.Items.SpawnPickupAtPlayer(className)
    end
    return false
end

function S2ML.Inventory.Remove(itemIdOrClass, count, target)
    count = math.max(1, math.floor(tonumber(count) or 1))
    target = target or S2ML.Inventory.GetPlayerComponent()
    if not target then return false end

    local className = resolveClassName(itemIdOrClass)

    local ok = S2ML.KnownClasses.TryCall(target, Fns.Remove, className, count)
    return ok
end

function S2ML.Inventory.GetCount(itemIdOrClass, target)
    target = target or S2ML.Inventory.GetPlayerComponent()
    if not target then return 0 end

    local className = resolveClassName(itemIdOrClass)

    local ok, count = S2ML.KnownClasses.TryCall(target, Fns.GetCount, className)
    if ok and type(count) == "number" then return count end
    if ok and count == true then return 1 end
    return 0
end

function S2ML.Inventory.Has(itemIdOrClass, count, target)
    count = count or 1
    return S2ML.Inventory.GetCount(itemIdOrClass, target) >= count
end

function S2ML.Inventory.GetAll(target)
    target = target or S2ML.Inventory.GetPlayerComponent()
    if not target then return {} end

    local ok, items = S2ML.KnownClasses.TryCall(target, Fns.GetAll)
    if ok and items then
        local list = {}
        for _, item in pairs(items) do
            table.insert(list, item)
        end
        return list
    end
    return {}
end

function S2ML.Inventory.EachItem(target, callback)
    if type(callback) ~= "function" then return 0 end
    local items = S2ML.Inventory.GetAll(target)
    for i, item in ipairs(items) do
        S2ML.SafeCall(callback, item, i)
    end
    return #items
end

function S2ML.Inventory.CountAll(target)
    return #S2ML.Inventory.GetAll(target)
end

function S2ML.Inventory.GiveMany(list, target)
    if type(list) ~= "table" then return false end
    local allOk = true
    for _, entry in ipairs(list) do
        local id = entry.id or entry.item or entry.class
        local amount = entry.count or 1
        if not id or not S2ML.Inventory.Give(id, amount, target) then
            allOk = false
        end
    end
    return allOk
end

-- =============================================
-- CONTAINER QUERIES
-- =============================================

function S2ML.Inventory.GetContainersNear(location, radius)
    location = S2ML.Player.NormalizeVector(location)
    if not location then return {} end
    radius = radius or 500

    local containers = {}
    local actors = nil
    S2ML.SafeCall(function() actors = FindAllOf("StorageContainer") end)
    if not actors then return containers end

    for _, actor in pairs(actors) do
        if S2ML.IsValid(actor) then
            local loc = nil
            S2ML.SafeCall(function() loc = actor:K2_GetActorLocation() end)
            loc = S2ML.Player.NormalizeVector(loc)
            if loc then
                local dist = S2ML.Player.Distance(loc, location)
                if dist and dist <= radius then
                    table.insert(containers, { actor = actor, distance = dist })
                end
            end
        end
    end

    table.sort(containers, function(a, b) return a.distance < b.distance end)
    return containers
end

function S2ML.Inventory.GetBaseContainers(location, radius)
    return S2ML.Inventory.GetContainersNear(location, radius)
end

function S2ML.Inventory.FindNearestContainer(location, radius)
    local containers = S2ML.Inventory.GetContainersNear(location, radius or 500)
    if #containers > 0 then
        return containers[1].actor, containers[1].distance
    end
    return nil, nil
end

function S2ML.Inventory.GetItemCount(container, itemId)
    local IC = S2ML.Inventory.GetComponent(container)
    if not IC then return 0 end
    return S2ML.Inventory.GetCount(itemId, IC)
end

function S2ML.Inventory.ConsumeItem(container, itemId, amount)
    local IC = S2ML.Inventory.GetComponent(container)
    if not IC then return false end
    return S2ML.Inventory.Remove(itemId, amount or 1, IC)
end

function S2ML.Inventory.Transfer(itemId, amount, fromContainer, toContainer)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local fromIC = S2ML.Inventory.GetComponent(fromContainer)
    local toIC = S2ML.Inventory.GetComponent(toContainer)
    if not fromIC or not toIC then return false end
    if not S2ML.Inventory.Remove(itemId, amount, fromIC) then return false end
    if not S2ML.Inventory.Give(itemId, amount, toIC) then
        -- Best effort rollback
        S2ML.Inventory.Give(itemId, amount, fromIC)
        return false
    end
    return true
end

function S2ML.Inventory.DropAtPlayer(itemIdOrClass, count)
    count = math.max(1, math.floor(tonumber(count) or 1))
    local className = resolveClassName(itemIdOrClass)
    if not S2ML.Items or not S2ML.Items.SpawnPickupAtPlayer then return false end
    local allOk = true
    for _ = 1, count do
        if not S2ML.Items.SpawnPickupAtPlayer(className) then
            allOk = false
        end
    end
    return allOk
end

S2ML.Log("S2ML_Inventory loaded.", "DEBUG")

-- S2ML_Probe.lua
-- Runtime class and function discovery tool for Subnautica 2.
-- Press Ctrl+P in-game to scan all UObjects and log categorized results.
-- Press Ctrl+I to inspect the class directly under the player's crosshair.
-- Results appear in the UE4SS console window and UE4SS.log.
--
-- This module is the S2ML equivalent of Nautilus's debug/discovery tooling.
-- Run a probe after loading a save, then search UE4SS.log for class names
-- to fill in the correct values for S2ML.Items.Register baseClass, etc.

S2ML.Probe = S2ML.Probe or {}

-- =============================================
-- CATEGORY DEFINITIONS
-- =============================================

local CATEGORIES = {
    inventory  = { "inventory", "backpack", "container", "storage", "slot", "equipment", "hotbar" },
    crafting   = { "craft", "fabricat", "recipe", "workbench", "station", "blueprintcraft" },
    tech       = { "tech", "research", "unlock", "knowledg", "pdatree", "scan", "fragment" },
    player     = { "player", "character", "pawn", "survivor", "diver", "protagonist" },
    save       = { "save", "persist", "checkpoint", "serial", "autosave", "savegame" },
    audio      = { "audio", "sound", "music", "sfx", "ambien", "cue" },
    hud        = { "hud", "notif", "widget", "message", "screen", "ui", "overlay", "display" },
    item       = { "item", "pickup", "loot", "drop", "collect", "fragment", "resource", "tool" },
    world      = { "biome", "zone", "region", "depth", "terrain", "ocean", "base", "module" },
    creature   = { "creature", "fish", "leviathan", "fauna", "npc", "enemy", "predator" },
}

local function matchesCategory(name, keywords)
    local lower = name:lower()
    for _, kw in ipairs(keywords) do
        if lower:find(kw, 1, true) then return true end
    end
    return false
end

-- =============================================
-- FULL SCAN
-- =============================================

-- Scan all live UObjects and log everything categorized by domain.
-- Only Class and Function objects are listed (not instances) to keep output manageable.
function S2ML.Probe.Run()
    S2ML.Log("=== S2ML PROBE: Subnautica 2 Class Discovery ===")

    local results = {}
    for cat in pairs(CATEGORIES) do results[cat] = {} end
    local total = 0

    -- #17: wrap ForEachUObject in pcall so a bad object can't abort the full scan
    local scanOk, scanErr = pcall(function()
        ForEachUObject(function(obj, id)
            local ok, fullName = pcall(function() return obj:GetFullName() end)
            if not ok or not fullName then return end

            -- Only index Class and Function objects (not actor instances, assets, etc.)
            local isClass    = fullName:find("^Class ")
            local isFunction = fullName:find("^Function ")
            if not isClass and not isFunction then return end

            -- Skip pure engine internals to reduce noise; keep /Script/Subnautica2 priority
            for cat, keywords in pairs(CATEGORIES) do
                if matchesCategory(fullName, keywords) then
                    table.insert(results[cat], fullName)
                    total = total + 1
                    break
                end
            end
        end)
    end)
    if not scanOk then
        S2ML.Log("ForEachUObject scan error: " .. tostring(scanErr), "WARN")
    end

    -- Print sorted by category
    local catOrder = { "item", "inventory", "crafting", "tech", "player",
                       "save", "audio", "hud", "world", "creature" }
    for _, cat in ipairs(catOrder) do
        local items = results[cat]
        if items and #items > 0 then
            -- Sort Subnautica2 module entries to the top
            table.sort(items, function(a, b)
                local aS2 = a:find("Subnautica2") and 1 or 0
                local bS2 = b:find("Subnautica2") and 1 or 0
                if aS2 ~= bS2 then return aS2 > bS2 end
                return a < b
            end)
            S2ML.Log(string.format("--- %s (%d) ---", cat:upper(), #items))
            for _, name in ipairs(items) do
                S2ML.Log("  " .. name)
            end
        end
    end

    S2ML.Log(string.format("=== PROBE DONE: %d entries across %d categories. Search UE4SS.log for details. ===",
        total,
        (function() local n=0; for _,v in pairs(results) do if #v>0 then n=n+1 end end; return n end)()))
end

-- =============================================
-- TARGETED INSPECT
-- =============================================

-- Inspect a single UObject: log its class, all readable properties, and UFunctions.
-- Useful to confirm property names before writing S2ML.Items.Register({ properties = {...} })
function S2ML.Probe.Inspect(obj)
    if not obj then
        S2ML.Log("Probe.Inspect: nil object passed.", "WARN")
        return
    end
    if not obj:IsValid() then
        S2ML.Log("Probe.Inspect: object is no longer valid.", "WARN")
        return
    end

    local fullName = "?"
    S2ML.SafeCall(function() fullName = obj:GetFullName() end)
    S2ML.Log("=== INSPECT: " .. fullName .. " ===")

    -- Class name
    S2ML.SafeCall(function()
        local cls = obj:GetClass()
        if cls and cls:IsValid() then
            S2ML.Log("  Class: " .. cls:GetFullName())
        end
    end)

    -- World location (if actor)
    S2ML.SafeCall(function()
        local loc = obj:K2_GetActorLocation()
        S2ML.Log(string.format("  Location: X=%.1f Y=%.1f Z=%.1f", loc.X, loc.Y, loc.Z))
    end)
end

-- Inspect the actor nearest to the player (within 300 units)
function S2ML.Probe.InspectNearest(className)
    className = className or "Actor"
    local PC = FindFirstOf("PlayerController")
    if not PC or not PC:IsValid() then return end
    local Pawn = nil
    S2ML.SafeCall(function() Pawn = PC.Pawn end)
    if not Pawn or not Pawn:IsValid() then return end
    local loc = nil
    S2ML.SafeCall(function() loc = Pawn:K2_GetActorLocation() end)
    if not loc then return end

    local nearest, dist = S2ML.World.FindNearest(className, loc)
    if nearest then
        S2ML.Log(string.format("Nearest '%s' at %.1f units:", className, dist))
        S2ML.Probe.Inspect(nearest)
    else
        S2ML.Log("Probe.InspectNearest: no '" .. className .. "' found nearby.", "WARN")
    end
end

-- =============================================
-- INVENTORY DUMP (player's current items)
-- =============================================

-- Log every item currently in the player's InventoryComponent.
function S2ML.Probe.DumpPlayerInventory()
    S2ML.Log("=== PLAYER INVENTORY DUMP ===")
    local PC = FindFirstOf("PlayerController")
    if not PC or not PC:IsValid() then
        S2ML.Log("  No PlayerController found.", "WARN"); return
    end
    local Pawn = nil
    S2ML.SafeCall(function() Pawn = PC.Pawn end)
    if not Pawn or not Pawn:IsValid() then
        S2ML.Log("  No Pawn found.", "WARN"); return
    end

    local IC = nil
    S2ML.SafeCall(function()
        local c = Pawn.InventoryComponent
        if c and c:IsValid() then IC = c end
    end)
    if not IC then
        S2ML.Log("  No InventoryComponent found on Pawn.", "WARN"); return
    end

    -- Try common collection getters
    local getterFns = { "GetAllItems", "GetItems", "K2_GetItems", "GetContents", "GetItemList" }
    for _, fn in ipairs(getterFns) do
        local ok, items = pcall(function() return IC[fn](IC) end)
        if ok and items then
            S2ML.Log("  (via " .. fn .. ")")
            for _, item in pairs(items) do
                local name = "?"
                S2ML.SafeCall(function() name = item:GetFullName() end)
                S2ML.Log("    " .. name)
            end
            S2ML.Log("=== END INVENTORY DUMP ===")
            return
        end
    end
    S2ML.Log("  Could not retrieve item list — no compatible getter found.", "WARN")
    S2ML.Log("=== END INVENTORY DUMP ===")
end

-- =============================================
-- KEYBINDS
-- =============================================

-- Ctrl+P : full class discovery scan
RegisterKeyBind(Key.P, { Key.LEFT_CONTROL }, function()
    S2ML.Log("Probe.Run triggered via Ctrl+P...")
    S2ML.Probe.Run()
end)

-- Ctrl+I : inspect nearest Actor
RegisterKeyBind(Key.I, { Key.LEFT_CONTROL }, function()
    S2ML.Log("Probe.InspectNearest triggered via Ctrl+I...")
    S2ML.Probe.InspectNearest("Actor")
end)

-- Ctrl+U : dump player inventory
RegisterKeyBind(Key.U, { Key.LEFT_CONTROL }, function()
    S2ML.Log("Probe.DumpPlayerInventory triggered via Ctrl+U...")
    S2ML.Probe.DumpPlayerInventory()
end)

S2ML.Log("S2ML_Probe loaded. Ctrl+P=scan  Ctrl+I=inspect nearest  Ctrl+U=inventory dump", "DEBUG")

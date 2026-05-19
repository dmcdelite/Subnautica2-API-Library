-- S2ML_Tech.lua
-- Technology tree / research unlock API for Subnautica 2.
-- STUB: TechManager class name unconfirmed — run S2ML.Probe.Run() to discover.
-- #16
--
-- USAGE (from another mod):
--   S2ML.Tech.Register({
--       id            = "com.author.mymod.deepdrill",
--       displayName   = "Deep Drill Module",
--       prerequisites = { "com.author.mymod.basicdrill" },
--       cost          = { { item = "Titanium", count = 5 }, { item = "Diamond", count = 2 } },
--       items         = { "com.author.mymod.deepdrill_item" },
--       recipes       = { "com.author.mymod.deepdrill_recipe" },
--       onUnlock      = function(id) S2ML.Notify.Message("Deep Drill unlocked!") end,
--   })
--
--   S2ML.Tech.Unlock("com.author.mymod.deepdrill")
--   S2ML.Tech.IsUnlocked("com.author.mymod.deepdrill")  --> true/false

S2ML.Tech = S2ML.Tech or {}

local Registry  = {}   -- id -> techDef
local Unlocked  = {}   -- id -> bool  (local cache, supplements game state)

-- Common manager class names to probe for
local MANAGER_CLASSES = {
    "TechTreeManager", "ResearchManager", "TechManager",
    "UnlockManager",   "KnowledgeManager", "PDAManager"
}

-- =============================================
-- INTERNAL: find the game's tech manager
-- =============================================
local function FindTechManager()
    for _, cls in ipairs(MANAGER_CLASSES) do
        local obj = nil
        S2ML.SafeCall(function() obj = FindFirstOf(cls) end)
        if obj and obj:IsValid() then
            S2ML.Log("Tech: using manager '" .. cls .. "'", "DEBUG")
            return obj
        end
    end
    return nil
end

-- =============================================
-- REGISTRATION
-- =============================================

-- Register a technology node.
--
-- techDef fields:
--   id            (string, required)  unique reverse-DNS id
--   displayName   (string)
--   description   (string)
--   prerequisites (table)   { "techId1", "techId2", ... }
--   cost          (table)   { { item = "ClassName", count = n }, ... }
--   items         (table)   item ids unlocked by this tech
--   recipes       (table)   recipe ids unlocked by this tech
--   onUnlock      (function(techId))  callback when unlocked
function S2ML.Tech.Register(techDef)
    if type(techDef) ~= "table" or not techDef.id then
        S2ML.Log("Tech.Register: techDef.id is required.", "WARN")
        return false
    end
    techDef.prerequisites = techDef.prerequisites or {}
    techDef.cost          = techDef.cost          or {}
    techDef.items         = techDef.items         or {}
    techDef.recipes       = techDef.recipes       or {}
    Registry[techDef.id]  = techDef
    S2ML.Log("Tech.Register: '" .. techDef.id .. "'", "DEBUG")
    return true
end

function S2ML.Tech.Get(id)    return Registry[id] end
function S2ML.Tech.ForEach(fn)
    for id, def in pairs(Registry) do S2ML.SafeCall(fn, id, def) end
end

-- =============================================
-- UNLOCK STATE
-- =============================================

-- Check whether a technology is currently unlocked for the local player.
-- Checks local cache first, then queries the game's tech manager.
function S2ML.Tech.IsUnlocked(techId)
    if Unlocked[techId] then return true end

    local TM = FindTechManager()
    if not TM then return false end

    local result = false
    local checkFns = { "IsUnlocked", "IsTechUnlocked", "HasTech",
                       "IsResearched", "K2_IsUnlocked" }
    for _, fn in ipairs(checkFns) do
        local ok, val = pcall(function() return TM[fn](TM, techId) end)
        if ok and val ~= nil then
            result = (val == true)
            break
        end
    end
    return result
end

-- Unlock a technology node, firing onUnlock callbacks and enabling its recipes.
-- Returns false if prerequisites are not met.
function S2ML.Tech.Unlock(techId)
    local techDef = Registry[techId]

    -- Check prerequisites
    if techDef then
        for _, prereq in ipairs(techDef.prerequisites) do
            if not S2ML.Tech.IsUnlocked(prereq) then
                S2ML.Log("Tech.Unlock: prerequisite '" .. prereq .. "' not met for '" .. techId .. "'", "WARN")
                return false
            end
        end
    end

    -- Try game's tech manager
    local nativeOk = false
    local TM = FindTechManager()
    if TM then
        local unlockFns = { "UnlockTech", "Unlock", "GrantTech",
                            "ResearchTech", "K2_UnlockTech", "AddKnowledge" }
        for _, fn in ipairs(unlockFns) do
            local ok = pcall(function() TM[fn](TM, techId) end)
            if ok then nativeOk = true; break end
        end
    end

    -- Cache locally regardless (so IsUnlocked() reflects it)
    Unlocked[techId] = true

    -- Fire onUnlock callback
    if techDef and techDef.onUnlock then
        S2ML.SafeCall(techDef.onUnlock, techId)
    end

    S2ML.Log("Tech.Unlock: '" .. techId .. "' " ..
             (nativeOk and "unlocked via game API." or "cached locally (game API not found; run Ctrl+P to find it)."))
    return true
end

-- Convenience: unlock all registered techs regardless of prerequisites.
-- Useful for debugging / cheat commands.
function S2ML.Tech.UnlockAll()
    for id in pairs(Registry) do
        Unlocked[id] = true  -- bypass prereq check
        local techDef = Registry[id]
        if techDef and techDef.onUnlock then
            S2ML.SafeCall(techDef.onUnlock, id)
        end
    end
    -- Also push to game manager
    local TM = FindTechManager()
    if TM then
        local unlockFns = { "UnlockTech", "Unlock", "GrantTech", "K2_UnlockTech" }
        for id in pairs(Registry) do
            for _, fn in ipairs(unlockFns) do
                if pcall(function() TM[fn](TM, id) end) then break end
            end
        end
    end
    S2ML.Log("Tech.UnlockAll: all registered technologies unlocked.")
end

S2ML.Log("S2ML_Tech loaded.", "DEBUG")

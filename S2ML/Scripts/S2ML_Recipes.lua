-- S2ML_Recipes.lua
-- Crafting recipe registration and injection into Subnautica 2's CraftingStation.
-- STUB: CraftingStation injection (InjectAll, AddRecipe) not yet implemented.
--       Recipes are registered and stored; injection fires when game APIs are confirmed.
-- #16
--   S2ML.Recipes.Register({
--       id          = "com.author.mymod.superbattery_recipe",
--       result      = "Battery",           -- item class name or registered item id
--       resultCount = 2,
--       ingredients = {
--           { item = "Titanium", count = 1 },
--           { item = "AcidMushroom", count = 2 },
--       },
--       craftStation = "CraftingStation",
--       craftingTime  = 3.0,
--   })
--
-- Injection fires automatically when the player opens any CraftingStation
-- (via the OnFabricatorOpened event already wired in S2ML_Events).

S2ML.Recipes = S2ML.Recipes or {}

local Registry  = {}   -- id -> recipeDef
local Injected  = {}   -- tostring(station) -> bool  (per-instance injection guard)

-- =============================================
-- REGISTRATION
-- =============================================

-- Register a crafting recipe.
--
-- recipeDef fields:
--   id           (string, required)  unique reverse-DNS id
--   result       (string, required)  item class name or S2ML item id
--   resultCount  (integer, default 1)
--   ingredients  (table)   { { item = "ClassName", count = n }, ... }
--   craftStation (string,  default "CraftingStation")  target station class
--   unlockTech   (string)  tech id that must be unlocked before this recipe appears
--   craftingTime (number,  default 2.0)  seconds
function S2ML.Recipes.Register(recipeDef)
    if type(recipeDef) ~= "table" or not recipeDef.id then
        S2ML.Log("Recipes.Register: recipeDef.id is required.", "WARN")
        return false
    end
    if not recipeDef.result then
        S2ML.Log("Recipes.Register: recipeDef.result is required.", "WARN")
        return false
    end
    if Registry[recipeDef.id] then
        S2ML.Log("Recipes.Register: '" .. recipeDef.id .. "' already registered.", "WARN")
        return false
    end
    recipeDef.resultCount  = recipeDef.resultCount  or 1
    recipeDef.craftStation = recipeDef.craftStation or "CraftingStation"
    recipeDef.craftingTime = recipeDef.craftingTime or 2.0
    recipeDef.ingredients  = recipeDef.ingredients  or {}

    Registry[recipeDef.id] = recipeDef
    S2ML.Log("Recipes.Register: '" .. recipeDef.id .. "'", "DEBUG")
    return true
end

function S2ML.Recipes.Get(id)    return Registry[id] end
function S2ML.Recipes.ForEach(fn)
    for id, def in pairs(Registry) do S2ML.SafeCall(fn, id, def) end
end

-- =============================================
-- INJECTION
-- =============================================

-- Attempt to inject all registered recipes into a CraftingStation actor.
-- Called automatically from the OnFabricatorOpened event.
function S2ML.Recipes._InjectIntoStation(station)
    if not station or not station:IsValid() then return end

    local key = tostring(station)
    if Injected[key] then return end
    Injected[key] = true

    -- Discover the recipe-managing component on this station
    local recipeComp = nil
    local compNames = {
        "RecipeComponent", "RecipeList", "CraftingComponent",
        "RecipeDatabase",  "RecipesComponent", "ItemCraftingComponent",
        "FabricatorComponent", "CraftingManager"
    }
    for _, name in ipairs(compNames) do
        S2ML.SafeCall(function()
            local c = station[name]
            if c and c:IsValid() then recipeComp = c end
        end)
        if recipeComp then
            S2ML.Log("Recipes: recipe component '" .. name .. "' found on station.", "DEBUG")
            break
        end
    end

    if not recipeComp then
        -- Station itself may handle recipes directly
        recipeComp = station
        S2ML.Log("Recipes: no dedicated component found — trying station directly.", "DEBUG")
    end

    -- Attempt injection for each registered recipe
    local injected, total = 0, 0
    for id, recipeDef in pairs(Registry) do
        total = total + 1

        -- Gate on tech unlock if specified
        if recipeDef.unlockTech and not S2ML.Tech.IsUnlocked(recipeDef.unlockTech) then
            S2ML.Log("Recipes: '" .. id .. "' locked behind tech '" .. recipeDef.unlockTech .. "'", "DEBUG")
            goto continue
        end

        -- Build a simple ingredient table compatible with common UE patterns
        local ingrTable = {}
        for _, ing in ipairs(recipeDef.ingredients) do
            table.insert(ingrTable, { ItemClass = ing.item, Amount = ing.count or 1 })
        end

        -- Try multiple function signatures
        local addFns = {
            "AddRecipe", "RegisterRecipe", "InjectRecipe",
            "K2_AddRecipe", "AddCraftingRecipe", "AppendRecipe"
        }
        for _, fn in ipairs(addFns) do
            local ok = pcall(function()
                recipeComp[fn](recipeComp,
                    recipeDef.result,
                    ingrTable,
                    recipeDef.resultCount,
                    recipeDef.craftingTime)
            end)
            if ok then
                injected = injected + 1
                S2ML.Log("Recipes: '" .. id .. "' injected via " .. fn, "DEBUG")
                break
            end
        end

        ::continue::
    end

    S2ML.Log(string.format("Recipes._InjectIntoStation: %d/%d recipes injected.", injected, total))
end

-- Subscribe to the fabricator-opened event (fired by S2ML_Events hook)
S2ML.Events.Subscribe("OnFabricatorOpened", function(station, player)
    S2ML.Recipes._InjectIntoStation(station)
end)

S2ML.Log("S2ML_Recipes loaded.", "DEBUG")

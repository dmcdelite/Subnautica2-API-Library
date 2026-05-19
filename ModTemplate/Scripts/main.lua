-- ModTemplate — example child mod using S2ML v3.0
-- Copy this folder to ue4ss/Mods/YourModName and enable in mods.txt

local S2 = require("S2MLBridge")
S2.RequireVersion("3.0.0")

local MOD_ID = "com.example.modtemplate"

S2.Items.Register({
    id          = MOD_ID .. ".superbattery",
    displayName = "Super Battery",
    baseClass   = "Battery",
    properties  = { Charge = 500 },
    onPickup    = function(pc)
        S2.Notify.Success("Super Battery acquired!")
    end,
})

S2.Recipes.Register({
    id          = MOD_ID .. ".superbattery_recipe",
    result      = MOD_ID .. ".superbattery",
    resultCount = 1,
    ingredients = {
        { item = "Battery", count = 2 },
        { item = "Titanium", count = 1 },
    },
    unlockTech  = MOD_ID .. ".superbattery_tech",
})

S2.Tech.Register({
    id          = MOD_ID .. ".superbattery_tech",
    displayName = "Super Battery Tech",
    onUnlock    = function(id)
        S2.Notify.Message("Super Battery blueprint unlocked!")
    end,
})

S2.Player.WhenReady(function(PC)
    S2.Notify.Hint("ModTemplate loaded — open a fabricator to see the new recipe.")
end)

S2.Events.Subscribe("OnFabricatorOpened", function(station, player)
    S2.Log("Fabricator opened!", "DEBUG")
end)

S2.Events.Subscribe("OnPlayerDeath", function(PC, loc)
    S2.Notify.Warning("You died! ModTemplate noticed.")
end)

S2.Log("ModTemplate v1.0.0 ready.")

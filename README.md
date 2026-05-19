# Subnautica2-API-Library
Nautilus-style UE4SS Lua API library for Subnautica 2 modding with UE4SS Lua.
## Features
- Event-driven mod API (`OnPlayerSpawned`, `OnFabricatorOpened`, `OnPlayerDeath`, and more)
- Modular systems for player, inventory, items, recipes, tech, world, sounds, notifications, save/load
- Runtime discovery tools (`S2ML.Probe`) for unstable Early Access class/function names
- Shared bridge loader for child mods (`S2MLBridge.lua`)
- Starter template mod (`ModTemplate`) for fast plugin creation
## Compatibility
- Subnautica 2 Early Access
- UE 5.6 (target runtime)
- UE4SS 3.0.1 (recommended)
## Installation
1. Copy these folders/files into your game UE4SS `Mods` directory:
   - `S2ML/`
   - `shared/S2MLBridge.lua`
   - `ModTemplate/` (optional, example mod)
2. Enable S2ML in `mods.txt`:
   ```txt
   S2ML : 1
Enable your own mod after S2ML:
S2ML : 1
YourMod : 1


Quick Start (Child Mod)---

-- YourMod/Scripts/main.lua
local S2 = require("S2MLBridge")
S2.RequireVersion("3.0.0")
S2.Player.WhenReady(function(PC)
    S2.Notify.Message("My mod loaded!")
    S2.Inventory.Give("Battery", 2)
end)


Keybinds and Console Commands
Keybinds
Ctrl+P -> run full discovery probe
Ctrl+I -> inspect nearest actor
Ctrl+U -> dump player inventory
Console (ConsoleHelper)
s2ml version
s2ml modules
s2ml give <item> [count]
s2ml save
s2ml tp <X> <Y> <Z>
s2ml depth
s2ml probe
s2ml inspect [class]
s2ml inv
s2ml reset
Project Layout
S2ML/
  API.md
  Scripts/
    main.lua
    S2ML_Core.lua
    S2ML_KnownClasses.lua
    S2ML_Engine.lua
    S2ML_Config.lua
    S2ML_Events.lua
    S2ML_Player.lua
    S2ML_Inventory.lua
    S2ML_Items.lua
    S2ML_Recipes.lua
    S2ML_Tech.lua
    S2ML_World.lua
    S2ML_Sounds.lua
    S2ML_Notify.lua
    S2ML_Save.lua
    S2ML_Assets.lua
    S2ML_Interact.lua
    S2ML_Time.lua
    S2ML_Probe.lua
shared/
  S2MLBridge.lua
ModTemplate/
  Scripts/
    main.lua
Documentation
Full API reference: S2ML/API.md
Version history: CHANGELOG.md
Early Access Notes
Subnautica 2 is still changing quickly. Some hooks and function names may shift between builds.

Recommended workflow after updates:

Load a save
Run Ctrl+P probe
Check UE4SS.log for /Script/Subnautica2 name changes
Update class/function candidates in S2ML_KnownClasses.lua
Contributing
Issues and bug reports are welcome.
When reporting bugs, include:

Game version/build
UE4SS version
S2ML version
Repro steps
Relevant UE4SS.log lines

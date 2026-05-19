# S2ML — Subnautica 2 Modding Library

**Version:** 3.0.0  
**Target:** Subnautica 2 Early Access · UE 5.6 · UE4SS 3.0.1  
**Role:** Nautilus-style Lua API for UE4SS mods (items, recipes, tech, player, world, events)

---

## Installation

S2ML ships as a UE4SS mod. Enable it in `ue4ss/Mods/mods.txt`:

```
S2ML : 1
YourMod : 1
```

**Load order:** S2ML must load before any mod that depends on it.

Optional debug mode: create `ue4ss/Mods/S2ML/S2ML_debug.flag` (empty file).

---

## Quick Start (child mod)

```lua
-- YourMod/Scripts/main.lua
local S2 = require("S2MLBridge")
S2.RequireVersion("3.0.0")

S2.Player.WhenReady(function(PC)
    S2.Notify.Message("Hello from my mod!")
    S2.Inventory.Give("Battery", 2)
end)

S2.Events.Subscribe("OnFabricatorOpened", function(station, player)
    -- Recipes auto-inject via S2ML.Recipes.Register
end)
```

Copy `ModTemplate/` as a starting point.

---

## Module Reference

### S2ML (Core)

| Function | Description |
|----------|-------------|
| `S2ML.Log(msg, level?)` | Log to UE4SS console (`INFO`, `DEBUG`, `WARN`) |
| `S2ML.SafeCall(fn, ...)` | pcall wrapper; returns values or `false, err` |
| `S2ML.GetPC()` | Cached local PlayerController |
| `S2ML.Init()` | Validates UE4SS APIs (called automatically) |
| `S2ML.RequireVersion("3.0.0")` | Version gate for child mods |
| `S2ML.Reset()` | Clear session caches and event listeners |
| `S2ML.GetModules()` | List loaded API module names |

### S2ML.Events

Pub/sub event bus + built-in game hooks.

| Event | Payload | When |
|-------|---------|------|
| `OnPlayerSpawned` | `PC` | Player pawn is valid (lobby-safe) |
| `OnPlayerDeath` | `PC, location` | Pawn lost during gameplay |
| `OnFabricatorOpened` | `station, player` | Crafting station interact |
| `OnStorageOpened` | `container, player` | Storage container interact |
| `OnGameSaved` | `slotName` | After successful save |
| `OnGameLoaded` | `slotName` | After successful load |

| Function | Description |
|----------|-------------|
| `Subscribe(event, fn)` | Add listener |
| `Unsubscribe(event, fn)` | Remove listener |
| `Once(event, fn)` | One-shot listener |
| `Clear(event)` | Remove all listeners |
| `Trigger(event, ...)` | Fire custom event |

### S2ML.Player

| Function | Description |
|----------|-------------|
| `GetPC()` | PlayerController |
| `GetPawn(PC?)` | Controlled pawn |
| `IsInGame(PC?)` | True if pawn exists |
| `GetLocation(PC?)` | `{ X, Y, Z }` world position |
| `GetRotation(PC?)` | `{ Pitch, Yaw, Roll }` |
| `GetDepth(PC?)` | Depth stat or Z-estimate |
| `GetStat(name, PC?)` | Discovery-based stat read |
| `Teleport(loc, PC?, sweep?)` | Move player |
| `WhenReady(fn)` | Callback after spawn (lobby-safe) |
| `NormalizeVector(v)` | FVector table normalizer |
| `Distance(a, b)` | 3D distance |

### S2ML.Inventory

| Function | Description |
|----------|-------------|
| `GetPlayerComponent()` | Player InventoryComponent |
| `Give(item, count?, target?)` | Add item to inventory |
| `Remove(item, count?, target?)` | Remove/consume item |
| `GetCount(item, target?)` | Item quantity |
| `Has(item, count?, target?)` | Boolean check |
| `GetAll(target?)` | All items in container |
| `GetContainersNear(loc, radius?)` | Nearby StorageContainers |

### S2ML.Items

Register custom items and patch CDO defaults.

```lua
S2ML.Items.Register({
    id          = "com.author.myitem",
    displayName = "My Item",
    baseClass   = "Battery",       -- /Script/Subnautica2 class
    properties  = { Charge = 999 },
    stackSize   = 1,
    onPickup    = function(pc) end,
    onLoad      = function(def) end,
})
```

| Function | Description |
|----------|-------------|
| `Register(itemDef)` | Register item |
| `Get(id)` / `IsRegistered(id)` | Lookup |
| `Give(idOrClass, count?)` | Delegates to Inventory |
| `GetCDO(className)` | Class Default Object |
| `ApplyProperties(obj, props)` | Patch UObject properties |
| `SpawnPickupAtPlayer(className)` | World pickup fallback |

### S2ML.Recipes

```lua
S2ML.Recipes.Register({
    id          = "com.author.recipe",
    result      = "Battery",
    resultCount = 1,
    ingredients = { { item = "Titanium", count = 2 } },
    unlockTech  = "com.author.tech",
    craftStation = "CraftingStation",
})
```

Auto-injects when player opens a fabricator (`OnFabricatorOpened`).

### S2ML.Tech

```lua
S2ML.Tech.Register({ id = "...", prerequisites = {}, onUnlock = fn })
S2ML.Tech.Unlock(id)
S2ML.Tech.IsUnlocked(id)
S2ML.Tech.UnlockAll()  -- debug
```

### S2ML.World

| Function | Description |
|----------|-------------|
| `SpawnActor(class, loc, rot?)` | Spawn at location |
| `SpawnAtPlayer(class, offsetZ?)` | Spawn above player |
| `GetActorsInRadius(class, origin, radius)` | Sorted nearby actors |
| `FindNearest(class, origin)` | Nearest actor + distance |
| `TeleportTo(actor, loc)` | Move actor |
| `DestroyActor(actor)` | Safe destroy |
| `DestroyAllOfClass(className)` | Bulk destroy |

### S2ML.Notify

| Function | Description |
|----------|-------------|
| `Message(text, duration?)` | Multi-channel notification |
| `ScreenMessage(text, duration?, color?)` | On-screen debug message |
| `Success / Warning / Error(text)` | Colored shortcuts |
| `Hint(text)` | Cyan tutorial-style |
| `Queue(messages, delayMs?)` | Sequential messages |

### S2ML.Sounds

`Play2D(name)`, `PlayAtLocation(name, loc)`, `PlayAttached(name, actor)`, `PlayAtPlayer(name)`

### S2ML.Save

| Function | Description |
|----------|-------------|
| `Save(slotName?)` | Save game (console or native API) |
| `Load(slotName?)` | Load game |
| `AutoSave(intervalSeconds?)` | Periodic autosave loop |

### S2ML.Assets

| Function | Description |
|----------|-------------|
| `Load(path)` | LoadAsset / StaticFindObject with cache |
| `Find(pathOrName)` | Alias for Load |
| `GetCDO(className)` | Class default object |

### S2ML.Engine

UE helper wrappers: `GetGameplayStatics()`, `GetKismetSystemLibrary()`, `GetWorld()`, `PrintString(text, color?, duration?)`, `StaticFind(path)`.

### S2ML.Config

Key=value config files: `Load(path, defaults?)`, `Save(path, cfg)`, `Get(path, key, default)`, `Set(path, key, value)`.

### S2ML.Time

| Function | Description |
|----------|-------------|
| `Delay(ms, fn)` | One-shot delayed callback |
| `Repeat(intervalMs, fn, maxRuns?)` | Repeating timer; returns id |
| `Cancel(timerId)` | Stop repeating timer |
| `OnGameThread(fn)` | ExecuteInGameThread wrapper |
| `GameSeconds()` | World time if available |

### S2ML.Interact

`RegisterCraftingHook(event?)`, `RegisterStorageHook(event?)`, `RegisterAll()`

### S2ML.Probe (discovery)

| Keybind | Action |
|---------|--------|
| Ctrl+P | Full class scan → UE4SS.log |
| Ctrl+I | Inspect nearest actor |
| Ctrl+U | Dump player inventory |

Console: `s2ml probe`, `s2ml inspect [class]`, `s2ml inv`, `s2ml reset`

### S2ML.KnownClasses

Central registry of class paths and function name candidates. Update after probing.

---

## Console Commands

```
s2ml version
s2ml modules
s2ml give Battery 5
s2ml save
s2ml tp 0 0 -1000
s2ml depth
s2ml probe
s2ml inspect StorageContainer
s2ml inv
s2ml reset
```

---

## Discovery Workflow

Many game APIs are discovered at runtime (EA builds change). Before hardcoding:

1. Load a save in-game
2. Press **Ctrl+P** → search `UE4SS.log` for `/Script/Subnautica2` classes
3. Press **Ctrl+U** → verify inventory function names
4. Enable **SaveFunctionFinder** → `savescan s2` for save APIs
5. Update `S2ML_KnownClasses.lua` with confirmed names

---

## Architecture

```
mods.txt
  └── S2ML (loads first — global S2ML table)
        ├── Core / KnownClasses / Engine
        ├── Events (hooks ClientRestart, Crafting, Death)
        ├── Player / Inventory / Items / Recipes / Tech
        ├── World / Sounds / Notify / Save / Assets
        ├── Interact / Time / Probe
        └── shared/S2MLBridge.lua (require shim for child mods)
  └── YourMod (require S2MLBridge, subscribe events, register content)
```

---

## Semver Policy

- **Major:** Breaking API changes to public module functions
- **Minor:** New modules or backward-compatible features
- **Patch:** Bug fixes, new KnownClasses entries

Child mods should call `S2.RequireVersion("3.0.0")` at startup.

---

## Limitations (EA)

- Inventory/tech/save function names use discovery fallbacks until confirmed in-game
- Recipe injection depends on CraftingStation API shape
- HUD notifications fall back to ClientMessage / on-screen debug text
- Sound asset paths must be verified per build

Use **S2ML.Probe** and **SaveFunctionFinder** to harden APIs as the game updates.

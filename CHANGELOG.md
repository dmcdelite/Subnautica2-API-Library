# Changelog

All notable changes to this project are documented in this file.

## v3.1.0 - 2026-05-19

### 50 upgrades and improvements

1. Bumped S2ML version to `3.1.0`.
2. Added structured log levels (`TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`).
3. Added timestamped log output.
4. Added runtime log level setter (`S2ML.SetLogLevel`).
5. Added `S2ML.WarnOnce` to prevent repeated spam warnings.
6. Added SafeCall argument type validation.
7. Added `S2ML.IsValid` safe UObject validity checker.
8. Added `S2ML.DeepCopy` utility for nested tables.
9. Added `S2ML.MergeTables` deep merge helper.
10. Added `S2ML.Clamp` numeric helper.
11. Added `S2ML.WrapContext` for safe hook unwrapping.
12. Added force-refresh support to `S2ML.GetPC`.
13. Added reusable required API status cache.
14. Added `S2ML.CheckRequiredAPIs` helper.
15. Added `S2ML.IsReady` lifecycle check.
16. Added semantic version comparator (`S2ML.CompareVersion`).
17. Added `S2ML.NewId` unique id generator helper.
18. Reset now clears one-shot warning cache.
19. Reset now clears time timers via `CancelAll`.
20. Reset now clears config cache via `Config.Invalidate`.
21. Events now validate callback type on subscribe.
22. Events now return listener id from `Subscribe`.
23. Added `Events.UnsubscribeById`.
24. Added `Events.ClearAll`.
25. Added `Events.WaitFor` with timeout support.
26. Added `Events.Count`.
27. Added `Events.GetEventNames`.
28. `Events.Trigger` now uses snapshot iteration for safe mutation.
29. Event callback errors now log with event name context.
30. Added `OnClientRestart` event trigger.
31. Hook context unwrapping now uses `S2ML.WrapContext`.
32. Death detection now tracks last known player location.
33. Fixed death event firing when pawn transitions valid -> invalid.
34. Added player vector constructors (`NewVector`, `AddVector`, `ScaleVector`).
35. Added player right/up vector helpers.
36. Added player speed helper (`GetSpeed`).
37. Added underwater helper (`IsUnderwater`).
38. Added forward teleport helper (`TeleportForward`).
39. Added surface teleport helper (`TeleportToSurface`).
40. Added player name helper (`GetName`).
41. Added cached location helper (`GetCachedLocation`).
42. Added `Player.WaitForSpawn` timeout-aware readiness callback.
43. Added timer id return from `Time.Delay`.
44. Added `Time.CancelAll`.
45. Added `Time.IsActive`.
46. Added millisecond timers (`Time.NowMs`, `Time.UptimeMs`).
47. Added `Time.Debounce`.
48. Added `Time.Throttle`.
49. Added inventory batch/utility ops (`GiveMany`, `EachItem`, `CountAll`, `FindNearestContainer`, `Transfer`, `DropAtPlayer`).
50. Added expanded console commands in `main.lua` (`debug`, `loglevel`, `whereami`, `tpf`, `api`, `events`) plus module load stats.

## v3.0.0 - 2026-05-19

- Expanded S2ML into a full UE4SS Lua API library for Subnautica 2.
- Added new modules: `KnownClasses`, `Engine`, `Player`, `Config`, `Save`, `Assets`, `Interact`, and `Time`.
- Hardened `Core`, `Events`, `Inventory`, and `Items` integration.
- Added `S2MLBridge.lua` for child-mod `require()` support.
- Added `ModTemplate` starter mod for dependency and API usage examples.
- Added `S2ML/API.md` comprehensive API documentation.


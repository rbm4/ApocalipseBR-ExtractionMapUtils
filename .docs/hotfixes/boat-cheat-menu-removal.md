# Boat cheat menu removal

Status: implemented; awaiting in-game validation.

## Symptom and cause

The bundled AquasarYatchClub mechanics UI included cheat menus on parts and on
the window background. The access check used the global mechanics cheat flag or
an access-level comparison against `"None"`. Its callbacks sent built-in
`vehicle` commands for keys, hotwiring, repairs, rust, condition, container
contents and vehicle removal. A separate debug scenario enabled right-click
boat spawning. Hiding these entries alone would leave their callbacks callable.

## Fix

Applied to both `common` and `42.17` under `AquasarYatchClub/media/lua`
(with the version folder before `media`):

- `client/Boats/ISUI/ISBoatMechanics.lua`: delete both cheat menu paths, their
  callbacks, modal callbacks and cheat toggle. Remove global-cheat bypasses for
  install/uninstall availability and rename materials. Stop resetting vanilla
  `ISVehicleMechanics.cheat` when this UI loads.
- `client/Boats/ISUI/ISBoatPartMenu.lua`: delete `onDebugFill`; always prepare
  required items for installing, uninstalling and renaming. Replace the existing
  `0.099F` literal with the equivalent Lua number `0.099` so the file can also be
  compiled by the regression harness.
- `server/Boats/Boats.lua`: remove the global-cheat shortcut from propeller
  install/uninstall checks.
- `client/Boats/ISUI/ISBoatMenu.lua`: remove the unused mechanics-anywhere debug
  option lookup.
- Delete `client/_Debug/boatClickSpawn.lua` and
  `client/_Debug/AquatsarYachtsDebug.lua`, including their spawn handler and
  debug scenario registration.

No new configuration switch enables these menus. Normal boat gameplay actions
remain. Engine methods with debug/cheat names used for legitimate vehicle
conversion, state restoration and the manual starter remain necessary.

The removed callbacks targeted vanilla `vehicle` commands; they were not custom
Aquatsar server cheat handlers. This patch removes the bundled mod's cheat entry
points. It does not change vanilla server command permissions, native admin
tools, or other mods. It is not a security audit of normal Aquatsar commands.

## Validation

Run from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/boat-cheats.lua
```

Result: PASS for `common` and `42.17`. The harness compiles all changed runtime
files, loads mechanics/part/server modules with mocked engine boundaries, checks
that cheat callbacks are absent, and exercises both right-click paths with admin,
debug and global-cheat state enabled. It also verifies normal action queuing,
required-item preparation and running/stopped-engine propeller restrictions.
The original implementation fails these callback/menu and bypass regressions.

No live client/server session was run. After distributing the updated mod and
restarting the server and clients, validate mechanics menus, normal boat
maintenance, launching/loading and manual-starter behavior in Build 42.17.

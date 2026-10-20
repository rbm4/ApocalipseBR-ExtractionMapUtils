# Lobby construction protection

Status: implemented locally; awaiting Build 42 dedicated-server/client validation.

With `ApocExtractionMapUtils.LobbyEnabled=true`, player construction is blocked
on the same configured footprint and Z as [lobby removal protection](../hotfixes/lobby-disassembly-protection.md).
The rule has no faction/admin exemption and remains active after exits or the
perimeter are released. It uses shared `LobbySettings.lua`; no new option or
dependency is required. Outside the footprint, or with the lobby disabled, the
native behavior and return values are preserved.

## Behavior and ownership

`shared/ApocExtractionMapUtils_LobbyConstruction.lua` owns construction guards.
`LobbyProtection.lua` exposes `isProtectedPosition(x,y,z)` alongside its square
helper so unloaded/missing squares cannot evade coordinate checks.

- `ISBuildingObject.tryBuild` rejects protected placement before native build
  setup/ingredient processing, including its direct skip-action path.
- `ISBuildIsoEntity.isValid` rejects protected previews and Java server build
  validation. Its `create` method is also guarded before native creation.
- `Actions.build` rejects server construction dispatch, including legacy classes
  that override the base building validity method.
- `ISMultiStageBuild.isValid/complete` reject wall/frame upgrades using the
  actual target object's square, before stage execution/material consumption.
- The client/SP `ISBuildAction` guard rejects validity and start; blocked SP
  completion calls native `stop` for cleanup instead of invoking its creating
  `perform`. The dedicated server does not load this client-only class.

B42 entity footprint checks use `getFace()` script dimensions and occupied or
blocking tile offsets, including Z layers. A build anchored outside is rejected
if any occupied entity tile overlaps the lobby. Empty offsets are ignored and
checks do not depend on grid-square loading. A legacy class without entity face
metadata is checked at its anchor; arbitrary legacy/custom multi-tile offsets
are not inferred.

This feature concerns construction and upgrades. Moving existing furniture into
the lobby, inventory crafting/dropping, decoration actions such as painting,
other elevations, custom creation paths and raw object-add packets are outside
these guards. Existing removal restrictions and authorized server/RCON perimeter
creation/removal retain their behavior.

## Verified native boundaries

Local vanilla `media/lua/` sources:

- `client/BuildingObjects/TimedActions/ISBuildAction.lua`: `start` submits
  `createBuildAction`; SP `perform` also creates directly.
- `server/BuildingObjects/ISBuildingObject.lua`: `tryBuild` sets up the build
  action and build-panel ingredients, or creates directly for skip-action cursors.
- `server/BuildingObjects/ISBuildIsoEntity.lua`: face dimensions and offsets,
  `isValid` and `create`; creation validates before material consumption.
- `shared/ActionManager.lua`: Java `OnProcessAction("build", ...)` dispatches
  through the current `Actions.build` table entry and invokes the cursor's create.
- `shared/BuildingObjects/TimedActions/ISMultiStageBuild.lua`: `complete` applies
  the stage and consumes materials; `perform` owns presentation/queue cleanup.

Decompiled `zombie/core/BuildAction.java`: the server reconstructs the Lua cursor,
calls its `isValid(square)` and emits the build event on completion. This is why
client-only timed-action guards are insufficient.

## Verification

Run from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-construction.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

All passed on 2026-10-20. The construction harness also runs the removal harness.
Tests mock engine boundaries and cover client/server/SP installation, early and
completion denial, upgrades, multi-tile/layer overlap, missing squares, preserved
cancellation/returns, duplicate loading and permitted outside/disabled behavior.

No live game test was run. Install matching files on clients/server and restart.
Try walls, floors, stairs, double doors, furniture construction and wall upgrades
inside/on the east/south boundary, plus an outside-anchored entity that overlaps.
Check rejection without creation/material loss; repeat outside, with the lobby
disabled, in SP, and after RCON perimeter release. Rendering, native crafting
reservation cleanup and actual build packet synchronization need this validation.

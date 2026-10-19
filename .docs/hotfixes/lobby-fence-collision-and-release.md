# Lobby fence collision and exit removal

Status: implemented in 0.2.1; awaiting dedicated-server/client verification.
Affected feature: [Lobby perimeter and RCON release](../features/lobby-perimeter.md).

## Symptom and cause

The user reported that players could climb over the original metal perimeter
and walk through the closed door graphics on their running server.

The local decompiled `IsoPlayer.canClimbOverWall()` has a wall-climbing path
independent of `IsoThumpable.setIsHoppable(false)`. It rejects `CantClimb`.
The old `constructedobjects_01_48/49` tile definitions have wall collision but
lack `CantClimb`, so ordinary wall climbing was not disabled.

The old door graphics `fixtures_doors_01_68/69` have `doorW/doorN` and attachment
flags, without the fence wall collision properties. The implementation treated
these as non-door barriers. The reported walk-through behavior is consistent
with using door graphics outside the normal door mechanism. This was not
reproduced in a local live-server session; this change removes that mechanism.

## Fix and migration

- All 286 edges now use the vanilla military/barbed fence sprites
  `fencing_01_88` (N) and `fencing_01_90` (W), including the six exit positions.
- Parse evidence from the installed `newtiledefinitions.tiles` confirms
  `CantClimb` + `WallNTrans/WallWTrans`, with no short/tall hopping flags. The
  Java loader converts these wall properties to directional collision.
- Startup validates the actual runtime sprite flags before changing saved state.
  Climbable, passable or wrong-direction substitutes disable initialization.
- `ReleaseExits` despawns the six owned exit fences through server-authoritative
  native removal. Maintenance never respawns released exits. `OpenDoors` is a
  compatibility alias with the same token and release latch.
- Migrate the known 0.2.0 default asset signature only at unchanged bounds/count.
  Keep saved positions and release state. Queue replacement/removal of old
  owned assets, preserving migration signatures across subsequent restarts for
  still-unloaded chunks. Keep unrelated map objects intact.
- Preserve the maximum HP/protection, tick count/time budgets, finite deduped
  work queue, load hooks and slow recovery scans.

Changed runtime files are the core server `ApocExtractionMapUtils_Lobby.lua`,
`ApocExtractionMapUtils_LobbyConfig.lua` and `42/mod.info`. Tests are in
`tests/lobby-perimeter.lua`; packaging and operating documentation were updated.

## Validation

The installed tile file was read using the decompiled loader's little-endian
integer/newline string format and parsed to its exact end. Source inspection
confirmed the collision-property conversions and `CantClimb` check.

Commands run successfully:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

Regression assertions cover the required sprite flags, no door creation,
six removals with zero replacement additions, gaps remaining empty through
scan/load/restart, unloaded release, and both closed/released legacy migration
after another restart. RCON parser/dispatcher integration uses the actual local
extension. Engine/file boundaries remain mocked; no live multiplayer test was
run. Restart server and clients, confirm old assets are replaced as chunks load,
try walking/climbing at every side and corner, release via RCON, then verify six
single-tile gaps persist after saving/restarting and ordinary cars cannot pass.

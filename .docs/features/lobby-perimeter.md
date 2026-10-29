# Lobby perimeter and RCON release

Status: updated in 0.2.2; awaiting Build 42 dedicated-server/client validation.
Version 0.3.0 adds [PostgreSQL event activation](postgresql-event-control.md):
the scheduled event removes the entire perimeter; the manual RCON behavior
documented here still removes the six exits.
Sandbox bounds, default-on switches and 0..3 usable doors are documented in
[lobby sandbox configuration](lobby-sandbox-configuration.md). The descriptions
below of a continuous fence apply with `LobbyDoorCount=0`; the default is now 3.

Related foundation: [Login placement and map visibility](lobby-and-map-visibility.md).
Source investigation: [World-control APIs](../reports/2026-10-19-lobby-world-control-api-investigation.md).

## Behavior

When `SandboxVars.ApocExtractionMapUtils.LobbyEnabled=true`, the dedicated server builds a non-climbable military/barbed-fence perimeter around the inclusive interior
X=14260..14321, Y=11812..11892, Z=0. The supplied corners are normalized so their
order does not matter. This encloses 62 by 81 tiles with 286 identical fence edge
objects, including six single-tile removable exits. North/west edges belong to the square
at that coordinate; east/south edges occupy the neighbouring square, so the
east wall is stored at X=14322 and the south wall at Y=11893.

Exit positions are randomly selected once and saved in global ModData under
`ApocExtractionLobby`. They avoid corners and have at least two intervening wall
tiles along an edge. Positions stay fixed across chunk reloads and normal save
restarts. Single-tile openings are intended for pedestrians and keep ordinary
cars from entering/leaving. Actual collision, diagonal corners, vehicle sizes,
and the chosen location's terrain still need in-game verification.

All assets have maximum/current health 2147483647, the maximum positive Java
int accepted by the inspected setter/save/network fields. They cannot normally
be thumped, dismantled, climbed or barricaded. Use the intended server setting
that disables sledgehammers. These flags address normal gameplay; administrative
deletion, fire, vehicle physics, animal damage, other mods and modified clients
are not a universal indestructibility guarantee. Missing assets are repaired
when the square loads or during the slow scan.

Version 0.2.2 additionally blocks world-object scrap/disassembly and thumpable
dismantling on every interior tile and the east/south perimeter squares at the
configured Z. This applies to all players, regardless of faction or role, and
continues after exit release. It covers native welding scrap actions and
already-queued actions at completion, on both client and server. Target object
positions are checked, not the player's position or ownership marker. Outside
the protected footprint, native checks still apply. The follow-up removal hotfix
also blocks furniture/floor pickup, sledgehammer destruction and ground-material
shoveling. Placement, rotation, repair and inventory-item disassembly remain
available. [Construction protection](lobby-construction-protection.md) additionally
blocks new builds and wall upgrades. Moving existing furniture remains available.
These rules cover the configured Z only, not every building floor.
See [the disassembly hotfix](../hotfixes/lobby-disassembly-protection.md) for
verified action paths, tests and limitations. Authorized RCON fence removal
continues to use native world removal without going through these player actions.

Every segment, including the exits, uses `fencing_01_88` (north) or
`fencing_01_90` (west). The installed vanilla tile definitions give these sprites
`CantClimb` and `WallNTrans`/`WallWTrans`; the loader converts those wall properties
to directional collision. Both short/tall hoppable flags are absent. Startup
validates directional collision plus `CantClimb` and rejects either hoppable
flag family. `setIsHoppable(false)` alone does not stop normal wall climbing.

With `LobbyDoorCount=0` there are no door sprites or door-state transitions.
With 1..3, the corresponding exit segments are usable doors and maintenance
preserves their open state. The release command
despawns only the six designated fence segments through native server removal.
The result is 280 fence objects and six single-tile pedestrian gaps. Rescans,
repairs and chunk reloads deliberately leave those gaps empty. Other fence
segments retain their protection and repair behavior.

The release latch is saved with the layout. With an unpatched/older engine, a
normal restart of an already released save leaves exit gaps empty. With the
updated 42.21.0 event bridge, the lobby automatically recloses when the cached
manager agenda confirms there is no active operation, including while another
operation is queued. See [automatic reconstruction](../hotfixes/lobby-fence-between-operations.md). The module does not implement zombie clearance, an event
lifecycle, server-authoritative player relocation or forced chunk streaming.
Existing map objects are preserved; the builder does not clear buildings,
trees, parked vehicles or other obstructions. Verify the perimeter and all six
exit positions on the target map before admitting players.

## Installation and command

Enable `ApocalipseBrRCONextension` on both server and clients before the core
`ApocalipseBR-ExtractionMapUtils` mod. The core's `42/mod.info` declares the exact
dependency ID; the extension is installed separately, not copied into this
repository. Minimum version is now 42.13.0, matching that dependency.

On server startup with unreleased exits, the core generates a one-use UUID and
writes it to the server's Lua cache:

```text
<server Zomboid cache>/Lua/ApocExtractionLobby-<server-name>-open-token.txt
```

The server log identifies that filename without printing the token. Unsafe
characters in the server name are replaced with underscores. Read the current
file on the server and send the following through RCON, substituting the token
and a unique request ID:

```text
servermsg ##APOCBR_RCON##ExtractionLobby##ReleaseExits##lobby-release-001##<TOKEN>
```

The extension receives `servermsg` on connected clients and relays it to the
server, then waits its two-second duplicate-relay grace period before dispatch.
**At least one connected client with the extension is required.** With an empty
server, this transport cannot deliver the command; retry after a client joins
with a new request ID. No lobby coordinates or object IDs are accepted from the
payload: the only operation is releasing the six configured exits. The former
`OpenDoors` command remains an alias of `ReleaseExits`, so existing integrations
now remove exit fences instead of opening doors. The token filename is unchanged.

This extension's relay callback is not proof of RCON authentication. Ordinary
clients can forge relay packets. The server-local token authorizes the fixed
release operation and is consumed before release. It is never put in global or
object ModData (clients can request global ModData by name). Broadcast receivers
can see the token only when release is already being requested; reuse after
consumption cannot initiate a later release. Do not reuse this mechanism for
arbitrary payload-bearing or repeatable privileged commands without a separate
authentication design. Restarting an unreleased server generates a new token.

On acceptance the token file reads `consumed` and the log says `ReleaseExits
accepted`. File creation/verification/consumption failures leave the release
disabled/closed. Invalid-token payloads are rejected without logging their
contents. The extension has no response channel to RCON, so use the server log
and actual exit gaps to confirm execution. Repeating the command after release
has no effect.

## Configuration and work budget

The master sandbox setting `ApocExtractionMapUtils.LobbyEnabled` defaults to
`true` in sandbox defaults. When absent during Lua startup or explicitly disabled, startup does not validate sprites, build a plan,
read/write lobby ModData, generate tokens, load/subscribe the RCON relay, or
subscribe to scheduled events. Tick/load callbacks return immediately and direct
release calls refuse the request. Disassembly wrappers delegate to native behavior.
Relocation additionally requires `RelocateOnLogin=true`. Only map reveal is on
by default; zombie money drops have a separate disabled-by-default switch.

Restart the server and reconnect clients after changing the master switch.
Disabling stops control; it does not delete saved fences, reset their native
flags, consume existing token files, or reset the saved release state. Remove
existing assets deliberately before retiring a previously active lobby.

Configure bounds, floor and door count in the sandbox settings. Advanced sprite
and performance settings remain in `common/media/lua/shared/ApocExtractionMapUtils_LobbySettings.lua`.
Restart clients/server after changes. The existing server
`ApocExtractionMapUtils_LobbyConfig.lua` now forwards to the shared settings so
older module requires continue to work. Server enforcement uses the server's
own configuration. These bounds remain independent of sandbox login coordinates.

| Configuration | Default | Meaning |
| --- | --- | --- |
| X1/Y1, X2/Y2, Z | Supplied bounds, Z=0 | Inclusive interior tiles. |
| ExitCount | 6 | Clamped to 0..6, selected once per saved layout. Replaces DoorCount. |
| MaxEdgesPerTick | 4 | Hard count cap; configurable from 1 to 16. |
| MaxTickMilliseconds | 2 | Stops starting more edge operations after elapsed budget. |
| RescanMilliseconds | 60000 | Recheck all edges, spreading operations across ticks. Minimum 10000. |
| ExitCheckMilliseconds | 2000 | Recheck only exits. Minimum 1000. Replaces DoorCheckMilliseconds. |
| FenceNorth / FenceWest | fencing_01_88 / fencing_01_90 | N/W military fence sprites; validated collision and climb flags. |

Initialization creates a small plan and enqueues edges; it does not mutate the
world in one startup loop. Each tick processes at most four edges, checking the
elapsed time between operations. One native operation cannot be preempted, so
the two-millisecond budget is not a hard bound on an individual engine call.
Unloaded/null squares are skipped once, without repeatedly retrying them each
tick. `LoadGridsquare` only queues matching edges; placement happens later.
Repeated callbacks are deduplicated, no square references are retained, and the
finite plan is capped at 4096 edges. A mostly unloaded default lobby costs 286
lookups per minute plus six exit lookups per two seconds, spread across ticks.
Errors log once per failing edge until it succeeds and retry only on a later
load/check/scan. Intact objects are not continually recreated or rebroadcast.

The known default 0.2.0 perimeter upgrades automatically at identical bounds
and exit count. Its saved door positions become exit positions and its release
latch is preserved. Owned old walls/doors are replaced as their squares load,
using the same tick budgets. Legacy ownership signatures remain saved so an old
chunk loaded after another restart is still repaired. A released old save has
its old doors removed rather than replaced. Unrelated map objects are preserved.
No world reset or manual cleanup is needed for this upgrade.

Other changes to bounds, exit count or sprites on an existing save are rejected
rather than silently relocating the perimeter. Deliberately remove the old owned
assets and migrate/remove its `ApocExtractionLobby` state while the server is
stopped or through trusted administrative tooling before changing the layout.
Disabling this feature stops its work; it does not delete existing assets.

## Engine paths and persistence

- Server hooks: `OnServerStarted`, `LoadGridsquare`, and `OnTick`. The dedicated
  server updates `IngameState`, which dispatches `OnTick`.
- `IsoThumpable` is exposed by `LuaManager`; its constructors accept the square,
  sprite names, orientation and Lua table. Save/load persist the open state,
  flags, health, sprites and mod data (`IsoThumpable.java:438-640`).
- `square:AddSpecialObject()` registers the object in the normal/special lists,
  enters the world and updates neighbours, collision, pathfinding and regions
  (`IsoGridSquare.java:5855`). `object:transmitCompleteItemToClients()` sends the
  native `AddItemToMap` packet (`IsoObject.java:4811`). Normal world saves own
  chunk persistence; the mod does not force a synchronous world save.
- Exit removal uses `square:transmitRemoveItemFromSquare()` with its native
  server removal/network/collision path. It creates no replacement door object.
- Like the inspected BrushToolSaveFix, mutation happens on the server and marks
  the square's zone as having construction. Its movable-item pipeline is not
  required for purpose-built `IsoThumpable` walls. Unlike its brush helper,
  the lobby does not try to create squares for missing chunks.
- Fence properties were read from the complete installed
  `media/newtiledefinitions.tiles` (2,972,120 bytes). The Java loader's
  `WallNTrans`/`WallWTrans` conversions live in `IsoWorld.java:897/924`.
  `IsoPlayer.canClimbOverWall()` checks `CantClimb` (`IsoPlayer.java:5579`).

## Files and verification

Runtime files: `shared/ApocExtractionMapUtils_LobbySettings.lua`,
`shared/ApocExtractionMapUtils_LobbyProtection.lua`,
`server/ApocExtractionMapUtils_LobbyConfig.lua` (compatibility forwarder),
`server/ApocExtractionMapUtils_Lobby.lua`, and `42/mod.info`.
Packaging descriptions and the root README reflect the dependency/feature.

Executed successfully on 2026-10-19:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

The lobby harness mocks engine/file boundaries and verifies normalized bounds,
286 fences before release and 280 after, six separated exits, fixed saved positions, startup deferral, missing
chunks, deduplication, count/time budgets, object protection, idempotency, saved
release, late-load release without fence respawning, token validation/consumption/replay, file failures,
invalid configuration and duplicate module loading. Regressions cover rejection
of climbable, passable and incorrectly oriented sprites, and closed/released
0.2.0 migration with old assets loading after a further restart. Its optional argument loads
the actual local RCON extension shared API and dispatcher, verifying parsing,
relay/grace/dedup behavior against the lobby handler. Without that argument it
runs the standalone engine-boundary harness only. Existing regression harnesses
also pass. Documentation links and whitespace were reviewed.

Not tested live: native serialization/packet handling, server restart after a
world save, client late join and chunk reload, collision/pathfinding/vehicles,
sprite rendering/corners, actual RCON delivery, fire/destruction interactions,
and measured server tick costs. Verify these on the intended B42 dedicated
server before relying on the lobby for an event. In particular, players should
not enter the lobby until all perimeter chunks have loaded and been populated.

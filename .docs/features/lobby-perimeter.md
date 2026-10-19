# Lobby perimeter and RCON release

Status: implemented in 0.2.0; awaiting Build 42 dedicated-server/client validation.
Related foundation: [Login placement and map visibility](lobby-and-map-visibility.md).
Source investigation: [World-control APIs](../reports/2026-10-19-lobby-world-control-api-investigation.md).

## Behavior

The dedicated server builds a metal-wall perimeter around the inclusive interior
X=14260..14321, Y=11812..11892, Z=0. The supplied corners are normalized so their
order does not matter. This encloses 62 by 81 tiles with 286 edge objects: 280
walls and six single-tile door positions. North/west edges belong to the square
at that coordinate; east/south edges occupy the neighbouring square, so the
east wall is stored at X=14322 and the south wall at Y=11893.

Door positions are randomly selected once and saved in global ModData under
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

Before release, each door uses the metal-door graphics on an `IsoThumpable`
barrier with `isDoor=false`. This prevents ordinary door interactions from
opening it from either side; vanilla locks alone do not provide that rule.
The release command replaces only the six barriers with open, single-piece
`IsoThumpable` doors. Their flags/health remain protected. The server reasserts
the open state if a player later closes a released door.

The release latch is saved with the layout. A normal restart of an already
released save leaves doors open; this version has no close/reset command or
daily schedule. The module does not implement zombie clearance, an event
lifecycle, server-authoritative player relocation or forced chunk streaming.
Existing map objects are preserved; the builder does not clear buildings,
trees, parked vehicles or other obstructions. Verify the perimeter and all six
exit positions on the target map before admitting players.

## Installation and command

Enable `ApocalipseBrRCONextension` on both server and clients before the core
`ApocalipseBR-ExtractionMapUtils` mod. The core's `42/mod.info` declares the exact
dependency ID; the extension is installed separately, not copied into this
repository. Minimum version is now 42.13.0, matching that dependency.

On server startup with unreleased doors, the core generates a one-use UUID and
writes it to the server's Lua cache:

```text
<server Zomboid cache>/Lua/ApocExtractionLobby-<server-name>-open-token.txt
```

The server log identifies that filename without printing the token. Unsafe
characters in the server name are replaced with underscores. Read the current
file on the server and send the following through RCON, substituting the token
and a unique request ID:

```text
servermsg ##APOCBR_RCON##ExtractionLobby##OpenDoors##lobby-open-001##<TOKEN>
```

The extension receives `servermsg` on connected clients and relays it to the
server, then waits its two-second duplicate-relay grace period before dispatch.
**At least one connected client with the extension is required.** With an empty
server, this transport cannot deliver the command; retry after a client joins
with a new request ID. No lobby coordinates or object IDs are accepted from the
payload: the only operation is releasing the configured perimeter.

This extension's relay callback is not proof of RCON authentication. Ordinary
clients can forge relay packets. The server-local token authorizes the fixed
release operation and is consumed before release. It is never put in global or
object ModData (clients can request global ModData by name). Broadcast receivers
can see the token only when release is already being requested; reuse after
consumption cannot initiate a later release. Do not reuse this mechanism for
arbitrary payload-bearing or repeatable privileged commands without a separate
authentication design. Restarting an unreleased server generates a new token.

On acceptance the token file reads `consumed` and the log says `OpenDoors
accepted`. File creation/verification/consumption failures leave the release
disabled/closed. Invalid-token payloads are rejected without logging their
contents. The extension has no response channel to RCON, so use the server log
and actual door state to confirm execution. Repeating the command after release
has no effect.

## Configuration and work budget

Edit `common/media/lua/server/ApocExtractionMapUtils_LobbyConfig.lua` in the core
mod and restart. This is server-owned Lua configuration, independent of the
existing sandbox login coordinates.

| Configuration | Default | Meaning |
| --- | --- | --- |
| Enabled | true | Enables perimeter initialization/maintenance. |
| X1/Y1, X2/Y2, Z | Supplied bounds, Z=0 | Inclusive interior tiles. |
| DoorCount | 6 | Clamped to 0..6, selected once per saved layout. |
| MaxEdgesPerTick | 4 | Hard count cap; configurable from 1 to 16. |
| MaxTickMilliseconds | 2 | Stops starting more edge operations after elapsed budget. |
| RescanMilliseconds | 60000 | Recheck all edges, spreading operations across ticks. Minimum 10000. |
| DoorCheckMilliseconds | 2000 | Recheck only doors. Minimum 1000. |
| Wall/Door sprite fields | Vanilla metal assets | N/W closed walls/doors and N/W open door sprites. |

Initialization creates a small plan and enqueues edges; it does not mutate the
world in one startup loop. Each tick processes at most four edges, checking the
elapsed time between operations. One native operation cannot be preempted, so
the two-millisecond budget is not a hard bound on an individual engine call.
Unloaded/null squares are skipped once, without repeatedly retrying them each
tick. `LoadGridsquare` only queues matching edges; placement happens later.
Repeated callbacks are deduplicated, no square references are retained, and the
finite plan is capped at 4096 edges. A mostly unloaded default lobby costs 286
lookups per minute plus six door lookups per two seconds, spread across ticks.
Errors log once per failing edge until it succeeds and retry only on a later
load/check/scan. Intact objects are not continually recreated or rebroadcast.

Changing bounds, door count or sprites on an existing save is rejected rather
than silently relocating the perimeter. Deliberately remove the old owned
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
- Door replacement uses `square:transmitRemoveItemFromSquare()` and the same
  complete add path. Opening is set with `ToggleDoorSilent()` BEFORE insertion
  and full serialization. This avoids a nil actor in `ToggleDoor(nil)` and
  avoids treating a silent toggle as a complete live-world sync operation.
- Like the inspected BrushToolSaveFix, mutation happens on the server and marks
  the square's zone as having construction. Its movable-item pipeline is not
  required for purpose-built `IsoThumpable` walls. Unlike its brush helper,
  the lobby does not try to create squares for missing chunks.
- Metal sprites come from vanilla `entity_metal_walllvl2.txt` and
  `entity_metal_doorlvl1.txt`. Do not replace them with climbable fence sprites.

## Files and verification

Runtime files: `server/ApocExtractionMapUtils_LobbyConfig.lua`,
`server/ApocExtractionMapUtils_Lobby.lua`, and `42/mod.info`.
Packaging descriptions and the root README reflect the dependency/feature.

Executed successfully on 2026-10-19:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

The lobby harness mocks engine/file boundaries and verifies normalized bounds,
286 edges, six separated exits, fixed saved positions, startup deferral, missing
chunks, deduplication, count/time budgets, object protection, idempotency, saved
release, late-load release, token validation/consumption/replay, file failures,
invalid configuration and duplicate module loading. Its optional argument loads
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

# Rescue invalid login positions during operations

Current login-hook ownership: ExtractionMapUtils supplies both Lua login hooks and the login command handler; see [dialogue graphs and Lua login](../features/npc-dialogue-graphs.md).

Status: implemented; awaiting dedicated-server reconnect validation.

## Symptom and cause

The closed-lobby login gate preserved every saved position after release. A
character transferred from another server could therefore remain outside this
world's boundaries or spawn in the ocean while an operation was running.

## Fix

With `LobbyEnabled` and `RelocateOnLogin` enabled and a valid lobby destination:

- Closed lobby: retain the existing relocation for all living players at login.
- Released/unknown lobby: reset only positions outside the world's metagrid
  rectangle or on loaded open-water tiles. Bounds use `IsoMetaGrid.isValidSquare`
  with floored coordinates, including negative cells and exclusive upper edges.
- Preserve in-bounds land, vehicle passengers (including boats), and water tiles
  covered by a non-water solid floor. Outside-map vehicles still reset.
- Defer missing squares/floors. Retry requests at one-second intervals, at most
  15 per player, then preserve unresolved positions. Absent replies use the same
  retry budget. Completed decisions are consumed once per local player.

`shared/ApocExtractionMapUtils.lua` owns the geometry predicate;
`server/ApocExtractionMapUtils_Lobby.lua` derives decisions from the server's
player and world, never client coordinates. `client/ApocExtractionMapUtils_Login.lua`
requests decisions and applies the existing teleport only to the affected local
player. Single player uses the same predicate locally.

The optional Build 42.21.0 `ApocBRPlayerLogin` Java bridge also resets a known
cross-server login regardless of valid terrain or operation state. It now compares
an immutable previous-server result from the independent successful-login audit.
The old `ApocBR.LastConnectedServerId.v1` mod-data marker is no longer read or
written. Pending history results retry; a ready result with no previous occurrence
uses the geometry fallback. Every participating server must carry the Java patch
and enable PostgreSQL, including servers loading players from SQLite. See
[successful-login history](../features/successful-login-history.md).

With the bridge present, server Lua calls its one-shot `teleportToLobby` using
the configured destination. It uses vanilla `GameServer.sendTeleport` including
movement/anti-cheat resets. The client acknowledges `serverTeleported` without
running its old teleport. Without the bridge, existing client placement remains.
Single player remains local. No database migration or client Java patch is needed.

These boundaries cover the current world, including metagrid world-generation
extensions, not event regions or the lobby perimeter. Without a known Java login origin, no transfer history is inferred: imported
players on safe land remain, while open-water logins reset regardless of origin. This checks login only.

See [lobby placement](../features/lobby-and-map-visibility.md).

## Validation

Passed from the repository root with
`npm exec --yes --package=fengari-node-cli -- fengari <test>`:

- `tests/login-position.lua`: map edges/negative coordinates, open water,
  bridges/floors, offshore passengers, unloaded geometry, server decisions,
  forged client coordinates, disabled settings, known cross-server safe-land
  rescue, same-server reconnect and native teleport readiness.
- `tests/login-lobby-state.lua`: deferred requests, release/closed decisions,
  invalid-position rescue, duplicate/unsolicited replies, option/death guards,
  streaming retry pacing/budget and independent local-player decisions and suppression of duplicate client placement
  after server teleport acknowledgement.
- `tests/login-and-maps.lua`, `tests/lobby-perimeter.lua`,
  `tests/map-reveal-server.lua` and `tests/cartography.lua`: existing regressions.

Engine references inspected under the local decompiled B42 source root:
`iso/IsoMetaGrid.java` (`isValidSquare`, 256-tile metagrid bounds) and
`iso/IsoGridSquare.java` (`isWaterSquare`, floor `FloorMaterial=Water`). Water flag
and floor-overlay handling follows bundled `AquasarYatchClub`'s
`shared/AquaSwimShared.lua` conventions.

Tests mock engine boundaries. Actual terrain streaming, boat occupancy restoration,
teleport synchronization and anti-cheat acceptance still require a dedicated
server/client test. Unloaded geometry is never taken as proof of an invalid spawn.

# Startup lobby zombie cleanup

Status: implemented 2026-11-04; awaiting Build 42.22.1 dedicated-server validation.

## Configuration and behavior

Enable `SandboxVars.ApocExtractionMapUtils.LobbyCleanupZombies = true` and
`LobbyEnabled = true`, then restart. Default remains false. Requires the updated
42.22.1 server Java patch with `ApocBRLobbyStreaming` and patched `LoadedAreas`,
as well as this mod. The older geometry-only bridge is rejected explicitly.
Missing bridge or invalid geometry logs FAILED and performs no cleanup.
The feature is independent of fence construction, login relocation and event release.

Every process startup, `OnServerStarted` queues the complete configured lobby
rectangle. No saved completion flag prevents future startup runs. The job runs
on `OnTickEvenPaused`, including an empty server with PauseEmpty enabled. It
cannot block `OnServerStarted`: the loader requires subsequent server frames.
Server readiness/login is not gated on job completion; wait for COMPLETE in the
logs before admitting players if the lobby must be clean before entry.

The server loads one 64x64 server cell at a time through native relevance requests.
This necessarily loads surrounding chunks in that cell, but deletion touches only
the inclusive normalized `LobbyX1/Y1`..`LobbyX2/Y2` interior at `LobbyFenceZ`.
The fence's extra east/south anchoring squares are excluded. After full main-thread
cell integration, register a temporary population activation area for that cell.
The bridge drains population updateMain on the server thread while paused;
unpaused servers keep their normal update path. Allow five seconds for initial
settling, then process at most four intersecting 8x8 chunks (256 tiles) per callback.
Repeat bounded verification sweeps until native readyToPause reports no pending
population work, at least two sweeps finish, and no removal occurs for five seconds.
Chunk progress counts unique chunks, not repeated sweeps. Missing squares on the
configured floor are empty, not a reason to create terrain.

Remove IsoZombie objects with removeFromWorld then removeFromSquare. Preserve
players, animals, corpses and reanimated players. Removal does not kill zombies
or award kill rewards/objectives. Existing server-authorized ID packets tell
clients to remove the same identities from affected loaded tiles. Clients cannot
request or choose cleanup targets. Single player is skipped with a diagnostic;
forced server streaming is dedicated-server-only.

After each cell, stop renewing its relevance request. Native ServerMap.postupdate
then saves/unloads it when no player or other native requester needs it. Never
call ServerCell.Unload directly or evict player chunks. Explicitly remove the
temporary population area on cell completion, cancellation and failure. It has a
15-second renewal limit as an additional stale-request safeguard. No fake players,
ImportantAreaManager entries, worker threads or permanent pins are created.
Completed, cancelled and failed jobs stop making loading requests.

## Logs and failure handling

The `[ApocExtractionLobbyCleanup]` prefix always prints, independently of DebugLogging:

- START: normalized bounds, floor, total cells and intersecting chunks.
- LOADING: cell index and coordinates.
- PROGRESS: every five seconds, with phase, chunks, removals and populationReady.
- CLEANED: per-cell totals, verification passes, populationReady and request release.
- COMPLETE: chunks, removals, loaded/missing tiles, elapsed time and request release.
- FAILED/CANCELLED: partial totals and request release; never report incomplete work as success.

Cell loading/cleanup has a 120-second deadline. Invalid map cells, API exceptions
and timeout abort the run without retry loops or permanent retention. Disabling
either option during the job cancels it. A duplicate startup event or module load
does not rerun cleanup in the same process. Restart after changing configuration.

This is a finite startup cleanup, not a safe zone. Zombies entering or spawning
after the final verification survive. It activates and removes virtual population
through the normal realization path rather than deleting broad population cells
or modifying save files. It does not disable respawns or advance the game clock.
Native population timing/readiness, loaded-cell saving, actual unloading and client
ownership must be checked on the dedicated server. See the
[zero-removal startup hotfix](../hotfixes/lobby-cleanup-virtual-population.md).

## Source evidence and affected files

Verified against `apocalipsebr-zomboid-patches/42.22.1/decompiled/zombie/` and its
patched ServerMap implementation:

- ServerMap.loadOrKeepRelevent uses map-relative 64-tile cell indices; preupdate
  integrates loading and clears per-frame relevance before Lua's server update.
- ServerCell.Load2/RecalcAll2 integrates chunks and indoor zombies before marking
  completion; postupdate uses relevance and player influence to unload/save.
- IngameState fires OnTickEvenPaused even while paused; normal population
  updateMain runs only when unpaused.
- LoadedAreas.set(false) normally contains player/connection areas, not forced
  server cells. Its new server-only hook appends the cleanup population area.
- LuaManager exposes the new bridge only on the server. Server-map access runs
  on the server thread from Lua callbacks, never a loader or NPC worker.

Mod files: server/ApocExtractionMapUtils_LobbyCleanup.lua,
client/ApocExtractionMapUtils_LobbyCleanupClient.lua (existing replication), sandbox
option, EN/PTBR labels and tests/lobby-cleanup.lua. Lua paths are relative to
`ApocalipseBR-ExtractionMapUtils/common/media/lua/`.
The bridge and its validation are documented in the patch repository under
`42.22.1/docs/features/2026-11-04-lobby-startup-streaming.md`.

## Verification

Passed on 2026-11-04:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-cleanup.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
py tests/translation-locales.py
git diff --check
```

The mocked Lua harness covers opt-in/master/client guards, nonblocking startup,
paused callbacks, delayed virtual population after an empty first sweep, native
pending-work refusal, settling, multiple cells, bounded deletion, exclusions, exact
bounds/floor, logging, finite requests, no repeat deletion, restart, timeout,
missing bridge, invalid map, exceptions, cancellation and client identity sync.
Production bridge fixture and exact-game-JAR compilation also passed (see patch
guide). No live server was started or installed patch deployed for this change.

# Initial lobby zombie cleanup

Status: implemented 2026-10-30; awaiting dedicated-server/client validation.

## Configuration and behavior

Enable `SandboxVars.ApocExtractionMapUtils.LobbyCleanupZombies = true` and
`LobbyEnabled = true`, then restart the server. The cleanup option defaults to
false. It is independent of fence construction, login relocation and operation
release state. EN/PTBR sandbox labels explain the behavior.

On the first natural `LoadChunk` for each lobby chunk during a server run,
remove existing `IsoZombie` objects from the inclusive rectangle defined by
`LobbyX1/Y1` and `LobbyX2/Y2`, at `LobbyFenceZ` only. Corner order is normalized.
The extra east/south squares used to anchor fences are outside this interior
cleanup area. Players, animals, corpses and reanimated players are preserved.
Removal does not kill zombies or trigger kill rewards/objectives.

Each callback examines at most 64 tiles on the configured floor. It never loads
chunks, scans the global zombie list, retains zombie references, or queues a
future area sweep. Chunk coordinates are derived from exposed grid-square
methods rather than Java field access. Invalid lobby geometry does no cleanup.

Visited chunk keys are held in memory only. Already cleaned chunks are never
cleaned again in that run, even after unloading/reloading, fence release or
player reconnect. A new server run starts fresh. Newly visited lobby chunks
still receive their first cleanup if loaded much later in the run. Zombies
entering or spawning after the initial callback survive: this is an initial
cleanup, not a safe zone or spawn-prevention system. In particular, population
materialized asynchronously after `LoadChunk` is outside this pass. Restart
after changing settings; live reconfiguration is not supported.

## Authority and replication

The server removes selected zombies with `removeFromWorld()` followed by
`removeFromSquare()`. For multiplayer, a server-only command includes the
removed online IDs and affected tile rectangle. Clients mirror removal only for
matching IDs on those loaded tiles. There is no client request handler and no
client authority to choose zombies. Unloaded client squares are left alone;
server world state supplies subsequent loads. Single player removes locally.

Affected files:

- `server/ApocExtractionMapUtils_LobbyCleanup.lua`
- `client/ApocExtractionMapUtils_LobbyCleanupClient.lua`
- `media/sandbox-options.txt` and EN/PTBR `Sandbox.json`
- `tests/lobby-cleanup.lua`

Lua paths are relative to `ApocalipseBR-ExtractionMapUtils/common/media/lua/`.

## Engine evidence and limitations

Verified against local `apocalipsebr-zomboid-patches/42.21.0/decompiled/`:

- `zombie/iso/IsoChunk.java`: `getGridSquare(int,int,int)` and `LoadChunk` at
  the end of `doLoadGridsquare`; chunk dimensions are 8x8.
- `zombie/Lua/LuaManager.java`: exposes `IsoChunk`, `IsoZombie` and server commands.
- `zombie/characters/IsoZombie.java`: online ID getter and removal lifecycle.
- `zombie/commands/serverCommands/RemoveZombiesCommand.java`: native removal
  order and reanimated-player exclusion. Native code additionally queues a
  `NetworkZombiePacker` deletion; the mod uses its own server-to-client command
  because that packer is not exposed in vanilla Lua.
- `zombie/network/ServerMap.java` and `zombie/popman/ZombiePopulationManager.java`:
  some indoor/population creation can happen after the chunk callback. Such
  later zombies are intentionally not watched or continuously removed.

Client replication, zombie ownership timing, population timing and saved-world
restarts still need a live dedicated-server/client test. No Java patch required.

## Verification

Passed on 2026-10-30:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-cleanup.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/login-lobby-state.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua
```

The new harness mocks engine boundaries and covers default-off/disabled/client
guards, normalized bounds and floor, multiple zombies on one square, exclusions,
outside chunks, empty/unavailable tiles, late natural chunk loading, no cleanup
on repeat loads/ticks, later entrants before the next tick, server restart,
single player and selective server-authorized client synchronization. JSON,
UTF-8 without BOM, documentation links and diff whitespace were also checked.

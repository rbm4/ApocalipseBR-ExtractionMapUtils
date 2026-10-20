# Lobby construction load order

Status: implemented locally; awaiting dedicated-server/client validation.

## Symptom and cause

During dedicated-server startup, the lobby construction module failed to require
`BuildingObjects/ISBuildingObject` and `BuildingObjects/ISBuildIsoEntity`, then
indexed `tryBuild` on nil. Construction protection was not fully installed.

Decompiled `Lua/LuaManager.java` registers each directory's require path inside
`LoadDirBase(sub)`; `require` searches only registered paths. `network/GameServer.java`
loads shared before server Lua. Both building cursor classes live in vanilla
`media/lua/server/BuildingObjects`, so requiring them from shared is too early.
`gameStates/GameLoadingState.java` loads server Lua for clients and single-player
as well, after client Lua has been registered.

## Fix and affected files

Move `ApocExtractionMapUtils_LobbyConstruction.lua` from `shared/` to `server/`.
Keep its construction, footprint, upgrade and client/SP action checks intact.
Update `tests/lobby-construction.lua` to make server building dependencies
unavailable during the shared pass and exercise installation in the server pass
for dedicated server, client and single-player. See
[construction protection](../features/lobby-construction-protection.md).

## Validation

Run on 2026-10-20 from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-construction.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
```

Both passed. The construction harness also runs disassembly protection tests;
it covers startup ordering, duplicate loads, blocked builds and upgrades, entity
overlap, cancellation, native returns and outside/disabled behavior. Engine
boundaries are mocked; no live game or dedicated-server test was run.

Deploy the move on both server and clients, removing the old shared copy, then
restart. Confirm startup has no failed building requires or nil-table exception,
and test construction inside/outside the lobby without unwanted material loss.

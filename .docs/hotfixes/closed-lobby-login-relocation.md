# Login relocation only while the lobby is closed

Current login-hook ownership: ExtractionMapUtils supplies both Lua login hooks and the login command handler; see [dialogue graphs and Lua login](../features/npc-dialogue-graphs.md).

Status: implemented; awaiting in-game multiplayer movement validation.

This records the original lifecycle fix. The subsequent
[position rescue hotfix](invalid-login-position-rescue.md) adds invalid-position
rescue after release and bounded retries; its behavior supersedes the blanket
release bypass described below.

## Symptom and cause

Reconnecting during an active operation moved players to the fixed lobby
coordinates. The login hook checked sandbox options but ignored the persisted
lobby release state.

## Fix

`client/ApocExtractionMapUtils_Login.lua` waits for a fresh `LoginLobbyState`
reply before placing players. It sends one request on the next tick after
`OnGameStart`, which B42 fires before `sendPlayerConnect`.
`server/ApocExtractionMapUtils_Lobby.lua` derives `closed` from its initialized
state, `LobbyEnabled`, `released == false` and `removedAll ~= true`; request
payloads cannot override that decision. Replies are consumed once per login,
and placement rechecks options and living players. Single player reads the
local saved ModData; absent state skips placement.

Manual exit release and scheduled whole-perimeter release both suppress login
placement immediately, before queued world edits finish. Their saved latches
continue to suppress placement after restart. The current lifecycle has no
automatic reclosure; relocation resumes only with a closed lobby state.
See [lobby placement](../features/lobby-and-map-visibility.md).

## Validation

Passed from the repository root using
`npm exec --yes --package=fengari-node-cli -- fengari <test>`:

- `tests/login-lobby-state.lua`: deferred multiplayer request, closed-only
  placement, active/unknown state, duplicate/unsolicited replies, option changes,
  and dead players.
- `tests/login-and-maps.lua`: existing login/map regressions plus released,
  removed and missing local lobby state.
- `tests/lobby-perimeter.lua`: authoritative closed decision, manual release,
  forged state ignored, scheduled activation and persistence after restart.
- `tests/map-reveal-server.lua` and `tests/cartography.lua`: existing map checks.

Engine references inspected: `gameStates/IngameState.java` (`OnGameStart` before
`sendPlayerConnect`), `network/GameServer.java` (`OnClientCommand` dispatch),
and `network/GameClient.java` (`OnServerCommand` dispatch), under the configured
local decompiled B42 source root.

These tests mock engine boundaries. Dedicated-server reconnects while closed and
during an operation, chunk streaming, movement synchronization and anti-cheat
acceptance remain untested in game. If no server reply arrives, login placement
is skipped; there is no continuous teleport enforcement or retry loop.

# Independent lobby relocation after death

Status: implemented 2026-10-26; awaiting live B42 dedicated-server/client validation.

## Before this change

`OnCreatePlayer` queued the same relocation request as `OnGameStart`. There was
no death/respawn classification, so a closed lobby could override a safehouse or
map/mod spawn even on the same server. The code checked server history, lobby
state and saved-position geometry; it did not independently configure respawns.
The mod did not choose a safehouse or map spawn itself.

## Configuration and behavior

`SandboxVars.ApocExtractionMapUtils.RelocateOnRespawn` defaults to `false`.

| Connection/spawn path | Setting | Result |
| --- | --- | --- |
| Login, including known cross-server arrival | RelocateOnLogin | Existing login policy: closed-lobby relocation, cross-server relocation and invalid-position rescue. |
| Replacement character in the same accepted connection slot | RelocateOnRespawn=false | Preserve the safehouse, map or other mod's selected spawn, even with a closed lobby. Skip login-origin and geometry rescue overrides for this respawn. |
| Replacement character in the same accepted connection slot | RelocateOnRespawn=true | Relocate to the configured lobby, including during operations, independently of RelocateOnLogin. |

Both paths require `LobbyEnabled=true` and valid `LobbyX`, `LobbyY`, `LobbyZ`.
The destination helper accepts either enabled relocation switch, while the
server applies only the switch for the trusted spawn classification. An enabled
respawn does not wait for the asynchronous cross-server history result. The
successful-login audit remains independent and still records accepted players.

The mod leaves the game's safehouse and other mods' spawn selection mechanisms
in place; with respawn relocation disabled it does not validate or adjust their
chosen respawn position. Other mods can still perform their own later teleports.
A disconnect/reconnect is a new login, not a same-session respawn. Initial co-op
slots are independent and do not count as respawns of another slot.

## Ownership and source checks

The 42.21.0 `ApocBRPlayerLogin` bridge classifies accepted replacements using a
server-thread-owned weak map of authenticated connection objects and accepted
slot indices. Duplicate acceptance of the same player remains idempotent. The
additive `isRespawn(player)` getter performs no SQL and ignores client flags; it
works while login auditing is disabled or pending. It exposes no live state to
worker threads. The map has at most four entries per live connection and no
persistent database representation.

In single-player, the client Lua records `OnPlayerDeath` for the local slot and
carries it through `OnCreatePlayer`/`OnGameStart`. Multiplayer decisions and the
native teleport use the server's classification. NPC roster discovery continues
on both login and respawn, regardless of relocation settings.

Verified local sources: `IsoPlayer.java` emits `OnPlayerDeath`; `LuaManager.java`
`initUISystem` and `GameLoadingState.java` emit `OnCreatePlayer`; patched
`GameServer.receivePlayerConnectReady` calls `successfulLogin` after assigning
the accepted character to its authenticated connection/slot.

Deploy the updated mod and Java patch together, restart the server and reconnect
clients. An older Java bridge lacks authoritative respawn detection and retains
its prior multiplayer login classification. No database migration is required.

## Files and verification

Mod files: shared `ApocExtractionMapUtils.lua`, client `Login.lua`, server
`LoginServer.lua`, `sandbox-options.txt`, and EN/PTBR `Sandbox.json` labels.
Engine: `42.21.0/src/zombie/savefile/ApocBRPlayerLogin.java` and its production
fixture `tools/test_player_login_origin.py`.

Passed on 2026-10-26:

- `tests/login-position.lua`: server-owned classification, disabled respawn in
  closed lobby despite cross-server history, independent enabled respawn during
  pending history, forged client flags and existing geometry/login behavior.
- `tests/login-lobby-state.lua`: single-player death/create/start ordering,
  respawn enabled with login disabled, default-off preservation and existing
  client request/retry/native-teleport handling.
- `tests/login-and-maps.lua` and `tests/lobby-perimeter.lua`: existing regressions.
- `python tests/translation-locales.py`: EN/PTBR completeness, JSON/BOM checks,
  and the independent default-off sandbox setting.
- Companion `python tools/test_player_login_origin.py`: 31 production checks,
  including new connection versus respawn, duplicate accepts, co-op slots,
  disabled audit and worker access rejection.
- Companion `42.21.0/patchApocalipseBr.ps1 -DryRun`: all 301 server sources compile
  against the real installed 42.21.0 game JAR, without deployment.

Lua harness command from the mod root:
`npm exec --yes --package=fengari-node-cli -- fengari tests/<name>.lua`.
Engine/JDBC boundaries are mocked; actual safehouse selection, other spawn mods,
movement synchronization, anti-cheat, death/reconnect and co-op timing still
require dedicated-server/client testing.

Related: [successful-login history](successful-login-history.md),
[login placement](lobby-and-map-visibility.md), and
[lobby sandbox configuration](lobby-sandbox-configuration.md).

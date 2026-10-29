# Lobby fence between operations

Status: implemented 2026-10-26; awaiting dedicated-server/client validation.

## Symptom and cause

After an operation released the whole perimeter, `removedAll` and `released`
remained saved forever. Queuing another operation did not clear them, so
maintenance and chunk loading continued removing fences. The engine can also
replay a durable receipt for an older operation while the next one is queued.

## Fix

`server/ApocExtractionMapUtils_Lobby.lua` checks the new 42.21.0 cached
`ApocBREventControl.getLobbyFenceState()` at startup and on the existing
two-second exit check. A confirmed closed state clears release flags and event
identity, refreshes the server-only command token and queues the complete saved
perimeter for reconstruction. Exit positions, ownership checks, chunk deferral
and per-tick budgets are preserved. Old receipt callbacks are refused while
confirmed closed. Steady checks do not rotate tokens or recreate intact assets.

A queued operation without an active operation means closed. An active operation
keeps its released perimeter; uncertain or stale agenda data preserves the saved
state. A new due operation can still release before the manager publishes its
active entry. Manual exit releases are reclosed at the next confirmed idle check.
Older engines without the new method retain existing behavior.

The bridge uses the guide's existing active-name/end estimate and manager
freshness rules, not schedule ID presence. Reaching the estimated end allows
reclosure, without stopping objective runtime. Both the mod and updated Java
server patch must be installed and the server restarted. No SQL changes.

Affected files: lobby Lua, `tests/lobby-perimeter.lua`, and companion patch
`42.21.0/src/zombie/apocalipse/events/ApocBREventControl.java` plus its production
fixture `tools/test_lobby_event_control.py`. The lobby fixture also supplies the
currently required `getOnlineID()` login mock.

## Verification

Passed on 2026-10-26:

- `npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension`: startup/runtime reclosure, active/unknown preservation, receipt replay rejection, fixed exit positions, stable tokens, late-loaded rebuilding, repeat release and real RCON relay integration.
- `tests/login-lobby-state.lua`, `tests/login-and-maps.lua`, and `tests/lobby-disassembly.lua` via the same Fengari command: passed.
- Companion `python tools/test_lobby_event_control.py`: 265 production assertions, including queued/active overlap, old receipts, expired estimates and stale/future manager snapshots.
- Companion `42.21.0/patchApocalipseBr.ps1 -DryRun`: all 301 server sources compiled against the installed game JAR; no deployment.

Engine/file/JDBC boundaries are mocked in fixtures. Native collision, client
replication, saved-world restart, manager synchronization and overlap timing
still require live validation. Fences can only be built as their chunks load.

Related features: [lobby perimeter](../features/lobby-perimeter.md) and
[PostgreSQL event activation](../features/postgresql-event-control.md).

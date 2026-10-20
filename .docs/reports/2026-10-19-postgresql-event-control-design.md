# PostgreSQL event control and guide announcements

Status: historical design investigation. The accepted design is now implemented
as [PostgreSQL event activation](../features/postgresql-event-control.md), using
`player_rel` and whole-perimeter removal. The implementation's versioned contract
supersedes the API/transport proposals below. Target: patched
42.21.0 dedicated server plus the extraction mod. No game Java, gameplay Lua,
database schema, credentials or live database were changed by this investigation.
Related feature: [Lobby perimeter](../features/lobby-perimeter.md).

## Verified existing integration points

The patch repository is `Z:/git/Github/apocalipsebr-zomboid-patches`. Paths below
are relative to its `42.21.0/` directory, except where identified as mod Lua.

- `src/zombie/savefile/ApocBRPostgresConnector.java` already owns the PostgreSQL
  datasource/Hikari pool. Credentials come from the server environment/JVM
  configuration. `runBackgroundDatabaseWork()` distinguishes worker operations
  from foreground database budgets; it does not itself create a worker.
- `openDictionaryListenerConnection()` already opens a dedicated physical
  auto-commit session outside the query pool. A long-lived listener therefore
  need not monopolize the game's query pool, including when pool size is one.
- `src/zombie/world/ApocBRWorldDictionaryMirror.java` already implements
  `LISTEN`, `PGConnection.getNotifications()`, periodic reconciliation and
  reconnect reconciliation. This is the useful lifecycle pattern, not a reason
  to reuse its dictionary channel or replace its single dictionary shutdown
  callback for an unrelated event subscriber.
- `src/zombie/network/GameServer.java` initializes bridge hooks before
  `OnServerStarted` and invokes server-side hooks in its main loop. RCON update
  and these hooks have no requirement for a player relay. Event control can run
  there independently of simulation pause/game-clock progress.
- `src/zombie/gameStates/IngameState.java` implements `PauseEmpty` for an empty
  dedicated server. Event scheduling must use wall-clock time and a main-loop
  hook rather than depend on advancing in-game hours/minutes.
- `src/zombie/Lua/LuaManager.java` already exposes `ApocBRRadioBridge` only inside
  a `GameServer.server` guard. A narrow event bridge can use the same pattern.
- The guide's current `src/zombie/apocalipse/humans/brain/GuideBrain.java`
  creates a `HumanAction.Say("Oi!")`. `ServerHumanActuator.say()` forwards speech
  through `ServerHumanTransport.say()`. The cached schedule can be supplied at
  that greeting boundary without querying PostgreSQL from the brain or speech.
- Mod `server/ApocExtractionMapUtils_Lobby.lua` already performs bounded,
  idempotent removal of selected exits, handles unloaded squares, and persists a
  release latch. Its public `releaseExits(payload)` currently requires a
  one-use token because it is called by the RCON extension's untrusted client
  relay. It is not yet a typed internal scheduler API.

There is no next-event subscription or guide event-time integration in these
inspected paths. Existing database connectivity does not provide that feature
automatically. The patches working tree also contains ongoing human/trading and
persistence changes; they were inspected without modifying them.

## Recommended flow

```text
External backend / administrator
        |
        | commit durable schedule update, optionally NOTIFY
        v
PostgreSQL schedule scoped to server + world
        |
        | dedicated background listener + periodic bounded reread
        v
Immutable, validated cached event snapshot
        |
        +--> server main-loop event controller --> server Lua lobby release
        |
        +--> guide greeting uses the same accepted schedule snapshot
```

This removes the online-player dependency. RCON can remain available for manual
administration; it is no longer the transport required for scheduled activation.
No raw SQL execution, JDBC connections or database credentials should be exposed
to Lua. The exposed call should return already-cached, typed event data only.

Suggested API shape, subject to the eventual backend contract:

```lua
-- Proposed server-only API; these functions DO NOT exist yet.
local event = ApocBREventControl.getNextEvent()
-- event.id, event.revision, event.name, event.startsAtEpochMillis, event.state
-- getStatus() distinguishes disabled, starting, ready and stale/unavailable.
```

Java accepts schedule updates on its worker, installs them on the server thread,
and publishes a typed Lua notification there. The mod also reads current state
at startup so a missed callback cannot lose an event. A notification payload
only requests a reread; it must not be interpreted as executable Lua, arbitrary
commands, or the authoritative event body.

## Schedule and execution contract to settle

No existing event table/API contract has been supplied. If there is no existing
one, a small durable schedule table should describe at least event ID, target
server/world, name, real activation timestamp (`timestamptz`), monotonic revision
and lifecycle state. Cancellation/rescheduling must update the durable record
and revision, not only emit a notification. The backend owns publication; the
game accepts only its configured target scope and validated fields.

The external update should commit first and notify in the same transaction.
The listener commits LISTEN before its first reread and reconciles again after
every reconnect. Periodic bounded reads recover missed notifications. Query
timeouts, bounded backoff and rate-limited error codes prevent an unavailable DB
from stalling or flooding the server. Snapshot getters never wait on JDBC.

The activation timestamp is a real instant, independent of `PauseEmpty` and game
time acceleration. Store/compare in UTC; show the guide's time in an explicitly
configured zone, with America/Fortaleza as the proposed display default. Include
the date as well as the time to avoid ambiguous next-day announcements.

At the deadline, the main-loop controller should request release with a stable
event ID/revision. The mod needs a separate trusted server entry point sharing
the existing bounded mutation queue. Do not bypass token checks on the public
client-relay handler. Persist the applied event identity; retries and startup
reconciliation must be idempotent. Report "release requested" separately from
"all loaded segments removed" and do not claim unloaded chunks were edited.
True atomic exactly-once mutation across PostgreSQL and world-save files is not
available; recovery must safely repeat the desired-state operation.

With no players, activation can be recorded immediately. Unloaded perimeter
chunks are removed/skipped according to the accepted event state when they
eventually load. Do not force terrain streaming merely to acknowledge an event.

Before implementation, choose the outage/cancellation policy explicitly. A
conservative default is to keep fences closed if the current schedule cannot be
confirmed fresh at activation, retain an already-applied release, and reconcile
overdue scheduled events on reconnect/startup. A previously cached schedule is
not proof it has not since been cancelled.

## Guide behavior

Use the same accepted event ID/revision for the greeting and activation. While
scheduled, append the event name and real activation date/time to its normal
greeting. After activation, announce that entry is open. With no valid schedule
or an unconfirmed stale schedule, use an appropriate fallback instead of
announcing an invented time. The guide is presentation, not the scheduler;
event activation cannot depend on its spawn, loaded square, visibility, current
brain state or whether it has greeted a player already.

Keep the deterministic greeting state machine intact and supply detached
schedule/message data at the actuator/action boundary. Existing native speech
transport should carry the result to clients. Text localization and message
length validation belong in the implementation contract.

## Perimeter scope and repeat events

Current release removes six saved single-tile exit segments. The latest request
also mentions clearing the lobby fence, which could mean the entire perimeter.
The choice is pending clarification. Removing all 286 segments would require a
different persisted desired state and queue selection; it must also suppress
maintenance respawning every removed edge.

The current lobby release latch is permanent per save and has no rearm/reset
operation. Supporting a sequence of events requires an event-specific lifecycle
and a defined rule for rebuilding the lobby between events. That behavior must
not be inferred merely from a new event ID. This first integration can be scoped
to receiving one next event and releasing once, with later reset designed
separately.

## Verification and implementation boundaries

Performed: read-only tracing of the actual 42.21.0 patched connector, listener,
server loop, Lua exposure and human greeting/speech paths, plus the current mod
release handler. No live DB/RCON/game test or runtime test execution was needed
for this documentation-only investigation. Reviewed report links and diff.

For implementation, test production Java worker/controller code with fake JDBC
and clock sources: zero clients, PauseEmpty, repeated/missed notifications,
cancel/reschedule revisions, wrong-server events, DB failure/reconnect,
restart/overdue events, bounded work and clean shutdown. Add Lua coverage for
typed release authorization, repeated event IDs, late chunks and release scope;
retain existing lobby/disassembly regressions. Extend guide tests without
hardcoding the old greeting. Compile all affected 42.21.0 patches against the
real game JAR with `patchApocalipseBr.ps1 -DryRun`, then validate scheduling,
speech, save/restart and world mutation on a dedicated server.

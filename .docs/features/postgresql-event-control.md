# PostgreSQL event activation

Status: implemented in 0.3.0; awaiting live 42.21.0 patch/PostgreSQL/backend/mod
integration. Requires the patched dedicated server and a backend-owned migration
in the `player_rel` schema. The backend's asynchronous synchronization is owned
by the backend and is not implemented in this mod.

The full integration contract and reference DDL are versioned alongside the
server patch:

```text
Z:/git/Github/apocalipsebr-zomboid-patches/42.21.0/LOBBY-EVENT-CONTROL.md
Z:/git/Github/apocalipsebr-zomboid-patches/42.21.0/LOBBY-EVENT-CONTROL.sql
```

The game registers a `player_rel.lobby_event_control` row per configured
server/world. The backend publishes a named event, UUID, increasing revision,
real activation timestamp and scheduled/cancelled state. A background worker
reads one row every 30 seconds by default and posts validated immutable data
to the server thread. Lua and the guide read cached data without SQL.

## Enablement and behavior

Set the mod sandbox option `ApocExtractionMapUtils.LobbyEnabled=true` (default
`false`). Disabled lobby control neither subscribes to the event nor authorizes
Lua release calls. The JVM settings below independently control the patched
engine's polling and guide announcements; the Lua sandbox switch does not change
those Java features.

After the backend migration, enable the normal PostgreSQL connector and add:

```text
-Dapocbr.events.enabled=true
-Dapocbr.events.serverKey=extraction-test
-Dapocbr.events.displayZone=America/Fortaleza
```

Use `apocbr.guide.enabled=true` for the existing guide actor. The 42.21.0 patch
says `Olá!` as it waves, then sends a separate message announcing the next
operation's name and countdown. If an operation is confirmed active, the
follow-up also reports its estimated remaining time. These new speech keys use
PT-BR fallback text in shared `Translate/EN/IG_UI.json` for dedicated servers.
The countdown uses real seconds, independent of game time and display timezone.

Apply manager runtime migration **V13** before installing the updated Java patch.
Its five informational `guide_*` columns carry the next operation, confirmed
active operation's estimated end, and publication time for this exact server/world.
The estimate uses scheduled start plus configured duration and never stops the
event. Release intent/revision/receipt ownership and Lua activation stay unchanged.
Engine-stale data or manager snapshots older than 60 seconds yield temporary
unavailability; keep the manager sync delay below 60 seconds. Empty agendas get
an explicit no-upcoming-operation message. Visitor loss/trade interrupts the
sequence; existing greeting cooldowns remain in force.

Activation runs on real time and does not require a connected player, an active
guide, or an advancing game clock. A fresh due schedule triggers
`OnApocBRLobbyEventDue` on the server main thread. The mod subscribes after
startup initialization and calls `Lobby.releaseForEvent(id, revision)`.
This typed path validates the current due schedule or a durable prior release
receipt through the exposed bridge.
It is separate from the client-relayed, token-protected RCON handler.

**Scheduled activation removes the entire owned perimeter**, including all 286
default segments, instead of only the six exits. The mod persists `removedAll`,
event ID/revision and the existing release latch in its world ModData. It queues
all edges with the existing four-edge/two-millisecond budgets. Empty/unloaded
terrain is never forced into memory. Later loads and repair scans keep every
owned edge absent; unrelated world objects are retained.

The engine asynchronously publishes `release_requested` with the accepted event
ID/revision back to the control row. This means desired-state acceptance, not
proof that unloaded map files were changed. Reapplying an overdue scheduled
event after restart is safe even if the database already contains a receipt.
Durable receipts also restore removal after the backend cancels/clears the
desired schedule, covering the receipt-to-world-save crash window. A crash
before both a world save and the async receipt are durable can still lose an
acceptance if the backend also removes its original intent before recovery;
retain desired schedules until observing their matching receipt.
There is no atomic transaction across PostgreSQL and normal game saves.

New activation fails closed when a snapshot is stale/unavailable; already
accepted removal stays in effect. Cancelling/rescheduling must advance the
desired revision and be observed before activation. Cancellation cannot undo
an already accepted release. This version has no automatic lobby rearm:
publishing another event does not rebuild the perimeter.

The existing manual RCON `ReleaseExits`/`OpenDoors` command still removes six
exit segments and requires its token/connected relay. Scheduled activation has
no such transport dependency and can remove the remaining perimeter after a
manual release. Unpatched servers retain the existing manual behavior; they
cannot consume PostgreSQL schedules.

## Files and verification

Guide countdown update: `python tests/guide-translations.py` passes checks for
the exact greeting, substitution placeholders, estimated-duration wording, valid
JSON and BOM-free UTF-8. The patch repository's production fixtures pass 72
brain/action, 217 event-control and 78 lifecycle/packet assertions, and its
42.21.0 patch script compiles successfully against the real game JAR with
`-DryRun`. These are isolated checks; live speech/animation timing and the
coordinated V13/manager/game deployment still require in-game verification.

Mod runtime changes: `server/ApocExtractionMapUtils_Lobby.lua`,
shared `Translate/EN/IG_UI.json` and `42/mod.info`.
See [perimeter behavior](lobby-perimeter.md) and the earlier
[design investigation](../reports/2026-10-19-postgresql-event-control-design.md).

`tests/lobby-perimeter.lua` now covers trusted event validation, whole-perimeter
removal through the tick queue, acknowledgement retry, retained event identity,
unloaded activation, restart and no reconstruction. The existing real RCON
extension integration remains in that harness. Disassembly/login/map regression
harnesses also apply. Java production worker/controller and guide tests live in
the patch repository. Tests mock engine/file/JDBC boundaries; no live event or
migration has been executed. Restart server/clients after installing, then test
the backend write, guide announcement, empty-server deadline, receipt and
late-loaded perimeter on the actual dedicated server.


## Metadata-capable engine bridge

The 42.21.0 v2 event patch adds an optional third argument:
`OnApocBRLobbyEventDue(eventId, revision, context)`. Existing perimeter code
continues to accept its first two arguments unchanged. Apply manager runtime
migration V14 before updating the manager/game patch. The website's operation
parameters now reach `context.metadataJson` inside a JSON envelope containing
`schemaVersion`, `gameType`, `ruleset`, `durationMinutes` and `parameters`.
`context.isReplay` identifies prior-release restoration; an old receipt without
its matching desired definition has no metadata. Objective consumers must save
accepted definitions and progress rather than infer a new round from a replay.
`ApocBREventControl.getEventContext(id, revision)` also provides a fresh matching
cached table without SQL. The mod now parses these definitions through the
[event definition schema](event-definition-schema.md), retaining validated server
Lua data. After release acknowledgement, the [objective runtime](objective-tracker.md)
attaches authoritative progress and a client tracker; preparation alone does not
activate gameplay, and receipt replays do not start a fresh round.

Game schedule polling defaults to 30000 ms and freshness to 90000 ms; existing
JVM overrides take precedence. Already-cached deadlines use the normal server
loop, while new edits/cancellations and receipt writes wait for the next poll.
The manager sync default remains 10 seconds. The full API and rollout details
are in the patch's `42.21.0/LOBBY-EVENT-CONTROL.md`. No Extraction Lua changed
for this additive bridge enhancement.

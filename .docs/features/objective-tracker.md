# Authoritative objectives and client tracker

Status: implemented for the dedicated-server multiplayer flow; isolated tests
pass, awaiting live Build 42 validation. The tracker is a standalone ISUI
implementation informed by the Quest RPG investigation. It requires no Quest
RPG installation, files, globals, assets, quest parser or client tracking engine.

## Activation and metadata contract

`EventDefinitions` validates the event envelope. `Objectives.prepare(record)`
now builds a server plan containing event UUID, definition revision, UI settings,
objective definitions, references, resolved region geometry and private provider
properties. It does not publish prepared objectives. After successful lobby
release acknowledgement, `Objectives.activate(plan)` attaches that plan to the
server service. The runtime then enters `in_progress`. Other gameplay/region/
boss modules remain scaffolds; this does not implement zombie replenishment.

Use [the kill tracker example](../../contracts/examples/objective-tracker-kills-v1.json).
In the website operation editor, paste only its `parameters` object and set
game type/ruleset/duration in their normal fields. It references an existing
Regions ID `event_docks`; replace that ID or supply schema-valid inline bounds.
No sample event is automatically injected.

Existing schema fields drive the UI: `id`, `type`, `scope`, `target`, `required`,
`titleKey`, `dependsOn`, `regionIds` and `entityIds`. Additional recognized
properties, within the schema's existing extension objects:

| Property | Meaning |
| --- | --- |
| `parameters.properties.objectivesUI.title` | Event heading; defaults to operation name |
| `parameters.properties.objectivesUI.titleKey` | Optional translated event heading, with title fallback |
| `parameters.properties.objectivesUI.visibleRows` | 1-8 visible rows; default 6; small viewports reduce this further |
| `parameters.properties.participants` | Optional array of canonical server usernames allowed to receive/contribute; omitted means all authenticated players |
| `objective.properties.title` | Plain objective label; falls back to ID when absent |
| `objective.properties.recipients` | Optional username array narrowing visibility/contribution for this objective |

Empty recipient lists deny everyone; omitted lists impose no additional filter.
UI labels are bounded and sanitized. An existing `titleKey` resolves on the
client with plain title fallback. Arbitrary provider properties stay on the
server and can be retrieved through its API; they are never sent as raw JSON.
No database migration or schema regeneration is needed for these extension fields.

`kill_zombies` requires an explicit positive target. Other types default to a
target of one for display if omitted, but are `unsupported` until a server handler
registers them. Boss/rescue/collection/territory handlers are not implemented by
this feature. Unsupported or unresolved objectives cannot complete themselves.

## Server authority and progress rules

`ApocExtractionMapUtils_Objectives/Service.lua` owns the accepted event, private
definitions and counters in server memory. Character ModData and client commands
are never used as progress evidence. The only client command accepted by this
protocol is `RequestSnapshot`; attempts to submit counters are ignored.

- Player scope uses canonical authenticated username, retaining progress across
  character death/client reconnect/online-ID changes during the same server run.
- Team scope uses server-resolved `Faction.getPlayerFaction(player):getName()`.
  No faction means `unavailable`. Leaving a faction changes the view to the new
  faction's counters, never transfers the old faction's progress.
- Event scope shares a counter among eligible participants.
- Dependencies must be supported, visible to the actor and at target before
  progress can be credited. Evaluation occurs on the server at credit time.
- Missing referenced Regions geometry produces `unavailable`; it never silently
  becomes a global objective. Region geometry is resolved during preparation.
- With no region references, a kill objective is global. Otherwise a death must
  be in at least one referenced rectangle, including its configured Z range.
  XY/Z use tile coordinates and inclusive bounds.

`Kills.lua` consumes server `OnZombieDead`, validates the attacked-by player
against the server's live online-player object, and captures death coordinates
plus username/faction. It queues primitives, not zombie/player references.
Thus an already-confirmed kill survives disconnection before queue processing
and contributes to the faction held at death. Weak zombie-object deduplication
is cleared by `OnZombieCreate` for pooled incarnations. This uses the engine's
server-resolved death attribution; it does not independently prove every kind
of fire/vehicle kill. Unattributed/nonplayer deaths are not credited.

Kill processing is bounded to 64 objective evaluations or two milliseconds per
tick, with a maximum 2048 pending deaths. Overflow increments
`ApocExtractionMapUtils.Objectives.metrics.droppedKills` and emits a debug log
when debug logging is enabled. This explicit overload limit needs live load
testing; normal processing performs no zombie or terrain scans. Population
maintenance remains a separate future Regions responsibility.

## Server API for other handlers

```lua
local service = require "ApocExtractionMapUtils_Objectives/Service"
service.registerType("defeat_boss") -- install only alongside the actual server handler
local definition = service.getDefinition(eventId, "commander_objective")
service.setProgress(eventId, "commander_objective", actualPlayer, 1)
service.increment(eventId, "another_objective", actualPlayer, 1)
```

These are trusted server-Lua APIs, not remotely callable commands. Updates check
event identity, live player identity, recipient eligibility, scope, prerequisites,
installed type and bounded integer progress, and clamp to the target. The
internal `captureSubject`/`creditKill` path is reserved for server death evidence.
`getDefinition` returns a copy, including server-only extension properties.

`EventRuntime.finish(eventId)` detaches objectives and causes subscribers to
receive an empty replacement snapshot. Duration is still informational and
does not automatically finish an operation. Backend cancellation retains the
existing release-only meaning; no automatic rollback/rearm was introduced.

A newer definition revision replaces the plan. Counters survive only for
exactly unchanged objective plans within the same event UUID. Changes to an
objective's type/target/scope/geometry/properties/references/recipients reset
that objective; new event UUIDs start fresh. Even a label edit in the objective
plan resets that row. Changing only event-level heading/visible-row settings
retains unchanged objective counters. Old queued deaths do not cross revisions.

**Server process restart persistence is not implemented.** Client reconnect is
supported while the server holds the active event. A release receipt cannot
reconstruct lost definitions/progress after restart; durable storage/resume is
a separate requirement before promising restart recovery. Receipt replays still
do not start a new round or reset counters.

## Targeted versioned synchronization

The command module is `ApocExtractionObjectives`, protocol version 1. Clients
request a baseline once ready, even before an event exists, then remain
subscribed for activation, progress, replacement and finish. Requests use bounded
retry/backoff; the server rate-limits each authenticated recipient to one request
per second. `OnClientCommand` supplies the trusted player; supplied username/
counter fields have no authority.

Every server send uses `sendServerCommand(player, ...)`, never the broadcast
overload. POD presentation rows contain only ID, title/key, type, scope, required,
target, count and status. Each packet includes recipient online ID so separate
local-player stores on the same client connection do not consume each other's
messages. There is one active view/stream per connected recipient.

| Command | Contract |
| --- | --- |
| `SnapshotBegin` | New stream ID, echoed request ID, event/definition identity, heading, row count, chunk count, visible limit, version 0 |
| `SnapshotRows` | Indexed chunks of at most 8 rows (at most 16 chunks for 128 objectives) |
| `SnapshotCommit` | Commit version 0 after all chunks arrive |
| `Progress` | Matching stream/event/definition identity, contiguous from/to progress versions, at most 8 changed absolute totals/statuses |
| `Heartbeat` | Idle sequence watermark after 10 seconds without a data send; detects a lost final update without sending a catalogue |

Definition revisions and recipient progress versions are independent. Each new
snapshot has a unique stream ID and resets its progress sequence to zero.
Repeated/stale updates are ignored. A gap, invalid update or mismatched future
identity requests a new snapshot. Chunk assembly is bounded, accepts reordered
chunks/early commit, rejects conflicting duplicate chunks and times out after
30 seconds. The client atomically installs definitions and progress together.
Requests carry a new token, so responses from a prior connection/request cannot
overwrite the new replica. Partial snapshots never replace the visible baseline.

The server coalesces changes through per-recipient comparisons no more often
than every 500 ms, with four bounded recipient jobs/messages per tick. Unchanged
data/audiences reuse their cached projection rather than rebuilding it while idle. Each
projection is capped by the schema's 128 objectives. Unchanged private views
receive no progress packet when someone else's personal counter moves. Faction/
eligibility and definition identity are rechecked before every queued packet,
including snapshot chunks; a changed audience invalidates the old job. Offline
sessions are removed and references released. No online-player/world scans or
catalogue broadcast are performed per kill.

## Client store and UI

`Store.lua` contains only the replicated state, packet validation, cached visible
selection/completion totals and a bounded notification queue. It never counts
kills or sends evidence. `Network.lua` owns retries, requests and recipient
routing for up to four local-player slots.

`Tracker.lua` creates one mouse-transparent HUD per local player. It shows an
event heading, required-objective completion summary, bounded objective rows, server counters,
scope/status, checkboxes and smoothly interpolated bars. The full 128-row list
is scrollable, while only 1-8 viewport-appropriate rows are rendered. Press **O**
to toggle move/scroll mode for the primary local player; wheel scrolling and
dragging are enabled only in that mode. Per-panel `setEditing` is also available
to future split-screen/controller controls. Position is stored in local character
ModData without transmitting gameplay state.

Selection, clipped labels, counters and layout rebuild on replicated-data,
scroll, font or viewport changes. Optional rows remain visible and are marked optional, but do not block
the required-objective summary. Unchanged frames do not scan the objective
catalogue or repeat text measurement. Only visible row interpolation and at most
four completion cards are animated. Empty/dead-player panels collapse and stop
taking input. UI creation replaces stale UI-manager attachments on reconnect.

Completion notifications come only from a live transition to complete. Snapshot
installation silently establishes the baseline and clears queued cards. Logging
in, changing factions, resynchronizing or reconnecting never generates a card
for every objective already completed while the player was absent. UI labels
use existing EN `IG_UI.json` with namespaced keys; no external assets are needed.

## Verification

Run from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/objectives-sync.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/objectives-ui.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/event-runtime.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/event-definitions.lua
```

The synchronization fixture exercises production prepare/service/sync/kill/client
code, scoped recipients, no client authority, chunk assembly, versions/gaps,
reconnect/online-ID change, quiet baselines, faction change during transfer,
death attribution/geometry/Z/duplicate/pooling, custom server APIs, revision
migration, explicit finish, 128 rows and packet budgets. UI tests verify bounded
rendering, cached layout/text work across unchanged frames, scrolling, scaling,
mouse transparency, death/recreation and idempotent client startup. Existing
runtime/intake/lobby/RCON regressions remain applicable.

These fixtures stub engine objects/packets/ISUI. Actual dedicated-server/client
rendering, key conflicts with other mods, split-screen routing, faction updates,
fire/vehicle attribution and load/queue metrics still require in-game validation.
No live deployment or operation activation was performed during implementation.


Executed successfully for this change: `tests/objectives-sync.lua` (1058
production-path assertions, including targeted packet/work budgets),
`tests/objectives-ui.lua` (17 UI/store/lifecycle assertions),
`tests/event-runtime.lua` (34), `tests/event-definitions.lua` (90), the existing
lobby-perimeter harness with the real RCON extension dispatcher, login/maps,
map-reveal-server and cartography harnesses. Generator consistency, AJV strict
validation of the kill example, guide translation checks, new UI translation
references/JSON, UTF-8 without BOM, documentation paths and `git diff --check`
also passed. Packet/ISUI fixtures use stubs; these results do not assert live
multiplayer rendering, measured server performance or process-restart recovery.

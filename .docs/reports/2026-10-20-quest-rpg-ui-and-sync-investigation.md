# Quest RPG UI extraction and objective synchronization investigation

Date: 2026-10-20. Status: local source investigation and proposed implementation
boundary. No Quest RPG files copied, gameplay/network code changed, or live PZ
test performed. Existing Extraction working-tree changes preserved.

Source inspected:
`Z:/SteamLibrary/steamapps/workshop/content/108600/3794041246/mods/Quest RPG/42.20.4/`.
Its `mod.info` identifies `QuestSystem`, author `Parrish_FR`, modversion `1.0` and
minimum game `42.0.0`. The versioned source folder is 42.20.4; this is not proof
of live compatibility with the test server's 42.21.0 engine. Engine command
signatures below were checked against 42.21.0 decompiled source.

Related: [event runtime scaffold](../features/event-runtime-scaffold.md),
[event definition schema](../features/event-definition-schema.md).

## What Quest RPG actually does

Quest definitions and player progress are separate:

- `shared/QuestSystem_Shared.lua` builds an indexed quest book from text quest
  definitions. `QS.get(id)` resolves definitions; `QS.all()` returns ordered
  definitions. Its existing `registerQuest`/`registerQuests` extension API accepts
  its own text format, not our JSON schema or a presentation-only view model.
- `QS.data(player)` stores character state in `player:getModData().QuestSystem`.
  `active[questId]` holds acceptance time and `prog[objectiveIndex]`; `track`,
  `trackOff` and `hud` store presentation preferences. Active progress belongs
  to the character; completion history is separately keyed by username (or a
  singleplayer key) in global state. Death and account history have deliberately
  different semantics. We must choose our own death/reset policy explicitly.
- Client `QuestSystem_Tracking.lua` registers event hooks and a player update
  handler throttled to 400 ms. It updates personal counters locally. Zombie
  deaths feed a nearby-death/type queue; differences in `getZombieKills()` are
  matched with that queue. Other hooks cover crafting, building and other deeds.
- `bump(...)` centralizes clamping, dirty marking and completion feedback. It
  generates objective-complete/quest-ready toasts rather than doing that in the
  renderer. The server validates hand-in rules against available state, but
  personal progress and some shared contributions originate on clients.

This is not a server-owned objective tracker with a passive client. Its gameplay
tracking, client ModData upload and text-definition parser should not be brought
over merely to make its UI work.

## Login, synchronization and live progress

Relevant entry points, relative to the inspected `media/lua` directory:

| File / entry point | Behavior |
| --- | --- |
| `client/QuestSystem_Init.lua:onGameStart` (180) | Clears board-received state and old windows, creates toast/tracker, requests the board |
| `client/QuestSystem_Client.lua:C.askBoard` (81) | Sends `requestBoard`, optionally with the already-received board revision |
| `server/QuestSystem_Server.lua:requestBoard` branch (about 2360) | Replies to the requesting player with `boardReset` or `boardSame` |
| `client/QuestSystem_Client.lua:onServerCommand` (1647) | Applies snapshots, shared updates and completion responses |
| `client/QuestSystem_Client.lua:C.applyBoard` (103) | Replaces the definition catalogue, rebuilds indexes and refreshes UI |
| `client/QuestSystem_Client.lua:C.applyShared` (195) | Installs authoritative shared/depot counters received with the board |
| `client/QuestSystem_Client.lua:C.flush` (42) | Coalesces dirty character ModData transmission to about two seconds |
| `client/QuestSystem_Client.lua:C.flushShared` (1186) | Batches contributions by quest/objective before sending `shareProgress` |
| `server/QuestSystem_Server.lua:onShareProgress` (1887) | Adds eligible shared contributions and broadcasts changed absolute totals |

On login, the client explicitly asks for a snapshot rather than waiting for a
future world-state broadcast. The journal asks again when opened. The search
found these triggers and a legacy-change fallback, not an ongoing exponential
retry loop for the initial request.

The server response includes definitions as `lines`, preferences, `rev`, and
the recipient's completion history/standing/squad/shared state. If the client's
definition revision already matches, `boardSame` sends records without repeating
all definition lines. `pushBoard` increments that revision and broadcasts a
replacement board after edits. It is a complete replacement, not a merge that
would retain removed definitions.

The client applies records/settings/definitions/shared state in an explicit order
and calls `refreshUI`. The code also receives `OnReceiveGlobalModData` and can
rebuild from global ModData transmissions. Quest RPG therefore uses **both
commands and ModData**, not commands alone. Server board/history files provide
additional persistence recovery; those backups are part of its quest engine,
not dependencies required by the HUD's drawing code.

Personal progress is uploaded using `player:transmitModData()`, coalesced through
a dirty flag; deliberate accept/abandon/hand-in actions flush immediately. Shared
progress is different: clients accumulate contributions for two seconds, the
server adds them to shared state, then sends `sharedProgress {id,group,prog}`.
`prog` contains changed absolute totals, not the entire catalogue. That packet
is broadcast and each client filters its group. The shown progress handler has
no per-update sequence/version guard. We should add one and target actual
recipients in our implementation rather than broadcasting team/private changes.

## UI files worth extracting

All files below are under `media/lua/client` in the reference mod.

| Source | Useful portion | Dependencies to replace/remove |
| --- | --- | --- |
| `QuestSystem_UI_Tracker.lua` (20 KB) | HUD objective rows, checkboxes, animated bars, title/counters, drag/position behavior; optional top event banner | `QuestSystem_Client`, `QS.data/get/all/progressOf/objectiveDone/isComplete`, quest conditions/hand-in/compass and journal coupling |
| `QuestSystem_Theme.lua` (34 KB) | Palette, text metrics/clipping, gradients, progress bars, checkboxes, elapsed-time animation | Rename globals; retain only needed primitives; strip unused category/tooltip/icon features |
| `QuestSystem_UI_Toast.lua` (6 KB) | Small animated notification overlay with bounded queue | Theme/category helpers, translation names, lifecycle integration |
| `QuestSystem_UI_Widgets.lua` (78 KB) | Optional later extraction of button/list/objective detail drawing | Much of the file depends on Quest RPG's quest model, explanations, portraits, rewards, conditions and map features |
| `QuestSystem_UI_Journal.lua` (59 KB) | Optional later journal layout/selection shell | Requires widgets, guide, codex, squad, client actions and much more; unsuitable as the initial isolated import |

Start with the first three as **adapted, renamed derivatives**, not unchanged
files. A source `require "QuestSystem_Client"` would import the original client
engine, which in turn requires the very large shared quest implementation. Keep
our own namespace/ISUI class names so neither installation nor accidental global
collisions depend on Quest RPG being absent.

The inspected media tree contains Lua, JSON translations and text configuration;
no custom image files were found. Most visual drawing is rectangles/lines. Theme
icon helpers can reference vanilla textures, but the tracker/toast core does not
require an imported portrait/texture pack. Extract relevant translation keys
under our namespace and follow the project's B42 JSON translation conventions.

No local license/README granting redistribution was found in the inspected
Workshop item. Preserve source provenance/author attribution and establish the
reuse terms before redistributing copied implementation; this investigation
has not copied its code or made a licensing determination.

## Behavior and efficiency worth keeping

- The HUD renders one pinned quest, falling back to the first active one unless
  the player explicitly chose to stop tracking. Its event banner can show shared
  event totals separately. This fits an event heading with multiple objective
  rows; we need not manufacture a separate original-format quest for every row.
- Bars ease to authoritative targets using elapsed time. Checkbox/counter/ready
  feedback works without repeatedly creating panels.
- HUD mouse handling is disabled during play. Dragging becomes available while
  the journal is actually visible, derived each frame rather than a sticky flag.
  Empty panels collapse to height zero. This avoids invisible UI blocking clicks.
- Toasts share one mouse-transparent overlay and retain at most four entries.
- UI manager attachment is renewed on game start, saved position is restored,
  and resolution changes clamp/update positions. This avoids stale Lua panels
  surviving a UI-manager reset after reconnect.
- Font heights are measured once; clipping uses binary search and avoids cutting
  UTF-8 continuation bytes. Animation timing is shared across panels.
- Event-banner membership is cached for 500 ms. Quest definition lookups use an
  index; UI refresh happens on data changes.

These are useful patterns, not proof that the entire mod is optimized for our
scale. Tracker `currentQuest()` can scan `QS.all()` in both prerender and render
when no valid pin exists. Completion/progress/layout calculations recur during
rendering. The event banner caches membership, but calculates percentages while
drawing. Widget rendering checks every layout row for visibility rather than
using a visible-range index. The original tracker has no pagination appropriate
to our maximum 128 objectives. Its globals and `getPlayer()`/index-zero checks
also center on the primary local player; split-screen requires explicit design.

Our view model should cache selection, layout, labels, completion and totals
when definitions/progress/preferences/scale change. Only visible rows, bar
interpolation and optional lightweight compass display should need per-frame
work. No world scans or network calls belong in prerender/render. Bound visible
rows and add scrolling/pinning rather than allowing 128 rows off screen.

## Proposed Extraction integration (not implemented)

```text
Validated event definition
    -> Objectives.prepare: build event-scoped objective plan
    -> confirmed runtime activation
    -> Objectives.activate: attach plan to authoritative ObjectiveService
    -> server progress handlers: update counters and mark changed IDs
    -> server ObjectiveSync: snapshot / coalesced updates
    -> client ObjectiveStore: validate and atomically install data
    -> adapted tracker / optional banner / toast / later journal
```

`Objectives.lua` should be the lifecycle adapter, not the networking dispatcher
or renderer. Its current `prepare` returns only an objective array and has no
`activate` method. Before wiring this, retain event identity/revision with the
plan or extend the runtime's module context; do not infer identity from whichever
`getLatest()` record happens to exist when a packet is built. Prepare must not
send active quests to players before release-confirmed activation.

Suggested server-only API responsibilities:

- `attachEvent(eventContext, objectives)`: retain shared definitions once and
  initialize the accepted event's handlers/state.
- `setProgress(eventId, objectiveId, owner, absoluteValue, status)`: called by
  authoritative gameplay handlers; clamp/check completion and mark a change.
  A delta-style internal API may be useful for server-confirmed zombie deaths.
- `snapshotFor(player)`: project definitions and current player/team/event state
  relevant to that actual server-resolved player.
- `detachEvent(eventId, reason)`: send removals/end state and release queues/
  references after an explicit lifecycle decision.

The API names are proposals, not existing callable functions. Server-owned
definitions and per-player/team/event counters should be separate stores; do
not copy the full definition catalogue into every player's record. Stable
objective IDs, event UUID and explicit definition revisions replace the source
mod's numeric objective indexes. Changes to a definition revision need a
deliberate progress migration/reset policy; revision alone is not a new round.

Suggested command module: `ApocExtractionObjectives`, separate from the original
mod's `QuestSystem`. This is a proposed protocol:

| Direction | Command | Meaning |
| --- | --- | --- |
| Client -> server | `RequestSnapshot` | Client UI is ready; supplies known protocol/definition/state versions, never counters or a trusted player identity |
| Server -> client | `Snapshot` | Recipient-visible definitions and absolute progress, event identity, definition revision and state version |
| Server -> client | `Progress` | Batched changed objective IDs with absolute values/status, event/definition identity and from/to state versions |
| Server -> client | `EventEnded` / replacement snapshot | Explicit teardown/removal; clears old tracker rows |

Maintain definition and progress versions separately. Repeated absolute updates
are idempotent; drop old versions and request a fresh snapshot on gaps or
definition mismatch. Commit a snapshot atomically so a renderer cannot combine
new definitions with old progress. Large snapshots require byte/item budgets,
bounded chunk assembly and a commit/version boundary; schema size limits alone
do not guarantee that a network table will fit in one packet.

On login/reconnect, the client resets server-specific data, creates the UI once
the player/UI is ready, then requests a snapshot with bounded retry/backoff.
Server `OnClientCommand` supplies the actual player object used for scope checks.
Serve current counters as well as definitions even when definition revisions
match. Push the event to players already online at activation; login is not the
only delivery point. Allow progress received before UI construction to populate
the store, then build the panel from it. Reconnect snapshots should not replay a
toast for every objective already completed while offline.

Batch dirty objectives, for example over a measured 0.5-2 second window, with
global work/message/byte budgets and bounded resumable recipient traversal.
Completion/activation can request an earlier flush within those budgets. Send
player scope to its owner, team scope to subscribed team members, event scope
to eligible event participants. No full catalogue broadcast per kill, periodic
snapshot polling, or per-player OnTick objective scans. Team membership and
death/reconnect transitions require explicit resnapshot/ownership handling.

The client presentation API should expose snapshot/update/removal operations
on its own store and return a cached tracked-quest view to the HUD. Personal
pin/position/visibility preferences can remain local. The server owns progress;
the client owns only rendering/animation and presentation choices.

The runtime currently has only in-memory preview state, and receipt replays do
not reactivate it. This proposed UI sync can serve online clients from an active
in-memory event, but durable restart recovery requires saved event definitions
and progress plus a resume lifecycle. The original lobby release receipt alone
cannot restore objectives. Do not label the preview scaffold as an active quest
service merely because the UI can render it.

## Verified engine transport and validation scope

`42.21.0/decompiled/zombie/Lua/LuaManager.java` exposes targeted
`sendServerCommand(player,module,command,args)` and client requests via
`sendClientCommand(player,module,command,args)`. `GameServer` dispatches
`OnClientCommand(module,command,player,args)`; `GameClient` dispatches
`OnServerCommand(module,command,args)`. No new Java patch is needed for this UI
transport. Its local-player targeting/routing still needs runtime validation,
especially for multiple local players sharing a connection.

`network/TableNetworkUtils.java` serializes supported table values recursively.
Build bounded presentation DTOs containing explicit primitive values/tables.
Do not send the schema decoder's null sentinel/metatable semantics, functions,
runtime objects, Regions engine handles or the entire private event metadata.

Validation performed: inspected local files/symbols/call paths and engine command
bindings. No gameplay tests, profiling, UI rendering or packet tests were run;
this change is documentation only. Before implementation, agree on initial HUD
scope (recommended tracker/toast first), progress ownership/death policy and
the snapshot/update contract. Future tests should cover login with an already
active event, reconnect, activation while online, out-of-order/duplicate/gapped
updates, objective removals, team changes, UI reload/scale, row limits and UTF-8.

# Event runtime and modular handlers

Status: implemented runtime with authoritative objectives; other world handlers
remain previews. See [objective tracking](objective-tracker.md) for the server
service, recipient protocol, real zombie-kill handler and client UI.

## Activation order

`EventDefinitions.onEventDue` retains an authorized, validated record in `latest`
and passes a copy to `EventRuntime.acceptDefinition`. Modules prepare in this
fixed order: Notification, Gameplay, Regions, Bosses, Objectives. Schema or
authorization failures do not reach preparation. A failed preparation marks the
runtime failed and prevents module activation. Intake retains the valid record;
runtime errors do not acknowledge or prevent existing lobby release behavior.

`Lobby.releaseForEvent` calls `EventRuntime.confirmRelease(id, revision)` after
the bridge acknowledges release successfully. A prepared definition and a
matching due release are both required. A pending latch supports either Lua
listener order. Confirmation is desired-state acceptance, not proof that all
queued/unloaded fence work is complete. Manual RCON exit release does not start
these modules. With lobby control disabled, preparation can occur but no
release-confirmed activation is performed.

States are `preparing`, `prepared`, `activating`, `in_progress`, `failed` and
`finished`. Mode is `objectives`: objectives are authoritative, while gameplay
selection, region policy changes and boss spawning still only print previews.
`Objectives.activate` attaches the server-owned plan and subscribers receive it;
the Notification module's console message alone is not gameplay activation.
`EventRuntime.finish(eventId)` detaches the objective service and marks the
runtime finished, causing an empty snapshot to clear client trackers.

Duplicate ID/revision delivery does not rerun modules. Older revisions or
conflicting identity at the same revision cannot replace current state. A newer
accepted revision prepares/activates a replacement plan; objective counters are
migrated only when that objective's plan is unchanged within the same event UUID.
Receipt replay is logged but never starts a new round. Module failures have no
automatic retry for that revision. Duration is informational, not an implicit end.

State remains in memory. Player reconnect uses the live server objective state;
server process restart recovery is not implemented. Durable round state,
receipt-to-save recovery, cancellation/rollback, and rearm still need their own
contracts before promising full multi-round recovery.

## Files and module interface

Runtime files live under
`ApocalipseBR-ExtractionMapUtils/common/media/lua/server/`:

```text
ApocExtractionMapUtils_EventRuntime/
  Runtime.lua
  Diagnostics.lua
  Modules/
    Notification.lua
    Gameplay.lua
    Regions.lua
    Bosses.lua
    Objectives.lua
ApocExtractionMapUtils_Objectives/
  Service.lua
  Sync.lua
  Kills.lua
ApocExtractionMapUtils_ObjectivesServer.lua
```

The runtime is `ApocExtractionMapUtils.EventRuntime`; `getSnapshot()` returns a
copy of event identity, status and module plans. These are trusted server Lua
APIs, not client commands. Each module has a unique `name` and
`prepare(record) -> planTable`; optional `activate(plan)` handles confirmed
release. Register modules in the ordered list in `Runtime.lua`. Inputs/retained
plans/activation arguments are copied. Do not poll `getLatest()` from modules.

| Module | Behavior |
| --- | --- |
| Notification | Console preparation/activation messages |
| Gameplay | Previews game type/ruleset/duration/event properties |
| Regions | Read-only existing-region lookup and proposed policy preview |
| Bosses | Previews `entities` with `type="boss"`; no spawn |
| Objectives | Builds the UI/server contract, then activates authoritative progress/synchronization |

The Regions preview adapter reads
`RegionManager.Server.registeredZones[regionId]` and reports resolved, missing,
unavailable or inline-preview bindings. It does not call admin mutation APIs or
edit the persistent region file. The Objectives adapter separately resolves
geometry for regional kills; unresolved references are unavailable, not global.
Zombie population control and runtime PvP policy overrides remain unimplemented.
Bosses use the schema's entities collection, not an extra top-level bosses field.

## Validation and diagnostics

Runtime diagnostics keep the existing `[ApocExtractionEventRuntime][preview]`
prefix for the remaining preview modules; that prefix does not describe the
objective service's authority. Emission follows the mod's existing `debugLog`
sandbox setting. Payload previews are bounded/sanitized. The client tracker is
independent of debug logging.

The existing [schema example](../../contracts/examples/event-definition-v1.json)
contains future handlers, shown as unsupported by the tracker until installed.
For a working first objective use the
[kill tracker example](../../contracts/examples/objective-tracker-kills-v1.json),
with valid configured region geometry. Only paste its `parameters` object in
the website JSON editor. See [the objective guide](objective-tracker.md) for UI
properties, recipients and in-game controls.

Run `tests/event-runtime.lua`, `tests/event-definitions.lua`,
`tests/objectives-sync.lua`, `tests/objectives-ui.lua` and the existing
`tests/lobby-perimeter.lua` RCON integration through Fengari. Fixtures cover
listener ordering, copies, failed acknowledgements, replay/idempotence,
recipient authority and client synchronization. They mock engine boundaries;
actual PZ autoload, multiplayer and rendering remain to be checked in game.
No live deployment was performed.

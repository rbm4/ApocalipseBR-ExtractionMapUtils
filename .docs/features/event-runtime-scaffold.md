# Event runtime and preview modules

Status: implemented scaffold; awaiting live dedicated-server validation. All
modules run in **preview mode** and write console diagnostics. No objective,
population, boss spawning, PvP override or player notification UI is implemented.

## Entry points and activation order

`EventDefinitions.onEventDue` retains the authorized, validated record in
`latest`, then calls `EventRuntime.acceptDefinition` with a defensive copy.
The runtime prepares modules in a fixed order: Notification, Gameplay, Regions,
Bosses, Objectives. Failed schema/authorization checks never reach this handoff.
An exception in a module marks the preview failed and stops downstream modules.
Intake still retains its valid record; runtime failure does not acknowledge or
prevent the existing perimeter release.

`Lobby.releaseForEvent` calls `EventRuntime.confirmRelease(id, revision)` only
after `ApocBREventControl.acknowledgeRelease` succeeds. The runtime also checks
the bridge's current `isDue` identity. A matching prepared definition plus this
confirmation triggers activation preview. Either listener can run first; a
single pending confirmation handles the order. The lobby protects this callback
with `pcall`, so a preview error cannot undo an accepted release.
Confirmation means accepted perimeter-removal intent, not completion of all
queued or unloaded terrain work.

States are `preparing`, `prepared`, `activating`, `preview_active`, and `failed`.
`preview_active` means a successful mock dispatch, not a playable event with
working rules. Successful parsing alone leaves the event `prepared`. With lobby
control disabled or unsuccessful acknowledgement it remains prepared; no
activation notification is printed. Manual RCON exit release does not activate
this runtime.

Repeated ID/revision deliveries do not repeat preparation or activation. Older
revisions and conflicting identities at the same revision cannot replace the
preview. A newer validated revision replaces it; this is safe only because
modules have no gameplay effects. Receipt replays print a bounded diagnostic
but do not start modules, even with matching metadata. Receipt-only replays
remain ignored by intake. Failed modules have no automatic retry for that revision.

The scaffold keeps **one preview and one pending release in memory**. It does
not persist active rounds, progress or module effects. Durable restart recovery,
stop/cancel/rearm, rollback and cleanup must be implemented before replacing
mock handlers with world mutations. A restart receipt cannot synthesize a new round.

## Folder and extension interface

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
```

The orchestrator is exposed as `ApocExtractionMapUtils.EventRuntime`.
`getSnapshot()` returns a defensive copy of event ID/revision, mode, status and
module plans. These are trusted server-Lua APIs, not network commands. Nothing
is broadcast or placed in client-requestable global ModData.

Each module returns a unique `name` and `prepare(record) -> planTable`. Optional
`activate(plan)` handles the confirmed-release phase. Add modules to the ordered
list in `Runtime.lua`. Inputs, retained plans and snapshots are copied to isolate
modules and callers. Modules select relevant parsed values; future providers
must also validate their own semantics. No module polls `getLatest()` or installs
an OnTick handler.

| Module | Current preview |
| --- | --- |
| Notification | Prints event preparing, then event activating after release confirmation; server console only |
| Gameplay | Reads game type, ruleset, informational duration and event properties |
| Regions | Resolves registered IDs and prints proposed geometry/PvP/population/tags/properties |
| Bosses | Selects `parameters.entities` with `type="boss"` and prints their bounded definition |
| Objectives | Prints type, scope, target, required flag, references, dependencies and properties |

Bosses use the existing entities collection, not a new `bosses` field. Other
entity types are logged as awaiting future providers. Unknown gameplay/objective
types can be previewed; that does not claim their handlers exist.

The Regions adapter reads optional
`RegionManager.Server.registeredZones[regionId]`, the authoritative registry
populated by the Regions server module. This is read-only integration with its
existing contract; no generic event API exists there yet. Do not call its admin
`addHotRegion`/`updateHotRegion` methods to preview data. Bindings report
`resolved`, `missing_region`, `provider_unavailable` or `inline_preview`.
External bounds/Z/properties and requested policies remain separate. No registry,
engine zones or `RegionManager_Regions.txt` are modified. Missing providers/IDs
are diagnostic here; real application must reject unresolved requirements.
No dependency/packaging change is needed for this optional preview.

## In-game validation and bounds

Use the existing [schema example](../../contracts/examples/event-definition-v1.json).
Paste only its `parameters` object in the website editor, and set game type,
ruleset and duration in their existing fields. Schedule a new operation on the
test world with the bridge enabled, V14 applied and lobby control enabled for
the release-confirmed phase. No synthetic event is automatically injected.

Enable `ApocExtractionMapUtils.debugLog=true` in the server sandbox first.
Look for `[ApocExtractionEventRuntime][preview]` in the dedicated-server log.
Each line identifies Notification, Gameplay, Regions, Bosses, Objectives or Runtime.
The final Notification line says `Event activating` and explicitly identifies
console-only notification/mocked gameplay. Receipt replay has its own diagnostic.

Diagnostics sanitize control characters and cap strings, recursion, fields and
line size; large properties are omitted/truncated. Distinct previews log once,
duplicates are suppressed. Work uses the schema bounds (64 regions, 64 entities,
128 objectives) once per definition. There are no terrain/zombie/player scans
or per-tick jobs. This is not a measured performance guarantee or population scheduler.

## Verification

Run from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/event-runtime.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/event-definitions.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
```

The runtime harness passes 34 assertions covering intake-to-module routing,
provider resolution/absence, nested properties, copy isolation, confirmation
ordering, duplicates/replays, revision replacement, failure containment, empty
definitions and bounded diagnostics. Intake retains its 90 passing assertions.
The perimeter regression verifies notification only after successful
acknowledgement; the actual RCON dispatcher integration also passes.

Login/maps, map-reveal-server and cartography regressions also pass. Fixtures
mock the engine/Regions registry. PZ auto-load order, website dispatch, live
registry readiness and log output still need dedicated-server validation.
No live event activation or deployment was performed.

Related: [definition schema](event-definition-schema.md),
[event bridge](postgresql-event-control.md), [lobby perimeter](lobby-perimeter.md).

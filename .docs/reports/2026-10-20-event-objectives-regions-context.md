# Event objectives, region population and moodles investigation

Date: 2026-10-20. Status: source investigation and implementation proposal;
no gameplay implementation, deployment, live database access or benchmarks.
Extraction HEAD: `5611e51`, with existing uncommitted work preserved.
Regions HEAD: `ebe3f34`. Region implementation target: `42.18` (latest mod
folder); the existing event bridge and engine evidence below target game
`42.21.0`. Confirm the running build before changing Java.

Related feature: [PostgreSQL event activation](../features/postgresql-event-control.md).

Follow-up: the subsequent v2 bridge now transports metadata as a third hook
argument. The [event definition schema](../features/event-definition-schema.md)
implements bounded Lua parsing. The transport-gap observations below describe
the earlier source state; population and gameplay work remain proposals.

## Verified current data flow

1. The manager's `/admin/operations` form stores an operation in its app database.
   `Operation` has `gameType`, `ruleset` and `parametersJson` (`parameters_json`).
   The documented parameters field accepts a JSON object, limited to 16000
   characters. This is the existing input location for future objective data.
2. `OperationSyncWorker` / reconciliation publish release intent through
   `JdbcLobbyEventControl.publish(scope, eventId, name, startsAt, state)` to
   `player_rel.lobby_event_control`. This boundary does NOT publish game type,
   ruleset or parameters. Separate guide columns contain announcement data.
3. Patched Java `ApocBREventControl.READ` polls that scoped row in a background
   worker (default two seconds), hands an immutable snapshot to the server main
   thread and exposes cached Lua getters. No metadata column/getter exists.
4. Java dispatches `Events.OnApocBRLobbyEventDue(eventId, revision)`. There are
   exactly two arguments; no metadata table or JSON is passed.
5. Extraction `Lobby.onStarted()` subscribes `Lobby.releaseForEvent`. That method
   validates `isReleaseAuthorized`, persists perimeter-removal intent and event
   identity, queues world work, then calls `acknowledgeRelease`.

Source roots:

- Manager: `Z:/git/Github/apocalipsebr-manager/manager`; see `docs/operations.md`,
  `domain/entity/app/Operation.java`, `infrastructure/adapter/JdbcLobbyEventControl.java`
  under `src/main/java/com/apocalipsebr/zomboid/server/manager/`.
- Engine patch: `Z:/git/Github/apocalipsebr-zomboid-patches/42.21.0/`;
  `src/zombie/apocalipse/events/ApocBREventControl.java` and `LOBBY-EVENT-CONTROL.md`.
- Mod: `ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_Lobby.lua`.

The RCON extension is a different path: server messages are relayed by clients;
subscribers receive a string payload. Scheduled activation uses the trusted Java
bridge and needs no connected relay. Do not feed objectives through RCON merely
because it can carry strings.

## Lifecycle gap

The existing hook means release authorization, not a complete event lifecycle.
It retries and also replays a durable prior release receipt after restart, even
if desired intent was cancelled/cleared/replaced. It must not reset objectives
or create a new active round on every invocation. Estimated duration in guide
data is informational; there is no authoritative end/completion/rearm protocol.
The manager can publish the next occurrence while the previous event is active.
The latest desired row therefore cannot be the sole storage of active metadata.

Proposed foundation: a separately versioned event specification with bounded
JSON, schema version, event identity and immutable definition revision/hash.
Publish identity and specification atomically; reject same-revision changes.
Java parses/validates off the simulation thread and exposes a matching cached
specification. Extraction validates supported objective types and region IDs,
then persists the accepted definition and progress together in world state.
Keep active state distinct from pending schedules. A replay resumes saved
progress. Missing/invalid specifications must never silently start an objective.
Define explicit finish/cancel/replacement semantics before adding round reset.
Metadata retention must cover recovery; a receipt containing only ID/revision
cannot reconstruct a lost objective specification or unsaved progress.

## Regions: reusable foundations and missing work

`Z:/git/Github/apocalipse-br-regioes/Apocalipsebr-regions/42.18/media/lua/`:

- `shared/RegionManager_Config.lua`: categories and example definitions.
- `server/RegionManager_Server.lua`: loads `RegionManager_Regions.txt` via game
  file APIs relative to Zomboid data, merges category defaults and
  `customProperties`, registers zones and handles admin edits.
- First category defining a property wins; custom properties override it.
- `RegionManager.Server.registeredZones[id]` holds definition, merged
  properties, engine handle and inclusive XY bounds. Definition has `z`;
  existing client membership uses XY only. New objective/population code must
  explicitly define Z semantics rather than inherit that ambiguity.
- `AllZoneBoundaries` is cached and contains a selected property list plus raw
  custom properties/categories; it does not send every merged category property.
  Moodle display needs explicit resolved, public property descriptors.
- `client/RegionManager_Client.lua` builds a 256-tile spatial index.
  `RegionManager_ClientTick.lua` offers `registerModule` with entry/exit and
  periodic `onTick(player, currentZones)` callbacks. Its 80-tick interval is
  frame dependent, not a real-time guarantee. State currently centers on
  `getPlayer()` / one previous-zone set; split-screen needs separate handling.
- Server `ZombieHelper.FindRegionsAt` currently scans all registered regions.
  Avoid reusing that full scan in a new high-frequency population path.
- `zombieDensity`, `zombieRespawn` and `noZombies` appear as configuration/type
  declarations; no controller consuming these names was found in latest Lua.
  Existing trait logic is not a regional population maintenance system.

Ownership proposal: Regions owns geometry, loaded-zombie counts, replenishment
policies and region-property moodles. Extraction owns event definitions,
objective state/progress/completion and event UI. A narrow server API attaches
and releases event-owned population policies by event/region ID without rewriting
the persistent base region definition. Overlapping policies require an explicit
precedence rule and shared spawning accounting to prevent duplicate replenishment.

## First objective contract (proposal, not currently accepted input)

```json
{
  "schemaVersion": 1,
  "objectives": [
    {
      "id": "clear_docks",
      "type": "kill_zombies_in_region",
      "regionId": "event_docks",
      "target": 100,
      "scope": "player"
    }
  ],
  "regionPolicies": [
    {
      "regionId": "event_docks",
      "population": {
        "minAlive": 30,
        "maxAlive": 45,
        "minPlayerDistance": 45,
        "refillCooldownSeconds": 30
      }
    }
  ]
}
```

Numbers are illustrative, not measured defaults. Coordinates remain in Regions;
metadata references stable IDs. Objective target and minimum population are
independent. `maxAlive` is a replenisher ceiling, not a guarantee that migration
or vanilla spawning cannot exceed it. Decide player/team/event-wide progress,
death/reset rules, eligible killers and overlap credit before implementation.
Suggested initial rule: zombie death position inside the region and matching
Z, attributable to a valid player; per-player progress persists by stable player
identity (not connection ID). Fire, vehicles and disconnected killers need policy.

Engine evidence in `42.21.0/decompiled/zombie/`:

- `characters/IsoZombie.java:onKilled` fires `OnZombieDead(zombie)` after loot
  initialization. `IsoGameCharacter.Kill` sets attacked-by and guards repeated
  onKilled calls. Network death processing calls `dieNetwork` -> `Kill` too.
- `network/packets/character/DeadCharacterPacket.java` supplies killer identity
  and death location. Consume the server event and server-resolved objects;
  do not accept a client objective counter or treat packet attribution as
  independent proof of every kind of kill.
- Existing Extraction `ApocExtractionMapUtils_ZombieMoney.lua` is a local
  example of server-only death handling and valid connected-player checking.
- Death credit still needs an objective-level duplicate guard and pooled-object
  lifecycle handling. Outfit IDs are not a proven globally unique kill identity;
  online IDs can be reused. Do not persist either alone as a universal death key.

## Population work budgets and safety (proposal)

Count loaded, living zombie objects inside the configured region/Z. Virtual
population is a separate engine system (`ZombiePopulationManager.virtualizeZombie`);
zero loaded objects does not mean the entire unloaded region is empty.
Do not force-load terrain or replenish empty unloaded areas.

Use one shared scheduler with resumable cursors, region/chunk spatial indexing,
hard item/attempt limits AND a small elapsed-time limit per tick. Budgets must
cover nested loops, player checks, indexing, reconciliation, queue cleanup and
spawning, not just the outer region loop. Round-robin regions and apply
cooldowns/backoff. No region-area scan, whole-world list copy or
regions-times-all-zombies pass in one tick. Any global reconciliation traversal
must be shared and spread across ticks; mutable engine lists require handling
index shifts and restarts. Use event hints plus reconciliation rather than
trusting create/death events to account for movement and unloads.

Expose count freshness/coverage; incomplete scans must not be treated as exact
zero. Replenishment should wait for sufficient recent coverage, reserve pending
spawns and revalidate before execution. Rebuild runtime references after restart;
release unloaded/reused objects. Avoid accumulating historical zombie references.
Pause inactive/event-disabled policies; defer when no suitable loaded area exists.

Spawn only a small bounded number per scheduled slice, after candidate validation:
inside the region/Z, live loaded square, floor, no water/obstruction/stairs,
engine `VirtualZombieManager.instance:canSpawnAt(x,y,z)`, and exclusion distance
from ALL relevant players. Player-disconnect/movement and square state require a
final check. Distance is not invisibility; an out-of-sight guarantee needs a
separate verified visibility policy. Avoid enclosed/unreachable candidates;
`canSpawnAt` is a local check, not proof of a route to players.

`LuaManager.GlobalObject.addZombiesInOutfit` returns created zombies, but calls
`createRealZombieAlways` on its chosen square without calling `canSpawnAt`.
The caller must validate terrain. Request one zombie per call, count successful
returns, and stop on failed candidate/spawn budgets. No retry-until-success loop.
Native spawn logging also needs measurement before selecting refill rates.

## Lifestyle moodle findings

Reference:
`C:/Users/ricar/Zomboid/Workshop/apocalipsebr-extras/Contents/mods/Lifestyle/common/media/lua/client/LSMoodleManager.lua`.

Lifestyle creates independent `ISUIElement` instances and places them below
active vanilla moodles. It stores values/levels in player `LSMoodles`, reads
`Properties/MoodleProperties.lua`, respects the moodle size option, draws icons
and translated tooltips, and removes UI on death. It includes MoodleFramework
layout overrides that reserve space for Lifestyle icons. This is visual stack
integration, not new Java vanilla MoodleTypes.

Use the layout concept in a Regions-owned presentation adapter, with explicit
compatibility for Lifestyle/MoodleFramework. Do not assume its manager is a
generic external registration API: properties are module-defined, value access
uses `getPlayer()`, and startup clears `LSMoodles`. Separate player instances,
deterministic ordering, bounded visible indicators, scale/resolution changes and
death/reconnect cleanup need deliberate support. Compute active property
descriptors on region-state changes, not by rescanning zombies in render.
Aggregate overlapping properties consistently. Begin with actual enforced
properties (PvP, sprinter chance, active replenishment), not labels for unused
configuration. Show kill progress in the objective tracker; moodles can identify
the active objective region without creating one icon per counter.

## Implementation sequence and verification

1. Specify/version the metadata transport and lifecycle across manager, runtime
   migration, Java cache and Extraction, preserving the existing release API.
2. Implement persistent, idempotent server objective state and regional kill
   accounting, then client snapshot/delta presentation and reconnect sync.
3. Implement the Regions population scheduler/API with bounded incremental
   accounting, spawn validation, conflict rules and instrumentation.
4. Add Regions public property descriptors and moodle presentation adapters.

Tests should cover replay/restart without reset, mismatched metadata/revision,
invalid/disabled regions, Z/boundary/overlap rules, duplicate deaths and pooled
objects, movement/unload/reload reconciliation, scan incompleteness, global work
limits, no viable terrain, nearby players, failed spawns and policy teardown.
Measure tick cost, reconciliation age, candidate failures and successful spawn
rates on a dedicated server. Test fire/vehicle kills, empty-server activation,
reconnect and Lifestyle/MoodleFramework layout in game.

Validation for this report: local source/document inspection only. No gameplay
tests were run because no runtime behavior changed. Proposed schemas, budgets,
API ownership and edge-case policies have not been implemented or benchmarked.

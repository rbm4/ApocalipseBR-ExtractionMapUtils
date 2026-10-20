# Event definition schema and Lua intake

Status: implemented as a data foundation; awaiting live dedicated-server
validation. No objective, loot, rescue, territory, boss, population or moodle
gameplay handler is implemented by this feature.

Accepted definitions feed the [event runtime](event-runtime-scaffold.md).
Release-confirmed activation now attaches [authoritative objectives and a client
tracker](objective-tracker.md), including regional zombie kills. Other world
handlers remain previews; parsing alone never activates an objective.

## Contract and input

Keep JSON. It already crosses the manager/PostgreSQL/Java boundary, has a
portable schema format and decodes into ordinary Lua tables without executing
source. Changing to Lua text would require a new transport contract and introduce
executable configuration. YAML adds a parser and implicit typing without helping
this existing path. Backend code may use DTOs/builders internally and serialize
the same JSON contract.

The canonical machine-readable contract is
[`contracts/event-definition-v1.schema.json`](../../contracts/event-definition-v1.schema.json)
(JSON Schema draft 2020-12). The
[complete example](../../contracts/examples/event-definition-v1.json) includes
kill, loot, rescue, territory and boss definitions. These type names illustrate
future handlers; parsing them does not mean those handlers exist.

In `/admin/operations`, set game type, ruleset and duration in their existing
fields. Paste **only the example's `parameters` object** into the JSON parameters
editor. The manager generates the surrounding envelope:

```json
{
  "schemaVersion": 1,
  "gameType": "extraction",
  "ruleset": "default",
  "durationMinutes": 60,
  "parameters": {
    "schemaVersion": 1,
    "regions": [
      {"id": "docks", "regionId": "event_docks", "pvp": "disabled"}
    ],
    "objectives": [
      {"id": "clear", "type": "kill_zombies", "scope": "player", "regionIds": ["docks"], "target": 100}
    ],
    "properties": {"friendlyFire": false}
  }
}
```

`parameters` is the website's current custom-data field. `properties` is an
extension object defined by this schema **inside** parameters and individual
definitions; it is not an additional database column. Game type/ruleset/duration
are preserved in the parsed result. Duration remains informational.

Existing envelope/parameters versions are both 1. Empty parameters `{}` remains
valid and normalizes to empty collections. Parameters version may be omitted and
defaults to 1. Unknown common fields are rejected to catch misspellings. Existing
arbitrary parameters such as `maxPlayers` must move under `parameters.properties`.
Custom data is never silently dropped.

Adding provider-specific fields under a `properties` object or a new syntactically
valid type ID does not require a database migration or change to this structural
parser. Its handler still needs implementation and its own semantic validation.
Changing common fields requires updating the schema, generated rules, tests and
consumers; breaking meanings require a new schema version. Backend validation
against this schema is possible now, but this change does not wire it into the
manager's editor/service. It remains the runtime Lua contract until that separate
integration is made. Runtime V14 / the v2 metadata bridge are prerequisites.

## Shared structure

Identifiers are 1–80 ASCII letters, digits, `_`, `.` or `-`, case sensitive.
IDs must be unique within their collection; objective and entity references use
event-local IDs. Collection ordering is retained.

| Member | Meaning |
| --- | --- |
| `parameters.regions` | Up to 64 event region bindings/policies |
| `parameters.objectives` | Up to 128 objective definitions |
| `parameters.entities` | Up to 64 named world-element definitions |
| `properties` | Arbitrary JSON object for provider-specific data |

A region requires `id` and exactly one geometry source:

- `regionId`: stable existing ID from Regions. The event-local `id` can differ.
- `bounds`: inclusive `minX`, `minY`, `maxX`, `maxY`, `minZ`, `maxZ`, all required.
  XY integers are bounded to ±1000000; Z to -32 through 31. These are contract
  limits, not a guarantee of playable terrain at any coordinate. Minima must not
  exceed maxima.

Regions can specify `pvp` (`inherit`, `enabled`, `disabled`), `tags`, `population`
and `properties`. PvP defaults to `inherit`. Population requires `minAlive` and
`maxAlive` (0–5000, ordered); optional `minPlayerDistance` is 10–1000 tiles and
`refillCooldownSeconds` is 5–86400. These limits validate configuration, not safe
server capacity. No population behavior is applied. Region providers must later
resolve external IDs, enforce map bounds/Z, validate terrain and handle overlap,
policy budgets and teardown. Referenced-region geometry is not copied or guessed.

An objective requires `id`, `type` and explicit `scope` (`player`, `team`, `event`).
Optional fields are `titleKey`, `target` (positive integer up to 1000000),
`required` (default true), `regionIds`, `entityIds`, `dependsOn` and `properties`.
Targets are optional because providers may express multiple item amounts or
other completion conditions in properties. References must exist locally;
dependencies cannot cycle or refer to the objective itself. Arrays of references
or tags contain at most 16 distinct IDs. The schema accepts new type names;
future dispatch must reject/disable missing handlers explicitly rather than
claiming an unsupported objective is active or complete.

An entity requires `id` and `type`, with optional event-local `regionId`,
`position` (`x`, `y`, integer `z`), `tags` and `properties`. Entity definitions can
represent a rescue NPC, boss, loot container or future provider. A position is
checked against inline bounds when both are supplied; existing region geometry,
pathing and actual spawn capability require the future Regions/entity adapter.

Examples of provider-owned properties include item requirements and consumption,
loot-table IDs, capture/contest timings, NPC templates, boss stats, rewards and
participation rules. None is interpreted or executed by the common parser.
Do not use properties to bypass future authoritative handler validation.

## Lua API and server hook

`shared/ApocExtractionMapUtils_EventSchema.lua` is pure data code:

```lua
local Schema = require "ApocExtractionMapUtils_EventSchema"
local definition, err = Schema.parse(context.metadataJson)
local record, err = Schema.parseContext(eventId, revision, context)
```

Failures return `nil, errorCodeOrPath`. A definition retains the envelope shape:
`definition.gameType`, `.ruleset`, `.durationMinutes`, `.parameters.regions`,
`.parameters.objectives`, `.parameters.entities` and extension properties.
Absent collections normalize to arrays, absent property bags to objects,
objective `required` to true and region PvP to `inherit`. Other optional settings
remain absent; no gameplay defaults are inferred.

`parseContext` checks UUID/revision identity and schedule fields and returns:

```lua
{
  eventId = "...", revision = 1, name = "Operation",
  startsAtMillis = 1790000000000, state = "scheduled", isReplay = false,
  definition = { schemaVersion = 1, gameType = "extraction", ... }
}
```

Pure parsing is not authorization. `server/ApocExtractionMapUtils_EventDefinitions.lua`
subscribes on `OnServerStarted` to the engine's
`OnApocBRLobbyEventDue(eventId, revision, context)`. It checks fresh matching
cached metadata through `getEventContext`, then `isDue` for fresh dispatch or
`isReleaseAuthorized` for replay. It installs a record atomically only after
validation. Parse failures leave the previous record intact; repeated identical
attempts are cached and logged once per most recent attempt. Payload contents
are never logged. Only one latest record and one attempt are retained.

```lua
local record = ApocExtractionMapUtils.EventDefinitions.getLatest()
if record then
    -- record.definition is a defensive copy; changing it cannot modify intake.
end
```

`getLatest()` means **last successfully parsed received definition**, not current
active gameplay state. It is server-only, independent of the lobby sandbox
switch, never broadcast, and never acknowledges/releases the lobby. After
retaining the record, intake hands a copy to `EventRuntime.acceptDefinition`
for module preparation. The runtime's activation separately waits for a
successful lobby release acknowledgement. Existing
perimeter behavior still runs through its original listener, including when
metadata is invalid. This feature does not add a network command or SQL call.
On unpatched servers the listener remains inactive.

Receipt-only replays have no specification and leave the latest record alone.
Matching replays with metadata can be parsed, retaining `isReplay=true`; they
must not be treated as a new round. No activation is synthesized by inspecting a
cached desired schedule at startup. Records are currently in memory and absent
until the hook delivers valid metadata. They are not persisted objective state.
The next lifecycle implementation must persist accepted definitions/progress,
handle revisions/finish/cancel/rearm and recover the receipt-to-world-save gap.

## JSON and computation bounds

`shared/ApocExtractionMapUtils_JSON.lua` decodes data without `loadstring`, Java
JSON dependencies or a Regions dependency. It rejects malformed/trailing JSON,
duplicate members, invalid UTF-8/Unicode escapes, non-finite/unsafe numbers,
more than 24 value levels, more than 8192 values, and strings over 32768 UTF-8
bytes. All numbers are within Lua's safe ±9007199254740991 range.

The Lua byte bound is intentionally stricter than Java's 32768 UTF-16-character
transport bound for non-ASCII input. The manager editor's existing 16000-character
parameters limit still applies. Backend producers should check UTF-8 bytes too.
There is no per-tick scan: bounded parsing happens once per distinct most recent
hook payload/source; dependency checks visit each objective/edge once.

`JSON.kind(value)` distinguishes arrays, objects and JSON null.
`JSON.null` preserves null values and array positions. `JSON.copy` preserves
these distinctions. Booleans stay booleans. Type metadata uses Lua metatables;
future persistence/serialization must explicitly handle null/container kinds
instead of assuming arbitrary game ModData serialization preserves metatables.

`contracts/event-definition-v1.schema.json` is the canonical structural schema.
`tools/generate-event-schema.py` generates the Lua rule table and test example;
do not edit generated files. The Lua interpreter implements this schema's
explicit subset of JSON Schema, not a general arbitrary-schema service. If new
keywords are added, extend the interpreter and its tests. Lua adds ordered
bounds/population, unique-ID, reference, entity-position and acyclic-dependency
checks that standard JSON Schema cannot express here; backend consumers need
equivalent semantic checks. Transport complexity limits apply in addition to
the machine-readable structural schema.

## Files and verification

Runtime files are the four shared `ApocExtractionMapUtils_JSON`, `EventSchema`,
`EventSchemaRules` and server `EventDefinitions` Lua modules. Contract and
example are in `contracts/`; generation tool and regression harness are
`tools/generate-event-schema.py` and `tests/event-definitions.lua`.

Run from the repository root:

```powershell
python tools/generate-event-schema.py --check
npm exec --yes --package=fengari-node-cli -- fengari tests/event-definitions.lua
npm exec --yes --package=ajv-cli -- ajv validate --spec=draft2020 --strict=true -s contracts/event-definition-v1.schema.json -d contracts/examples/event-definition-v1.json
```

Executed successfully: generator consistency check, AJV strict schema/example
validation, the Fengari harness (90 assertions) and the existing lobby-perimeter
regression harness (including release/replay). No live deployment was performed.

The Fengari harness covers valid multi-system data, normalization, unknown fields,
geometry and population limits, references/cycles/IDs, malformed JSON, UTF-8 and
surrogates, null/false, depth/node/byte limits, context identity, server-only
subscription, stale/not-due rejection, replay, retry logging, atomic rejection
and mutation isolation. It mocks the engine bridge; it does not prove live
website-to-game dispatch or game runtime timing.

See [event activation](postgresql-event-control.md) for deployment prerequisites
and [the context investigation](../reports/2026-10-20-event-objectives-regions-context.md)
for the region/population/moodle implementation direction.

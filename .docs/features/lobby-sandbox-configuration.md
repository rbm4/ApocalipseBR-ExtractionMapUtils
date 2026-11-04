# Lobby sandbox configuration

Status: implemented 2026-10-26; awaiting dedicated-server/client validation.

## Behavior and settings

All settings are in `SandboxVars.ApocExtractionMapUtils`. New-world defaults
turn on the lobby, fence and every building restriction. Existing explicit
`LobbyEnabled=false` values remain disabled. Missing master settings during Lua
loading remain inactive until the engine provides sandbox values. Login
relocation, death-respawn relocation and zombie money remain independently disabled by default.
See [respawn relocation](lobby-respawn-relocation.md) for preserving safehouse/map spawns.

| Setting | Default | Meaning |
| --- | --- | --- |
| LobbyEnabled | true | Master lobby control switch. |
| RelocateOnClosedLobby | true | With RelocateOnLogin enabled, relocate logins while closed only when LobbyDoorCount is 0. Automatically ignored with 1..6 doors. |
| LobbyCleanupZombies | false | [Clear existing zombies](lobby-zombie-cleanup.md) on every server startup using forced streaming; logs progress and releases loading requests. |
| LobbyCleanupMargin | 10 | Extra tiles beyond every side of the cleanup rectangle, including corners; integer 0..100. Zero clears only the lobby interior. |
| LobbyFenceEnabled | true | Build/maintain fence and doors; independent of area restrictions. |
| LobbyAllowZombieThumping | false | Allow zombies to thump mod-created fences and closed doors. Requires vanilla Thump on Construction. |
| LobbyX1 / LobbyY1 | 14260 / 11892 | First inclusive interior corner. |
| LobbyX2 / LobbyY2 | 14321 / 11812 | Second corner; order is normalized. |
| LobbyFenceZ | 0 | Floor for fence and all area restrictions. |
| LobbyDoorCount | 3 | Integer 0..6; zero means no usable doors. |
| LobbyBlockConstruction | true | Block new builds, including overlapping multi-tile entities. |
| LobbyBlockUpgrades | true | Block multistage building upgrades. |
| LobbyBlockDisassembly | true | Block world-object dismantling and scrap. |
| LobbyBlockPickup | true | Block furniture/floor pickup; preserve rotation. |
| LobbyBlockDestruction | true | Block native sledgehammer destruction. |
| LobbyBlockDigging | true | Block removal of ground materials with a shovel. |

A permanent lobby can use 1..6 doors without an event bridge or scheduled
operations. Players can open and close them normally at any time. Maintenance
preserves their open state. Temporary-operation servers can select 0 for a
continuous closed fence until release. The default perimeter still has 286
objects, with up to six designated exit segments replaced by actual doors.
Changing door count on restart reuses the saved exit positions and replaces only
segments whose type changes. Door count is independent of the six existing
removable exit segments: manual release removes those six, and scheduled release
removes the entire perimeter, including doors.

The restrictions apply throughout the same configured area on client and server,
including queued action completion and the actual east/south fence squares.
They continue when fence placement is disabled and after an operation releases
it. Disabling one restriction delegates its native actions while keeping the
others active. Mod-owned perimeter assets retain their native durability and
anti-dismantle flags; turning off an area restriction does not retire or weaken
the fence builder's repair behavior. Normal door use is allowed.

## Configuration and persistence limits

`LobbyAllowZombieThumping` changes the native `IsoThumpable` flag for fences and
doors. Restart the server and reconnect clients after changing it. With lobby
and fence control enabled, saved objects adopt the setting through the normal
load/maintenance queue without resetting the layout, release state or exit plan.
Open doors retain their open state when replaced. Unrelated map objects are
untouched. Health remains 2147483647 and maintenance still repairs damage and
recreates missing segments; this option enables thumping, not lasting breaches.
Vanilla `IsoThumpable.java:getThumpableFor()` excludes open doors, and `Thump()`
also checks `SandboxOptions.instance.lore.thumpOnConstruction`.

Implemented 2026-11-04; native zombie targeting, animation, damage and multiplayer
synchronization still require in-game validation. Regression coverage in
`tests/lobby-perimeter.lua` checks the absent/default flag, explicit false/true,
both object types, saved-world changes in both directions, open-door preservation,
stable exit plans, idempotent maintenance and damage repair. Locale validation
also checks the sandbox default and English/PTBR label completeness.

Validation passed on 2026-11-04 from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
py tests/translation-locales.py
git diff --check
```

`LobbyX`, `LobbyY`, and `LobbyZ` remain the separate login destination settings.
They are not perimeter corners and are not automatically moved when bounds change.
The shared resolver reads the sandbox bounds for both client previews and server
authority. No bounds or permissions are accepted from a client command.

Restart the server and reconnect clients after editing settings. The server
captures its fence plan at startup; protection hooks read the shared sandbox
configuration when invoked. Bounds must be at least seven tiles wide/high and
fit within the existing 4096-edge safety cap. Changing the saved perimeter layout
resets `ApocExtractionLobby` state and builds a fresh closed perimeter on restart.
Old fences stay in place for manual admin cleanup, including overlapping tiles.
See [layout reset](../hotfixes/lobby-layout-config-reset.md). Disabling the lobby/fence does not
remove previously saved objects. The advanced tick budgets and sprite choices
remain in `ApocExtractionMapUtils_LobbySettings.lua`.

No Java/API or database changes are required by these options. Automatic fence
reconstruction between operations still needs the bridge described in
[lobby fence between operations](../hotfixes/lobby-fence-between-operations.md).

## Files, source checks and verification

Implementation: shared `LobbySettings.lua` and `LobbyProtection.lua`, server
`Lobby.lua` and `LobbyConstruction.lua`, `sandbox-options.txt`, and English/PTBR
`Translate/*/Sandbox.json` in the core mod's `common/media` tree.

Native usable-door construction was checked against installed B42
`media/lua/server/BuildingObjects/ISWoodenDoor.lua` and decompiled
`zombie/iso/objects/IsoThumpable.java` (closed/open-sprite constructor,
`setIsDoor`, native open sprite persistence). Existing native action guards
remain in place; only their sandbox gates changed.

Passed from the repository root using
`npm exec --yes --package=fengari-node-cli -- fengari tests/<name>.lua`:

- `lobby-perimeter`: all 0..6 door counts, custom sandbox bounds/floor,
  maintenance preserving open doors, existing-world door count changes, manual
  release, disabled fence, invalid counts, migration and operation regressions.
  Also passed with `Z:/git/Github/Apocalipse-RCON-extension` as an argument for
  actual local RCON relay integration.
- `lobby-construction`: independent construction/upgrade toggles in client,
  server and single-player harnesses; includes `lobby-disassembly` tests for
  independent disassembly, pickup, destruction and digging switches, shared
  sandbox bounds and native helper/queued completion paths on both realms.
- `login-and-maps`, `login-lobby-state`, `map-reveal-server`, and `cartography`:
  existing login/map regressions.
- `python tests/translation-locales.py`: complete EN/PTBR labels, JSON, UTF-8
  without BOM, placeholders, default-true switches and numeric door range.

These are mocked engine-boundary checks. Native door collision/interaction,
client replication, persistent open state across an actual saved-world restart,
and sandbox synchronization still require a real B42 dedicated server/client.

Related: [perimeter](lobby-perimeter.md), [construction protection](lobby-construction-protection.md),
and [sandbox switches](sandbox-feature-switches.md).

## Door limit increase (2026-11-04)

The sandbox and server accept 0..6 usable doors; the default remains 3.
The perimeter harness covers every count, open-door maintenance, saved-layout
count changes and release of all six exit segments; 7 is rejected before
mutating saved layout state. No engine API behavior changed.

Passed from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
py tests/translation-locales.py
```

These checks use mocked world objects and the local RCON extension. Six-door
interaction and replication still require dedicated-server/client validation.

## Closed-lobby login switch (2026-11-04)

Implemented; awaiting dedicated-server/client validation. `RelocateOnClosedLobby`
defaults to true, including when absent from an existing save. It is an additional
gate under `LobbyEnabled` and `RelocateOnLogin`. `LobbyDoorCount > 0` always
disables closed-lobby login relocation. Missing door count uses the shared
fallback (3), which also disables this rule. The EN/PTBR sandbox tooltips warn
that the door count overrides the switch. Permanent lobbies with doors therefore
preserve normal login positions even if their event state remains closed.

Server-transfer relocation, in-map water rescue and the separate death-respawn
option retain their own rules. Disabling this switch does not disable those
other reasons for relocation. Fence state and event release logic do not change.

The shared policy helper is in `ApocExtractionMapUtils.lua`; both
`LoginServer.lua` and client `Login.lua` apply it. The client rechecks the current
policy before honoring a closed-lobby reply. Sandbox configuration and the
existing EN/PTBR `Sandbox.json` category files supply the new control.

Passed from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/login-position.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-lobby-state.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
py tests/translation-locales.py
```

Coverage includes both switch states for every door count 0..6 on server and
single player, missing settings, client reply gates, independent transfer and
respawn policies, and existing map/login regressions. Translation checks cover
JSON parsing, matching keys, the warning, default and BOM-free UTF-8. Engine
boundaries are mocked; live sandbox synchronization and movement require a
real dedicated server and client.

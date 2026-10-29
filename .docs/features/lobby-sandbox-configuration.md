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
| LobbyFenceEnabled | true | Build/maintain fence and doors; independent of area restrictions. |
| LobbyX1 / LobbyY1 | 14260 / 11892 | First inclusive interior corner. |
| LobbyX2 / LobbyY2 | 14321 / 11812 | Second corner; order is normalized. |
| LobbyFenceZ | 0 | Floor for fence and all area restrictions. |
| LobbyDoorCount | 3 | Integer 0..3; zero means no usable doors. |
| LobbyBlockConstruction | true | Block new builds, including overlapping multi-tile entities. |
| LobbyBlockUpgrades | true | Block multistage building upgrades. |
| LobbyBlockDisassembly | true | Block world-object dismantling and scrap. |
| LobbyBlockPickup | true | Block furniture/floor pickup; preserve rotation. |
| LobbyBlockDestruction | true | Block native sledgehammer destruction. |
| LobbyBlockDigging | true | Block removal of ground materials with a shovel. |

A permanent lobby can use 1..3 doors without an event bridge or scheduled
operations. Players can open and close them normally at any time. Maintenance
preserves their open state. Temporary-operation servers can select 0 for a
continuous closed fence until release. The default perimeter still has 286
objects, with up to three designated exit segments replaced by actual doors.
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

`LobbyX`, `LobbyY`, and `LobbyZ` remain the separate login destination settings.
They are not perimeter corners and are not automatically moved when bounds change.
The shared resolver reads the sandbox bounds for both client previews and server
authority. No bounds or permissions are accepted from a client command.

Restart the server and reconnect clients after editing settings. The server
captures its fence plan at startup; protection hooks read the shared sandbox
configuration when invoked. Bounds must be at least seven tiles wide/high and
fit within the existing 4096-edge safety cap. Moving an existing saved perimeter
is rejected: deliberately remove/migrate its owned assets and
`ApocExtractionLobby` saved layout first. Disabling the lobby/fence does not
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

- `lobby-perimeter`: all 0..3 door counts, custom sandbox bounds/floor,
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

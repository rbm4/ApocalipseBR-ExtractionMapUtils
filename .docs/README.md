# Extraction module documentation

The core mod controls the ApocalipseBR test-server lobby and will grow into the
orchestrator for extraction and other gameplay events. The server is intended to
be linked to PostgreSQL; the existing core Lua files do not implement that
integration. Repository conventions live in [AGENTS.md](../AGENTS.md).

## Features

Durable gameplay specifications and current behavior belong in `features/`.

- [NPC dialogue](features/npc-dialogue.md): per-NPC right-click options, timed-action
  walk-up, server-owned reactions and dialogue registration hooks.

- [Sandbox feature switches](features/sandbox-feature-switches.md): map reveal
  is on by default; lobby, relocation and zombie money drops require opt-in.
- [Lobby placement and map visibility](features/lobby-and-map-visibility.md):
  existing foundation, configuration, and validation limits.
- [Lobby perimeter and RCON release](features/lobby-perimeter.md): bounded server
  construction, non-climbable military fences, and the command to remove exits.
- [Lobby construction protection](features/lobby-construction-protection.md):
  blocks player construction and upgrades, including overlapping B42 entities.
- [PostgreSQL event activation](features/postgresql-event-control.md): backend
  contract, guide schedule announcements and scheduled whole-perimeter removal.
- [Zombie money drops](features/zombie-money-drops.md): server-confirmed player
  kills add 1–10 money items to the corpse inventory.

Future event activation and database integration should receive their own feature
documents when designed. Mark proposals as planned until implemented.

## Hotfixes

Targeted corrections and compatibility workarounds belong in `hotfixes/`.

- [Chernarus road rendering](hotfixes/chernarus-road-rendering.md): existing
  cartography workaround and remaining in-game verification.
- [Lobby fence collision and exit removal](hotfixes/lobby-fence-collision-and-release.md):
  fixes the climbable perimeter/passable doors and migrates the existing save.
- [Lobby disassembly protection](hotfixes/lobby-disassembly-protection.md): blocks
  welding scrap, dismantling, furniture/floor pickup, sledgehammer destruction
  and ground-material shoveling throughout lobby squares on client and server.

## Reports

[Reports](reports/README.md) hold dated investigations and test results. They are
evidence for feature and hotfix documents, not the source of ongoing behavior
specifications.

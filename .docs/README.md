# Extraction module documentation

The core mod controls the ApocalipseBR test-server lobby and will grow into the
orchestrator for extraction and other gameplay events. The server is intended to
be linked to PostgreSQL; the existing core Lua files do not implement that
integration. Repository conventions live in [AGENTS.md](../AGENTS.md).

## Features

Durable gameplay specifications and current behavior belong in `features/`.

- [Independent respawn relocation](features/lobby-respawn-relocation.md):
  separate default-off death-respawn policy from login/server-transfer placement.
- [Successful-login history](features/successful-login-history.md): independent
  connection auditing and cached previous-server decisions for lobby relocation.

- [NPC dialogue](features/npc-dialogue.md): per-NPC right-click options, timed-action
  walk-up, server-owned reactions, cached roster subscriptions/push updates and
  dialogue registration hooks.
- [Database dialogue graphs and Lua login](features/npc-dialogue-graphs.md):
  startup content caching, ExtractionMapUtils-owned login requests, server-resolved PTBR dialogue,
  secret choices, account facts and bounded multipart transport.

- [Lobby sandbox configuration](features/lobby-sandbox-configuration.md): configurable
  perimeter bounds, 0..3 usable doors and individual building restrictions.
- [Sandbox feature switches](features/sandbox-feature-switches.md): map reveal
  and lobby protection are on by default; relocation and money drops require opt-in.
- [Lobby placement and map visibility](features/lobby-and-map-visibility.md):
  existing foundation, configuration, and validation limits.
- [Lobby perimeter and RCON release](features/lobby-perimeter.md): bounded server
  construction, non-climbable military fences, and the command to remove exits.
- [Lobby construction protection](features/lobby-construction-protection.md):
  blocks player construction and upgrades, including overlapping B42 entities.
- [PostgreSQL event activation](features/postgresql-event-control.md): backend
  contract, guide schedule announcements and scheduled whole-perimeter removal.
- [Event definition schema](features/event-definition-schema.md): versioned regions,
  objectives and entity data, JSON validation and server Lua metadata intake.
- [Event runtime scaffold](features/event-runtime-scaffold.md): ordered preview
  modules, region lookup and release-confirmed console activation diagnostics.
- [Authoritative objectives and tracker](features/objective-tracker.md): scoped
  server progress, targeted versioned snapshots/updates and a cached client HUD.
- [Zombie money drops](features/zombie-money-drops.md): server-confirmed player
  kills add 1–10 money items to the corpse inventory.

Future event activation and database integration should receive their own feature
documents when designed. Mark proposals as planned until implemented.

## Hotfixes

Targeted corrections and compatibility workarounds belong in `hotfixes/`.

- [Lobby fence between operations](hotfixes/lobby-fence-between-operations.md):
  rebuild the saved released perimeter when no operation is active, including
  while the next operation is queued.

- [NPC dialogue after respawn](hotfixes/npc-dialogue-respawn-roster.md): refresh
  stable-key/native-ID bindings, close old sessions and recover incomplete rosters.

- [Login options before online readiness](hotfixes/login-options-before-online-readiness.md):
  retain pending login checks until connection readiness and trace each relocation stage.

- [Boat radial seat boarding](hotfixes/boat-radial-seat-boarding.md): board an
  exterior seat immediately using radial-menu reach, preserving cabin access rules.

- [Boat cheat menu removal](hotfixes/boat-cheat-menu-removal.md): remove boat
  mechanics cheats, their callbacks, and debug boat spawning in both mod copies.

- [Invalid login position rescue](hotfixes/invalid-login-position-rescue.md): reset
  out-of-map and open-water logins during operations while preserving safe reconnects.

- [Closed-lobby login relocation](hotfixes/closed-lobby-login-relocation.md):
  preserve saved positions after manual release or scheduled operation activation.

- [English and Brazilian Portuguese labels](hotfixes/english-and-brazilian-portuguese-labels.md):
  correct English fallback text and add complete PTBR UI and sandbox translations.

- [NPC dialogue discovery payload](hotfixes/npc-dialogue-empty-discovery-payload.md):
  accept native payload-free roster requests instead of silently dropping them.

- [Chernarus road rendering](hotfixes/chernarus-road-rendering.md): existing
  cartography workaround and remaining in-game verification.
- [Lobby fence collision and exit removal](hotfixes/lobby-fence-collision-and-release.md):
  fixes the climbable perimeter/passable doors and migrates the existing save.
- [Lobby disassembly protection](hotfixes/lobby-disassembly-protection.md): blocks
  welding scrap, dismantling, furniture/floor pickup, sledgehammer destruction
  and ground-material shoveling throughout lobby squares on client and server.
- [Lobby construction startup](hotfixes/lobby-construction-load-order.md): loads
  building guards after B42 registers the server Lua dependencies.

## Reports

[Reports](reports/README.md) hold dated investigations and test results. They are
evidence for feature and hotfix documents, not the source of ongoing behavior
specifications.

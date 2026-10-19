# Repository purpose

This repository supports the ApocalipseBR Project Zomboid Build 42 test server's
lobby and extraction gameplay. The test server is intended to be linked to
PostgreSQL and host different gameplay events. The extraction module is the core
that will control the lobby and orchestrate event activation as features grow.
Do not assume that a database bridge or event lifecycle is already implemented.

## Component boundaries

- `ApocalipseBR-ExtractionMapUtils/`: our main extraction and server-control mod.
  Put lobby rules, player placement, map visibility, and future event
  orchestration here.
- `AquasarYatchClub/`: the boats mod. Keep boat behavior and compatibility changes
  scoped to this component; do not put general lobby rules here.
- `Restless-Waters/`: the map used by the event environment. Keep map content
  separate from extraction gameplay logic.
- `tests/`: Lua regression harnesses for the core mod.
- `project.json`, `package.json`, and `workshop/`: packaging and tooling. A
  packaging entry alone is not evidence of an active gameplay dependency.

Preserve these folder names, mod IDs, and the existing Build 42 `common` and
versioned-folder layout. Do not rename or restructure bundled components as part
of unrelated feature work. Inspect `project.json` and the relevant `mod.info`
files before changing dependencies or packaging.

## Implementation patterns

- Use `ApocalipseBR-ExtractionMapUtils/common/media/lua/` for core Lua behavior:
  `client/` for presentation and local hooks, `server/` for authoritative rules
  and command validation, and `shared/` for shared options and helpers.
- Follow the existing `ApocExtractionMapUtils` namespace, filename prefix,
  sandbox option group, and command module. Prefer focused files per concern.
- Keep lobby coordinates and gameplay options configurable. Do not hardcode a
  new lobby location or assume a particular event map's coordinates.
- Prefer additive event hooks. When wrapping vanilla functions, preserve their
  arguments, return values, and normal behavior outside the enabled feature.
- Verify Build 42 events and Java APIs against local vanilla Lua or decompiled
  sources before relying on them. Record the relevant source when a design
  depends on engine behavior.
- Validate gameplay requests on the server. Derive trusted state there instead
  of accepting client-provided positions, permissions, or event state.
- Treat the existing client login relocation as a prototype requiring dedicated
  server validation, not proof of authoritative spawn enforcement.
- Future PostgreSQL work must document the actual server-side integration
  boundary, configuration, and failure behavior. Keep credentials out of client
  Lua and repository files; do not invent a schema or transport ahead of design.
- Preserve unrelated working-tree changes, especially in bundled boat/map mods.

## Documentation contract

Every new feature or hotfix must include unit tests and documentation in the
same change. Add or update its document under `.docs/features/` or
`.docs/hotfixes/`, respectively, and record the test coverage, commands, and
results. Start with
[the documentation index](.docs/README.md) and keep its links current.

- `.docs/features/`: durable descriptions of gameplay behavior, configuration,
  ownership, integration points, and limitations. Update the relevant feature
  document whenever behavior changes.
- `.docs/hotfixes/`: targeted defect fixes and compatibility workarounds. Record
  the symptom, cause or hypothesis, affected files, fix, validation, and any
  remaining risk. Link the affected feature when applicable.
- `.docs/reports/`: dated investigations, test sessions, diagnostics, and measured
  results. Separate observations from hypotheses; link the relevant feature or
  hotfix instead of replacing its durable documentation with a report.

Use descriptive lowercase kebab-case filenames; prefix reports with
`YYYY-MM-DD-`. Feature documents should state their status (planned, implemented,
or awaiting in-game validation), purpose, behavior, configuration, affected
files, and verification. Hotfixes and reports must state what was actually
tested. Never describe a plan or mocked test as confirmed live-server behavior.
Keep the root README useful for installation and operation; link detailed docs
from it rather than growing a second feature history there.

## Current baseline and direction

The core currently contains configurable relocation on login, world map/minimap
knowledge reveal, and a Chernarus cartography workaround. See `.docs/` for their
scope and validation limits. Relocation is not lobby confinement and does not
cover every respawn path. Map knowledge reveal is not live entity visibility.

The intended direction includes forcing players into a designated map area,
controlling lobby behavior, and coordinating event activation for multiple event
types. Implement those follow-up features only when requested; this baseline
does not define event states, rules, or database contracts.

## Verification

For every new feature or hotfix, add or extend unit tests under `tests/` and run
them before considering the work complete. Cover the intended behavior and
relevant edge cases; hotfixes must include a regression test that reproduces the
defect and passes with the fix. Mock engine boundaries where needed, and document
any behavior that still requires in-game validation.

For relevant Lua behavior changes, run the applicable existing harnesses from
the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

These harnesses mock engine boundaries. Use an actual Build 42 dedicated server
and client to validate movement synchronization, anti-cheat, rendering, and
multiplayer lifecycle changes; report untested behavior explicitly. Documentation
only changes require link/path and diff review, not gameplay regression runs.

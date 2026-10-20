# Reports

Store investigations, diagnostics, benchmarks, and test-session results here as
`YYYY-MM-DD-short-description.md`.

Each report should record:

- Date, purpose, relevant mod revision, and game/server build when available.
- Environment, enabled mods, configuration, and reproduction steps.
- Observed results and supporting logs or measurements, with secrets removed.
- Hypotheses separately from confirmed observations.
- Validation performed, untested cases, and recommended next steps.
- Links to the affected feature or hotfix documents.

Keep durable behavior and configuration in `../features/` and corrective changes
in `../hotfixes/`. Update those documents when a report leads to a change.

## Investigations

- [2026-10-19: PostgreSQL event control and guide announcements](2026-10-19-postgresql-event-control-design.md):
  verified server-side integration points and proposed schedule/release contract;
  no runtime changes or live database operations.

- [2026-10-19: Lobby world-control APIs](2026-10-19-lobby-world-control-api-investigation.md):
  local Java/Lua evidence for zombie removal, perimeter placement, and timed gates;
  no live-server validation.

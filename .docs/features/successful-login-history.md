# Successful-login history and cross-server relocation

Status: implemented for the 42.21.0 server patch; live A-to-C reconnect validation remains required.

## Ownership and behavior

The server patch records each fully accepted character connection in
`player_rel.successful_login`, independently of ExtractionMapUtils, lobby options,
dictionary provenance, inventory decoding, relational capture and PostgreSQL player
loading. SQLite-backed A records the same event as PostgreSQL-backed C.
The account/world/identity-mode/slot identifies the character slot; a known
persistent character UUID additionally separates known character lives. When no
UUID exists yet the audit still records the slot; it cannot distinguish unknown lives.

The existing durable journal writes the detached event asynchronously. One SQL
transaction captures the previous server and inserts the occurrence. Replaying an
event UUID returns the same previous-server result without duplicating the row.
The cached result belongs to that accepted player and never queries SQL from Lua.
Old character mod-data markers are ignored.

The server login handler checks `ApocBRPlayerLogin.isReady(player)` before using
`hasChangedServer(player)`. A pending audit requests another attempt. A ready first
login returns previous ID 0 and uses existing geometry checks. A different known
server resets to the configured lobby even on safe land during an operation.
Native teleport acknowledgement and duplicate suppression remain unchanged.

Login hooks queue checks before evaluating enabled settings; multiplayer waits
for online registration before applying those settings. Client/server debug logs
trace queueing, settings skips, request attempts, response flags and native teleport
acceptance. See the [login readiness hotfix](../hotfixes/login-options-before-online-readiness.md).

Relocation still requires `LobbyEnabled`, `RelocateOnLogin` and valid lobby
coordinates. Those settings do not control audit recording. The existing client
budget is 15 requests at one-second intervals. If history remains unavailable,
the position is preserved and `retries_exhausted` is emitted when debug logging is on.

## Installation and diagnostics

Apply backend migration `V19__Create_Successful_Login_History.sql` before deploying
the server patch to every participating server. Enable `apocbr.postgres.enabled`,
use stable unique `apocbr.postgres.serverId` values and matching world/identity
configuration. `apocbr.postgres.loginHistory.enabled` defaults to true; setting it
false disables auditing and retains geometry fallback. No client Java patch is needed.

`[ApocBR][LoginHistory] QUEUED`, `RECORDED` and `QUEUE_FAILED` are normal server logs.
Recorded results include event UUID, previous/current server and changed-server
decision. Extraction's existing `debugLog` additionally emits `history_pending`,
`decision` and `retries_exhausted`. A pending result must not be interpreted as a
same-server decision. History is not retroactively filled from old markers.

An abrupt process loss before journal fsync can lose a staged occurrence. After
fsync, failed operations use existing retry/quarantine behavior. Cross-server
chronology uses captured login times; keep server clocks synchronized. A server
cannot see another server's uncommitted offline journal. Late replay retains old
history without replacing a newer login; it does not revise already delivered decisions.

## Files and validation

Affected Lua: `server/ApocExtractionMapUtils_LoginServer.lua` and
`client/ApocExtractionMapUtils_Login.lua`. Engine/schema ownership and operational
queries are documented in the patch repository's `42.21.0/PLAYER-LOGIN-ORIGIN.md`
and the manager's `docs/successful-login-history.md`.

Passed: `tests/login-position.lua` (pending history regression and server decisions),
`tests/login-lobby-state.lua` (bounded retry and native teleport acknowledgement),
engine `tools/test_player_login_origin.py` (production bridge/store/journal),
and the 42.21.0 patch `-DryRun` compilation. PostgreSQL migration and broader
persistence verification results are recorded in the engine/backend documents.
Engine fixtures and compilation do not establish live movement or anti-cheat behavior.

Validation on 2026-10-21: both backend migration tests passed on disposable PostgreSQL
14.24 with distinct migration/engine roles and zero skips. Engine persistence
resilience/recovery and all 531 reconstruction checks passed; `tests/login-and-maps.lua`
also passed. No live migration or deployment was performed.


Same-session replacement characters now use the independent default-off
[respawn relocation policy](lobby-respawn-relocation.md). Their placement skips
login-origin/geometry overrides when disabled; successful-login auditing remains
independent and unchanged. Requires the additive `ApocBRPlayerLogin.isRespawn`
bridge from the updated 42.21.0 patch.

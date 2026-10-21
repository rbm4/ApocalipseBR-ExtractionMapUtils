# Login settings evaluated before online readiness

Status: implemented; dedicated-client/server retest required.

## Observations and cause

The reported 2026-10-21 transfer from server 3 to server 4 successfully recorded
`previousServer=3`, `currentServer=4`, `changedServer=true`. This is a known
cross-server login, not a first-history fallback. The corresponding local client
console contains enabled lobby/relocation settings, a configured destination,
and working HumanList traffic, without a login decision/teleport message.
Those logs do not prove which stage dropped the relocation request.

Inspection found a reproducible timing defect: OnGameStart/OnCreatePlayer queued
relocation only if enabled at that instant, and OnTick discarded disabled entries
before waiting for a registered online ID. A player created before usable options
arrived could therefore lose relocation permanently. NPC discovery has a separate
queue and could still succeed. A regression fixture reproduces this failure with
options disabled during the event and enabled by online readiness. Whether this
precise ordering caused the reported live failure remains unconfirmed.

A second local observation is that the subscribed Steam item 3822608465 contains
an older login module (one request and closed-lobby-only response), while the
local Workshop staging folder matched repository Lua before this fix. Presence
of both copies does not establish which copy the running process used. Verify
the loaded version by its new client `queued; protocol=2` log and update the
deployed mod copies together.

## Change

`client/ApocExtractionMapUtils_Login.lua` always queues living players at login
hooks. Multiplayer waits for a nonnegative online ID before evaluating the
relocation options. Disabled options then skip explicitly; enabled options use
the existing authoritative request, retry budget and native teleport acknowledgement.
NPC discovery, disabled gameplay behavior and single-player rules are retained.

Client debug logs now identify queue settings, settings-based skips, outgoing
request attempts/online IDs, and response flags. The server login module logs
request receipt and native teleport acceptance/destination, in addition to its
existing history-pending and policy-decision logs. All use existing `debugLog`.

This does not force teleport for a same-server reconnect. Because the failed
placement already audited server 4, a meaningful cross-server retest must first
successfully log into server 3, then server 4, after updating server/client Lua.

## Verification

Passed from the repository root using
`npm exec --yes --package=fengari-node-cli -- fengari <test>`:

- `tests/login-lobby-state.lua`: new delayed-options regressions for both login
  hooks, plus existing settings/death guards, bounded retries, split-screen and
  native teleport acknowledgement. The first new regression failed before the fix.
- `tests/login-position.lua`: authoritative policy, audit readiness and native teleport.
- `tests/login-and-maps.lua`: login, disabled settings, single player and map regressions.
- `tests/human-roster.lua`: NPC bootstrap, cache and lifecycle regressions.

Engine event ordering checked against 42.21.0 decompiled
`gameStates/IngameState.java` (OnGameStart precedes sendPlayerConnect) and
`network/GameClient.java` (sendPlayerConnect sets online ID to -1).
These are mocked Lua checks, not confirmation of a successful live teleport.

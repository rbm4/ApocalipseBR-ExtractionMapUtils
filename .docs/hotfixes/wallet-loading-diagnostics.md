# Wallet stays loading: dispatch, retry and stage diagnostics

Status: dispatch/retry hardening and diagnostics implemented; original live
failure remains to be confirmed from the next instrumented run. Created
2026-11-11. Owning features: [API connectivity](../features/wallet-api-connectivity.md)
and [radio UI](../features/wallet-radio-ui.md).

## Observed evidence

The user reported the UI staying on loading, Sync not resolving it, and only
`[ApocBR][API] started` appearing on the server. Local server command logs for
2026-11-11 show `ApocWallet.LoadBalance` at 19:17:53 and multiple
`ApocWallet.RefreshBalance` commands afterward. The native command receive path
therefore works; these command log entries occur before Lua dispatch and do not
prove that the wallet Lua handler accepted them.

The Java startup line proves that the independent HTTP bridge initialized, not
that a Lua operation was submitted or an HTTP response received. Neither wallet
Lua controller previously logged its installation or request progression. The
existing UI also disabled Sync during loading and its controller ignored Sync
while waiting, leaving no manual recovery until timeout.

Inspection of exact-build sources confirmed that the dedicated server does call
`IngameState.update()`, which can emit `OnTick` while unpaused. This hotfix does
not claim that `OnTick` is client-only or replace the scheduler on that premise.
The logs do not yet establish why the original pending operation failed to
reach completion.

## Changes

- Client and server controllers emit one `LOADED` diagnostic and have duplicate
  installation guards.
- The server command handler acknowledges the intent, then calls
  `ServerService.kick(player)` to attempt admission immediately for that one
  authenticated player. It does not scan the whole pending map per command and
  does not wait for the first tick. Existing global admission pacing, identity
  validation and callback deadlines remain enforced.
- Pending identity/admission waits still use the temporary tick handler. It is
  removed when operations settle; there is no new permanent tick or balance poll.
- Sync remains usable while loading. After five seconds, an explicit refresh
  can resend the same pending command token. It preserves the original timeout
  and joins the same observers/backend operation. There is no automatic resend
  loop. The server continues to deduplicate accepted reads and rate-limit replies.
- `IDENTITY_API_OUTDATED` distinguishes an older Java `character(player)` result
  missing source-server/Steam fields. `INVALID_STEAM_ID` distinguishes a missing
  or unusable Steam identity. Neither condition submits incomplete backend data.
- The UI shows a bounded fixed error code when a request fails, alongside the
  unavailable balance state. It does not display raw backend response bodies.

## Trace and interpretation

Both sides log with `[ApocWallet]`, using only stage names, safe error codes and
our numeric timestamp/sequence correlation reference. They do not print API
credentials, character/Steam identifiers, names, balances, URLs or response
bodies. Arbitrary client tokens are replaced by `opaque` in diagnostics.

Expected progression:

```text
[ApocWallet][client] LOADED ... code=READY
[ApocWallet][server] LOADED ... code=READY
[ApocWallet][client] QUEUED ...
[ApocWallet][client] SEND ...
[ApocWallet][server] COMMAND_ACCEPTED ...
[ApocWallet][server] API_ACCEPTED ... code=QUEUED
[ApocWallet][server] COMPLETE ... code=OK
[ApocWallet][client] RECEIVE ... code=OK
[ApocWallet][client] COMPLETE ... code=OK
```

An initial client `RECEIVE code=PENDING` is normal. Other useful stages:

| Last stage/code | Meaning / next check |
| --- | --- |
| No server `LOADED` | The instrumented server Lua controller is absent, skipped or failed during installation. Check the installed mod files and startup Lua errors. Java bridge startup alone does not install the wallet Lua controller. |
| Client `SEND`, native command log present, no acceptance | Check server controller installation; `COMMAND_IGNORED` distinguishes malformed payload, player readiness and rate limiting. |
| `IDENTITY_WAIT` | Relational identity has not become ready; the existing bounded wait continues. |
| `IDENTITY_API_OUTDATED` | Use the updated `ApocBRModEntities` class and restart the server JVM. Replacing class files after startup does not reload an already loaded class. |
| `INVALID_STEAM_ID` | Native player identity cannot satisfy the backend contract; do not substitute an untrusted client Steam ID. |
| `API_WAIT` | Java admission rejected temporarily; its code reports throttling, queue capacity or backend cooldown. |
| `API_ACCEPTED`, no completion | The Java queue accepted the request. Check for the eventual callback or `API_TIMEOUT`; this stage alone does not prove successful HTTP ingestion. |
| `COMPLETE code=HTTP_401` etc. | HTTP completed with an error; correct the corresponding backend/auth/route issue. |
| Server completion, no client completion | Follow the targeted server-command return path and matching token/online ID. |

Unchanged identity/admission waits log only on stage transitions. Ignored wallet
commands are logged at most once per ten seconds globally, so invalid input does
not create per-command log spam. Normal logging is operation-based, not per tick.
For a quiet run, set `ApocWallet.Diagnostics.enabled = false` in server/client
Lua after loading; this does not alter request behavior.

Update/rebuild the wallet mod on both sides and restart/reconnect to load the
new Lua. No Java source changes were made by this hotfix. The already documented
Java bridge/identity prerequisites still apply.

## Verification

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-radio-ui.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-radio-access.lua
```

Results: 85 wallet, 50 UI and 27 radio-access assertions passed. New regressions
cover immediate server admission without firing a server tick, a manual retry
after initial dispatch was absent, original token/deadline preservation, no
duplicate backend request, rapid retry suppression, explicit old-identity API
failure, transition-only logging, diagnostic redaction and controller reload
guards. The UI test now verifies that pending state retains its explicit retry
control. Widgets, native events/network and Java boundaries are mocked.

No live backend request, running server modification or deployment was performed.
Actual recovery and the original failure's cause require the next in-game trace;
the patch is not evidence that the production root cause has been confirmed.

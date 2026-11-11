# Wallet API connectivity

Status: implemented; awaiting dedicated-server/backend validation. Created
2026-11-11. The operation/callback architecture is ready for RadioTraders display
integration. No wallet UI or balance mutation is implemented.

## Installation and prerequisites

Install and enable the independent `ApocalipseBR-Wallet` mod on server and
clients. Its `42/mod.info` requires Build 42.22.2. It does not depend on the
extraction mod, RCON extension or lobby settings. The existing `project.json`
entry includes it in this Workshop project's packaging.

The server needs the current 42.22.2 Java patches, including the generic
`ApocBrApiBridge` and the enriched `ApocBRModEntities.character` identity response.
The relational player binding must be active and ready for each character;
the wallet waits for its existing import/bind flow rather than issuing SQL.
Configure PostgreSQL/player-relational storage as usual, including registered
`apocbr.postgres.serverId`. The live player must have a valid Steam identity.

`apocbr.bridge.api.enabled` defaults to true. `apocbr.bridge.serverKey` must hold
the backend API credential; `apocbr.bridge.enabled` is independent. No API keys,
hosts or paths are stored in this mod. The Java endpoint enum owns the request
contract. The Java identity addition returns the configured source-server ID and
the exact unsigned Steam ID string, avoiding Lua double rounding of 17 digits.

## Layers and flow

Files live under `ApocalipseBR-Wallet/common/media/lua/`:

| Layer | File | Responsibility |
| --- | --- | --- |
| Shared protocol | `shared/ApocWallet/Protocol.lua` | Module/command names and client timing constants |
| Shared operation | `shared/ApocWallet/Operation.lua` | Bounded callbacks, observer cancellation, protected delivery and copied results |
| Client controller | `client/ApocWallet/ClientController.lua` | Login, startup, tick, server-command, death and disconnect hooks |
| Client service | `client/ApocWallet/ClientService.lua` | Operation callbacks, explicit refresh, response matching and per-local-player memory cache |
| Server controller | `server/ApocWallet/ServerController.lua` | Native authenticated command routing and targeted responses |
| Server service | `server/ApocWallet/ServerService.lua` | Identity readiness, operation coalescing, request scheduling, callback validation and backend-sourced cache |

1. `OnCreatePlayer` or `OnGameStart` starts a local loading operation. A temporary
   tick handler sends one `ApocWallet/LoadBalance` intent once the local online
   ID is assigned. Duplicate startup hooks and UI callers share this operation.
2. The client sends only an opaque correlation token. The native server callback
   supplies the authenticated player; client identity and balance fields are ignored.
3. The server queues one load per live player object. It resolves
   `ApocBRModEntities.character(player)` and waits if its status is
   `IDENTITY_PENDING`. Character UUID, source-server ID, Steam ID and session all
   come from this server-owned context. One unready import does not block other
   ready players.
4. The server calls `ApocBrApiBridge.request(CHARACTER_BALANCE, parametersJson,
   callback)`. Request JSON contains `runtimeUuid` (the relational character UUID),
   `sourceServerId`, and string `steamId`. The Java worker performs HTTP; no Lua
   thread blocks while waiting.
5. On the server-thread callback, the service rechecks player object, online ID,
   relational UUID/session and request ID. It caches a successful numeric balance
   and sends `BalanceState` only to that player. Failures remain explicit errors;
   an unavailable balance is never represented as zero.
6. The client matches token and online ID against its current local player,
   updates its memory cache and resolves the operation's attached callbacks.
   Split-screen slots have independent state. Both client and server remove
   their wallet tick handler once no pending operation remains.

Controller files operate only in multiplayer client/server roles. Single-player
has no fallback wallet, invented identity or balance.

## Callback contract for RadioTraders UI

```lua
require "ApocWallet/ClientService"
local Wallet = ApocWallet.ClientService

-- Read the login cache or join/start a load. Callback may execute immediately.
local unsubscribe = Wallet.requestBalance(0, function(result)
    if result.status == "ready" then
        -- Display result.balance. Zero is valid.
        -- result.updatedAt is the server capture timestamp in real milliseconds.
        -- result.cached indicates that this call was satisfied from cache.
    else
        -- Display an unavailable/error state using result.error.
    end
end)

-- A UI-open or explicit refresh action can request an updated backend value.
-- This starts one operation, with no recurring balance polling.
local unsubscribeRefresh = Wallet.refreshBalance(0, function(result)
    -- Update the balance label once this operation completes.
end)

-- On UI close, detach its observers. The shared request may serve other callers.
unsubscribe()
unsubscribeRefresh()

-- Snapshot only; no network or refresh side effects. Returns a copy.
local state = Wallet.getState(0)
-- status: idle/loading/ready/error; balance on ready, error on failure.

-- The server service offers the same callback API with a native player:
local unsubscribeServer = ApocWallet.ServerService.requestBalance(player, function(result)
    -- Backend-sourced display data; never proof a later purchase can succeed.
end)
```

`requestBalance` reads completed cached state, or starts/joins a pending operation.
`refreshBalance` requests a new read after a five-second cooldown; refresh calls
within the cooldown reuse the last completed state. The client measures cooldown
from local receipt time; the server independently enforces it from operation
start, so it does not trust client timing. A pending operation coalesces normal
and refresh callers. There are no automatic retries after an HTTP failure;
an explicit refresh can retry once cooldown expires.

Callbacks receive terminal `ready` or `error` snapshots, once per attached
observer. Each gets its own copy. Callback errors are isolated with `pcall`.
Each method returns an idempotent unsubscribe function. Unsubscribing releases
that observer without cancelling another caller's operation. Up to 32 observers
can attach to one operation; excess observers get `CALLBACK_LIMIT`. Death,
disconnect or player replacement settles attached observers with `CANCELLED`
and releases the pending work. A callback cannot restart work during disconnect
cleanup. Previously completed observers are not retained as subscriptions.

These are session-only display caches, not ModData or a persistent ledger.
Repeating login commands returns cached state; only explicit refresh starts
another read. Reconnect and respawn start fresh loads. No balance refresh runs
in a window render/update callback, on a repeating timer or after completion.
The backend owns all debits and credits through its other operations. Wallet Lua
never discounts balance, authorizes a purchase using its cache or writes a new
balance to the backend. Display freshness is explicit through `updatedAt`.

The local RadioTraders reference is Workshop `3807707103`, under
`mods/RadioTraders/42/media/lua/`. `client/RadioTraders/RT_TradeWindow.lua` is a
future UI integration point. Its shared `RT_API.lua` payment-provider contract
requires both `balance(player)` and `debit(player, amount)`; it is deliberately
not registered here because that would integrate spending, beyond a read-only
display. No RadioTraders vendor file or purchase logic was modified. The future
window should request/refresh once on open, set its label from the callback,
and call unsubscribe on close. It should not fetch from `render`/`update`.

## Limits and failure behavior

- Server cache: at most 256 player entries. Only pending operations are checked
  once per second. Completed/error entries are never scanned by `OnTick`.
- Both controllers dynamically register `OnTick` while operations are pending
  and unregister it on completion, timeout, cancellation or failure. Idle ticks
  make no wallet clock reads or player-map lookups. Client readiness/deadlines
  are checked at most every 250 ms while pending.
- Completed-cache cleanup uses `EveryOneMinute` with a ten-second real-time
  minimum interval. This event follows game time; cleanup can be delayed while
  paused. It removes disconnected/dead/replaced players and never requests a
  balance. Empty caches return without reading the clock.
- Repeated commands for an existing player get at most one immediate reply per
  two seconds. Tokens are bounded to 80 safe characters. Unknown modules/commands
  and players absent from the native online map are ignored.
- One new API admission attempt globally per two seconds. Java independently
  enforces its transport limiter, queue/body bounds, deadlines and 429 cooldown.
- Explicit refreshes are bounded to one new operation per player per five
  seconds, independently of the global/API limits. Cache reads do not bypass
  backend authorization or cause a debit.
- `THROTTLED`, `QUEUE_FULL` and `BACKEND_COOLDOWN` retry admission within the
  server's 120-second login budget. No duplicate request is admitted after an ID
  has been obtained. Backend/transport failures after admission are not retried.
- Identity/readiness and pre-admission wait: at most 120 seconds. Accepted API
  callback wait: at most 60 additional seconds. Late completions are ignored.
- Client sends one intent per operation and waits for the pushed completion,
  with a 180-second total `REQUEST_TIMEOUT`. It does not poll command replies.
  Missing completion requires a later explicit refresh, not automatic requests.
- Missing/old Java identity fields, missing bridge, missing Steam identity and
  API failures produce an error code. There are no client-selected endpoints or
  credentials and no arbitrary balance write command.

## Verification

From the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet.lua
```

The production Lua harness mocks only engine/Java/network boundaries. Coverage
includes deferred login, forged client identity, duplicate/spammed requests,
trusted request JSON, admission backpressure, import readiness, stale sessions,
online-ID reuse, callback timeout/error/NaN handling, cache copies, death and
disconnect cleanup, full client/server flow, split-screen out-of-order replies,
global spacing and bounded server entries. Operation-specific tests also cover
cached callbacks, shared refreshes, observer limits/unsubscribe, callback errors,
disconnect reentrancy, tick attachment/removal, zero idle clock/map accesses,
explicit backend balance changes and coarse cache cleanup.

Java validation lives in the patches repository:

```powershell
$env:APOCBR_TEST_VERSION='42.22.2'
py tools/test_character_mod_entities.py
.\42.22.2\patchApocalipseBr.ps1 -BuildOnly
```

The identity fixture checks exact Steam ID preservation, configured server ID
and authoritative runtime UUID alongside existing scoped-entity checks. Engine
event/command signatures were verified in the local exact-build Java sources:
`LuaManager.GlobalObject.getPlayerByOnlineID`, `GameServer.receiveClientCommand`,
`GameLoadingState`/`AddCoopPlayer` (`OnCreatePlayer`) and `LuaEventManager`
(`OnDisconnect`). The existing `getSteamIDFromUsername` helper is client-only;
it is deliberately not used for server authentication.

No live backend request, database mutation or deployment was performed. Actual
dedicated-server load order, relational readiness, backend credentials/identity
matching, reconnect/respawn and split-screen synchronization remain smoke tests.

Initial connectivity verification on 2026-11-11: 48 wallet Lua assertions passed; the target Java scoped-entity
fixture passed 375 assertions. The 42.22.2 `-BuildOnly` compilation passed with
370 sources / 1061 class files, retained in the patches repository under
`42.22.2/artifacts/build_20261111_182253/`. Documentation links and diff checks
passed. The existing user addition to `project.json` was preserved.

The callback architecture update is Lua-only; Java sources were not changed.
Verified 2026-11-11: all 75 wallet assertions passed, including dynamic tick
removal, zero idle clock/player lookups, explicit refresh after backend changes,
server refresh throttling independent of client timing, callback coalescing,
limits, reentrancy, cancellation during dispatch and disconnect cleanup. The
fixture uses production Lua with mocked engine/API boundaries. The local B42
`Lua/Event.java` confirms `Events.OnTick.Remove` and safe event-list removal
during dispatch; `LuaEventManager` confirms `EveryOneMinute`. No runtime CPU
measurements, live backend requests or RadioTraders UI smoke tests were performed.

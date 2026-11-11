# Wallet API connectivity

Status: implemented; awaiting dedicated-server/backend validation. Created
2026-11-11. No wallet UI or balance mutation is implemented.

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
| Client controller | `client/ApocWallet/ClientController.lua` | Login, startup, tick, server-command, death and disconnect hooks |
| Client service | `client/ApocWallet/ClientService.lua` | Deferred login intent, response matching and per-local-player memory cache |
| Server controller | `server/ApocWallet/ServerController.lua` | Native authenticated command routing and targeted responses |
| Server service | `server/ApocWallet/ServerService.lua` | Identity readiness, deduplication, request scheduling, callback validation and authoritative cache |

1. `OnCreatePlayer` or `OnGameStart` creates local loading state. The next tick
   sends `ApocWallet/LoadBalance` once the local online ID is assigned. Duplicate
   startup hooks reuse the same pending operation.
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
6. The client matches token and online ID against its current local player, then
   stores a copied response in memory. Split-screen slots have independent state.

Controller files operate only in multiplayer client/server roles. Single-player
has no fallback wallet, invented identity or balance.

## Cache contract for future UI

```lua
-- Client: index defaults to 0; returns a copy.
local state = ApocWallet.ClientService.getState(0)
-- state.status: "idle", "loading", "ready", "error"
-- state.balance exists only after a successful response (zero is valid).
-- state.error is a fixed error code on failure.

-- Server: authenticated native player; also returns a copy.
local authoritative = ApocWallet.ServerService.getState(player)
```

These are session-only Lua caches, not ModData, player mod data or a persistent
ledger. Repeating login commands returns cached state and never refreshes a
completed/error session. Reconnect and respawn use a fresh player object and
start a fresh load. Death/disconnect clears client state; the server prunes dead,
disconnected and replaced player objects during its next maintenance tick. Late
callbacks cannot populate the next life. A future explicit refresh/UI/update
contract is separate work.

## Limits and failure behavior

- Server cache: at most 256 player entries. Maintenance runs once per second;
  it processes only this bounded map, not world entities.
- Repeated commands for an existing player get at most one immediate reply per
  two seconds. Tokens are bounded to 80 safe characters. Unknown modules/commands
  and players absent from the native online map are ignored.
- One new API admission attempt globally per two seconds. Java independently
  enforces its transport limiter, queue/body bounds, deadlines and 429 cooldown.
- `THROTTLED`, `QUEUE_FULL` and `BACKEND_COOLDOWN` retry admission within the
  server's 120-second login budget. No duplicate request is admitted after an ID
  has been obtained. Backend/transport failures after admission are not retried.
- Identity/readiness and pre-admission wait: at most 120 seconds. Accepted API
  callback wait: at most 60 additional seconds. Late completions are ignored.
- Client intent polling: once per five seconds while loading, stops on success
  or error, with a 180-second total timeout. The correlation token survives
  polling. Repeated client intents do not bypass server/API deduplication.
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
global spacing and bounded server entries.

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

Verified 2026-11-11: 48 wallet Lua assertions passed; the target Java scoped-entity
fixture passed 375 assertions. The 42.22.2 `-BuildOnly` compilation passed with
370 sources / 1061 class files, retained in the patches repository under
`42.22.2/artifacts/build_20261111_182253/`. Documentation links and diff checks
passed. The existing user addition to `project.json` was preserved.

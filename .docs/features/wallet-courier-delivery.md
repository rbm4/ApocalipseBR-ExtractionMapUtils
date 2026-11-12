# Wallet courier pickup and delivery

Status: implemented foundation; awaiting dedicated-server/client validation.
Created 2026-11-11. The [player market and radio operator](wallet-player-market.md)
now integrates the service with posting/buying and exact-item custody. The user
reports the debit backend implemented; seller-credit backend support is required
as documented in that market guide.

## Ownership and behavior

The wallet owns the courier implementation and assets. No DroneCompanion or
RadioTraders runtime dependency is required. `DroneRenderer.lua` ports the
DroneCompanion technique: cached visual-only item instances, native
`Render3DItem`, the support body and four independently rotating rotor meshes.
The imported models/textures are credited in the asset provenance file.

`CourierRoute.lua` performs a bounded cardinal grid search (625 visited nodes,
12-tile approach), rejecting solid squares and blocked wall/door/window edges.
The client interpolates the approach for eight seconds, hovers for two, then
reverses the route for eight seconds and removes the visual. An enclosed target
uses a vertical approach on its square. This is local visual navigation, not
native actor/vehicle navigation, long-distance aviation or roof avoidance.
Routes are planned once; subsequent changes to doors/obstacles are not replanned.
Only loaded client squares render. A missing drone render never prevents cargo.

Delivery jobs choose an arrival 30–90 wall-clock seconds after scheduling.
Compatible purchases at the same exact square and owner merge into a waiting
drone before its approach begins. The first ETA stays fixed. Pickups likewise
merge by owner before approach; a subsequent pickup updates that cosmetic
rendezvous to the latest pickup square. Each accepted batch sends a translated
ETA to the wallet radio log strip. The existing PTBR/default-language policy is
preserved in EN/UI.json and PTBR/UI.json. Opening the radio later shows the latest
message; courier sync refreshes outstanding ETAs every fifteen seconds.

## Trusted server interfaces

```lua
local Courier = require 'ApocWallet/CourierService'
local Purchase = require 'ApocWallet/PurchaseService'
local Store = require 'ApocWallet/EntityStore'

-- Invoke mutating server interfaces inside Store.run('unique-operation-key',
-- function() ... end) so persistence checkpoints can await entity callbacks.

-- A server catalog creates this quote. Never forward a client's price or item IDs
-- into this trusted interface without resolving/validating the catalog listing.
local orderId, error = Purchase.buy(player, 'stable-order-key', {
    amount = 150, -- positive INTEGER wallet units; maximum 1,000,000,000
    reason = 'market.purchase',
    items = {{type='Base.Axe', count=1}},
}, function(result)
    -- result.ok means the debit is confirmed and durable delivery is scheduled.
    -- It does not mean the cargo has already arrived.
end)

-- Exact authoritative inventory objects; reject equipped items. This removes
-- immediately, stores native item-save blobs in custody, and schedules only a
-- cosmetic pickup. It does NOT publish a listing or credit money.
local jobId, error = Courier.pickup(player, 'stable-post-key', {inventoryItem})
```

There is deliberately no client command accepting prices, arbitrary item creation,
debit requests or inventory removal. A later market controller must authenticate
intents and call these server interfaces. Direct `Courier.delivery(user, receipt,
squareCoordinates, itemSpecs)` is available for trusted fulfillment callers only.
The normal buying entry point is `Purchase.buy`, which gates delivery on the API.
Each quote and merged delivery accepts at most 100 items; at most 256 pending purchases and 256 active
courier jobs are admitted. Ledger records/escrow are retained for reconciliation;
a market retention/consumption policy remains future work.

## Debit contract for the backend session

Java endpoint: `ApocBrApiBridge.CHARACTER_DEBIT`.

```http
POST /api/v1/game/characters/{runtimeUuid}/debit?sourceServerId=2&steamId=76561198000000001
X-API-Key: <existing server credential>
Content-Type: application/json

{
  "amount": 150,
  "reason": "market.purchase",
  "idempotencyKey": "12345678-1234-4234-8234-123456789abc:stable-order-key"
}
```

Successful JSON response:

```json
{
  "balance": 850,
  "transactionId": "stable-backend-transaction-id",
  "idempotencyKey": "12345678-1234-4234-8234-123456789abc:stable-order-key"
}
```

The server captures the runtime character UUID, Steam ID, source-server ID,
username, square, item specifications, amount and reason BEFORE sending the API
request. No engine item/database reference is required by the backend. Credentials,
URL resolution, body validation and HTTP execution remain in Java.

Backend requirements (not implemented in this change): validate server scope and
character ownership; atomically debit only when balance is sufficient; persist a
unique transaction by character/server/idempotency key. Repeating the exact body
must return the original transaction and result without debiting again, including
after disconnect/death or a lost HTTP response. A changed amount/reason for the
same key must return 409. Check existing idempotent results before current-life
eligibility checks so replay can reconcile an already completed debit. Keys must
outlive the engine's retained order records. Suggested terminal errors: 400 bad
request, 401/403 authorization, 402 insufficient funds, 404 unknown character,
409 key conflict, 422 invalid binding/operation. Return 429/5xx for transient
failures. The engine retries ambiguous/transport failures with the SAME body/key;
it never interprets a cached displayed balance as debit authorization.

The key is character UUID plus caller order key. Use a new caller key for every
distinct purchase. Do not reuse a key after completion. Reasons accept ASCII
letters/digits, spaces and `_.:%-`, up to 128 characters; keys up to 160 in Java.
The Lua caller portion is limited to 80. These are ledger identifiers, not prose
typed by players. The server owns all values.

## Persistence, disconnects and failure behavior

The [entity-backed wallet checkpoint](wallet-entity-persistence.md), scoped by
server/world in `game_runtime.mod_data`, stores purchase requests before HTTP,
confirmed receipts, active jobs, destination coordinates, placement progress,
finished job summaries and pickup custody. Mutation boundaries wait for the
ApocalisebrPack entity callback before continuing. Legacy native GlobalModData is
read only for initial import when the SQL row is absent. Completed jobs leave the active update set; receipt tombstones
remain to prevent repeat scheduling. API requests have a 70-second reconciliation
deadline; a late callback for an older attempt is ignored and the stable backend
key permits replay. HTTP 4xx listed above stops the order without creating cargo.
The shipping backend must implement idempotency before this endpoint is used.

No delivery lookup requires the original player. Goods are created on the saved
purchase square when due, even if the buyer disconnects or moves. If the square
is unloaded, the service renews the existing server-thread
`ApocBRLobbyStreaming.keepCellLoaded(x,y)` request (one destination per update),
and waits for geometry integration. It does not activate virtual zombies. An
invalid/missing square or missing streaming patch leaves the paid job pending;
it is never silently discarded. Route planning and handoff are bounded to two jobs
per update; at most one forced destination load is requested per update. ETA is nominal: map loading/server downtime can
delay actual placement. Wall-clock jobs resume after restart. OnTickEvenPaused
keeps fulfillment alive on empty paused dedicated servers.

The server creates ordinary items with `instanceItem`, tags each with job/cargo
IDs, then uses `square:AddWorldInventoryItem(item, .5, .5, 0, true)` for native
multiplayer transmission. It retains partial progress and scans the square for
tagged items on retry. There is no client-authorized "arrived" or "give item"
message. The drone is purely cosmetic.

Pickup serializes exact native items through the server-thread Java facade
`encodeItem` (base64 `worldVersion + saveWithSize`, maximum 1 MiB per item and
4 MiB total per request). Native save data preserves supported item attributes
and contained items. Equipped items are refused. A write-ahead `removing` escrow
record is saved before inventory removal and becomes `held` afterward. On
reconnection/sync, interrupted removals reconcile by original character and
native item ID. A future publisher must only consume `held` entries and record
its own idempotent custody transfer; it must not blindly decode the same blob
multiple times. `decodeItem` is provided by Java for that future custody boundary.

**Crash limit:** native player/chunk saves and GlobalModData are separate files.
These are not one atomic database transaction. Receipt/progress tagging handles
normal retries, reloads and disconnects, but sudden process/power loss between
native world/inventory saves and ledger saves still needs reconciliation. Do not
claim exactly-once physical item persistence across arbitrary crashes. A future
database-backed custody/outbox can strengthen that guarantee.

## Verification

- `npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-drone-renderer.lua`
  checks model caching, body/four rotors, counterrotation and unloaded-square skip.
- `... fengari tests/wallet-courier.lua`: offline/unloaded delivery, stable square,
  ETA bounds, batching, partial failure retry, durable reload, immediate pickup,
  custody, duplicate requests/callbacks, API-success gating and rejected debit.
- `... fengari tests/wallet-courier-client.lua`: clock-offset alignment, arrival,
  hovering, departure cleanup, radio ETA and bounded/enclosed routes.
- Existing wallet, radio UI and radio-access harnesses and the translation
  validator remain required. These are mocked engine tests, not live game proof.
  Results on 2026-11-11: courier service 28 checks, courier client 10 checks,
  renderer checks passed; existing wallet 96, radio UI 67 and access 27 checks
  passed. Translation JSON/key/placeholder/UTF-8 checks and asset hashes passed.
- Java API tests use production classes, real Kahlua and loopback HTTP. Exact-JAR
  BuildOnly compilation is recorded in the Java courier feature guide.

Still required: dedicated server/client model orientation and z-height, multiplayer
render timing, item removal replication, offline/paused streaming, native item
codec roundtrip with real customized items, orderly restart and backend integration.

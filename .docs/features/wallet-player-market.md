# Player market and radio operator

Status: implemented; awaiting dedicated-server/client validation. Created
2026-11-11. The debit backend is reported implemented by the user. The matching
seller-credit endpoint described below must exist before seller wallet payments
can be confirmed. No backend implementation was changed in this work.

Persistence update: [wallet entities](wallet-entity-persistence.md) replace native
GlobalModData writes with atomic record mutations scoped to
`game_runtime.mod_data`. Interrupted posts retain their token. V54, the updated
Java bridge, pack facade and wallet must be deployed together with both game
instances stopped during conversion; V50 projections become historical archives.

## Player interaction

Open the existing wallet radio, power its two-way device, then press
**Sintonizar**. The player calls Controle do Mercado with their deterministic
sector. Static plays while tuning; after the server validates the radio, a short
handshake finishes and the operator acknowledges. The operator's animated
portrait appears in the radio display. This contact is a presentation of the
player market; it contributes no NPC stock.

The six physical keys, in their existing skin positions:

| Key | Offline | Connected |
| --- | --- | --- |
| 1 | Sintonizar | Comprar / Anunciar / Gerenciar expired stock |
| 2 | Visual | Menu: Mercado, Mochila, Meus expirados, Buscar por nome, Limpar busca |
| 3 | Anterior, disabled | Previous page |
| 4 | Próxima, disabled | Next page |
| 5 | Boletim, disabled | Refresh bulletin and displayed balance |
| 6 | Encerrar | Hang up and close |

Comprar asks quantity. Anunciar asks quantity and price **per unit**. The inventory
view excludes equipped items, the radio in use, and containers that still hold
other items; contents of carried bags are enumerated to a bounded depth. A page
contains at most six item groups/listings. Listings show names, deterministic
cargo codes, available quantity and unit price. Currency comes from the wallet;
network/backend details and internal errors are not shown in the market flow.

Every accepted post and buy action queues a player transmission with cargo code,
quantity and sector. Operator acknowledgments follow authoritative responses;
"credits confirmed / drone dispatched" only follows a successful debit and
durably queued delivery. Delivery/pickup ETA is spoken once per courier job;
later ETA syncs update text without repeated chatter. Page requests allow one
short player/operator exchange per five seconds, with actual navigation paced
at 350 ms. Silent purchase-status polling does not produce gossip. Lines are
spaced 1.4 seconds apart and queues/history are bounded. All captions, dialogs,
and protocol speech use PTBR keys; the existing Brazilian-Portuguese fallback
policy remains in both EN and PTBR catalogs.

Cargo code: `CARGA-` plus a five-digit hash of the full item type, rolling
`n=(n*31+byte)%100000`. Sector: `Sxxx-yyy-Nz`, using 100-tile grid coordinates and
the native square's floor. These are deterministic display codes; actual item,
listing and transaction identifiers remain authoritative server values.

Examples (with the translated values substituted at runtime):

> Controle, registrar CARGA-01234, 2 unidades, setor S012-034-N0.
> Solicito coleta. Câmbio.

> Roger. CARGA-01234, 2 unidades sob custódia. Registro confirmado;
> agrupando coleta. Câmbio.

## Ownership and trade lifecycle

`MarketProtocol.lua` owns shared display codes and bounds. `MarketService.lua`
owns radio sessions, paginated server inventory, listings, reservations, exact
item custody and seller-credit obligations. `MarketController.lua` accepts only
market intents and dispatches bounded work on normal and paused ticks.
`MarketClient.lua` owns client correlation, pending requests and roleplay queues;
`RadioDialogue.lua`, `OperatorPortrait.lua`, and `UI/MarketPanel.lua` provide
speech, the animated portrait, audio and controls. `RadioMarketController.lua`
attaches these to the existing wallet windows without a RadioTraders dependency.

The native server command supplies the player. Tune and subsequent page/post/buy
requests resolve the actual inventory/world/vehicle radio, verify two-way/power
state, and verify proximity/ownership. The server derives the character identity;
client identity, buyer prices, fulfillment item types and balances are ignored.
Server-side admission limits reject rapid commands. A radio session lasts at most
30 minutes without activity. MarketStatus is private to the authenticated buyer.

Posting records a pending listing, calls the existing immediate pickup/custody
service, then publishes only after the native save blobs are held. Native item
IDs and same-type checks are server-owned; equipped items and overlapping
container payloads are rejected. Pickup drones aggregate through the existing
courier service. The pickup animation does not remove items again. A custody
record marked `market` cannot be republished as a fresh held post.

Buying reserves exact listing units on the server before attempting payment.
Competing buyers cannot reserve the same units. The quote uses the stored unit
price and preserves the exact native item-save blob for each unit. The durable
reservation includes buyer identity and the square at the buy request. After
confirmed debit, the existing courier queues delivery there, independently of
the player remaining online. Delivery decodes the original items, retaining
condition, attachments and other native saved state; it does not substitute
pristine prototypes. A failed debit releases the reservation. Ambiguous debit
results keep it reserved until idempotent reconciliation.

**Self-purchases are explicitly enabled for testing.** The ordinary debit,
delivery and seller-credit paths all apply, even when seller and buyer match.
The same 10% sale fee applies to self-purchases.

Listings and transaction metadata are persisted as independently keyed records
through atomic mutation batches. Active indices are reconstructed on startup
and separate collecting listings, open listings,
unsettled purchases and unpaid credits from retained history. Up to four listing
recoveries and four transaction reconciliations run per update, with one seller
credit admission attempt. The existing purchase/courier capacities remain; open
plus collecting listings are capped at 2048. This market belongs to the current
server world/save; it is not a cross-server listing database.

Post/buy retries use the same client token. Business intent mutations commit
before removal/payment; unchanged HTTP admission retries issue no SQL writes. Reservations that survive a restart before debit admission can
resume without a live player. Seller payouts have separate immutable keys and
remain pending until acknowledged. Native chunk/player saves cannot share the
wallet SQL transaction: the existing arbitrary-crash atomicity limitation in
the [courier guide](wallet-courier-delivery.md) remains.

## Listing expiry, recovery, fees and search

Status: implemented; awaiting in-game multiplayer validation. Updated 2026-11-12.

Each listing remains public for **48 real-world hours**, starting when its exact
items enter market custody. `getTimestampMs()` is epoch wall-clock time
(`LuaManager.java`, `getTimestampMs()` delegates to `System.currentTimeMillis()`),
so offline server time counts. The 500 ms market tick delists expired stock;
buy requests also enforce the deadline, including requests from stale pages.
Legacy listings without a deadline use their stored publication/creation time;
those already older than 48 hours expire on access/update.

The connected radio's **Menu** key opens Mercado, Mochila, Meus expirados,
Buscar por nome and Limpar busca. In **Meus expirados**, select a listing and
press **Gerenciar** to choose:

- **Recuperar itens**: return all remaining unsold units by the existing courier
  to the seller's server-captured current square, retaining native item blobs.
- **Republicar por 48h**: publish the remaining units at the existing unit price
  for another full 48 hours, without another pickup or an upfront fee.

Only the listing's server-derived seller character can see/manage expired stock.
Expired items remain in custody indefinitely until managed; no inventory is
silently destroyed. Outstanding buyer reservations must settle before the seller
can manage that listing. Purchases reserved before expiry may finish afterward;
a failed payment releases units into expired custody rather than reopening them.
Sold or returned units cannot be reclaimed. Return intents, courier receipts and
repost acknowledgments are persisted, and same-token retries cannot duplicate
items or repeatedly extend a listing's deadline. Pending returns resume on the
server after restart without needing a connected seller, including courier-queue
backpressure. Reposts respect the existing 2048 active-listing limit.

On completed sales the buyer pays the listed gross amount. The seller receives
`gross - floor(gross * 10 / 100)` wallet credits. Rounding is per completed
purchase, in whole credits: gross 30 gives fee 3 / proceeds 27; gross 19 gives fee
1 / proceeds 18; a gross below 10 has a zero whole-credit fee. Posting, expiry,
recovery, reposting and failed purchases incur no fee. The transaction records
`fee` and `proceeds`, while the durable seller-credit obligation uses net proceeds
and its existing immutable idempotency key. Previously recorded credits are not
rewritten. This does not change the backend credit/debit contract.

Name search is server-side literal substring matching, applied **before
pagination** to market, inventory and expired-item views. It ignores ASCII letter
case, preserves the query across navigation/refresh, resets to page 1 for a new
search, and accepts at most 100 bytes without control characters. Clearing search
restores the full view. Matching uses the item name already shown by the server;
non-ASCII letters retain Lua's native case semantics. No patterns are evaluated.

Inspection of installed RadioTraders Workshop `3807707103` found
`42/media/lua/shared/RadioTraders/RT_Advanced.lua:A.findItems` filtering item
script definitions by include/exclude hashes and a callback. No player-facing
name-search UI was found in its Lua code. Wallet search is independent of that
helper and does not add a RadioTraders dependency. New controls/messages use the
existing EN and PTBR `UI.json` catalogs with the existing PTBR fallback policy.

## Seller-credit backend contract

The existing debit route/body remain unchanged. New Java alias:
`ApocBrApiBridge.CHARACTER_CREDIT`.

```http
POST /api/v1/game/characters/{sellerRuntimeUuid}/credit?sourceServerId=2&steamId=76561198000000001
X-API-Key: <existing server credential>
Content-Type: application/json

{
  "amount": 150,
  "reason": "market.sale",
  "idempotencyKey": "12345678-1234-4234-8234-123456789abc:sale:17:stable-buy-token"
}
```

Success uses the same mutation receipt shape:

```json
{
  "balance": 1150,
  "transactionId": "stable-seller-credit-transaction",
  "idempotencyKey": "12345678-1234-4234-8234-123456789abc:sale:17:stable-buy-token"
}
```

Validate the authenticated game-server scope and seller ownership/binding.
Amount is a positive integer wallet-unit value, maximum 1,000,000,000. Reason is
`market.sale`; the underlying bridge accepts at most 128 ASCII ledger characters.
Keys are at most 160 ASCII identifier characters. Atomically add the amount and
persist a unique result by server/character/key; exact replay returns the original
receipt, changed amount/reason returns 409. Offline sellers must be supported;
existing receipts must reconcile after disconnect or life changes. No engine
item reference is required. This is a server credential capability, not a public
client-controlled credit endpoint.

The engine records the obligation only after the buyer's debit/delivery is
confirmed. No response, malformed receipt, unavailable endpoint or HTTP error
clears that obligation. Admission failures back off five seconds; other failures
retry the same payload/key after sixty seconds. A 404 therefore stays pending
until the endpoint is installed. Operators can inspect the pending `credits`
records; the player UI never claims that a seller payout has completed early.
Backend conflicts/auth failures require administrator correction rather than
discarding an owed amount. Payment and delivery are a durable saga, not a single
distributed database transaction.

## Ported presentation assets

The sixteen Sparks portrait frames and Static/Squelch/Hangup sounds were copied
from the installed RadioTraders Workshop 3807707103 and namespaced as ApocWallet
assets. The portrait uses its original eight-frame-per-second animation while
the operator speaks, a still frame while listening and bounded scan-line effects
while tuning. This ports RadioTraders' animated 2D portrait path; optional live
3D survivor/custom-outfit portrait infrastructure is not required. Source paths
and attribution are in the [asset provenance](../../ApocalipseBR-Wallet/common/media/textures/ApocWallet/operator/PROVENANCE.md).

## Verification

Run from the ExtractionMapUtils repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-market.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-market-client.lua
py -3 tests/wallet-translations.py
```

- `... fengari tests/wallet-market.lua`: 70 checks using production services,
  mocked engine/HTTP boundary. Covers tune authentication, immediate exact-item
  posting, duplicate tokens, private custody, server prices, competing buyers,
  debit gating, seller credit, failed-debit stock release, self-purchase success,
  offline reservation recovery, exact-condition delivery, 48-hour boundaries,
  private expired views, stale purchases, repost replay, search before pagination,
  exact-item returns, return restart recovery, post-expiry settlement and sale-fee rounding.
- `... fengari tests/wallet-market-client.lua`: 34 checks using production client,
  dialogue, portrait and panel code with native widget stubs. Covers handshake
  delay, local-player correlation, spoken codes/sectors, reply-only acknowledgments,
  page chatter limits, same-token retries, silent status checks, one ETA per job,
  quantity controls, six buttons, frame caching, measurement-free rendering,
  menu actions, filtered pagination, recovery/repost commands and stable retries.
- Existing wallet/courier/radio tests and the expanded B42 catalog validator
  remain required. Tests do not invoke the live backend.
- Java: 105 production API/Kahlua/loopback HTTP checks passed; exact-JAR BuildOnly
  passed with 371 sources / 1062 classes, artifact directory
  `42.22.2/artifacts/market-radio-2026-11-11` in the Java patches repository.

Pending in-game verification: radio inventory/world/vehicle power synchronization,
native speech bubbles, modal focus, portrait and sound appearance, item removal
replication, unloaded offline delivery, and the real debit/seller-credit backend.
No deployment was performed.

Expiry/search validation run (2026-11-12): market service 70 checks and market
client/UI 34 checks passed. Regression harnesses `wallet.lua` (96),
`wallet-courier.lua` (28), `wallet-courier-client.lua` (10),
`wallet-entity-store.lua` (21), `wallet-radio-ui.lua` (67), and
`wallet-radio-access.lua` passed via
`npm exec --yes --package=fengari-node-cli -- fengari tests/<name>.lua`.
`py -3 tests/wallet-translations.py` and `git diff --check` passed. The expected
mock persistence-failure log lines in the market harness exercise save failures.
New EN/PTBR catalog entries parsed successfully and all files touched by this
feature were checked for UTF-8 encoding without BOM. Tests mock engine/API
boundaries; in-game context-menu focus/layout, courier return replication, and
real backend net payouts remain unverified. No deployment was performed.

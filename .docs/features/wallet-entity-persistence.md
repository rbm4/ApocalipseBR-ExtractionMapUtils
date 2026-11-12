# Wallet entity persistence in game_runtime

Status: implemented; isolated database and actual Kahlua tests passed, live server
validation pending. Created 2026-11-11. This supersedes the attempted native-file
flush fix for the unexposed `ModData.save()` call.

## Dependency and contract

`ApocalipseBR-Wallet/42/mod.info` requires **APOCALISEBR_PACK**. The wallet imports
`ApocBR/Entities` from ApocalisebrPack; it does not execute SQL, own a connection,
choose a datasource or accept client scope identifiers.

The pack facade now provides `serverScope()`, `encode(table)` and `decode(text)`.
Java captures the configured engine server ID and current save-world name.
Data-only JSON preserves arrays and string-keyed tables, rejects userdata/cycles,
limits depth to 64 and collections to 100,000 entries, and bounds documents to
32 MiB of Java characters. Finite numeric values must fit Lua's exact range.
The new entity field type `text` supports these bounded payloads; existing
`string` fields retain their 4096-character bound. No URLs, JDBC or schema DDL
cross the Lua facade.

## Database map

All tables are on **game_runtime**, schema **mod_data**. Flyway migration:
[V50__Create_Wallet_Entity_State_And_Market_Tables.sql](Z:/git/Github/apocalipsebr-manager/manager/src/main/resources/db/game-runtime-migration/V50__Create_Wallet_Entity_State_And_Market_Tables.sql).

| Runtime data | PostgreSQL table |
| --- | --- |
| Whole wallet checkpoint, counters and active indices | `wallet_mod_data` |
| Pending courier jobs | `wallet_courier_job` |
| Delivery idempotency receipts | `wallet_courier_receipt` |
| Finished courier summaries | `wallet_courier_finished` |
| Exact native item blobs and pickup custody | `wallet_item_custody` |
| Pending/completed debit and fulfillment orders | `wallet_purchase` |
| Player listings | `wallet_market_listing` |
| Reservations and trades | `wallet_market_transaction` |
| Seller payout obligations/receipts | `wallet_market_credit` |
| Wallet-owned per-object metadata | `wallet_item_mod_data` |

The mapped repository is `ApocWallet.State` -> `mod_data.wallet_mod_data`, with
composite IDs `(server_id, world, record_id)` and the existing optimistic revision
contract. Its record ID is `global:ApocWallet.Couriers.v1`. The payload contains
the complete wallet state. PostgreSQL projects each collection into the separate
tables in the SAME transaction, using a trigger with upserts/deletes. This is
intentional: a custody/listing/receipt transition cannot partially commit across
independent entity writes. The projection tables expose each record's JSONB
payload plus generated `state` and `owner_name` columns and scoped state indexes.
They are read models; do not modify them independently of the checkpoint.

The migration explicitly grants schema access, table privileges and trigger
execution to `pz_server_01`, and preserves defaults for objects created by
`apocalipsebr`. It requires the existing `player_rel.server` registry. No live
migration was executed by this session.

## Asynchronous consistency

`EntityStore.lua` loads the scoped row asynchronously before activating trades.
It serializes wallet operations in a bounded 128-task queue, deduplicated by
command token or periodic worker name. At a persistence checkpoint the coroutine
waits for the entity save callback. Inventory removal, HTTP debit dispatch and
success acknowledgment proceed only AFTER the corresponding revision commits.
Neither Lua nor the server simulation thread blocks on JDBC. Completions and
continuations run on the normal server Lua thread, including OnTickEvenPaused.

BUSY/UNAVAILABLE admission retries after five seconds. CONFLICT/OUTCOME_UNKNOWN
reads the authoritative row: an identical committed payload resumes once; a
different payload aborts the operation and reloads rather than overwriting it.
Permanent failures block new work, restore the last acknowledged snapshot and
surface the existing PTBR recording-error response. Startup/schema failures keep
trades unavailable and retry the entity load; local autosave is never substituted
for a successful database acknowledgment. Economy callbacks enter the same queue
and reacquire their records by ID before applying results.

Pickup item ownership and exact native bytes are rechecked after the asynchronous
write-ahead acknowledgment. If the player moves/changes/equips the item while SQL
is pending, custody is cancelled without removing that item. If a restart leaves
an interrupted removal, recovery only takes the exact original objects still
present; missing/mismatched objects produce `uncertain` custody requiring review,
not an automatically published duplicate.

SQL cannot atomically transact with the game's native inventory/world files.
The original crash limit therefore remains around the physical handoff. Stable
receipts, native markers and uncertain custody protect recovery; this feature
does not promise exactly-once native item survival across arbitrary JVM/power loss.

## Global and object ModData

Wallet services use `EntityStore.data()` instead of `ModData.getOrCreate`.
`EntityStore.modData(kind, id)` stores wallet-owned object metadata in the same
checkpoint and its `wallet_item_mod_data` projection. Delivered item markers are
written there and mirrored to the native item table for multiplayer/world retry
recognition. Complete native item ModData/attributes remain preserved in the
encoded custody item blobs. Native item tables are transport/game caches; wallet
business records and checkpoints are authoritative in PostgreSQL.

This maps the wallet's ModData, not every unrelated mod's global table or all
future changes to arbitrary vanilla objects. Existing wallet UI/balance caches
remain transient and the backend remains authoritative for money.

On startup, an existing SQL row always wins. Only if it is NOT_FOUND does the
store read the legacy native `ModData.get('ApocWallet.Couriers.v1')` once, copy it
as the initial state and commit it through the entity checkpoint before enabling trades.
It does not delete the old native data. After SQL creation, stale native data is
ignored. Import before removing the old save files; do not run two writable
servers against the same server/world scope.

## Deployment and verification

Apply V50 using the manager's existing game-runtime Flyway datasource. Deploy the
updated 42.22.2 Java patch, the pack facade and wallet files together; enable the
pack dependency, restart the JVM and reconnect clients. No change to the debit or
credit HTTP contracts is required. An older bridge without the new contract
leaves the wallet in startup-unavailable state.

- `npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-entity-store.lua`:
  21 checks, using the REAL pack Lua facade with asynchronous entity/database
  doubles. Covers import, server/world scope, delayed commits, duplicate tokens,
  busy admission, lost acknowledgment, restart authority, metadata and item races.
- `py -3 tools/test_wallet_store_kahlua.py` in the patches repository executes
  those same production Lua files and checks in the installed game's actual
  Kahlua runtime, with its stdlib. Passed.
- `py -3 tools/test_mod_entities.py --version 42.22.2`: 326 Java mapping/worker
  checks plus Lua lifecycle/scoped reads. Includes bounded text and JSON behavior.
- `WalletEntityMigrationTest`: two tests passed against disposable PostgreSQL
  17.6 using separate backend/engine roles; Flyway apply/re-run/validation, actual
  projection updates/deletes/rollback, CAS and server/world isolation were checked.
  The disposable cluster was stopped afterward. The first full manager test-build
  hit unrelated missing target/classes artifacts; the focused tests were compiled
  and run with the same POM dependencies in an isolated temporary build.
- Existing wallet, market, courier, UI and translation regression checks remain
  required. Exact-JAR Java BuildOnly is recorded in the engine feature guide.

Still required: live dedicated-server startup/import, PostgreSQL outage recovery,
real item removal/replication, offline delivery and restart validation with this
deployment combination. No live database or server was deployed/restarted here.

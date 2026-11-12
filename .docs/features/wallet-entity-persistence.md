# Wallet record mutations in game_runtime

Status: implemented; isolated PostgreSQL, Lua and actual Kahlua validation passed;
live dedicated-server validation pending. Updated 2026-11-12. Supersedes the V50
whole-wallet checkpoint design. See [the CPU investigation](../reports/2026-11-12-wallet-postgres-cpu-review.md)
and [mutation hotfix](../hotfixes/wallet-record-mutations.md).

## Persistence contract

The independent wallet requires **APOCALISEBR_PACK** and server patches **42.22.2**.
It imports the pack's server-only `ApocBR/Entities` facade. Money remains owned by
the existing backend debit/credit APIs; Lua never authorizes spending from its
balance cache. No SQL, credentials or client-chosen identity enter wallet Lua.

`Entities.document('ApocWallet.Couriers.v2')` exposes asynchronous `load(callback)`
and `mutate(revision, mutationId, operations, callback)`. Java captures configured
server ID and the native world on the owning Lua thread, serializes the bounded
operation array before admission and uses the existing persistence replay worker
for JDBC. Completions return to the owning Lua thread through OnTickEvenPaused.
No mutable Lua tables or live player objects cross to the database worker.

Manager migration **V54__Wallet_Record_Mutations.sql** creates:

| Table | Purpose |
| --- | --- |
| mod_data.entity_document_state | One small revision/token/hash row per server/world/document |
| mod_data.entity_document_record | Independently keyed JSONB records per collection and record ID |

The record primary key is `(server_id, world, document_id, collection, record_id)`.
Canonical collections are `jobs`, `receipts`, `finished`, `escrow`, `purchases`,
`itemData`, `market.listings`, `market.requests`, `market.transactions`,
`market.credits` and `market.actions`. `$` and `market.$` store individual root
scalar fields such as sequence counters. Payloads wrap one value as `{"value":...}`.
Pending/open/expired indexes are rebuilt in memory from canonical records at
startup. V50's wallet_mod_data and nine projection tables become historical
archives; they no longer describe current wallet state after V54.

## Mutation and commit barriers

Services name the collection/key pairs they change in `Store.persist(...)`.
Only those records are encoded and compared with their acknowledged per-record
value. Unchanged records cause no SQL. A delete names its exact key. There is no
recurring whole-root serialization, history traversal, SQL snapshot replacement,
full collection upsert or full collection delete sweep. A changed record is still
encoded as a complete entity value, including its item blobs where applicable;
this is record-level mutation, not a byte/field delta within an item blob.

One SQL function call locks the small scope revision row, checks optimistic
revision, applies at most 256 runtime operations by primary key and advances the
revision in the same transaction. The database validates the fixed function/table
contract; it does not repeat JDBC schema/primary-key discovery on each mutation.
The entire batch rolls back on any invalid record. A mutation token plus digest
recognizes an identical last committed batch after a lost acknowledgment. A
changed body or another writer conflicts rather than overwriting data.

Wallet operations remain serialized through the bounded 128-task coroutine
queue. Inventory removal, delivery acknowledgments and HTTP dispatch retain
their durable business-intent barriers. Explicit listing/unit reservations and
transactions commit together. Fulfillment receipts make later transitions
recoverable when a process stops between commits. Native inventory and SQL still
cannot transact atomically; uncertain interrupted custody requires review.

BUSY/UNAVAILABLE and unknown commit outcomes replay the same bounded mutation
at five-second intervals. SQL errors, conflicts and operation failures block the
wallet, restore affected acknowledged records and reject queued work. They do not
automatically resume closures holding stale record references. Diagnose the
failure and restart/reload after resolving it; gameplay is otherwise unaffected.

## Retry scheduling

Payment intents and seller obligations commit when created, before HTTP dispatch.
Repeated API admission attempts do not resave those intents. `nextAttempt`,
`requestId` and `attempts` are runtime scheduling fields omitted from stored
purchase/credit records. Restart can retry immediately using the SAME durable
idempotency key/body; backend idempotency remains required. A changed business
response/error may update that one record; repeated equal values are skipped.
Existing HTTP retry/error classifications are preserved.

## Import, bounds and deployment

Stop BOTH wallet-enabled server instances before applying V54 through the
manager's **game-runtime Flyway datasource**. V54 atomically converts existing V50
wallet snapshots into independent records, preserving their source scopes and
canonical history. Original snapshots/projections remain intact for diagnosis;
a guard rejects writes from the retired v1 wallet so mixed versions cannot fork
authoritative state. The old V50 migration is unchanged.

Deploy the updated Java patches, pack `ApocBR/Entities.lua` and wallet together,
then restart both server JVMs and reconnect clients. Applying V54 while old
wallet instances continue writing will deliberately make those wallets fail;
this is a coordinated maintenance rollout. Do not simply downgrade the wallet
against V54: the archives no longer include post-migration trades.

An existing v2 SQL document always wins. Only NOT_FOUND permits one-time native
`ModData.get('ApocWallet.Couriers.v1')` import. The initial creation can contain up
to 100,000 records in one atomic transaction; normal mutations are capped at 256.
JSON has the existing 64-level/100,000-entry collection limits and 32 MiB Java
character bound. Startup reconstruction is capped at 100,000 records and 32 MiB
of aggregate record/key characters. Oversize imports/loads fail explicitly,
without partial activation. No database query runs for a ready idle store.
Historical retention/archival remains future work; record mutations remove its
cost from unrelated writes, but do not make retained history or startup unbounded.

## Verification

From this repository: `npm exec --yes --package=fengari-node-cli -- fengari`
followed by each of `tests/wallet-entity-store.lua`, `tests/wallet-market.lua` and
`tests/wallet-courier.lua`.

The mutation fixture uses the real pack facade/store/services with an async
transport double. It covers import, delayed commits, busy admission, unknown
commit replay, metadata, item races, targeted deletes, unchanged writes,
3,000-record retained history, retry bookkeeping, payment admission without SQL,
queue reconstruction and fail-closed conflict handling. Java/Kahlua and actual
PostgreSQL validation commands/results are in the linked hotfix.

No production migration, server restart, deployment or live CPU benchmark was
performed. Real multiplayer item handoff, reconnect/restart and recovery during
an actual database/API outage remain deployment smoke tests.

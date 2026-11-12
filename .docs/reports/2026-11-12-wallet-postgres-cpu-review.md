# Wallet PostgreSQL CPU review — 2026-11-12

Status: source review; production attribution pending. Wallet revision `bb449e4`;
Java source inspected in the patches repository's `42.22.2` tree. Exact deployed
artifacts, production payload sizes, query rates and query timings are unverified.
See [entity persistence](../features/wallet-entity-persistence.md) and
[API connectivity](../features/wallet-api-connectivity.md).

## Reported incident

CPU increased from roughly 3–5% at about 00:30 local time and remained elevated
overnight; provider currently limits it to 30%. Provider listed PostgreSQL
`pz_server_01 / game_runtime` connections from `72.62.137.60` (45.1%) and
`179.198.119.1` (28.7%), both labelled `idle`. User confirmed both clients run
instances of the recent wallet/entity updates. No live database was accessed.

`idle` is the backend's current activity state, not evidence that its earlier
queries were cheap. The provider's CPU sampling method is unknown. Obtain sampled
CPU by PID and interval query statistics before attributing sustained CPU to a
particular statement. Process percentages also cannot be equated directly with
the provider's whole-VPS percentage without its core count and accounting method.

## Confirmed source findings

1. **Full-state write amplification, highest-priority suspect.**
   `server/ApocWallet/EntityStore.lua` defines one `ApocWallet.State` entity with
   composite key `(server_id, world, record_id)` in `mod_data.wallet_mod_data`.
   `record_id` is `global:ApocWallet.Couriers.v1`; `payload` contains the entire
   wallet tree. Every changed checkpoint serializes and sends that tree. Saves
   use the indexed composite key and optimistic revision; there is no missing
   primary key in this mapping.

   Manager migration `V50__Create_Wallet_Entity_State_And_Market_Tables.sql`
   attaches `project_wallet_entity` AFTER INSERT or UPDATE OF payload. Each
   checkpoint parses the document and traverses all nine projected collections:
   jobs, receipts, finished, escrow, purchases, listings, transactions, credits,
   itemData. Each collection executes an INSERT/ON CONFLICT plus a DELETE pass.
   The distinct-payload predicate avoids rewriting equal child rows, but still
   enumerates input, probes conflicts and evaluates comparisons. The parent text
   also has a JSONB validation CHECK. One small state change therefore incurs
   work across the whole history and exact item blobs. This is CPU amplification
   even without large numbers of changed rows.

2. **Persistent retry work can continue with no players.**
   `PurchaseService.submit/update` checkpoints before debit admission, then again
   on accepted-result processing. Admission failure schedules another attempt
   after three seconds; transient responses use backoff up to 48 seconds.
   `MarketService.credit/update` checkpoints before credit admission, retries
   admission after five seconds and unsuccessful responses after 60 seconds.
   Credits have no permanent-error terminal branch. Multiple eligible obligations
   can each progress on successive 500 ms service updates; these delays are
   per-record, not a single global checkpoint limit. The API transport has its
   own limits, but those do not prevent the pre-admission SQL checkpoint.
   Controllers also run through `OnTickEvenPaused`, so empty-server pause does
   not stop this work. Successful settled records leave pending indexes; this
   is conditional retry work, not proof that every idle server writes forever.

3. **History is retained in the hot checkpoint.**
   Active courier jobs are removed on completion, but finished summaries,
   receipts, escrow, purchases, listings, transactions, credits, actions and
   request indexes have no general archival/retention policy in these services.
   The 256 pending purchase/job and 2048 active listing limits do not bound total
   historical payload size. Exact blobs can occur in several related records.
   Larger history increases every later save's cost. Do not delete idempotency
   receipts or custody records as a quick cleanup; that needs a recovery design.

4. **Every entity database request repeats schema validation.**
   Java `ApocBRModEntities.execute` calls `validate` before find/save/etc. It
   executes a WHERE false metadata query and JDBC `getPrimaryKeys`, then the
   actual operation and commit. This is avoidable round-trip/catalog overhead
   under high request rates, but no measured evidence identifies it as dominant.
   Character identity lookups use tracked bindings in memory; `poll()` drains
   Java completion results and does not query PostgreSQL.

5. **No unconditional SQL polling found in the wallet tick path.**
   `EntityStore.persist` skips SQL when encoded state equals its committed
   snapshot. Ready-store idle updates do not find/save. Bootstrap failure retries
   at five-second intervals, and conflict/unknown commit outcomes perform a
   reconciliation find. Courier/market/purchase controllers schedule tasks every
   tick (both normal and paused events), but their service time gates and
   read-only in-memory scans are not themselves database calls. Login/balance
   display operations have a memory cache and bounded registration retries.

## Working hypothesis and discrimination

Two updated instances independently running pending debit/credit retries against
growing full-state snapshots and projections can explain sustained PostgreSQL
CPU. This remains a hypothesis until production counters confirm it. The latest
wallet persistence commit is timestamped 00:09:38 -0300 on November 12; its
proximity to the reported 00:30 onset supports investigation, but does not prove
deployment time or causality. Other entity consumers and native persistence
share `pz_server_01` and application name `ApocBR-game-persistence`.

Run the accompanying [read-only psql capture](2026-11-12-wallet-postgres-capture.sql)
against **game_runtime**, twice 60 seconds apart in separate autocommit calls.
It contains no DDL, resets, cancellation or full wallet payload output. Inspect
the optional JSON summary once after the cheap size/revision capture. Query
texts can contain identifiers/literals; review before sharing outside the team.

- Compare wallet revision and `n_tup_upd` deltas: increasing values prove wallet
  checkpoints, while stable values during high CPU weaken this hypothesis.
- Match active PID/client/application/query to interval OS samples, e.g.
  `pidstat -u -p <pid1>,<pid2> 1 30` if installed. Obtain current PIDs from SQL.
- If pg_stat_statements is already installed/loaded, compare calls, execution
  time and WAL deltas for wallet UPDATE versus native persistence/catalog work.
  Execution time includes waiting; it is not a CPU measurement. Trigger work
  contributes to the parent UPDATE; nested statements need track=all to appear
  separately. Do not enable/restart/reset anything before preserving evidence.
- Inspect pending counts, nextAttempt ranges, attempt counts and error buckets.
  Stable backlog with increasing revisions/attempts strongly suggests retry
  churn. No pending work and stable revisions points to another caller/query.
- A trigger timing analysis belongs in an isolated copy: EXPLAIN ANALYZE UPDATE
  executes writes and is intentionally absent from this production capture.

## Recommended changes after attribution

Keep custody and monetary commit barriers. First stop retrying terminal seller
credit errors automatically and separate retry/admission bookkeeping from durable
business transitions where crash recovery permits. Next make projection work
conditional on changed collections/records; equal child payload predicates alone
do not avoid enumeration. Longer term use bounded transactional changes with
archival of settled history, preserving idempotency and custody recovery. Cache
successful schema validation per mapping with explicit invalidation/failure
handling. Each change requires regression coverage and its own hotfix document.

## Verification and limits

Source trace covered wallet entities, all three periodic workers, controllers,
the real pack facade, Java entity execution/identity/connector and manager V50.
No gameplay changes, migration, deployment or production query was performed.
Validation results:

- `npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-entity-store.lua`:
  all 21 existing checks passed.
- Isolated temporary script `%TEMP%/apoc-wallet-cpu-review.lua` appends experiments
  to the existing harness so it can reuse the real pack facade, store and wallet
  service modules with the same asynchronous database double. A fresh empty
  root, initialized service collections and committed baseline were scheduled
  for 14,400 cycles at 250 ms intervals (one simulated hour): zero SQL admissions.
- The same fixture then added one pending seller credit and an API stub that
  rejects admission. Successful SQL acknowledgments were delivered while
  advancing the market scheduler for 60 simulated seconds: **12 API admission
  attempts and 12 SQL checkpoints**. No players were needed. This reproduces
  pre-admission write churn, without claiming its database CPU cost was measured.
- `git diff --check` and relative documentation-link review passed.

The extra experiments use simulated time/engine/database boundaries; they are
diagnostic observations, not new gameplay behavior or PostgreSQL benchmarks.
Mocked tests cannot establish production SQL cost.

PostgreSQL references:
[activity and cumulative statistics](https://www.postgresql.org/docs/18/monitoring-stats.html),
[pg_stat_statements](https://www.postgresql.org/docs/18/pgstatstatements.html).

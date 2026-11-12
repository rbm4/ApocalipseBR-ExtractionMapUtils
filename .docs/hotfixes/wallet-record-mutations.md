# Wallet record mutations

Created 2026-11-12. Status: implemented and tested in isolation; live rollout pending.
Owning feature: [wallet persistence](../features/wallet-entity-persistence.md).
Investigation: [PostgreSQL CPU review](../reports/2026-11-12-wallet-postgres-cpu-review.md).

The previous persistence path rewrote the entire wallet and triggered nine
projection upsert/delete passes per checkpoint. Payment admission retries also
checkpointed before calling HTTP. One rejected seller-credit admission generated
12 SQL saves per simulated minute even without players.

EntityStore now tracks explicit changed collection/key pairs, compares only
those entities, and submits one atomic scoped record mutation batch. Services
declare their records at each business transition. Runtime HTTP scheduling is
excluded from persisted payment records and no longer triggers pre-admission
writes. Pending queues are rebuilt from canonical records after restart.

Companion changes: the pack facade exposes asynchronous scoped documents;
42.22.2 ApocBRModEntities captures immutable bounded mutation data and runs JDBC
on the existing replay worker; manager V54 imports existing snapshots once into
entity_document_state/entity_document_record. V50 remains unchanged and archived
snapshot writes are rejected. A coordinated stop/migrate/update/restart of both
instances is required; see the feature guide for bounds and recovery semantics.

Validation commands:

```powershell
# Mod repository
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-entity-store.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-market.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-courier.lua
# Patches repository
py -3 tools/test_mod_entities.py --version 42.22.2
py -3 tools/test_wallet_store_kahlua.py
.\42.22.2\patchApocalipseBr.ps1 -BuildOnly
# Manager, with GAME_RUNTIME_TEST_POSTGRES_URL pointing to a disposable loopback cluster
.\mvnw.cmd '-Dtest=WalletMutationMigrationTest' test
```

Results: 35 mutation-store assertions, 70 market assertions and 28 courier
assertions; Java entity fixture passed 348 checks; actual game Kahlua passed the
same store/services fixture. A changed purchase among 3,000 historical records
encoded/submitted exactly one record. Rejected debit/credit admission retries
produced zero SQL calls for a simulated minute. PostgreSQL migration tests cover
preservation, replay/CAS, rollback, independent scopes, deletion, unchanged
history, concurrent writers and runtime/import batch bounds: **7 tests passed**,
no skips/failures. Final exact-JAR BuildOnly compilation passed **373 Java sources /
1064 class files**, retained at
`apocalipsebr-zomboid-patches/42.22.2/artifacts/build_20261112_105402/`.

These are production-code fixtures with mocked engine/API boundaries plus an
isolated PostgreSQL 17.6 cluster, not a measured production CPU improvement. No
live server/database was changed. Native inventory and SQL retain their existing
cross-system crash boundary. Each changed record still includes its own blobs;
large single entities and long-term archival remain separate performance limits.

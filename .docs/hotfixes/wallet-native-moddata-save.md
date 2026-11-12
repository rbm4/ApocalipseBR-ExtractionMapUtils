# Wallet persistence failure and misleading unavailable-cargo reply

**Superseded resolution:** the user subsequently requested the established pack
entity contract. Current persistence is [PostgreSQL-backed](../features/wallet-entity-persistence.md),
not `saveModData()` or native GlobalModData writes. The diagnosis below remains
valid; the intermediate native-flush implementation/deployment instructions are
historical and must not be used for the current wallet.

Status: fixed in source; awaiting dedicated-server retest. Created 2026-11-11.
Owning features: [player market](../features/wallet-player-market.md) and
[courier delivery](../features/wallet-courier-delivery.md).

## Observed failure

The supplied dedicated-server trace failed in `CourierService.persist` while
`MarketService.post` registered a listing, then again during `reconcileListing`
about ten seconds later. Kahlua reported `Object tried to call nil`. The client
eventually displayed the ITEM response, "Negativo. Carga indisponível...".

This was not a purchase HTTP timeout. The Lua implementation called
`ModData.save()`. Exact 42.22.2 `zombie.world.moddata.ModData` exposes
`getOrCreate/get/add/remove/transmit/request` and related helpers, but no `save`.
Only `GlobalModData.instance.save()` implements the native disk operation, and
that class is not the Lua-facing ModData facade. Earlier Lua tests incorrectly
stubbed `ModData.save`, concealing the integration error.

An intent was added in memory before the bad save call. No pickup followed that
first exception. The old ten-second reconciliation rejected the intent for
missing custody; its replay could then produce ITEM even though the original
inventory items remained available. The unrelated `SpringFieldCricketCall1/2`
warnings name neither a wallet sound nor the failing Lua operation. No cricket
sound files or global sound definitions were changed by this fix.

## Change

The server-only `ApocBrApiBridge.saveModData()` calls the real native operation
on the initialized API bridge's owning server thread. It returns false for
client/worker access, NoSave mode, or a native save failure. Native I/O stays out
of the HTTP worker. The existing bridge is extended; no vanilla ModData class is
replaced and no autosave-only fallback is substituted for custody persistence.

Courier and purchase services check that this capability exists before accepting
mutations. Missing bridge support pauses fulfillment and rejects new trades with
STORAGE before creating an intent. Failed flushes stop the current operation and
back off five seconds. The market command boundary catches exceptions and returns
STORAGE for persistence failures, rather than leaving the client waiting for a
reply or conflating every infrastructure failure with missing inventory.

The client speaks a distinct PTBR recording-error message once and retries the
same post/buy token. A saved intent without custody can resume after validating
the original item IDs again. Interrupted intents are no longer marked as missing
cargo; legacy `rejected` records without a pickup error can also resume. Actual
missing/equipped items still produce ITEM; queue pressure and item-codec failures
retain separate response classes. The existing native-save crash-atomicity limit
still applies.

## Deployment

Deploy the updated 42.22.2 server patch **and** the wallet Lua/client translations,
then restart the server JVM and reconnect clients. The new Lua intentionally
blocks trades against an older patch lacking `saveModData`; updating only the Lua
will not enable persistence. The original GlobalModData tag and saved records
are retained; do not delete the market/custody tables to clear this error.
No files were deployed in this session.

## Verification

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-market.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-market-client.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-courier.lua
py -3 tests/wallet-translations.py
```

- Market: 36 checks, including absent save capability, failed disk flush before
  removal, interrupted intent and legacy-record replay without duplicate listing.
- Client: 26 checks, including stable-token retry and one distinct operator
  message across repeated recording failures.
- Courier: 28 checks. Engine stubs now correctly omit `ModData.save` and expose
  saving through the Java facade boundary instead.
- Java: 111 checks with production facade code and real Kahlua. Reflects the real
  ModData class to verify `save` is absent, invokes the new facade through Lua,
  and checks write failure, NoSave, client and unrelated-thread rejection. Native
  disk calls are stubbed in this isolated harness; no live save was modified.
- Exact-JAR BuildOnly: 371 sources / 1062 classes passed, artifacts retained at
  `42.22.2/artifacts/wallet-persistence-fix-2026-11-11` in the patches repository.

Still required: replay a post on the actual dedicated server, confirm immediate
inventory removal and the resulting listing, then verify normal save/restart and
delivery. Mocked tests and compilation are not proof of live disk persistence.

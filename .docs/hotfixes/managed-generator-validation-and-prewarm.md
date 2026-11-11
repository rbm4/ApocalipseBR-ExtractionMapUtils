# Managed generator validation and pre-warm diagnostics

Status: implemented on 2026-11-11; dedicated-server runtime validation pending.

## Symptom and cause

The lobby startup reported only `FAILED: configure a valid LobbyGeneratorX/Y/Z source tile`, hiding which option failed. Coordinates default to X=-1, Y=-1, Z=0. The packaged `LobbyFixedPower` default is already false, but saved or deployed sandbox values can still enable it; changing a default does not overwrite explicit existing values.

The engine also needs explicit map pre-warming before inspecting source squares on a dedicated server. An absent square before loading cannot be classified as an invalid placement. The previous reconciliation path did not expose enough detail to distinguish these cases.

## Result

Lua reports each invalid option with name, actual value/type, reason and accepted range, then CREATION_DENIED with the complete tile. Missing, nonnumeric, nonfinite, fractional, unconfigured (-1) and out-of-range values are distinguished. Neither a disabled/missing enable option nor invalid coordinates call Java. Java rejection and thrown bridge errors produce distinct mod logs.

Example:

```text
[ApocExtractionLobbyPower] CONFIG_REJECTED option=LobbyGeneratorX value=-1 type=number reason=unconfigured expected=integer_in_0..1000000
[ApocExtractionLobbyPower] CREATION_DENIED id=extraction-lobby tile=-1,-1,0 reason=invalid_sandbox_coordinates; configure X/Y/Z before enabling LobbyFixedPower
```

Java uses the same `ApocBRLobbyStreaming.keepCellLoaded` helper as lobby zombie cleanup. Up to four active jobs renew their requests each server frame until the cell is fully integrated. The 120-second deadline starts when each job obtains a slot, not while waiting in the queue. It does not need virtual-zombie population activation or a blocking Lua wait.

Logs progress through QUEUED_FOR_PREWARM, PREWARM_BEGIN, PREWARM_LOADING, PREWARM_READY and READY. Only after pre-warm completes does Java inspect the actual square and create/reuse a native generator. Known saved instances stay suspended during pending pre-warm and are not discarded merely because startup catalog finalization already occurred.

Outside-world coordinates reject registration immediately with the tile/reason. Invalid map-cell requests, timeout, a missing square after completed pre-warm, unsupported floor, solid/solid-transparent tiles or another generator deny creation with specific statuses. No retries or native construction occur after a terminal placement denial; unregister/re-register (or restart after fixing settings) is required. Runtime exception type and sanitized detail are logged. Healthy existing generators do not block themselves with their own collision flags, but saved instances still require a supported floor during startup validation.

Successful sources release the frame-local pre-warm requests; their cells can unload normally. Subsequent native reloads follow the manager's existing persistence behavior. This fixes initial validation/placement, not a permanent chunk-pinning policy.

## Verification and operation

- `npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-power.lua`: passed, including exact per-option failures, disabled/missing boolean, nil/string/fractional/infinite/range values and Java rejection/exception diagnostics.
- `py -3 tests/lobby-generator-sandbox.py`: passed; locks the packaged default to false and X/Y/Z defaults to -1/-1/0.
- Engine `py -3 tools/test_managed_generators.py`: passed deferred readiness, bounded renewing pre-warm, invalid cells, outside-world admission, missing square, missing floor, obstruction, timeout, no premature creation, saved-source suspension/reuse and existing lifecycle protections.
- Persisted startup and Lua protection regression harnesses also passed.

Real empty-server streaming, world placement and stock-client behavior still require validation after deployment. No live sandbox file or deployed server was changed. If a log reports generator_enabled=true, inspect the loaded server sandbox configuration and set LobbyFixedPower=false until coordinates are configured. See [lobby feature](../features/lobby-fixed-power.md) and [engine ownership/pre-warm guide](../../../apocalipsebr-zomboid-patches/42.22.2/docs/features/2026-11-11-fixed-power-regions.md).

# Lobby managed generator

Status: implemented; dedicated-server and unpatched-client gameplay validation pending.

The existing default-off `LobbyFixedPower` sandbox switch now registers a managed native generator instead of a powered rectangle. `LobbyEnabled` is still required. New settings `LobbyGeneratorX` and `LobbyGeneratorY` default to -1, requiring an explicit valid source tile; `LobbyGeneratorZ` defaults to 0. Bounds are X/Y 0..1000000 and Z -32..31. Restart after changes. The source should have a valid loaded square and be placed with normal generator effects, including indoor toxicity, in mind.

`ApocExtractionMapUtils_LobbyPower.lua` calls `ApocBRManagedGenerators.registerGenerator("extraction-lobby", x, y, z)` on server startup. Admission is logged separately from Java READY, which means a native generator actually exists and has been initialized. The Java manager uses normal generator coverage and existing object/chunk packets; no client Java patch is required by the design. Lobby fence/rectangle coordinates do not determine coverage. The existing enable switch's saved setting is retained, but coordinates must be configured explicitly after this refactor.

Java preserves fuel/condition and rejects shutdown, disconnect, state tampering and removal for managed generators. `ApocExtractionMapUtils_ManagedGeneratorProtection.lua` additionally guards normal shared activation/plug/pickup timed actions on the server, before inventory/world side effects. Other generators retain normal behavior. Full details and limits are in [the engine guide](../../../apocalipsebr-zomboid-patches/42.22.2/docs/features/2026-11-11-fixed-power-regions.md).

`[ApocExtractionLobbyPower]` logs START/gates, SKIPPED, REGISTER_BEGIN with source tile and REGISTERED or FAILED. `[ApocBRManagedGenerators]` provides creation, READY, protection and reconciliation logs. Missing/invalid settings do not create a guessed source. This lobby definition is independent of [database-managed generators](persisted-fixed-power.md).

Verification: Fengari `tests/lobby-power.lua` and `tests/managed-generator-protection.lua` passed, including source coordinates, sandbox gating, idempotent startup logs and rejection before pickup grants an inventory item. EN/PTBR Sandbox.json labels are updated. Real native streaming, persistence, sound/toxicity and stock-client appliances still need dedicated-server validation.

The [validation/pre-warm hotfix](../hotfixes/managed-generator-validation-and-prewarm.md) documents exact CONFIG_REJECTED logs and bounded engine pre-loading. `LobbyFixedPower` remains default false; existing saved settings can still explicitly be true. Initial placement is validated only after the cell has been forced into memory, never inferred from an unloaded square.

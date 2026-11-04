# Disable out-of-map login recovery

Status: implemented 2026-11-04; awaiting dedicated-server/client validation.

## Behavior and scope

The shared `loginPositionNeedsReset` predicate previously requested lobby
relocation when the player's floored coordinates were outside the world's
metagrid. This affected both multiplayer server decisions and single-player
login hooks, including vehicle passengers.

Out-of-map positions now return false immediately, without checking terrain or
waiting for tiles to stream. Map boundaries alone cannot trigger relocation.
Open-water rescue within the map remains active. Explicit closed-lobby,
cross-server arrival and enabled death-respawn policies remain active and can
still relocate an out-of-map player for those independent reasons.

No Java APIs, sandbox switches or database behavior changed. See
[lobby placement](../features/lobby-and-map-visibility.md) and the historical
[position rescue implementation](invalid-login-position-rescue.md).

## Files and validation

Changed `common/media/lua/shared/ApocExtractionMapUtils.lua` in the core mod,
`tests/login-position.lua`, and related README/feature documentation.

Passed from the repository root using:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/login-position.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-lobby-state.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

Regression coverage includes negative and exclusive upper map boundaries,
out-of-map vehicles, server decisions with unloaded terrain and native teleport
suppression, and single-player position preservation. Existing water, boat,
bridge, login-history, respawn and map behavior checks also pass.

These harnesses mock engine boundaries. Actual out-of-map reconnect behavior
and multiplayer synchronization remain untested on a live dedicated server.

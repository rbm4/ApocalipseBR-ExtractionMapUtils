# Reset lobby state when its layout changes

Status: implemented 2026-10-30; awaiting dedicated-server/client validation.

## Symptom and cause

Startup stopped with `saved lobby layout differs from config; migrate old
assets/state first` after changing perimeter coordinates. The saved signature
guard required manual migration before allowing a different layout.

## Behavior

After validating configuration and sprites, a different layout signature now
clears the existing `ApocExtractionLobby` table and creates a fresh exit plan
with release flags reset. This includes changes to bounds, floor, exit count
or fence sprites. Saved event identity and legacy ownership are discarded.
Normal event authorization can still release the new perimeter.

Old world objects remain untouched, including on overlapping perimeter squares.
Administrators remove them manually. The new layout only manages objects with
its own signature. Returning to a previously used signature can recognize its
remaining assets again. Unchanged-layout restarts retain their exit plan and
release state. The existing same-layout v0.2.0 asset upgrade is preserved;
door-count changes continue updating doors without regenerating exit positions.

Install the updated mod and restart the server after changing layout settings.
No save reset, Java patch or database change is required.

## Affected files

- `ApocExtractionMapUtils_Lobby.lua`: replace mismatch rejection with state reset.
- `tests/lobby-perimeter.lua`: changed bounds, floor and exit count; release,
  event and legacy-state reset; old-object identity preservation on overlapping
  squares; unchanged restart stability.
- Shared settings comments, EN/PTBR sandbox tooltips, README and the
  [perimeter](../features/lobby-perimeter.md) and
  [sandbox configuration](../features/lobby-sandbox-configuration.md) guides.

## Verification

Passed on 2026-10-30 from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/login-lobby-state.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua
```

EN/PTBR sandbox JSON parsed successfully; touched files checked for UTF-8 without
BOM. Documentation links and `git diff --check` verified. Harnesses mock engine
boundaries; live chunk loading, saved-world persistence and client replication
remain untested. Old fences on overlapping tiles can coexist with new objects
until administrators clean them up.

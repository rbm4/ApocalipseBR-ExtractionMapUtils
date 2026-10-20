# Lobby disassembly protection

Status: implemented in 0.2.2; awaiting live B42 dedicated-server/client validation.
Affected feature: [Lobby perimeter and RCON release](../features/lobby-perimeter.md).

## Symptom and verified paths

Players can attempt welding disassembly on the lobby military fences despite
their `setIsDismantable(false)` flag. The user's PvPTerritory mod successfully
guards destructive actions in controlled zones. Its shared
`FactionWar_SledgehammerLimit.lua` wraps timed-action `isValid`/`complete`, and
`RewardCrateProtection.lua` additionally guards movable scrap helpers. This fix
uses that approach with lobby bounds and an unconditional disassembly block,
without adding PvPTerritory as a dependency or changing its files.

Local vanilla Lua confirms the separate scrap path:

- `shared/Moveables/ISMoveablesAction.lua` validates a `scrap` action and calls
  `moveProps:scrapObjectViaCursor()` in `complete()`; welding animation is selected
  for blowtorches in `start()`.
- `shared/Moveables/ISMoveableSpriteProps.lua` owns `canScrapObjectInternal`,
  `scrapObjectInternal` and the cursor/start helpers. These use the scrap system,
  so a thumpable's dismantling flag alone is insufficient protection.
- `ISThumpableSpriteProps` in that same file overrides `canScrapObject`,
  `startScrapAction` and `scrapObjectViaCursor`; its cursor helper removes objects
  and returns build materials directly.
- `shared/TimedActions/ISDismantleAction.lua` uses `self.thumpable` and performs
  world removal/material returns in `complete()`.
- Decompiled `characters/CharacterTimedActions/LuaTimedActionNew.java:165`
  invokes Lua `complete()` only when not running as a multiplayer client.
  Shared server guards are therefore required. Client `OnGameStart` alone is
  insufficient. Native `perform()` handles cleanup/queue progression and is
  preserved by this fix.

## Change

These guards now require sandbox `ApocExtractionMapUtils.LobbyEnabled=true`
(default `false`). With the option absent or disabled, native actions remain
available throughout the lobby footprint, on both client and server.

`shared/ApocExtractionMapUtils_LobbyProtection.lua` loads the concrete native
classes and wraps their relevant methods on client, dedicated server and SP.
Duplicate loading does not multiply wrappers. Existing wrappers, arguments and
return values are retained for permitted actions, including PvPTerritory's
checks when that mod is installed.

The protected footprint is every inclusive interior tile
X=14260..14321/Y=11812..11892/Z=0 plus east fence squares
X=14322/Y=11812..11892 and south fence squares
Y=11893/X=14260..14321. The unused southeast diagonal square is excluded.
The rule uses the configurable normalized bounds, not hardcoded checks. It
protects world-object disassembly throughout those squares, not just objects
with our ownership marker. It has no faction/admin exemption and remains in
effect after exits are released.

Guards reject scrap/disassemble/dismantle moveable action validation and
completion, legacy thumpable dismantling, eligibility checks, cursor/start
helpers and the low-level scrap mutation. They return failure before native
removal, material/XP rewards or welding consumption in those paths. For actions
whose supplied square disagrees with an actual target object, a protected
object's actual square still blocks the request. Multi-sprite grid members are
also inspected so selecting an outside member does not scrap an inside member.

Other activities retain their normal behavior: rotation, placement,
repair and inventory-item disassembly are outside the scope of this restriction.
Pickup is blocked by the follow-up removal fix described below.
Authorized RCON exit removal calls native removal directly, so it is unaffected.
`Enabled=false` disables the guard along with perimeter maintenance.

Shared `ApocExtractionMapUtils_LobbySettings.lua` now defines the settings used
by both realms. The old server `ApocExtractionMapUtils_LobbyConfig.lua` is a
compatibility forwarder. Install matching settings on client and server; the
server always uses its own copy for enforcement. No new network command, faction
dependency, polling loop or visible hardcoded text was added. Fence geometry,
saved signatures/exit state and tick budgets are unchanged by this hotfix.

## Files and validation

Runtime: new shared settings/protection files, the server config forwarder and
`42/mod.info`. Tests: `tests/lobby-disassembly.lua`, with the existing perimeter
fixture updated to reset the shared settings module between cases.
README and the feature document describe the current config location and rule.

Executed successfully:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

The new harness verifies client/server loading without client startup events;
all interior/perimeter boundaries and floors; welding eligibility and direct
helpers; overridden thumpable scrap paths; queued completion; misleading action
squares; multi-tile targets; preserved native cleanup/arguments/multiple return
values; duplicate loads; custom bounds; disabled behavior; and allowed outside
or non-disassembly work. Existing perimeter/RCON and baseline regressions pass.
Engine/file boundaries remain mocked. Documentation links and diffs were checked.

No live server test was run. Restart clients and server, attempt welding scrap
on all four sides (especially the east/south edge squares) and an interior world
object, and confirm no removal/reward. Repeat outside the lobby to confirm normal
scrapping, then release exits via RCON. These concrete Lua hooks cover native
player disassembly, not administrative/other-mod direct world deletion, a
modified client's raw removal packets, or every third-party action class.

## Follow-up: furniture, floor and ground removal (2026-10-20)

Status: implemented locally; awaiting live dedicated-server/client validation.
Players reported removal of ground and chairs. The precise live action was not
observed. Inspection confirmed that the previous guard explicitly allowed
`ISMoveablesAction` mode `pickup`, which removes chairs/floor tiles and can break
furniture for parts. Sledgehammer destruction and ground shoveling also used
separate unguarded action classes. True `scrap` actions were already guarded;
this investigation does not establish that native scrap bypassed those checks.

The shared protection now blocks `pickup` validation/completion and movable
pickup eligibility, cursor and internal pickup helpers. Multi-sprite members
are checked for pickup just as for scrap. Vanilla rotation's internal pickup
(`rotating=true`) is preserved. Native `perform()` cleanup remains intact.
The footprint, single configured Z, sandbox opt-in and RCON removal are unchanged.

Verified local vanilla sources under `ProjectZomboid/media/lua/shared/`:

- `Moveables/ISMoveablesAction.lua`: separate `pickup` and `scrap` completion paths.
- `Moveables/ISMoveableSpriteProps.lua`: pickup can remove/break objects, replace
  floor sprites and grant items; rotation reuses pickup with its force/rotation flag.
- `TimedActions/ISDestroyStuffAction.lua`: its world target is `self.item`.
- `BuildingObjects/TimedActions/ISShovelGround.lua`: its target is `self.sandTile`;
  `self.item` is a boolean. `shovelGround(square)` changes terrain and grants bag
  contents. Both its timed-action methods and direct helper are now guarded.
- Decompiled `characters/CharacterTimedActions/LuaTimedActionNew.java` invokes
  Lua `complete()` outside the multiplayer client, so these guards remain shared.

Affected runtime file: `shared/ApocExtractionMapUtils_LobbyProtection.lua`.
Regression coverage added in `tests/lobby-disassembly.lua` reproduces the formerly
allowed pickup, destruction and shoveling paths. It checks both realms, actual
targets despite misleading squares, multi-tile pickup, direct helper denial,
outside/disabled behavior, preserved cleanup and rotation's internal pickup.

Executed successfully from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua Z:/git/Github/Apocalipse-RCON-extension
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

These are mocked regression tests, not in-game verification. After installing
matching files and restarting clients/server with `LobbyEnabled=true`, attempt
chair/floor pickup, scrap, sledgehammer destruction and ground collection inside
the lobby and along its east/south edges. Confirm no removal or rewards; repeat
outside and check rotation, repair and RCON release. Other elevations, weapon
damage, fire, unrelated action classes and direct/raw world mutations are not
made universally safe by these concrete Lua guards.

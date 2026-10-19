# Lobby world-control API investigation

Date: 2026-10-19. Status: source investigation; gameplay not implemented or
validated in game. Scope: the core extraction mod, not the bundled boats/map.
Related foundation: [Lobby placement and map visibility](../features/lobby-and-map-visibility.md).

## Evidence and environment

Inspected the current working tree and repository AGENTS.md. Existing unrelated
boat, raft, README, and documentation changes were preserved. Source roots:

- Java: `Z:/Downloads/ZomboidDecompiler/ZomboidDecompiler/bin/output/source/zombie`
- Vanilla Lua: `Z:/SteamLibrary/steamapps/common/ProjectZomboid/media/lua`

The exact game patch version corresponding to the decompiled snapshot was not
established. Findings apply to these local sources. No dedicated server/client
session was run. This documentation-only investigation needs no Lua regression
run; validation consists of source tracing and documentation link/path review.

## 1. Clear zombies within bounds

Lua can enumerate loaded zombies with `getCell():getZombieList()` or inspect
`getCell():getGridSquare(x, y, z):getMovingObjects()`. Filter `IsoZombie` objects
and authoritative coordinates against configured bounds. Iterate backwards when
removing from Java lists. Decide explicitly whether to remove reanimated players.

The important multiplayer reference is
`commands/serverCommands/RemoveZombiesCommand.java:69`. Its removal sequence is:

```java
NetworkZombiePacker.getInstance().deleteZombie(zombie);
zombie.removeFromWorld();
zombie.removeFromSquare();
```

Queue network deletion BEFORE removal: `deleteZombie()` captures the online ID,
while `removeFromWorld()` subsequently resets it. See
`popman/NetworkZombiePacker.java:60` and `characters/IsoZombie.java:4377`.

`VirtualZombieManager.instance:removeZombieFromWorld(zombie)` is Lua-exposed,
but its implementation only unregisters the emitter and invokes the two removal
methods; it does not queue the packer's deletion (`VirtualZombieManager.java:71`).
Neither does the inspected `IsoZombie.removeFromWorld()` implementation.
Consequently these calls alone are not a verified replacement for the MP command.

`NetworkZombiePacker` was not found in LuaManager's exposure list, whose
`shouldExpose()` checks membership (`Lua/LuaManager.java:2723`). Do not assume
`NetworkZombiePacker.getInstance()` is callable from ordinary mod Lua.

Verified existing command option for manual/admin or external server control:

```text
removezombies -x CENTER_X -y CENTER_Y -z Z -radius R
```

Despite the option name, the command visits an inclusive square, from center-R
through center+R on both axes, on ONE z level. It ignores unloaded/null squares,
and excludes reanimated players unless `-reanimated true` is supplied.
Vanilla admin Lua calls `SendCommandToServer("/removezombies ...")`
(`client/DebugUIs/ISSpawnHordeUI.lua:304`). This is a privileged CLIENT command,
not an autonomous server-Lua command execution API. Do not base lobby automation
on ordinary players having that permission.

Recommendation: keep bounds and policy in server Lua. For exact automatic MP
cleanup, identify a supported server-side command bridge or add a narrow Java
bridge wrapping the verified deletion sequence if no existing bridge is available.
No such bridge is implemented by this investigation.

Removal is not spawn prevention. Unloaded/virtual populations, later respawns,
and walking zombies require ongoing enforcement. A bounded periodic server sweep
can handle loaded zombies once deletion is solved. `OnZombieUpdate` is also
available, but is called in an active update branch and is unsuitable as proof
that every zombie is covered (`characters/IsoZombie.java:3347`).

`zpopClearZombies(cellX, cellY)` is a real exposed global
(`Lua/LuaManager.java:6725`), but delegates to a native population debug command
(`popman/ZombiePopulationManager.java:855`). It is a population-cell operation,
not an arbitrary tile rectangle or a persistent exclusion zone. Its native
implementation was not available here, so it is not the proposed lobby API.

## 2. Automatically build a rectangular perimeter

Use exposed `IsoThumpable` objects for player-built-style wall/fence segments:

```lua
local cell = getCell()
local square = cell:getGridSquare(x, y, z)
if not square then return end -- defer until this area is loaded
local wall = IsoThumpable.new(cell, square, spriteName, north, {})
wall:setCanPassThrough(false)
wall:setIsHoppable(false)
wall:setIsDismantable(false)
wall:setIsThumpable(false)
square:AddSpecialObject(wall)
wall:transmitCompleteItemToClients()
```

This is the relevant API sequence, not a complete production builder. It still
needs duplicate detection, validated sprites, configurable coordinates, and the
chosen damage/destruction policy. High health alone is not an indestructibility
policy. Use `setMaxHealth()` / `setHealth()` if destructible walls are intended.

Verified constructors: `iso/objects/IsoThumpable.java:406-430`.
Vanilla placement reference: `server/BuildingObjects/ISWoodenWall.lua:3`;
flag configuration: `server/BuildingObjects/ISBuildUtil.lua:362`.
`IsoThumpable` is exposed at `Lua/LuaManager.java:2124`.

`square:AddSpecialObject()` adds to both the normal and special object lists,
calls `addToWorld()`, recalculates neighbours, and notifies collision/pathfinding
and region systems (`iso/IsoGridSquare.java:5855`).
`transmitCompleteItemToClients()` sends `AddItemToMap` to relevant clients when
running on the server (`iso/IsoObject.java:4811`). Do not merely insert a sprite.

`north=true` means the square's NORTH edge; false means its WEST edge.
For an inclusive interior tile rectangle `[xmin..xmax] x [ymin..ymax]`:

- North: `(x, ymin)`, north=true.
- South: `(x, ymax+1)`, north=true.
- West: `(xmin, y)`, north=false.
- East: `(xmax+1, y)`, north=false.

The square outside the east/south interior boundary must therefore be loaded too.
Leave the intended gate edges free. Handle corners explicitly for appearance and
test diagonal movement. Do not place four walls on every perimeter tile.

Choose actual wall sprites without `HoppableN/W` or `TallHoppableN/W` properties
if confinement is the goal. `setIsHoppable(false)` alone is insufficient:
`isHoppable()` also consults sprite flags (`IsoThumpable.java:1738`). Tall fences
can also be climbable. Noclip bypasses collision (`TestCollide()`, line 859).

## 3. Spawn and open a gate at a scheduled game time

For a single-piece door/gate, use:

```lua
local gate = IsoThumpable.new(cell, square,
    closedSpriteName, openSpriteName, north, {})
gate:setIsDoor(true)
gate:setCanPassThrough(false)
square:AddSpecialObject(gate)
gate:transmitCompleteItemToClients()
```

Configure other building/protection flags before adding/transmitting it.
The constructor does not replace `setIsDoor(true)`.
Reference: `server/BuildingObjects/ISWoodenDoor.lua:3`.

For a wide double gate, reproduce the four-piece arrangement in
`server/BuildingObjects/ISDoubleDoor.lua:3`. The parts must use compatible sprites
with correct `DoubleDoor` properties; a decorative fence sprite is insufficient.
Use `IsoDoor.isDoubleDoorObstructed(gate)` before opening/closing, then
`IsoDoor.toggleDoubleDoor(gate, true)` ONCE on one part, guarded by its desired
open state. This coordinates the pieces, movement and synchronization
(`iso/objects/IsoDoor.java:2784`). Do not toggle every part independently.
`IsoDoor` is exposed at `Lua/LuaManager.java:2107`.

Single-piece `gate:IsOpen()` reports state. `gate:ToggleDoor(nil)` is unsafe:
the normal path dereferences `chr:getEmitter()` when state changes
(`IsoThumpable.java:1279`). `ToggleDoorSilent()` accepts no actor but does NOT
perform the full normal recalc/network path (`IsoThumpable.java:1392`). A server
wrapper using it must guard the current state, check obstruction, recalculate
neighbours and sync the object (`gate:sync()`), and validate pathfinding refresh
against the normal toggle path in game. The normal path additionally calls
`PolygonalMap2.instance.squareChanged()`; silent toggle is not a proven complete
drop-in replacement. Prefer the verified coordinated API for a wide gate.

Use `Events.EveryOneMinute.Add(handler)` in server Lua and
`getGameTime():getHour()` / `:getMinutes()` (or `:getTimeOfDay()`).
`GameTime.java:699-733` dispatches hour/minute events as GAME time advances.
Use `EveryHours` only if minute precision is unnecessary.

Reconcile desired state at startup, when gate squares become available, and on
minute changes. Avoid exact equality on floating-point time or blind toggles;
handle restart after the opening time, day rollover, time jumps, and obstruction.
Whether the gate opens once, opens daily, or follows an open/close window remains
a design choice. Real-world scheduled time would need a separate clock policy.

Locks alone do not enforce an event-only exit: the inspected ordinary locked
door checks depend on the interacting player's side and keys. Strict confinement
requires a separate server rule for premature interactions/destruction and
movement; scheduled opening alone does not supply that rule.

## Lifecycle and proposed ownership

Keep lobby configuration/helpers in shared `ApocExtractionMapUtils` and place
world mutation/scheduling in focused files under the core `media/lua/server/`.
No client request is necessary for the server to construct its own lobby.

Use `Events.OnServerStarted` for initialization and `Events.LoadGridsquare` to
defer or queue work when target squares load. Their Java trigger sites are
`network/GameServer.java:1536` and `iso/IsoChunk.java:3844`.
`IsoCell.getGridSquare()` delegates to `ServerMap` on dedicated servers
(`iso/IsoCell.java:3344`); it is a lookup, not a request to stream arbitrary terrain.

Make placement idempotent using object mod data (`getModData()`) plus inspection
of actual square objects. Track pending multi-square gates until all necessary
squares are available, including their open footprint. Do not treat one global
"built" flag as evidence that every wall exists after reload. Test persistence,
late joiners, collision, gate obstruction/sync, and zombie deletion on a real
dedicated server before declaring the lobby ready.

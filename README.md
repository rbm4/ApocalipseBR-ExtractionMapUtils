# ApocalipseBR - Extraction Map Utils

Build 42 event lobby foundation. Mod ID: `ApocalipseBR-ExtractionMapUtils`.

This repository brings together the extraction/lobby core in
`ApocalipseBR-ExtractionMapUtils/`, boats in `AquasarYatchClub/`, and the event map
in `Restless-Waters/`. The core will orchestrate gameplay events on the test
server, which is intended to be linked to PostgreSQL. That database integration
and event lifecycle are follow-up work.

See [AGENTS.md](AGENTS.md) for repository conventions and [.docs/](.docs/README.md)
for separate feature, hotfix, and report documentation.

## Install

Copy the `ApocalipseBR-ExtractionMapUtils` directory (containing `42` and `common`) into your `Zomboid/mods` directory, or package that directory under a Workshop item's `Contents/mods`. Enable the mod on the server and clients. Version 0.2.2 requires Build 42.13.0 or newer and the separately installed RCON extension, mod ID `ApocalipseBrRCONextension`. No map dependency is required yet.

The checked-in B42 directory is ready to install directly. The template's npm scripts require Project Zomboid Studio; verify that your Studio version supports B42's `42`/`common` layout before using generated output.

## Sandbox settings

Open **ApocalipseBR - Extraction Map Utils** in sandbox settings.

| Setting | Default | Behavior |
| --- | --- | --- |
| Force map and minimap reveal | On | Enable both maps, reveal map knowledge on client/server, and bypass light requirements. Minimap visibility follows normal controls. |
| Relocate to lobby on every login | On | Place players at the lobby each time they enter a game, including existing characters reconnecting. |
| Lobby X | -1 | World tile X. Set to a nonnegative coordinate to configure. |
| Lobby Y | -1 | World tile Y. Set to a nonnegative coordinate to configure. |
| Lobby Z | 0 | Floor, from -32 to 31; 0 is ground level. |

Both X and Y must be configured before relocation runs. Choose a valid floor tile on the loaded map; players arrive at its center. Login relocation does not validate distant tile geometry before loading it. The perimeter below is configured separately and does not set the login destination.

Example server `SandboxVars` block (replace X and Y with the eventual lobby):

```lua
ApocExtractionMapUtils = {
    ForceMapReveal = true,
    RelocateOnLogin = true,
    LobbyX = -1,
    LobbyY = -1,
    LobbyZ = 0,
},
```

Restart/reconnect after changing settings. Relocation runs once at game entry, not continuously; players can leave the lobby for the event. UI resets and reopening maps do not relocate players. Death/respawn within an existing session and adding another local player after game entry are outside this login hook.

## Implementation

- `OnGameStart` relocates local players using server-provided sandbox settings. The local B42 `IngameState.enter` fires this before `GameClient.sendPlayerConnect`. That connection packet contains no coordinates: `GameServer.receivePlayerConnect` loads the server-side character from the database, and the client reports its lobby position in subsequent movement updates. This is ordinary mod client behavior, not server enforcement against modified clients.
- Version 0.1.3 adopts the client/server known-map strategy inspected in FullMapReveal 1.1.0 (Workshop item 3796627078). This is an independent implementation in our mod; FullMapReveal is not a dependency. Test with that other mod disabled so the two implementations do not duplicate writes.
- Reveal only calls `setKnownInSquares`. It does not mark the world visited, change `HideUnvisited`/`BlurUnvisited`, replace minimap initialization, alter bounds, or reset zoom. Original game code owns minimap loading, fog, saved visibility and interaction. Map/light availability overrides remain for the original sandbox requirement. Version 0.1.4 separately adjusts Chernarus road styling as described below.
- Both sides derive real world bounds from the metagrid (256-square cells) and write blocks of at most 8192 squares per side. No client-supplied coordinates are accepted by the server.
- The client reveals at character creation and asks the server to update `WorldMapVisitedServer`. Server acknowledgements repair local knowledge without sending another request. Client retry passes run after 3, 10, 30 and 90 seconds. Opening either map schedules two repair passes after 1 and 4 seconds, including a minimap opened long after login. These hooks only observe the completed native opening/toggle.
- The native server map store loads a user lazily on the first PlayerVisited request and ignores earlier writes. A server write acknowledgement indicates a successful API call, not proof that the lazy store was already loaded. The server therefore retries up to eight passes, 15 seconds apart, and clears offline sessions. Requests are throttled to one per player instance per five seconds; retry windows can restart at most once per two minutes. Respawn/reconnect instances receive a new retry budget.
- The server stores revealed knowledge once its per-player map store is loaded. In single player, native exploration saves can retain revealed knowledge. Disabling the option stops writes and restores ordinary map/light availability checks; it does not erase learned map knowledge. No perpetual five-second client render/flag pump remains.
- Reveal displays available worldmap XML/image data, including custom maps that provide it. It does not generate missing map data, reveal live zombies/items, or bundle Chernarus.
- The 0.2.1 perimeter uses military fences and command-controlled removal of exit segments as described below. Event countdowns, zombie clearance, and a full event lifecycle remain future work.

## Lobby perimeter (0.2.2)

At dedicated-server startup, the mod queues a military-fence perimeter enclosing
X=14260..14321, Y=11812..11892, Z=0, including six randomized, saved single-tile exit
positions. Placement waits for loaded squares and runs across ticks (at most
four edges per tick with a two-millisecond elapsed-time budget). All fence segments
use maximum positive Java-int health, with thumping/dismantling/barricading off.
Keep sledgehammers disabled in the server settings.

The north/west sprites (`fencing_01_88/90`) carry vanilla `CantClimb` and wall
collision flags. The existing 0.2.0 perimeter upgrades gradually as chunks load,
preserving exit positions and the saved release state.

Configure bounds, exit count and work budgets in
`ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/ApocExtractionMapUtils_LobbySettings.lua`.
Install the same configuration on clients and server. The former server config
file now forwards to these shared settings. Version 0.2.2 blocks world-object
disassembly throughout the lobby and perimeter squares on Z=0, including welding
scrap actions. Checks run on client and server, regardless of faction, while
normal disassembly outside the lobby and other activities keep their behavior.
Exit segments are the same protected fence as the rest of the perimeter. Read the one-use token from
the server's `Zomboid/Lua/ApocExtractionLobby-<server-name>-open-token.txt`, then
send through RCON:

```text
servermsg ##APOCBR_RCON##ExtractionLobby##ReleaseExits##lobby-release-001##<TOKEN>
```

At least one connected client running the RCON extension is required by its
relay transport. The token is consumed on acceptance. The six exit fences despawn
through the tick queue or on later chunk loading; their gaps remain empty across
normal saves and restarts. The former `OpenDoors` command is a compatibility
alias for the same removal. See [configuration, persistence, command security and validation
limits](.docs/features/lobby-perimeter.md) before using the perimeter for an event.
Run `npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua`
for the standalone lobby regression harness.
Run `npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua`
for the disassembly-protection regression harness.

## In-game verification

1. Configure a known safe lobby tile; disable the base game's world map/minimap, enable light requirements, and disable Map All Known.
2. Join as a normal non-admin player. Confirm arrival at the lobby, normal minimap toggling, and revealed map geometry while zooming/panning into unexplored areas, including in darkness.
3. Walk away, disconnect, and reconnect with the same character. Confirm return to the lobby. Repeat with a new character and a distant lobby to check chunk loading and server anti-cheat logs.
4. Toggle the minimap, reopen the world map, and reset the UI; reveal should remain active without another relocation.
5. Leave X or Y at -1: login should keep the ordinary spawn and log a configuration reminder. Disable relocation: reconnect should keep the saved position.
6. Disable force reveal and rejoin: ordinary sandbox map restrictions should apply again.

The client log should contain:

```text
[ApocExtractionMapUtils] Known-map reveal loaded; native minimap rendering.
```

Fully restart the client and server with the updated mod files to remove old Lua
wrappers. Keep `ForceMapReveal=true`; no sandbox setting migration is needed.
Verify reveal at spawn, after opening/zooming both maps, and after reconnecting.
Also open the minimap for the first time more than two minutes after joining to
exercise a late PlayerVisited load. Normal unexplored shading can remain because
this implementation marks knowledge rather than forging visited history.

Run the regression harnesses from the repo root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
```

These execute the Lua code against engine boundaries: known-only reveal, preserved
native minimap setup/fog, finite spawn/map-open retries, acknowledgement repair,
late server store loading, throttling, respawn, offline cleanup, trusted bounds,
singleplayer and disabled behavior. They do not provide a running-game visual test.

## Chernarus zoom workaround (0.1.4, Lua only)

The latest client log fails in `WorldMapRenderer.Drawer.fillPolygon` reading an
index buffer. `forgot to call endRun()` follows as a rendering-state cascade.
This trace concerns map cartography, not terrain chunk deserialization.

The installed Chernarus `worldmap.xml.bin` parses to its exact file length: version
2, 256-square cells, 3 by 3 cells. Its densest cell has 2,066 four-point polygons,
including 1,558 roads. Original quads need about 12,396 triangle indices there;
including six road zoom variants gives an estimate of 68,484. Actual native
clipping can change these counts. B42's solid polygon path narrows the initial
index-buffer offset to a signed short. This is consistent with the crash, though
the log does not include the failing offset.

`ApocExtractionMapUtils_Cartography.lua` wraps `MapUtils.initDefaultStyleV1`, used
by both minimap initialization and the world map's V3 style setup. When loaded
data paths include `media/maps/Chernarus/`, road polygon layers use vanilla
`media/white.png` with their original fill colors. The textured renderer calls
`triangulate(cell, null)`, avoiding the extra road variants. Roads retain actual
polygon widths and may look thinner when zoomed out. Buildings, water, forest,
bounds, zoom controls, fog and saved visibility retain their native behavior.
Other maps are unaffected. This workaround is independent of `ForceMapReveal`.

Road layers wait above the visible zoom range until their texture is ready;
otherwise native rendering would fall back to the unsafe solid path. Pending
layers are restored once, and discarded if the style is rebuilt. A missing white
texture leaves roads hidden. The client logs:

```text
[ApocExtractionMapUtils] Chernarus road rendering workaround active (Lua textured polygons).
```

Fully exit and restart the client before testing: existing cached triangulations
cannot be safely repaired by reloading Lua. Update the mod on the server and
clients, then test opening both maps and zooming in/out repeatedly. No client
Java installation, workshop map modification or terrain/save reset is required.
The automated harness verifies style selection and texture readiness, not native
triangulation or a running-game crash fix. Confirm the result in a fresh session.
Local engine source and automated Lua harness checks verify the Lua integration points. Actual streaming, multiplayer synchronization and compatibility with other UI mods require a running B42 game/server. In particular, B42's server NoClip check may reject a large initial move from the saved location when both areas are loaded. This standalone Lua implementation does not invoke `GameServer.sendTeleport` (not exposed to vanilla Lua) or disable anti-cheat. Treat multiplayer relocation as pending validation; a server bridge to that native teleport method may be required if the server rejects it.

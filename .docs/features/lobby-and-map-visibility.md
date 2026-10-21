# Lobby placement and map visibility

Status: implemented foundation; dedicated-server relocation and visual rendering
still require in-game validation. This document records the existing baseline,
not a new gameplay change.

The separate [perimeter and RCON release](lobby-perimeter.md) feature documents
the 0.2.0 world assets; its coordinates do not automatically configure this
login relocation hook.

## Purpose and ownership

`ApocalipseBR-ExtractionMapUtils/` owns lobby and event-control logic.
`AquasarYatchClub/` supplies boats, and `Restless-Waters/` supplies the event map.
The current core does not require either component to execute its generic lobby
and reveal hooks.

## Current behavior

- With both lobby and relocation enabled, living players move to the configured
  lobby at login while the lobby is closed. After release (or with unknown lobby
  state), only invalid positions reset: outside the current world's metagrid
  bounds, or on loaded open-water tiles. Valid land, floors over water and
  in-bounds vehicle passengers preserve their positions during an operation.
  These are map bounds, not lobby bounds or event objective/region boundaries.
  With the optional 42.21.0 `ApocBRPlayerLogin` Java bridge, known cross-server
  logins reset even on valid land. The previous ID comes from the independent
  successful-login audit table. Pending audit results retry; first audited logins
  have unknown origin and retain the geometry fallback. Recording runs on every
  participating patched server even when lobby relocation is disabled. See
  [successful-login history](successful-login-history.md).
  ExtractionMapUtils' Lua `OnCreatePlayer`/`OnGameStart` hooks request a
  decision per local player after connection readiness. The server uses its own player coordinates, world bounds and
  terrain, ignoring client position/state claims. Unloaded geometry or absent
  replies retry once per second, up to 15 requests; unresolved positions stay.
  Single player applies the same geometry checks against its own world.
  See the [position rescue hotfix](../hotfixes/invalid-login-position-rescue.md).
  With the bridge present, the server initiates the native teleport packet and
  the client skips its old placement call. Unpatched servers retain client placement;
  dedicated-server movement and anti-cheat acceptance require in-game validation.
  This runs at login/replacement character creation, without continuous confinement.
- Force reveal enables map/minimap availability without light requirements and
  marks world geometry as known. Native minimap visibility controls, zoom, fog,
  and visited history remain in use. Missing map data and live entities are not
  revealed.
- Client reveal retries are finite. Server reveal derives its own world bounds,
  throttles requests, and retries writes to accommodate lazy per-player map-store
  loading. A server acknowledgement confirms the API call, not a loaded store.
- Disabling reveal stops new writes; it does not erase previously learned map
  knowledge.

## Configuration

Sandbox group: `ApocExtractionMapUtils`.

| Option | Default | Meaning |
| --- | --- | --- |
| `LobbyEnabled` | `false` | Master opt-in for lobby behavior, including relocation. |
| `RelocateOnLogin` | `false` | Place players in a closed lobby; after release, rescue out-of-map/open-water logins. |
| `LobbyX` | `-1` | Lobby world tile X; negative means unconfigured. |
| `LobbyY` | `-1` | Lobby world tile Y; negative means unconfigured. |
| `LobbyZ` | `0` | Lobby floor, from -32 to 31. |
| `ForceMapReveal` | `true` | Enable map availability and known-map writes. |

Both X and Y must be configured. Choose a safe, valid floor tile on the active
map. Reconnect/restart after changes; placement runs at entry, not continuously.

## Implementation map

Paths below are relative to `ApocalipseBR-ExtractionMapUtils/common/media/lua/`.

| File | Responsibility |
| --- | --- |
| `shared/ApocExtractionMapUtils.lua` | Options, lobby coordinates, reveal bounds. |
| `client/ApocExtractionMapUtils_Login.lua` | Login placement hook. |
| `server/ApocExtractionMapUtils_Lobby.lua` | Server-owned lifecycle and cached closed-state getter. |
| `server/ApocExtractionMapUtils_LoginServer.lua` | Lua login command, geometry/origin decision and native teleport adapter. |
| `client/ApocExtractionMapUtils_Maps.lua` | Native map availability/open wrappers. |
| `client/ApocExtractionMapUtils_Reveal.lua` | Local knowledge, requests, repair passes. |
| `server/ApocExtractionMapUtils_RevealServer.lua` | Server knowledge writes and request/retry handling. |

The separate [Chernarus hotfix](../hotfixes/chernarus-road-rendering.md) documents
the cartography wrapper.

## Validation and follow-up

Existing harnesses: `tests/login-and-maps.lua` and `tests/map-reveal-server.lua`.
They exercise mocked engine boundaries, not actual multiplayer movement or
rendering. No harnesses or live tests were run for this documentation baseline.
See the [root README](../../README.md) for commands and the in-game checklist.

In a dedicated-server session, verify new-character login, reconnect from a
distant location, safe chunk loading, anti-cheat acceptance, normal minimap
toggling, map reopening, and disabled/unconfigured options.

Future work will define authoritative placement, lobby orchestration, event
activation, and the PostgreSQL integration boundary. No event lifecycle or
database contract is established by this baseline.

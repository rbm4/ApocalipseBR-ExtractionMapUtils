# Lobby placement and map visibility

Status: implemented foundation; dedicated-server relocation and visual rendering
still require in-game validation. This document records the existing baseline,
not a new gameplay change.

## Purpose and ownership

`ApocalipseBR-ExtractionMapUtils/` owns lobby and event-control logic.
`AquasarYatchClub/` supplies boats, and `Restless-Waters/` supplies the event map.
The current core does not require either component to execute its generic lobby
and reveal hooks.

## Current behavior

- At `OnGameStart`, local living players are moved to the configured lobby tile.
  Reconnecting existing characters also runs this login hook. This is client
  placement; dedicated-server movement and anti-cheat acceptance remain to be
  verified. It does not enforce confinement or handle every in-session respawn.
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
| `RelocateOnLogin` | `true` | Apply lobby placement at game entry. |
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

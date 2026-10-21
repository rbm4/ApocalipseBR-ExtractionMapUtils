# Boat radial seat boarding

Status: implemented; awaiting Build 42.17 multiplayer validation.

## Symptom and cause

A player can reach a boat from shore and open its V radial menu, but selecting
a seat can fail when that seat's scripted outside position lies farther away.
The seat picker queued vanilla `ISEnterVehicle`, whose `start()` returns without
entering if the character is more than two tiles from the selected outside
position. Large boats can therefore be reachable while their entry positions
are over water and outside this distance.

## Behavior and affected files

Updated `media/lua/client/Boats/ISUI/ISBoatSeatUI.lua` in both
`AquasarYatchClub/common` and `AquasarYatchClub/42.17`.

Selecting an exterior entry seat while outside now boards immediately. It uses
the same boat lookup as the outside radial menu (`getBoatToInteractWith`) and
rechecks that reach at selection time. There is no distance check to the selected
seat, pathfinding to its outside point, or entry animation delay.

The seat must belong to a configured boat, be installed and unoccupied (including
items), and have both outside and inside passenger positions. Seats marked by an
`InCabin<PassengerId>` part cannot be entered directly from outside, even when
the cabin is unlocked. Players must board an exterior seat and then switch using
the existing seat connections and cabin-lock rules. Existing mouse, number-key
and controller selection paths all use this behavior through `useSeat`.

After validation, the implementation clears pending timed actions, calls the
engine's `enter`, sets/transmits the inside passenger position, plays the idle
animation and triggers the normal entry event and music cue. It preserves the
native heavy-item drop handling. An unsuccessful engine entry emits no position
update or entry event. There is no new client/server command or configuration.

## Verified source and limits

Local game source inspected:

- `Z:/SteamLibrary/steamapps/common/ProjectZomboid/media/lua/client/Vehicles/TimedActions/ISEnterVehicle.lua`:
  confirms the two-tile seat distance check and normal entry/completion effects.
- Decompiled `zombie/vehicles/BaseVehicle.java`, `enter`, `setCharacterPosition`
  and `transmitCharacterPosition`: confirms the exposed signatures and use of
  native vehicle entry/passenger-position packets.
- Decompiled `zombie/network/packets/vehicle/VehicleEnterPacket.java`: confirms
  the server processes the native entry packet through `BaseVehicle.enter` and
  relays passenger state to clients.

Boat exterior/cabin classification follows this mod's `InCabin` part convention.
These menu checks do not add server enforcement to the engine's existing entry
packet. No live server, client synchronization or anti-cheat behavior was tested.

## Validation

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/boat-boarding.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/boat-cheats.lua
```

Results: PASS for both `common` and `42.17` in both harnesses. Boarding tests mock
engine boundaries and cover immediate entry without seat-distance checks,
entry/position/event ordering, cabin rejection regardless of lock state,
occupied/missing seats, absent entry positions, stale boat reach, invalid seat
indices, existing vehicle membership, failed engine entry, cabin switching and
single-player/multiplayer heavy-item drop paths.

In game, verify a large yacht reachable from its stern, an exterior seat far
from shore, cabin entry/switching with locked and unlocked cabins, another player
occupying the destination, and a second client observing the selected seat.
Also confirm that moving away after opening the picker prevents boarding.

# Courier visual provenance

Ported on 2026-11-11 at the user's request from the installed DroneCompanion mod
by mirusona, Workshop 3834621996. Original root:
`Z:/SteamLibrary/steamapps/workshop/content/108600/3834621996/mods/DroneCompanion`.

Assets copied byte-for-byte:

- `common/media/models_X/WorldItems/DroneSupport.fbx` → `models_X/ApocWallet/Courier.fbx`
- `common/media/models_X/WorldItems/DroneRotor.fbx` → `models_X/ApocWallet/Rotor.fbx`
- `common/media/textures/WorldItems/DroneSupport.png` → `textures/ApocWallet/drone/Courier.png`
- `common/media/textures/WorldItems/DroneRotor.png` → `textures/ApocWallet/drone/Rotor.png`

`DroneRenderer.lua` adapts the cached-item body/rotor rendering technique and
measured model offsets from `42/media/lua/client/DroneCompanion/Draw.lua`.
Companion AI, combat, skills and DroneCompanion globals are excluded.

# Lobby fixed power

Status: implemented; awaiting dedicated-server and client validation.

The default-off `LobbyFixedPower` sandbox option registers the existing lobby X/Y rectangle across all floors when the server starts, provided `LobbyEnabled` is also on. Restart after changing the option or bounds. The mod requires the 42.22.2 server patch exposing `ApocBRFixedPower.setRegion`; missing or rejected bridges are logged without preventing other lobby functions. Server code owns the bounds; no client command supplies them.

The server-side checks report fixed power in this region. The patch does not alter client power checks or synchronize a region to clients, so client lighting and interactions can differ. Not every power-consuming behavior has been verified in-game. It does not create a physical generator, force-load tiles, or persist registry entries; startup registers the region again.

Verification: `npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-power.lua` passed, covering disabled and missing bridge, invalid bounds, one registration, and coordinates. The exact server patch compiled using its BuildOnly script. Multiplayer power, appliance state, lighting, global shutoff, reconnect and chunk reload still require in-game validation.

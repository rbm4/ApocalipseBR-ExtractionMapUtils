# Market operator portrait and audio

Ported 2026-11-11 at the user's request from the installed original RadioTraders,
Workshop 3807707103. Source root:
`Z:/SteamLibrary/steamapps/workshop/content/108600/3807707103/mods/RadioTraders/42/media`.

- `textures/RadioTraders/anim/sparks_00.png` through `sparks_15.png` copied
  byte-for-byte to `textures/ApocWallet/operator/control_00.png` through `_15.png`.
- `sound/RT_Static.ogg`, `RT_Squelch.ogg`, `RT_Hangup.ogg` copied byte-for-byte to
  `sound/ApocWallet/Static.ogg`, `Squelch.ogg`, `Hangup.ogg`.

`OperatorPortrait.lua` adapts the animated-frame/scan-line presentation from
`RT_TradeWindow.lua`. `RadioDialogue.lua` uses the original emitter sound technique
with wallet-owned sound definitions, correlation, queues and PTBR speech. No
RadioTraders runtime tables, trader stock, reputation or optional 3D outfits are
required. The operator represents the player-market faction.

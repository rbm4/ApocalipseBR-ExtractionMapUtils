# Wallet radio UI: RadioTraders extraction map

Status: source investigation and implementation map, not a shipped UI.
Inspected 2026-11-11. Owning feature: [wallet API connectivity](../features/wallet-api-connectivity.md).

Subsequent implementation: the [wallet-owned radio UI](../features/wallet-radio-ui.md)
now ports ordinary handheld/ham visuals and callback wiring. Its
[asset receipt](2026-11-11-wallet-radio-ui-assets.json) records 34 copied PNGs.
The investigation below retains its original pre-implementation scope.

## First milestone

Fork the visual radio UI into `ApocalipseBR-Wallet`, using our own Lua classes,
assets, translation keys and lifecycle. The installed RadioTraders mod will not
be a runtime dependency. Open the window from a radio, show an intentionally
empty list, and display the character balance through the existing wallet
callback API. No catalogue, purchase, debit, trader call or stock request is
needed for this milestone.

Recommended first skin: the standard handheld walkie. The desktop/ham shell can
be added using the same layout mechanism later. Both are mapped below; choosing
the handheld first is a scope recommendation, not an existing restriction.

Source root inspected:

```text
Z:\SteamLibrary\steamapps\workshop\content\108600\3807707103\mods\RadioTraders
```

All RadioTraders source paths below are relative to
`42/media/lua/`. Texture paths are relative to `42/media/`.

## Existing dependency chain

```text
RT_RadioWindowModule.lua
  wraps vanilla ISRadioWindow.createChildren; adds RWMRadioTraders
  -> RT_ContextMenu.fillTraderMenu
     -> RT_ContextMenu.openRadio
        -> RTSkinWindow, or RTTradeWindow in classic mode
           -> RTSkinWindow inherits RTTradeWindow
              -> RT_Client / RT_Shared / RT_Currency / RT_Advanced / RT_Options
              -> trader network, money inventory, bank, audio and portraits
```

The visible radio skin is not an independent widget in the source. Its parent
`RT_TradeWindow.lua` has 1965 lines, while `RT_SkinWindow.lua` has 661. Requiring
either unchanged would import native trading behavior. The fork should extract
selected UI code and derive directly from vanilla `ISCollapsableWindow`.

## Extraction allowlist

| Source and entry points | Extract/adapt | Wallet destination |
| --- | --- | --- |
| `client/RadioTraders/RT_RadioWindowModule.lua`: `RWMRadioTraders:new` (28), `createChildren` (38), `readFromObject` (54), wrapper at end of file | Vanilla radio-section insertion, button construction, actual player/device capture, joypad A prompt if retained. Button calls our open controller directly. | `client/ApocWallet/UI/RadioWindowModule.lua`, class `RWMApocWallet` |
| `client/RadioTraders/RT_ContextMenu.lua`: `openRadio` (17), inventory hook (115), world hook (227) | Window creation/fronting and optional inventory/world right-click entry. Use a single direct "open wallet" action rather than a trader submenu. | `client/ApocWallet/RadioUIController.lua` and optional `UI/RadioContextMenu.lua` |
| `client/RadioTraders/RT_SkinWindow.lua`: `skinTexture` (94), `sizeFor` (103), constructor (125), `clampToScreen` (180), `R` (187), `titleBarHeight` (192), selected `createChildren` (194), `layout` (248), `prerender` (485) | Standard radio background, proportional sizing, scaled LCD/list rectangles, drag/clamp and basic button placement. Implement a new window with its own direct vanilla base. | `client/ApocWallet/UI/RadioWindow.lua`, class `ApocWalletRadioWindow` |
| `client/RadioTraders/RT_SkinWindow.lua`: `RTSkinKey` (24 onward) | Optional visual key style for close/refresh buttons. Plain vanilla `ISButton` is sufficient initially. Remove animated marquee, alien styling and trader callbacks. | Optional `client/ApocWallet/UI/RadioButton.lua` |
| `client/RadioTraders/RT_SkinLayout.lua`: `SkinLayout.walkie` and optionally `ham` | Static artwork coordinate tables. Rename the namespace; omit alien map/eyes layout. | `client/ApocWallet/UI/RadioLayout.lua` |
| `client/RadioTraders/RT_TradeWindow.lua`: list setup in `createChildren` (229), `clampToScreen` (1635), safe parts of `close` (1664) | Vanilla scrolling-list construction, geometry concepts and UI removal. Create an empty list with no trade/double-click handler. Rewrite close for observer cancellation. | Fold the small extracted pieces into `UI/RadioWindow.lua` / `RadioUIController.lua` |
| `shared/RadioTraders/RT_Shared.lua`: `getDeviceData` (459), `isTwoWayRadio` (463) | Small standalone radio-identification helpers. `radioKind` from `RT_SkinWindow.lua` (19) is useful only when adding ham support. | `client/ApocWallet/RadioDevice.lua` |
| `client/RadioTraders/RT_Client.lua`: `UIPrefs` (84 onward) | Optional later: position/size persistence. Initial per-player window position can remain in memory. Never copy the command router or its global state. | Optional `client/ApocWallet/UI/RadioPreferences.lua` |

Do not retain `require "RadioTraders/..."`, `RadioTraders`, `RT`, `RTTradeWindow`,
`RTSkinWindow` or the single global `RT.activeWindow` as runtime dependencies.
Use `ApocWallet` names throughout, with a window registry keyed by local player
index and verified against the actual native player object.

## Artwork needed

Copy selected source artwork into a wallet-owned texture directory and update
the loader to use that directory. The PNGs are loose files; the radio UI does
not need the source mod's bank/UFO/helicopter texture packs or tile definitions.

| Source asset under `textures/RadioTraders/skins/` | Dimensions | Bytes | Phase |
| --- | --- | ---: | --- |
| `walkie_standard_sd.png` | 351 × 840 | 240895 | Handheld shell |
| `walkie_standard_hd.png` | 703 × 1681 | 930390 | Same shell at larger scale |
| `ham_standard_sd.png` | 982 × 319 | 336057 | Optional desktop shell |
| `ham_standard_hd.png` | 1965 × 638 | 1221227 | Optional desktop shell at larger scale |

Suggested wallet paths:

```text
common/media/textures/ApocWallet/radio/walkie_standard_sd.png
common/media/textures/ApocWallet/radio/walkie_standard_hd.png
```

The handheld layout uses artwork space 703 × 1681. Its `feed` rectangle is
`{112,603,450,325}`; its `list` rectangle is `{112,988,450,303}`. These are source
coordinate units, not final on-screen pixels. Preserve proportional scaling
using `k = windowWidth / layout.w`; map all child controls through the same
transform. The source SD images are half-resolution with integer rounding.

Place the balance/status text in the feed area and an empty `ISScrollingListBox`
in the list area. Keep it empty regardless of radio/trader availability. Only
close and optional explicit refresh controls need clickable hitboxes at first;
the shell's other physical buttons can remain decorative.

## Components to leave behind

- `RT_TradeWindow.update`: calls clock/audio helpers and periodically recounts
  inventory money, currencies and weather. The fork renders stored UI state.
- `RT_SkinWindow.update`, `drawFeed` and `render` as complete methods: they depend
  on the parent trade state, signal, weather, portraits, animated effects,
  alien radar, reputation and bank text. Extract geometry/drawing primitives;
  replace their contents with balance and an empty-list state.
- `RT_RadioWindowModule.refresh/update/prerender` as complete methods: they
  count available traders, run a 400 ms refresh and can request `bcInfo` during
  rendering. Our button only opens/fronts our window.
- `RT_ContextMenu.fillTraderMenu`: source disables opening when no traders are
  available. Our empty-list milestone must open without any trader catalogue.
- `RT_Client` router, `RT_Shared` as a whole, `RT_Config`, `RT_Catalog`,
  `RT_Currency`, `RT_Bank`, `RT_Finance`, `RT_Advanced`, payment providers and all
  RadioTraders server handlers. Existing wallet controllers/services already
  own identity, requests, throttling and callback delivery.
- Stock population, item icons, portrait animations/3D portraits, sound/music,
  bank cards, loans, contracts, operator contacts, map marks, alien equipment,
  settings panels, source hotkeys and HUDs.
- Buy/sell/job/partner tabs, double-click trading, redial, relay, hangup commands,
  bribes and source radio signal simulation. Closing our UI is a local UI action.

`checkRadio` (source `RT_Shared.lua:522`) also applies held-item, power and battery
rules. Those are gameplay policy, separate from recognizing a radio. Initially
detect a vanilla two-way radio and bind the actual device/player; additional
power/equipment restrictions should be explicit wallet rules, not dependencies
on RadioTraders sandbox settings. Device checks belong at open/button actions,
not in a balance polling loop.

## Proposed wallet flow

```text
Vanilla radio section or inventory context action
  -> ApocWallet.RadioUIController.open(player, radio)
     -> create/front one ApocWalletRadioWindow for this player
     -> empty list + loading/cached balance label
     -> ClientService.refreshBalance(player:getPlayerNum(), callback)
        -> existing wallet command / server service / Java API
        -> callback updates stored label/status once
  -> close / death / disconnect
     -> unsubscribe the window's callback
     -> remove UI and clear the matching registry entry
```

An already-open window should be brought forward without starting another
operation. For a fresh open, an optional `getState(index)` read can paint the
existing cache immediately; then one `refreshBalance` operation obtains the
display value, subject to existing coalescing/cooldown. No refresh belongs in
`render`, `prerender`, `update` or a permanently attached `OnTick`.

The callback may execute synchronously for cached state. Publish the window in
the per-player registry and initialize its lifecycle/generation guard before
subscribing. On callback, check that the window is still the active instance for
the same player and operation. Closing cancels only this observer; another UI
or login observer can still need the shared request. The callback stores text,
numeric balance and status; rendering only draws these fields.

Show a loading state while unknown, the real numeric value on success (including
zero), and an unavailable/error state on failure. Do not format missing or
failed data as balance zero. The cached number never authorizes spending; the
backend still owns debits/credits through its other operations.

Keep existing client/server controllers and services. The UI controller owns
window lifetime and wallet subscription; the view owns widgets/drawing. No new
Java class, server endpoint or server-side RadioTraders copy is required here.

## Native dependencies and localization

Require vanilla `ISUI/ISCollapsableWindow`, `ISUI/ISScrollingListBox`,
`ISUI/ISButton`, and `RadioCom/ISRadioWindow` / `RadioCom/RadioWindowModules/RWMPanel`
for the radio module. `ISUI/ISContextMenu` is needed only for the optional
right-click route. These are game dependencies, not vendored files.

The installed vanilla `ISRadioWindow.lua` confirms `createChildren/addModule` and
passes the actual player/device/data/type to `RWMPanel.readFromObject`.
`RWMPanel.lua` confirms the section lifecycle and base methods. The local
decompiled `zombie/inventory/types/Radio.java` confirms `getDeviceData()`.

The native `createChildren` wrapper must preserve its original call and add our
section once. Use wallet-owned classes and an installation guard, so load order
does not replace the vanilla window or attach duplicate modules. Do not patch
RadioTraders functions or require its globals, even if both mods are installed.

Create wallet-owned `UI_ApocWallet_*` keys under
`common/media/lua/shared/Translate/{EN,PTBR}/UI.json`: module title, open action,
balance label, loading, unavailable, empty list, close and refresh. Do not copy
the full multilingual trader catalogue or its fallback translation loader.

## Implementation order and verification

1. Fork the standard handheld layout/artwork and a standalone vanilla-derived
   window. It opens with an empty list and a placeholder balance state.
2. Add our radio section/open controller; optionally add the inventory context
   route. Verify no dependency on installed RadioTraders.
3. Bind the existing wallet callbacks, cancellation and per-player registry.
4. Add EN/PTBR strings and focused UI tests, then validate in game.

Required regression cases for implementation: original vanilla radio hook runs
once; no duplicate module/open window; empty lists open without stock/traders;
loading/success/zero/error balance states; synchronous cached callbacks; close
before completion; reopen before an old response; death/disconnect; split-screen
isolation; no render/update network calls; no inventory money scans; callback
unsubscription; texture/layout scaling and screen clamping. Visual confirmation
needs a B42 client; mocked widget tests do not establish correct appearance.

This investigation only changes documentation. No source/assets were copied,
no gameplay code changed and no runtime tests or backend requests were made.
Source paths, selected methods, texture headers/sizes and document links were
checked locally.

## Source fingerprint

Installed source snapshot identifiers (first 16 hexadecimal SHA-256 characters):

| File under `client/RadioTraders/` | Lines | SHA-256 prefix |
| --- | ---: | --- |
| `RT_RadioWindowModule.lua` | 155 | `1127b80cb32b2510` |
| `RT_ContextMenu.lua` | 258 | `f2048f3d36f67821` |
| `RT_TradeWindow.lua` | 1965 | `80e6f661c93d8f27` |
| `RT_SkinWindow.lua` | 661 | `eaaf5ea5fae00f3c` |
| `RT_SkinLayout.lua` | 12 | `b1f235c115e2d6da` |
| `RT_Client.lua` | 282 | `010b59af52c87571` |

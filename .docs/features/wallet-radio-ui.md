# Wallet-owned radio UI

Update 2026-11-11: the [player market/operator layer](wallet-player-market.md)
attaches tune-in, six market buttons, animated portraits, PTBR protocol speech and
radio effects to these shells. The empty-shell behavior described below remains
the base widget implementation; the market controller now supplies listings and
posting/buying actions during actual play.

Status: implemented in Lua; awaiting in-game visual and dedicated-server smoke
tests. Created 2026-11-11. This is an independent fork of selected RadioTraders
visual components, with no RadioTraders runtime dependency or purchase logic.
See [wallet API connectivity](wallet-api-connectivity.md) for backend setup and
the [source extraction map](../reports/2026-11-11-wallet-radio-ui-fork-map.md) for
the original component investigation.

## Opening and operation

Enable `ApocalipseBR-Wallet` on both server and clients with the previously
documented 42.22.2 Java API/identity patches. RadioTraders does not need to be
enabled. No texture packs, map dependencies or additional server endpoint are
required. The new UI code is client-side only.

- Open the normal controls for a two-way radio. The new **Wallet** section has
  an **Open wallet** button.
- Alternatively, right-click a two-way radio in inventory and choose **Open
  wallet**. World two-way radios expose the same context action. The native
  radio section also accepts a two-way vehicle device.
- The window displays the handheld or desktop/ham shell appropriate to the
  device, an intentionally empty list, and loading/ready/unavailable balance
  state. Zero is a valid balance; an error is not shown as zero.
- A radio carried in the player's inventory (including inside carried bags)
  opens immediately. A placed/ground radio opens immediately only when nearby
  and reachable. Otherwise the native pathfinder walks to an adjacent tile and
  opens the wallet after successful arrival. Cancelling/failing the walk, losing
  the device, or replacing/dying/disconnecting the player prevents opening.
- **Sync** requests the backend balance through `ClientService.refreshBalance`.
  Opening a fresh window does this once, sharing an existing pending operation
  or using the five-second cache cooldown. While loading, an explicit Sync can
  retry the same intent after five seconds; it does not start a duplicate read.
- **Skin** cycles the copied variants for that shell. **Close** removes the
  window and unsubscribes its UI observer. Skin choice is local to the window;
  the initial variant is Standard. No disk preferences are written.
- Reopening an already visible wallet brings it forward without another request.
  One window exists per local player; another player cannot receive its balance.
  Close the existing window before switching the same player's shell/device.

There are no traders, items, stock calls, buy/sell handlers, bank/card operations,
inventory-money scans, radio call simulation, audio, portraits or local debits.
The list is empty by design. The backend still owns all currency mutations.

## Source and asset ownership

The following client files live in
`ApocalipseBR-Wallet/common/media/lua/client/ApocWallet/`:

| File | Responsibility |
| --- | --- |
| `RadioDevice.lua` | Native two-way device detection, carrying ownership, reachable proximity and handheld/ham selection |
| `RadioEntryPoints.lua` | Inventory/world menus, death/disconnect/player-replacement and resolution hooks |
| `RadioUIController.lua` | Per-player window/approach registry, native walk completion, request guards and callback disposal |
| `UI/RadioWindowModule.lua` | Additive vanilla radio-section wrapper; preserves the original constructor hook |
| `UI/RadioWindow.lua` | Vanilla `ISCollapsableWindow` subclass, empty `ISScrollingListBox`, skin rendering, controls and cached labels |
| `UI/RadioLayout.lua` | Forked source artwork coordinates and per-shell skin allowlists |

Visual geometry, shell sizing, texture selection and radio-module construction
were adapted from RadioTraders Workshop item `3807707103`, principally
`RT_SkinLayout`, `RT_SkinWindow`, `RT_RadioWindowModule`, `RT_Shared` and the small
vanilla list setup in `RT_TradeWindow`. No executable upstream trading files
were placed in the wallet Lua tree; the new window directly inherits vanilla.

The copied PNG files are under
`common/media/textures/ApocWallet/radio/`. The
[copy receipt](../reports/2026-11-11-wallet-radio-ui-assets.json) records each
source path, SHA-256, byte size and PNG dimensions. There are **34 files**,
**24530730 bytes**, copied byte-for-byte:

- Handheld: Standard, Woodland, Digital, Tiger, Gold, Leopard, Blood Moon, Flag
  and Black Market, each in SD and HD (18 files).
- Desktop/ham: the same first eight variants, each in SD and HD (16 files).

Alien skins/equipment/radar/animation are excluded. Skin textures load lazily
for the selected shell/variant/size and are cached. SD/HD resolution is selected
from the displayed size; resizing does not load the whole skin collection.
The standard source artwork was visually inspected locally. These source
images retain their original baked-in visual branding.

## Lifetime and performance

The controller stores the window before subscribing because a cached balance
can invoke its callback synchronously. Completion checks the exact active
window, native player and request generation. Closing unsubscribes only that
observer, leaving shared login/UI requests intact. A later reply cannot change
a closed/replaced window. Death, disconnect and character replacement release
the appropriate windows.

Access is checked at open, Sync and balance callback delivery. A carried item's
outermost container must be this player's actual inventory; another character's
inventory is not a valid target. World proximity matches native
`luautils.walkAdj`: X/Y distance from tile center at most 1.6 and
`getCurrentSquare():canReachTo(target)`, which includes floor and wall/door
checks. A seated player may use the current vehicle's radio; the controller
does not try walking while the player is seated.

For a distant device, `AdjacentFreeTileFinder.Find` selects the destination and
`ISWalkToTimedAction:setOnComplete` triggers the final access check. No balance
request or window creation happens before arrival. Selecting an approach uses
the native interaction convention of replacing the current timed-action queue;
an identical active approach is deduplicated. Stop preserves native cancellation
and releases our intent. There is no wallet movement/timer polling. A completed
window is not continuously distance-polled; if the player walks away, Sync or
a later balance result closes an inaccessible window instead of issuing or
displaying a new result. This client UI gate does not authorize backend spending.

There are no added UI tick handlers. The wallet's draw methods use stored
strings and the selected texture; they perform no network calls, clock reads,
inventory scans or text measurement. Labels are formatted/measured only on creation,
layout/skin changes and balance callbacks. Pending request timers remain owned
by the existing wallet service and detach when idle.

Layout is proportional to the ported skin coordinates. Initial size, drag
release and explicit resolution/player changes clamp/reflow within the owning
player's split-screen viewport. There is no per-frame viewport or identity
polling. Radio power, battery, hand placement and trader availability do not
gate this read-only UI; native two-way device recognition is required at open.

The radio hook and context/event registrations have installation guards.
Wallet classes, globals, textures, command module and translations have their
own names. If RadioTraders is also enabled, normal hook chaining preserves the
original and wallet sections; this mod does not disable the upstream mod.

## Labels and localization

`common/media/lua/shared/Translate/EN/UI.json` contains wallet-owned `UI_*` keys
for the radio section, menu/button labels, loading/balance/error states, empty
list, skin names and tooltips. English is the fallback for other languages.
Additional language files were not invented. Internal skin IDs, protocol IDs
and numeric balances remain data, while all displayed labels use `getText`.

## Verification

Run from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-radio-ui.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-radio-access.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet.lua
```

The UI harness executes the production window, controller, entry points and
actual wallet client service/operation code. Only native widgets, devices,
events, texture loading and the network boundary are mocked. It models native
`initialise -> instantiate/createChildren -> addToUIManager` ordering. Coverage
includes the vanilla radio hook, duplicate installation, two-way filtering,
inventory stacks/world/vehicle/ham devices, one-window lifetime, loading and
balance callbacks, synchronous cache results, empty list, skin cycling, close
before response, reopen/stale callback safety, errors/zero, split-screen
isolation, resolution/font changes, drag clamping and death/disconnect cleanup.
Render loops are checked for no new requests, clock reads or text measurements.

Native lifecycle signatures were checked in the installed B42
`ISUI/ISUIElement.lua`, `ISCollapsableWindow.lua`, `ISButton.lua`,
`ISScrollingListBox.lua`, `RadioCom/ISRadioWindow.lua` and `RWMPanel.lua`.
The existing wallet harness separately covers the server service and API callback
boundary. Asset hashes/headers, JSON parsing/key coverage and UTF-8 without BOM
are also checked. Verified 2026-11-11: **47 radio UI assertions** and **75 wallet
service assertions** passed. All **34 PNG copies** match their recorded hashes
and source bytes; all **25 English UI labels**, literal/dynamic key coverage,
JSON syntax and BOM-free UTF-8 checks passed. Documentation links and diff checks
passed. The integer-balance display is also tested at Lua's maximum safe integer.

The access harness runs the actual device/controller code with mocked native
pathfinding and timed-action queues. It covers carried/bag/other-player radios,
reachable/blocked/wrong-floor targets, deferred opening, duplicate approaches,
cancellation, removed/moved targets, stale players, rejected queues, superseded
walks, out-of-range refresh/results, loose ground items and vehicle access.
The native action's completion/stop semantics and container ownership/range
methods were verified in `WalkToTimedAction.lua`, `ISTimedActionQueue.lua`,
`luautils.walkAdj` and local decompiled `ItemContainer`/`IsoGridSquare`/`IsoObject`.
Verified 2026-11-11 after the access change: **27 access**, **47 UI** and **75
wallet-service assertions** passed. Carried radios require no inventory scan;
approaches add no wallet tick listener. Real pathfinding/collision and walking
cancellation still require an in-game smoke test.

No Java compilation is needed for this Lua/asset change. No deployment, live
backend call or live game UI session was performed. In-game acceptance still
needs opening both shell types, choosing skins, reading the actual backend
balance, changing resolution/fonts and verifying mouse/split-screen behavior.

The later login-binding update requires the new Java `CHARACTER_LOGIN` endpoint
and backend POST route described in [API connectivity](wallet-api-connectivity.md).
The UI still uses the same callback contract; first balance loading now registers
the life before a first kill, and later Sync operations use GET.

See [loading diagnostics](../hotfixes/wallet-loading-diagnostics.md) for the
client/server stage trace, immediate dispatch and explicit manual retry. Fixed
failure codes are displayed when available. `EN/UI.json` now contains 26 UI keys.
## Brazilian Portuguese labels

Implemented; awaiting in-game font/rendering validation. All 26 wallet labels,
balance/status messages, tooltips and skin names use the existing
`UI_ApocWallet_*` keys. The catalogs live in the wallet's own
`common/media/lua/shared/Translate/PTBR/UI.json` and `EN/UI.json`, with
`language.txt` metadata in both folders. Both catalogs intentionally contain the
same Brazilian Portuguese text: PTBR is the selected-language translation and
EN supplies the Portuguese default for clients using other game languages.
This does not change the game's language setting or any other mod's labels.

Build 42's local decompiled `zombie/core/Translator.java` confirms category
loading through `forLanguageStack` and the default-language fallback. There is
no global Translator override or per-frame translation work. Existing UI
lookups remain at creation/state/layout changes. Radio text clipping now removes
whole UTF-8 characters so accented Portuguese text cannot be split mid-character.
Protocol values, developer logs and bounded diagnostic error codes remain
untranslated; the visible error prefix is translated. The wallet sandbox file
contains no options or labels to translate.

Validation on 2026-11-11:

```powershell
py -3 tests/wallet-translations.py
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-radio-ui.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/wallet-radio-access.lua
```

Catalog/default parity, display-key and skin coverage, placeholder consistency,
JSON parsing and UTF-8 without BOM checks passed. The Lua fixture checks the
Portuguese module title, loading state and inventory action, and clipping at
14 accented-character boundaries. All 67 radio UI and 27 radio access assertions
passed with mocked native boundaries. No live client rendering was tested.

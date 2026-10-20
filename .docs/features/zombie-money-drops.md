# Zombie money drops

Status: implemented; awaiting in-game validation.

The core mod adds 1–10 `Base.Money` items, inclusive, to each zombie killed
by a currently connected player. Every eligible kill receives loot; only the
quantity is random. Money stays in the corpse inventory for looting, alongside
normal items. It is not credited directly to the player or placed on the ground.
The vanilla ID is `Base.Money`, with a capital M.

## Ownership and configuration

`ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_ZombieMoney.lua`
registers an additive `Events.OnZombieDead` callback. It runs only when
`isServer()` is true, including the server side of hosted multiplayer. Client
and single-player environments do not register it. The callback requires sandbox
option `ApocExtractionMapUtils.ZombieMoneyDrops=true`, which defaults to `false`
and is independent of `LobbyEnabled`. The item and range remain fixed. Missing
or disabled settings leave inventory and reward markers untouched.

Attribution follows the reference `ZKC_ServerHandler.lua`: the server reads
`zombie:getAttackedBy()`, requires an `IsoPlayer`, and checks that the online ID
resolves to the same connected player. Unattributed, environmental, NPC, and
disconnected-player deaths receive no additional money. No client kill claims,
commands, statistics persistence, or dependency on ZKC are introduced.

A namespaced zombie mod-data marker prevents duplicate rewards on the same
zombie, and a namespace load guard prevents duplicate callback registration.

## Engine evidence

Verified in the local decompiled source under
`Z:/Downloads/ZomboidDecompiler/ZomboidDecompiler/bin/output/source/zombie/`:

- `characters/IsoZombie.java`, `onKilled`: calls `DoZombieInventory()` before
  `OnZombieDead`, then continues death processing.
- `iso/objects/IsoDeadBody.java`, corpse constructor: takes `died.getInventory()`.
- `inventory/ItemContainer.java`, `AddItems(String, int)`: appends that many items.
- `Lua/LuaManager.java`, `ZombRand(double, double)`: delegates to integer RNG;
  `ZombRand(1, 11)` uses an exclusive upper bound.
- Installed vanilla `media/scripts/generated/items/normal.txt` defines `Money`.

## Verification

Run from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/zombie-money.lua
```

The mock harness covers server/client registration, repeated loading, quantities
1 and 10, preserved normal loot, duplicate death callbacks, missing zombie or
inventory, non-player attribution, invalid IDs, disconnected players, and stale
player references. Result: PASS on 2026-10-19. `git diff --check` also passed.

Dedicated-server corpse synchronization and actual looting still require an
in-game test: kill zombies with a connected player and check each corpse has
1–10 extra money items; verify a second client sees and can loot the same items.

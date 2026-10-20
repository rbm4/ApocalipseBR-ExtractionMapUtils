# Sandbox feature switches

Status: implemented; Lua regression tests pass. Awaiting in-game validation.

Only map revealing is enabled by default. Settings belong to the existing
`ApocExtractionMapUtils` sandbox group in `common/media/sandbox-options.txt`.
The shared Lua helpers read current sandbox values when callbacks execute,
including when values were unavailable during initial module loading.

| Setting | Default | Scope |
| --- | --- | --- |
| `ForceMapReveal` | `true` | Existing client/server map reveal and map availability. |
| `LobbyEnabled` | `false` | Perimeter initialization/maintenance, disassembly protection, manual and scheduled release, and permission to relocate on login. |
| `RelocateOnLogin` | `false` | Login relocation, also requiring `LobbyEnabled=true` and valid lobby coordinates. |
| `ZombieMoneyDrops` | `false` | Server-confirmed zombie money rewards; independent of the lobby. |

Missing values behave like these defaults. Enabling the lobby alone does not
relocate players or award money. Existing explicit `RelocateOnLogin=true` values
are retained but cannot cause relocation unless the new master switch is enabled.

Disabled lobby startup performs no sprite validation, layout planning, ModData
writes, token creation, RCON loading/subscription, or engine event subscription.
World tick and square-load hooks return immediately. Direct release calls reject
requests, including callbacks retained from a previously enabled session.
Shared disassembly wrappers preserve native behavior when disabled.

Restart the server and reconnect clients after changing configuration. Existing
saved fences, native object flags, token files and release state are retained;
turning off control is not a world cleanup operation. The mandatory RCON mod
dependency is unchanged. The Java patch's database polling and guide actor have
their own JVM configuration; this switch controls the Lua mod only.

Implementation: shared option helpers, lobby settings/protection, server lobby
and zombie money callbacks, client login hook, sandbox definitions and the
existing `Translate/EN/Sandbox.json` labels/tooltips.

Related behavior: [lobby perimeter](lobby-perimeter.md),
[map visibility and relocation](lobby-and-map-visibility.md),
[scheduled event activation](postgresql-event-control.md), and
[zombie money drops](zombie-money-drops.md).

## Verification

Run each harness from the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/map-reveal-server.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-disassembly.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/zombie-money.lua
```

All six pass. Coverage includes absent/false master settings, unavailable sandbox
values, startup after settings arrive, paused queues and release calls, native
disassembly inside disabled lobby squares on both realms, relocation opt-ins,
unchanged map reveal with the lobby off, and disabled money drops without marker
or inventory mutation. Enabled-feature regression coverage remains in place.
JSON parsing, sandbox translation keys, UTF-8 without BOM and `git diff --check`
are also verified. Engine boundaries are mocked; dedicated-server startup,
client sandbox synchronization and existing-save behavior still need live tests.

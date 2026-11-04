# NPC dialogue actions and safehouse travel

Follow-up: [travel corrections](../hotfixes/safehouse-travel-silent-cancellation.md).
Revision 5 sends native teleport directly to the claim origin without requiring
loaded destination squares. Revision 4's memory-only cooldown remains in effect.

Status: implemented for the 42.22.1 Java bridge v5; isolated tests pass, live
dedicated-server validation pending.

## Setup

Apply manager `game-runtime-migration/V40__Npc_Server_Lua_Dialogue_Actions.sql`
and `V41__Agente_V_Safehouse_Travel_Pools.sql` after V39, install the matching
42.22.1 server patch, deploy this mod's `common` Lua files and restart. V41 gives
Agente V on apoc-dev the option **Pode me enviar ao meu abrigo?**, preserving the
original lore option. It seeds five PTBR variants per outcome: success, cooldown,
no_safehouse and unavailable. These are shared content, not extra NPC spawns.

## Registering actions

Put handlers in `common/media/lua/server/` and require
`ApocExtractionMapUtils_HumanActions` before registering:

```lua
local D = require "ApocExtractionMapUtils_HumanActions"
D.registerAction("example.check", function(ctx)
    -- ctx.player is authenticated; ctx includes npcKey/npcId/option/sequence.
    return {
        success = false,
        responsePool = "example.check.unavailable",
        values = { remainingMinutes = "10" },
        close = false,
    }
end)
```

Bind the action ID and response prefix in a draft database
`npc_engine.dialogue_choice_action` row, then publish the dialogue revision.
The manager editor preserves these rows on subsequent publications. Plain text
choices keep their existing response/speech and require no action binding. SQL
actions and NPC task commands cannot share a choice.

Handlers receive validated server context, not client-selected functions or
coordinates. They return an outcome pool, never hardcoded response strings.
Create `label_text` rows `<pool>.1` through `.32` with locale `PTBR` (and optional
translations). One resolved line is used for both NPC speech and panel response;
the engine avoids immediate repeats per NPC where alternatives exist. Named
`{placeholders}` take bounded string values with single-pass substitution. NPC
speech remains limited to 256 characters.

The bridge reserves the choice before invoking Lua. `dialogueComplete` validates
the result against that pending choice, speaks and consumes its sequence once.
Failed outcomes keep the current node and grant no flags; successful outcomes
apply authored transitions/flags. A missing/erroring handler uses the binding's
`.unavailable` pool. Missing/bad content releases the dialogue without executing
deferred effects. Optional `afterResponse` and `cancel` closures are server-only:
reserve resources during preparation, perform side effects after the response,
and release reservations when completion/framing fails. Arbitrary Lua mutations
are not rolled back automatically. The existing `selected` hook is a notification.

## Safehouse travel

`ApocExtractionMapUtils_SafehouseTravel.lua` registers
`player.teleport_safehouse`. The server resolves the player's owned/member
safehouse, refuses dead/disconnected/in-vehicle players and concurrent transfers,
and uses account identity from the Java bridge. Steam IDs remain exact strings;
non-Steam identity falls back to username.

The destination matches vanilla `ISSafehousesList:onClick(TELEPORT)`:
`safehouse:getX(), safehouse:getY(), 0`. The server calls the bridge's native
`GameServer.sendTeleport`, the same transport used by lobby relocation. No
`getGridSquare` lookup, free-floor scan or forced preloading gates this request;
native client relocation/streaming handles an unloaded destination. This is the
registered claim origin, not the claim center. There is no extra terrain scan.

The NPC's success pool authorizes/starts transfer. One native request is sent
after the response and a nonblocking 2.5-second reading interval. Confirmation
requires the same live player's server position on the exact target tile/floor.
The login-only `teleportToLobby` wrapper is not reused because its one-time login
flag would suppress repeated travel.
Only confirmed arrival records `getTimestampMs()` in a private server-memory table. The account must wait **six real
hours** from that success. The allowance is shared across NPCs/characters in the
running server process; death and reconnect do not reset it. A server restart clears it. Responses round remaining time
up to minutes. Rejection, missing safehouse, invalid tile, timeout, death or
disconnect before confirmation leave the previous success timestamp intact.

At most 256 pending trips are tracked. Polling runs every 250 ms with a 20-second
preparation deadline and a separate 20-second arrival deadline after sending.
Membership/connection/vehicle state is revalidated before sending;
No map loading leases are held by this service.
Failed late transfers do not consume cooldown or emit another response after the
conversation closes. Cooldown is not saved to Global ModData or PostgreSQL.
Old saved timestamps are ignored without deleting them. Revision 4 therefore
clears the allowance on every server restart.

## Verification

From the repository root:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/safehouse-travel.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/human-dialogue-graphs.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/human-dialogue.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/human-roster.lua
```

Results: 25 travel/action checks, 31 graph/routing checks, 89 existing dialogue
checks and 45 roster checks. Fixtures exercise production Lua with engine
boundaries mocked: no premature cooldown, exact six-hour boundary, reload,
missing safehouse, blocked/cold destinations, disconnect/death/vehicle changes,
timeout, one native request, callback errors and completion-before-effect order.
The Java repository additionally passes target JDBC/pool/lease fixtures,
26 manager tests and full exact-JAR compilation (312 sources / 913 classes).

The unrelated existing `tests/human-dialogue-labels.py` print-gate assertion fails
on the pre-existing direct logging in `ApocExtractionMapUtils_LobbyCleanup.lua`;
that file was not changed for dialogue actions. In-game streaming, physical
landing, speech delivery, anti-cheat and save/restart behavior remain to verify.

Related: [dialogue graphs](npc-dialogue-graphs.md), [NPC dialogue](npc-dialogue.md).

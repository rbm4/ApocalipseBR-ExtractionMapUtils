# NPC dialogue drops payload-free discovery requests

Status: implemented and regression-tested; awaiting dedicated-server validation.

## Symptom and evidence

The client repeatedly logged `send command=HumanList` and `list_waiting`, with
no server receive/reply trace and no NPC context menu. Inspection of local
`C:/Users/ricar/Zomboid/server-console.txt` showed server dialogue startup had
actually succeeded: `bridge_status status=ready version=1` and `close_hook_bound`.
The guide spawned as key `guide`, online ID 1024.

## Cause and fix

Verified against `42.21.0/decompiled/zombie/network/GameClient.java`,
`sendClientCommand`, and `42.21.0/src/zombie/network/GameServer.java`,
`receiveClientCommand`, in the local patch repository: an empty Lua argument
table is transmitted with `hasArgs=false`. The server consequently invokes
`OnClientCommand` with nil arguments. The dialogue handler required a table
before its receive log, silently discarding every payload-free roster poll.

`server/ApocExtractionMapUtils_HumanDialogsServer.lua` now normalizes nil to an
empty table for `HumanList` only. Other argument types and payload-free mutation
commands remain rejected. Receive logs include `argsType=nil` for the normalized
discovery request; malformed arguments log `request_ignored reason=invalid_args`.
All logs remain behind `ApocExtractionMapUtils.debugLog`.

## Validation and operation

`tests/human-dialogue.lua` now models the native transport boundary by passing
nil for absent/empty command tables. This reproduced the original failure before
the fix. With the fix, all 59 assertions pass, including nil discovery against
missing/available bridges, receive logging, invalid payload types, mutation
payload rejection and the existing reservation/arrival/selection lifecycle.

Commands run from the mod repository:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/human-dialogue.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/debug-logging.lua
python tests/human-dialogue-labels.py
git diff --check
```

The logging harness and translation/configuration checks pass too. Engine/network
boundaries are mocked; no live-server fix or deployment is claimed. Update the
server Lua file and restart the server, then reconnect and verify server
`receive argsType=nil command=HumanList`, `roster_ready`, client `roster_updated`
and `menu_added`. The existing client roster poll needs no protocol change.

Related feature: [NPC dialogue](../features/npc-dialogue.md).

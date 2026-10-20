# NPC dialogue and walk-up interactions

Status: implemented for the patched dedicated server 42.21.0; awaiting in-game
multiplayer validation. Install this mod on clients and server, and deploy the
matching server Java patch. No client Java patch is needed. An unpatched server
advertises no interactive NPCs; ordinary player menus remain unchanged.

## Player flow

The client refreshes nearby registered actors every five seconds while no
conversation is active. Right-click the NPC, open **Conversar com <name>**, and
choose a dialogue option. The server reserves that specific actor before any
movement begins. The client queues a vanilla `ISPathFindAction` derivative to
one of eight adjacent positions, followed by `ApocHumanTalkAction` to request
arrival validation. Native pathfinding handles routes/doors and cancellation,
following the same path-action + interaction-action pattern as the claim mod.

The NPC stops roaming and faces the visitor during approach and conversation.
The selected option executes only after server-approved arrival. A dialogue
panel shows the answer and allows further choices. **Encerrar conversa** closes
it. The guide's starter choices greet/wave, explain the lobby, and thank/thumbs-up.
NPC speech is audible through the existing nearby chat transport; panel text is
translated locally. This first version has a flat option list, not a branching
quest or shop system.

Opening the context menu alone does not reserve the NPC; choosing an option does.
The native `OnPreFillWorldObjectContextMenu` hook sees `fetchVars.clickedPlayer`
after Java's `ISWorldObjectContextMenuLogic.fetch`. An explicit `IsoPlayer` in
`worldobjects` takes precedence. Only IDs in the server's NPC roster qualify;
player/display names are never treated as identities. Native nearby-player
selection remains the fallback, including its adjacent-square behavior.

## Registering dialogue and reactions

Load after `ApocExtractionMapUtils_HumanDialogs`. Definitions can be shared or
server-only; the server sends public option IDs and label keys to the client.
The key must match an existing `ServerHumanDefinition.key`, not its display name.
Registering dialogue does not spawn an NPC.

```lua
require "ApocExtractionMapUtils_HumanDialogs"
local dialogs = ApocExtractionMapUtils.HumanDialogs

dialogs.register("guide", {
    greetingKey = "IGUI_MyMod_Welcome",
    options = {
        {
            id = "directions",
            textKey = "IGUI_MyMod_AskDirections",
            responseKey = "IGUI_MyMod_Directions",
            emote = "wavehi", -- optional native emote
            onSelect = function(player, selection)
                -- Server-only callback, after validated arrival/selection.
                -- selection has key, id, token, option, sequence, responseKey.
            end,
        },
    },
})

dialogs.on("selected", function(player, selection)
    -- Observe registered selections without replacing another handler.
end)
```

Add referenced `IGUI_*` strings to the owning mod's
`media/lua/shared/Translate/EN/IG_UI.json` (or its `common/media` equivalent).
This mod follows its existing PT-BR fallback text convention in that category.
The default guide profile can be replaced by registering `guide` after the base
file. A registration has 1?12 options, unique IDs up to 48 characters, and optional
native emotes up to 40 characters. Responses must translate to at most 256
characters to fit the Java speech boundary. Active conversations retain their
original definition until closed; re-registration affects later conversations.

`dialogs.on` supports `reserved`, `opened`, `selected`, and `closed`. All fire on
the server. Callback errors are isolated and logged without player payloads.
Callbacks may extend gameplay but must validate any additional privileged action;
this feature does not implement item delivery or credit spending. Selection
sequence numbers stop duplicate requests within a session; they are not durable
purchase receipts.

## Authority and lifecycle

- Discovery includes same-floor actors within 32 tiles. Starting requires the
  actual authenticated player within 8 tiles and unobstructed visibility.
- Exactly one visitor per NPC and one NPC per visitor. Native trading and
  dialogue exclude each other. A second player gets a busy response.
- Approach expires after 30 seconds. Arrival/selection require the same player
  instance, connection and session token, the same floor, visibility, and distance
  at most 2.5 tiles. An open conversation ends beyond 3 tiles.
- Idle dialogue expires after 60 seconds; accepted selections refresh it. Emotes
  last 2.5 seconds. Closing, clearing queued actions, path failure, disconnect,
  death, loss of visibility/range, or despawn releases the actor. Server deadlines
  still release it if a client cancellation never arrives.
- Only server-registered option IDs execute. Client-supplied text, emotes,
  coordinates, Steam IDs or NPC keys cannot choose the reaction or owner.
- Selection requests must use the next sequence number and are limited to one
  accepted reaction per 500 ms. Discovery/open requests have separate throttles.
  Server replies include the recipient's online ID for split-screen filtering.

The command module is `ApocExtractionMapUtils`, using `HumanList`, `HumanBegin`,
`HumanArrive`, `HumanSelect`, and `HumanClose`. Responses are `HumanList`,
`HumanReserved`, `HumanOpened`, `HumanSelected`, `HumanClosed`, and `HumanRejected`.
The server-only `ApocBRHumanAPI` bridge is installed on the first simulation tick.
The mod waits for its close event before subscribing. No database, RCON call,
economy change, new dependency, or production deployment is involved.

## Code and verification

Core Lua files under `ApocalipseBR-ExtractionMapUtils/common/media/lua/`:

- `shared/ApocExtractionMapUtils_HumanDialogs.lua`: registry, hooks, starter guide.
- `server/ApocExtractionMapUtils_HumanDialogsServer.lua`: command validation,
  session sequencing, callbacks and public metadata.
- `client/ApocExtractionMapUtils_HumanDialogsClient.lua`: NPC matching, context
  options, timed actions, replies and cancellation.
- `client/ApocExtractionMapUtils_HumanDialogPanel.lua`: dialogue display/buttons.
- `shared/Translate/EN/IG_UI.json`: guide/menu/panel labels.

The Java implementation is documented in the patch repository's
`42.21.0/NPC-DIALOGUE.md`. Verified sources include that version's `LuaManager`,
`LuaEventManager`, `ISWorldObjectContextMenuLogic`, and local vanilla
`ISWorldObjectContextMenu.lua`, `ISPathFindAction.lua`, `ISBaseTimedAction.lua`
and `ISEmoteRadialMenu.lua`.

Run from this repository:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/human-dialogue.lua
python tests/guide-translations.py
python tests/human-dialogue-labels.py
```

The dialogue harness passes 43 assertions covering registration, authenticated
routing, initial/follow-up reactions, invalid options/tokens, replay rejection,
callback isolation, recipient filtering, context-menu probes, path/talk ordering,
queue cancellation and panel close. Engine/UI boundaries are mocked. The panel's
Lua syntax and translation JSON/UTF-8 are checked separately. Java production
lease tests and game-JAR dry compilation are recorded in the patch guide.

Manual validation remains necessary for rendered character picking, UI layout,
pathfinding around doors/obstacles, movement synchronization, native emote
playback, disconnect/despawn behavior and two-player contention on a dedicated
42.21.0 server. No live-server behavior is claimed by these tests.

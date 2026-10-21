# Cached PostgreSQL dialogue graphs and Lua login

Status: implemented for server 42.21.0; isolated database, engine-fixture and Lua
checks pass. Dedicated-server/client visual and movement checks remain required.

Bridge v4 update verified: dialogue client/server flow (78 assertions), engine
command adapter/framing (25), resolved panel labels/text (11), roster lifecycle
(27) and EN/PTBR translation consistency (52 labels per locale) pass. Tests cover
an English client displaying PTBR server text and commands omitting locale.
The engine's isolated PostgreSQL V18/Flyway tests also pass. Deploy the engine,
mod on both sides, and V18 together; no live deployment was performed.

## Ownership and startup

**ApocalipseBR-ExtractionMapUtils** owns login hooks, lobby relocation and NPC
roster requests. Its `client/ApocExtractionMapUtils_Login.lua` listens to
`OnCreatePlayer` and `OnGameStart`, queues each local character, waits for an
assigned online ID on `OnTick`, then calls
`HumanDialogs.client.requestRoster(player)` once. Repeated events for the same
character/ID do not send another request. Replacement characters get a new
subscription. NPC discovery works with relocation disabled.

The same mod owns dialogue presentation, timed actions, server session routing
and lobby rules. `server/ApocExtractionMapUtils_LoginServer.lua` handles login
commands and the last-server check. The dialogue tick handles expiry/diagnostics;
the login module initiates subscriptions. Install ExtractionMapUtils on clients
and server. The Regions Moodle plugin has no role or dependency in this flow.
NPC discovery remains Lua-owned; the engine's separate successful-login audit
runs at accepted connection time.

The NPC SQL worker reads published dialogue bindings, node/choice translations
and earned account flags with its startup snapshot **before actors activate**.
The simulation-thread Java bridge v4 supplies resolved views and conversation
commands over detached memory: `dialogueRoster`, `dialogueBegin`, `dialogueView`
and `dialogueSelect`. `dialogues()` supplies readiness/generation metadata only.
No login, menu, selection or speech request queries PostgreSQL.

The startup command remains `ApocExtractionMapUtils/HumanList`. Its response
contains bot identities **and actual localized dialogue data**, not translation
tags. The server retains an early subscriber until the Java/cache boundary is
ready; the client does not poll NPC discovery. Lobby relocation uses the mod's
separate `LoginLobbyState` request and existing bounded geometry retries.

ExtractionMapUtils' server Lua decides closed-lobby/invalid-position/server-change
relocation. Optional `ApocBRPlayerLogin` getters read the cached previous server
from independent successful-login history; the handler retries until that result
is ready. Its teleport helper uses the native packet. `GameServer` records accepted
connections for both SQLite and PostgreSQL players. `ServerPlayerDB` reconstruction
does not record logins. See [successful-login history](successful-login-history.md)
and the patch repository's `PLAYER-LOGIN-ORIGIN.md`.

## Content and progression

A versioned graph has `id`, `revision`, `entryNode`, `fallbackLocale` and keyed
`nodes`. Each node has localized title/description and ordered choices. Each
choice has a stable ID, destination node, localized title, description, panel
response and spoken response; an optional emote and close flag accompany it.
The panel shows node title/description, the chosen response and replacement
buttons for the current node. Choice descriptions appear as button tooltips.

The migration seeds the existing `hello`, `help`, `thanks` choices in EN and PTBR
as root self loops, preserving order, replies and emotes. Static registration and
translation keys remain a compatibility path **only when NPC SQL persistence is
disabled**. Persistence-enabled servers never substitute Lua defaults for an
unavailable or unbound database graph. V18 stores NPC interface/error labels and
automatic greeting/operation labels in `npc_engine.label_text`; trade speech
retains its separate content model. Standalone flat menus use server-resolved
label defaults.

NPC content defaults to **PTBR** without any JVM argument. The optional
`-Dapocbr.npc.language=EN` selects another NPC language at process startup.
Neither `user.language` nor client language controls NPC content. The engine
resolves the requested locale, PTBR, then the graph's authored fallback, and
logs its locale and first fallback. No global Translator language is changed.

The client sends NPC/session/node/revision/option/sequence identifiers through
the ordinary server Lua command handler. Lua forwards those identifiers and
the authenticated player to `ApocBRHumanAPI.dialogueSelect`. The engine owns
graph pinning, conditions, cooldown/order, fact acceptance, speech and cursor
advancement. It returns resolved response text and the next presentation.
Clients never submit a locale, response, effect or destination node.

`required_flag` and `forbidden_flag` gate choices. A successful choice can earn
`set_flag` and advance `next_node`. The server validates the pinned revision,
current node, flags, option, token, sequence, proximity and cooldown. Client
payloads never supply authoritative flags or response text.

Earned flags are cached per server/world/NPC/dialogue/account, preferring Steam
identity and otherwise the exact account username. The NPC worker stages
monotonic facts into `npc_engine.dialogue_flag` through the shared journal with
the scope epoch fence. They survive reconnect, character death and content
revision changes after persistence. Repeated facts are idempotent. A new
conversation starts at the graph entry node; only earned facts persist, not the
conversation cursor or lease. Publication does not reset earned facts.
Speech uses the existing public nearby chat transport. Empty `speech` keeps a
secret reply in the private dialogue panel only.

Capture is asynchronous, like NPC checkpoints: a crash can lose a newly earned
fact before the worker/journal stages it. This is content progression, not an
economic settlement or reward receipt. The cache supports 100,000 facts per
server/world and 128 per NPC/dialogue/account. Administrative deletion/reset
requires a controlled restart; facts cannot be revoked by client requests.

SQL graph facts come from the engine account-fact cache. The legacy Lua
`contextProvider` remains scoped to standalone registrations; it does not inject
facts into engine-owned SQL conversations. New gameplay/rewards require their own validated handlers; no SQL
row can execute Lua, Java or an arbitrary ChatGPT-supplied function.

## Secret content and transport

Login responses are personalized using cached account facts. Wire schema 2 sends
only current/root nodes, resolved node text, available option titles/descriptions
and interface labels in one language. Future nodes, graph edges, other locales,
unselected replies, conditions and flag effects stay server-side. A successful
selection sends a newly filtered view, making newly earned secret choices
available without reconnecting. The client updates its future root menu while
the current conversation keeps its own node.

`HumanList` protocol 2 supports whole small snapshots or bounded multipart
actor/graph/node/choice records. `HumanOpened` and `HumanSelected` reuse that
framing inside `contentFrame`. Frames target 32 KB, with a 1 MiB snapshot and
128-part cap. The estimator counts UTF-8 bytes and conservative table overhead.
Clients collect parts out of order, ignore duplicates/stale revisions and install
only complete snapshots. Partial snapshots do not remove a working roster.
Split-screen recipients and assemblers remain isolated. These are application
payload bounds, not a change to vanilla packet definitions.

There are at most 32 nodes, 128 choices, 12 choices per node, four locales and
256 KiB of translated content per database graph. A roster exceeding the snapshot
cap is rejected/logged rather than partially delivered; size content to the
number of active NPCs. Apply manager migration V18 and ship the updated clients,
server Lua and engine bridge v4 together. Prior published graphs stay intact.

Publication creates a new immutable revision. The worker checks the catalog on
its existing 30-second configuration cycle, then invalidates/pushes roster data
on the simulation thread. Existing conversations retain their original graph.
ChatGPT can later generate a draft graph and translations for the same validated
publication process. No model API or provider credentials are used in this flow.

## Verification

From the extraction repository:

```powershell
npm exec --yes --package=fengari-node-cli -- fengari tests/human-dialogue.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/human-dialogue-graphs.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/human-dialogue-panel.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/human-roster.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-lobby-state.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-position.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/login-and-maps.lua
npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-perimeter.lua
python tests/human-dialogue-labels.py
python tests/translation-locales.py
```

These fixtures execute production Lua with engine/UI boundaries mocked. Java
JDBC/worker and Flyway tests use disposable PostgreSQL with separate migration
and engine roles. See the backend's `docs/npc-dialogue-graphs.md` for SQL authoring,
and the patch repository's `42.21.0/docs/npc-dialogue-graphs.md` for engine checks.
No live migration, deployment or ChatGPT integration is performed by these tests.

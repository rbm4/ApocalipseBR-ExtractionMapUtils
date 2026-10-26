# NPC dialogue references after death and respawn

Status: implemented, isolated tests pass; awaiting live multiplayer validation.
Affected feature: [database dialogue graphs](../features/npc-dialogue-graphs.md).

The reported symptom was an NPC returning with a new native player ID while the
client retained its old dialogue reference. The existing Java lifecycle event and
Lua push path were already present; inspection alone did not prove which live
delivery stage failed. This fix makes identity rebinding explicit and adds recovery
for stale references, framing failures and missed lifecycle invalidation.

## Resulting behavior

- The server bridge supplies a monotonic `rosterRevision()` scalar and a fresh
  immutable incarnation token for each actor, alongside its stable key/current ID.
  Existing lifecycle events remain; native LuaEventManager already queues events
  emitted off the Lua thread. The scalar is safe for cross-thread revision reads;
  this is not a general thread-safety claim for native NPC world simulation.
- Server Lua detects revision changes and rebuilds/pushes personalized snapshots
  to all subscribers. A changing generation during snapshot construction is
  discarded. Stable idle ticks do not scan actors or resend menus.
- Delivery stays pending on framing/send failure and retries once per second.
  One client's failed send does not prevent other clients receiving the update.
- Clients replace native-ID and stable-key indexes only on a complete newer roster.
  Death/replacement closes old panels and invalidates queued talk actions.
  Context-menu callbacks resolve the latest binding before sending Begin.
- Startup, unknown-reference and incomplete-frame recovery is bounded to three
  requests per outstanding recovery, at least two seconds apart, with ten-second
  reply/frame timeouts. Idle clients with a complete view do not poll.

Trusted server Lua may call
`ApocExtractionMapUtils.HumanDialogs.refreshRoster(player)` to queue a personalized
full snapshot for one authenticated character. It does not grant choices or add
dialogue content. The current scope introduces no locked dialogue or unlock API.

## Files and deployment

Production Lua changes are in `ApocExtractionMapUtils_HumanDialogsServer.lua` and
`ApocExtractionMapUtils_HumanDialogsClient.lua`. The companion server Java changes
are `ServerHuman` incarnation metadata and `ServerHumanDialogue` roster generation
and API metadata in the 42.21.0 patch repository.

Update ExtractionMapUtils on **server and clients**, deploy the matching server
Java patch and restart/reconnect. No client Java patch or migration is required:
the database already persists the stable NPC key and respawn configuration, and
this change only repairs transient synchronization. Preserve the existing V30
respawn migration. Debug logs include `bridge_roster_changed`, `roster_rejected`,
`roster_resync`, `binding_changed` and roster apply/ignore messages.

## Verification (2026-10-26)

`npm exec --yes --package=fengari-node-cli -- fengari tests/human-roster.lua`
passed 45 assertions, including event-independent respawn, targeted refresh,
framing/native-send retry isolation and a lifecycle change during a snapshot.
`tests/human-dialogue.lua` passed 89 assertions, including death with an open panel,
fresh-ID rebinding, stale menu callbacks, duplicate/old delivery rejection, changed
incarnation and timed-out partial frames. Graph/framing tests passed 25, panel 11,
label checks 11; login/map regression passed.

The Java repository passed dialogue 69, mortality/respawn 32, worker async 31 and
sync 26 assertions; worker failure injection intentionally prints its caught
failure. Actual game-JAR dry compilation passed with 296 sources/874 class files.
No production migration, mod publication or deployment occurred. Validate with
two live clients through a full kill/respawn cycle, including open dialogue and
split-screen recipients, before claiming native multiplayer behavior verified.

# Safehouse travel silent cancellation

## Memory cooldown and exact-tile arrival (revision 4)

At the user's request, the six-hour account timer now lives only in a private
server Lua table. A server restart clears all travel cooldowns. Reconnecting or
respawning during the same process does not clear an account's timer. Old
Global ModData timestamps are ignored without deleting saved data; no migration
or Java patch is needed. Deployment/restart loads revision 4.

Arrival now requires the player's server position on the actual destination tile
at floor zero. The former 1.5-tile tolerance could count a neighboring tile as
arrival, especially noticeable for tiny claims. This is a confirmed source-level
weakness, not proof of the reported live transfer's exact cause. The timer still
starts only after one accepted native request and observed arrival. Regression
tests include a one-tile safehouse, neighbor rejection, memory reset, same-process
reconnect and zero persistent ModData accesses.

Status: diagnostic/failure-handling fix implemented; live root cause still needs
a new attempt using the instrumented mod. No Java patch or migration required.

## Destination readiness correction (revision 3)

The next live attempt logged `ARMED` then `WAITING_FOR_DESTINATION` and finally
`departure_timeout`. The post-response callback therefore did run; no additional
NPC speech acknowledgement is missing. The failure is before native packet send,
while locating a loaded destination. That trace alone does not reveal the native
streaming status or whether the center square is absent.

Source review found that a missing center square always returned `loading=true`,
even when `keepCellLoaded` returned 1 (fully integrated). Neighbors were never
searched in that case. Revision 3 separates cell readiness from square existence,
examines the bounded neighborhood even with a missing center and keeps all cells
intersecting the search alive (up to four at a cell boundary). An integrated area
with no free ground-floor tile is rejected rather than reported as still loading.

Loading gets a bounded 60-second preparation window; native request acceptance
starts a separate 20-second arrival window. Cancellation distinguishes
`response_not_armed_timeout`, `destination_loading_timeout` and `arrival_timeout`.
Loading diagnostics include claim-center coordinates, loaded/unavailable cell
counts and existing-square count, including the latest state at timeout.
The startup marker is now `LOADED ... revision=3`. No visible countdown UI was
added, and cooldown still begins only on confirmed arrival.

Production-Lua fixtures pass 37 travel checks (including missing-center/free
neighbor, integrated empty area, four-cell renewal and slow-load timeout), plus
32 dialogue graph checks, 89 existing dialogue checks and 45 roster checks. A live
attempt is still required to verify streaming and arrival on the actual map.

The 2026-11-04 local server log shows the travel selection accepted, HumanSelected
sent and the conversation closed. The installed Workshop travel Lua file matched
the repository by SHA-256. This proves selection reached completion, but the old
code emitted no scheduled/send/arrival or cancellation diagnostics, so it cannot
establish whether departure was armed, native streaming stalled, the native
bridge refused, or a later transfer timed out. No visible UI countdown was
implemented: departure uses a server-side 2.5-second delay.

The fix emits bounded operational transitions independent of debugLog:
`[ApocSafehouseTravel] LOADED ... revision=2`, `PREPARED`, `ARMED`, optional
`WAITING_FOR_DESTINATION`, `TELEPORT_SENT`, `ARRIVED`, and `CANCELLED reason=...`.
Every terminal cancellation now reports a reason, including membership changes,
vehicle/death/disconnect, missing landing tile, native refusal/exception and
departure/arrival timeout. Tick processing isolates exceptions per trip, releases
the failed reservation and leaves the account able to retry without a cooldown.
Only confirmed arrival still writes cooldown state.

The generic dispatcher logs `AFTER_RESPONSE_FAILED` with the caught error before
cancelling a prepared action; previously this pcall discarded its error. Logging
uses the shared bounded/sanitized `logOperation` helper. There is no per-tick or
unbounded loading log: a loading wait is emitted once per trip.

Redeploy the updated shared/server Lua files, restart to load them, and verify
the revision marker in the dedicated-server output. Retry once and inspect the
last `[ApocSafehouseTravel]` stage. `bridge_rejected` means native capability
validation failed; `departure_timeout` before TELEPORT_SENT means the route never
became ready; `arrival_timeout` after TELEPORT_SENT means no server-observed
arrival. These are diagnostic distinctions, not a verified live diagnosis yet.

Regression coverage executes production Lua with engine boundaries mocked:
native refusal and exceptions, polling exceptions and retry cleanup, operational
output with debug disabled, and generic post-response exception preservation.
Run safehouse-travel.lua, human-dialogue-graphs.lua, human-dialogue.lua and
human-roster.lua with the repository's fengari runner.

Related: [NPC dialogue actions and travel](../features/npc-dialogue-actions.md).

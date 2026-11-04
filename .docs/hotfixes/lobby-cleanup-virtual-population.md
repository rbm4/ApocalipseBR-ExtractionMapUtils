# Startup cleanup reports zero removals before zombies appear

Status: implemented 2026-11-04; regression/build passed; live retest pending.

The reported startup log completed 24/24 chunks with removed=0, but zombies were
visible after login. The original implementation treated ServerCell.isLoaded plus
a five-second wait as sufficient to clear zombies. This proved map geometry was
loaded, not that virtual population had materialized. Decompiled LoadedAreas.set
normally publishes player/connection areas separately from loaded server cells;
IngameState skips population updateMain while the empty server is paused. Those
source paths explain a plausible cause of the observed empty sweep. The live
server's internal population state was not captured, so this is not a confirmed
trace of each zombie from the report.

The updated 42.22.1 bridge temporarily appends the current cell to population
activation areas and consumes population updates on the server thread while
paused. Lua repeats bounded sweeps and requires native readiness, two completed
sweeps and five seconds without further removals before declaring the cell clean.
Pending population eventually times out as FAILED, not COMPLETE. Release removes
the population area and stops map relevance renewal. Other player areas survive.

Logs now include populationReady, verificationPasses, loadedTiles and missingTiles.
Missing floor geometry is visible rather than indistinguishable from a populated
empty floor. Startup remains configurable and finite; later arrivals/respawns
after completion are not continuously removed. See [feature specification](../features/lobby-zombie-cleanup.md).

Affected: server/ApocExtractionMapUtils_LobbyCleanup.lua, tests/lobby-cleanup.lua,
and the patch repository's ApocBRLobbyStreaming.java, LoadedAreas.java and
tools/test_lobby_streaming.py. Deploy the updated mod and complete 42.22.1 patch;
the geometry-only bridge is rejected before cleanup begins.

Validation: `npm exec --yes --package=fengari-node-cli -- fengari tests/lobby-cleanup.lua`
passes, including an empty first sweep, delayed materialization, pending population
timeout, legacy bridge rejection and release on error. The production Java bridge
and LoadedAreas fixture passes 24 checks. Full exact-JAR build passes: 310 sources,
911 classes under 42.22.1/artifacts/lobby-population-fix-20261104. These are mocked
engine-boundary tests and a real compatibility build, not native population testing.
No server was started or patch deployed by this change. Retest empty paused startup,
login, subsequent chunk reload and restart on the target dedicated server.

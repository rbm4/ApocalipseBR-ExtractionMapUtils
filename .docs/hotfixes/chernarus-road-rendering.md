# Chernarus road rendering workaround

Status: existing Lua workaround, introduced in mod version 0.1.4; native rendering
and crash resolution require in-game confirmation. No behavior was changed for
this documentation baseline.

## Symptom and suspected cause

The existing README records a client failure in
`WorldMapRenderer.Drawer.fillPolygon`, followed by `forgot to call endRun()`.
The documented investigation connects dense road polygons and road zoom variants
to a signed-short index-buffer offset. This is a cause hypothesis consistent
with the trace, not a confirmed failing offset.

## Scope and correction

File:
`ApocalipseBR-ExtractionMapUtils/common/media/lua/client/ApocExtractionMapUtils_Cartography.lua`.

The wrapper around `MapUtils.initDefaultStyleV1` selects loaded Chernarus map
data and renders road polygons with vanilla `media/white.png` and their existing
colors. It waits for texture readiness before restoring road layers to their
visible zoom range, avoiding the solid polygon fallback. Other maps keep their
normal style. This workaround operates independently of `ForceMapReveal`.

This is a compatibility fix, not a dependency on Chernarus or a change to
Restless-Waters' role as the event map. See the
[map visibility feature](../features/lobby-and-map-visibility.md).

## Validation and limits

`tests/cartography.lua` covers style selection and texture readiness with mocked
engine boundaries. No harness or game session was run for this documentation
baseline. The [root README](../../README.md) retains the investigation detail
and verification instructions.

Fully restart the client to discard cached triangulations, then open both maps
and repeatedly zoom in/out with the updated mod. Roads can appear thinner at low
zoom; a missing white texture leaves them hidden. Confirm crash resolution in a
fresh game session before treating the native-rendering hypothesis as verified.

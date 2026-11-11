local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path
local realPrint = print
local function fixture(opts)
    opts = opts or {}
    ApocExtractionMapUtils = nil
    package.loaded.ApocExtractionMapUtils = nil
    package.loaded["ApocBR/Entities"] = nil
    package.preload["ApocBR/Entities"] = function() return ApocBREntities end
    function isServer() return opts.server ~= false end
    local f = { clock = 0, finishes = 0, calls = {}, removed = {}, logs = {}, requests = 0, hooks = {} }
    function getTimestampMs() return f.clock end
    function print(message) f.logs[#f.logs + 1] = message end
    Events = {}
    for _, name in ipairs({ "OnServerStarted", "OnTickEvenPaused" }) do
        Events[name] = { Add = function(fn) f.hooks[name] = fn end }
    end
    ApocBREntities = { define = function(name, definition)
        assert(name == "Extraction.ManagedGenerator" and definition.table == "fixed_power_area")
        assert(definition.fields.server_id.id and definition.fields.world.id and definition.fields.area_id.id)
        return { listForServer = function(_, callback) f.requests = f.requests + 1; f.callback = callback end }
    end }
    ApocBRManagedGenerators = { registerGenerator = function(...)
        local args = {...}; f.calls[#f.calls + 1] = args
        return not opts.rejectAt or #f.calls ~= opts.rejectAt
    end, unregisterGenerator = function(id) f.removed[#f.removed + 1] = id; return true end, finishStartup = function() f.finishes = f.finishes + 1 end }
    if opts.noBridge then ApocBRManagedGenerators = nil end
    dofile(media .. "server/ApocExtractionMapUtils_FixedPowerAreas.lua")
    function f.start() if f.hooks.OnServerStarted then f.hooks.OnServerStarted() end end
    function f.tick(ms) f.clock = f.clock + ms; f.hooks.OnTickEvenPaused() end
    function f.logged(text)
        for _, message in ipairs(f.logs) do if message:find(text, 1, true) then return true end end
        return false
    end
    function f.complete(status, entities) f.callback({status=status, entities=entities}) end
    return f
end
local function area(id, enabled, bad, x)
    local values = { area_id = id, enabled = enabled ~= false, x = x or 20, y = 30, z = 2 }
    if bad then values.x = -1 end
    return { get = function(_, key) return values[key] end }
end
local f = fixture(); f.start(); f.start(); assert(f.requests == 1 and #f.calls == 0)
f.complete("OK", {area("house-a"), area("disabled", false)})
assert(#f.calls == 1 and f.calls[1][1] == "persisted-generator:house-a" and f.calls[1][2] == 20 and f.calls[1][4] == 2)
assert(f.logged("START table=mod_data.fixed_power_area") and f.logged("QUERY_BEGIN attempt=1/5"))
assert(f.logged("CATALOG_VALIDATED rows=2 enabled=1 disabled=1") and f.logged("REGISTERED id=persisted-generator:house-a tile=20,30,2 mode=managed_native_generator"))
assert(f.finishes == 1)
f.tick(5000); assert(f.requests == 1)
f = fixture(); f.start(); f.complete("OK", {}); assert(#f.calls == 0)
f = fixture(); f.start(); f.complete("OK", {area("a"), area("b", true, true, 21)}); assert(#f.calls == 0)
f = fixture(); f.start(); f.complete("OK", {area("a"), area("a")}); assert(#f.calls == 0)
f = fixture({rejectAt=2}); f.start(); f.complete("OK", {area("a"), area("b", true, false, 21)}); assert(#f.removed == 1 and f.removed[1] == "persisted-generator:a"); assert(f.logged("REGISTER_FAILED") and f.logged("ROLLBACK id=persisted-generator:a"))
f = fixture(); f.start(); f.complete("UNAVAILABLE"); f.tick(4999); assert(f.requests == 1); f.tick(1); assert(f.requests == 2)
f.complete("OK", {area("recovered")}); assert(#f.calls == 1)
f = fixture(); f.start(); f.tick(120000); f.complete("OK", {area("late")}); assert(#f.calls == 0); assert(f.logged("QUERY_IGNORED reason=startup_finished"))
f = fixture(); f.start(); f.complete("SCHEMA_ERROR"); f.tick(6000); assert(f.requests == 1 and #f.calls == 0)
f = fixture(); f.start(); for i=1,5 do f.complete("BUSY"); f.tick(5000) end; assert(f.requests == 5 and #f.calls == 0)
f = fixture(); f.start(); local many = {}; for i=1,256 do many[i] = area(tostring(i), true, false, i) end
f.complete("OK", many); assert(#f.calls == 0)
f = fixture(); f.start(); f.complete("OK", {area("a"), area("b")}); assert(#f.calls == 0) -- duplicate tile
f = fixture({noBridge=true}); f.start(); assert(f.requests == 0)
f = fixture({server=false}); f.start(); assert(f.requests == 0)
print = realPrint
print("persisted fixed-power startup tests passed")


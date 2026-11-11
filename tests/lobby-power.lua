local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path
local output = print
local function run(enabled, lobby, bridge, bad, coordinates)
    ApocExtractionMapUtils = nil
    package.loaded.ApocExtractionMapUtils = nil
    package.loaded.ApocExtractionMapUtils_LobbySettings = nil
    SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = lobby, LobbyFixedPower = enabled,
        LobbyGeneratorX = bad and -1 or 14, LobbyGeneratorY = 20, LobbyGeneratorZ = 0 } }
    if coordinates then
        local options = SandboxVars.ApocExtractionMapUtils
        for _, axis in ipairs({"X","Y","Z"}) do
            if coordinates[axis] ~= nil then options["LobbyGenerator" .. axis] = coordinates[axis] end
            if coordinates["omit" .. axis] then options["LobbyGenerator" .. axis] = nil end
        end
    end
    function isClient() return false end
    function isServer() return true end
    local calls, hook, logs = {}, nil, {}
    function print(message) logs[#logs + 1] = message end
    Events = { OnServerStarted = { Add = function(fn) hook = fn end } }
    ApocBRManagedGenerators = bridge and { registerGenerator = function(...) calls[#calls + 1] = {...}; if bridge == "error" then error("world placement test failure") end; return bridge ~= "reject" end } or nil
    dofile(media .. "server/ApocExtractionMapUtils_LobbyPower.lua")
    hook(); hook()
    print = output
    return calls, logs
end
assert(#run(false, true, true) == 0)
assert(#run(true, false, true) == 0)
assert(#run(true, true, false) == 0)
assert(#run(true, true, true, true) == 0)
local calls, logs = run(true, true, true)
assert(#calls == 1)
local a = calls[1]
assert(a[1] == "extraction-lobby" and a[2] == 14 and a[3] == 20 and a[4] == 0)
assert(logs[2]:find("REGISTER_BEGIN id=extraction-lobby tile=14,20,0", 1, true))
assert(logs[3]:find("REGISTERED id=extraction-lobby mode=managed_native_generator", 1, true))
assert(#logs == 3) -- duplicate startup does not repeat diagnostic events
local function logged(lines, text)
    for _, line in ipairs(lines) do if line:find(text, 1, true) then return true end end
    return false
end
local calls, logs = run(nil, true, true)
assert(#calls == 0 and logged(logs,"generator_enabled=false") and logged(logs,"SKIPPED"))
for _, test in ipairs({
    { coords={X=-1,Y=-1}, reason="option=LobbyGeneratorX value=-1 type=number reason=unconfigured" },
    { coords={omitX=true}, reason="option=LobbyGeneratorX value=nil type=nil reason=missing" },
    { coords={X="14"}, reason="option=LobbyGeneratorX value=14 type=string reason=not_a_number" },
    { coords={X=1.5}, reason="reason=not_an_integer" },
    { coords={Y=1000001}, reason="option=LobbyGeneratorY value=1000001" },
    { coords={Z=32}, reason="option=LobbyGeneratorZ value=32 type=number reason=out_of_range" },
    { coords={Z=math.huge}, reason="reason=not_finite" },
}) do
    local calls, logs = run(true, true, true, false, test.coords)
    assert(#calls==0 and logged(logs,test.reason) and logged(logs,"CREATION_DENIED id=extraction-lobby"))
end
local calls, logs = run(true,true,"reject")
assert(#calls==1 and logged(logs,"reason=java_registration_rejected"))
local calls, logs = run(true,true,"error")
assert(#calls==1 and logged(logs,"reason=bridge_error detail=") and logged(logs,"world placement test failure"))
print("lobby power tests passed")

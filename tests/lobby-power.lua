local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path
local function run(enabled, lobby, bridge, bad)
    ApocExtractionMapUtils = nil
    package.loaded.ApocExtractionMapUtils = nil
    package.loaded.ApocExtractionMapUtils_LobbySettings = nil
    SandboxVars = { ApocExtractionMapUtils = { LobbyEnabled = lobby, LobbyFixedPower = enabled,
        LobbyX1 = bad and -1 or 14, LobbyY1 = 20, LobbyX2 = 7, LobbyY2 = 10 } }
    function isClient() return false end
    function isServer() return true end
    local calls, hook = {}, nil
    Events = { OnServerStarted = { Add = function(fn) hook = fn end } }
    ApocBRFixedPower = bridge and { setRegion = function(...) calls[#calls + 1] = {...}; return true end } or nil
    dofile(media .. "server/ApocExtractionMapUtils_LobbyPower.lua")
    hook(); hook()
    return calls
end
assert(#run(false, true, true) == 0)
assert(#run(true, false, true) == 0)
assert(#run(true, true, false) == 0)
assert(#run(true, true, true, true) == 0)
local calls = run(true, true, true)
assert(#calls == 1)
local a = calls[1]
assert(a[1] == "extraction-lobby" and a[2] == 14 and a[3] == 20 and a[4] == 7 and a[5] == 10 and a[6] == -32 and a[7] == 31)
print("lobby power tests passed")

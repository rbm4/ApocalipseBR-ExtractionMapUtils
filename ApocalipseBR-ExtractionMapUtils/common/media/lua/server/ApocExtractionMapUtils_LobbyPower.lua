if isClient() then return end
require "ApocExtractionMapUtils"
require "ApocExtractionMapUtils_LobbySettings"

local Utils = ApocExtractionMapUtils
if Utils.LobbyPower then return end
local Power = {}
Utils.LobbyPower = Power
local attempted = false

function Power.start()
    if attempted or not Utils.lobbyEnabled() or Utils.getOptions().LobbyFixedPower ~= true then return end
    attempted = true
    if not isServer() or not ApocBRFixedPower or not ApocBRFixedPower.setRegion then
        print("[ApocExtractionLobbyPower] FAILED: 42.22.2 server fixed-power bridge unavailable")
        return
    end
    local c = Utils.getLobbyConfig()
    for _, field in ipairs({ "X1", "Y1", "X2", "Y2" }) do
        local value = c[field]
        if type(value) ~= "number" or value ~= math.floor(value) or value < 0 or value > 1000000 then
            print("[ApocExtractionLobbyPower] FAILED: invalid lobby rectangle")
            return
        end
    end
    local ok, accepted = pcall(ApocBRFixedPower.setRegion, "extraction-lobby", c.X1, c.Y1, c.X2, c.Y2, -32, 31)
    if not ok or accepted ~= true then
        print("[ApocExtractionLobbyPower] FAILED: server rejected region: " .. tostring(accepted))
        return
    end
    print("[ApocExtractionLobbyPower] Registered lobby rectangle for server-side power on all floors")
end
Events.OnServerStarted.Add(Power.start)

if not isServer() then return end
require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
if Utils.LobbyPower then return end
local Power = {}
Utils.LobbyPower = Power
local attempted = false
local function valueLabel(value) return tostring(value):sub(1,128):gsub("%c", "_") end
local function invalidReason(value, low, high)
    if value == nil then return "missing" end
    if type(value) ~= "number" then return "not_a_number" end
    if value ~= value or value == math.huge or value == -math.huge then return "not_finite" end
    if value ~= math.floor(value) then return "not_an_integer" end
    if value == -1 and low == 0 then return "unconfigured" end
    if value < low or value > high then return "out_of_range" end
end
function Power.start()
    if attempted then return end
    attempted = true
    local options = Utils.getOptions()
    print("[ApocExtractionLobbyPower] START lobby_enabled=" .. tostring(Utils.lobbyEnabled())
        .. " generator_enabled=" .. tostring(options.LobbyFixedPower == true))
    if not Utils.lobbyEnabled() or options.LobbyFixedPower ~= true then
        print("[ApocExtractionLobbyPower] SKIPPED: sandbox setting disabled"); return
    end
    local x, y, z = options.LobbyGeneratorX, options.LobbyGeneratorY, options.LobbyGeneratorZ
    local valid = true
    for _, entry in ipairs({{"LobbyGeneratorX",x,0,1000000}, {"LobbyGeneratorY",y,0,1000000}, {"LobbyGeneratorZ",z,-32,31}}) do
        local reason = invalidReason(entry[2], entry[3], entry[4])
        if reason then
            valid = false
            print("[ApocExtractionLobbyPower] CONFIG_REJECTED option=" .. entry[1]
                .. " value=" .. valueLabel(entry[2]) .. " type=" .. type(entry[2]) .. " reason=" .. reason
                .. " expected=integer_in_" .. entry[3] .. ".." .. entry[4])
        end
    end
    if not valid then
        print("[ApocExtractionLobbyPower] CREATION_DENIED id=extraction-lobby tile=" .. valueLabel(x) .. "," .. valueLabel(y) .. "," .. valueLabel(z)
            .. " reason=invalid_sandbox_coordinates; configure X/Y/Z before enabling LobbyFixedPower")
        return
    end
    if not ApocBRManagedGenerators or not ApocBRManagedGenerators.registerGenerator then
        print("[ApocExtractionLobbyPower] FAILED: managed-generator bridge unavailable"); return
    end
    print("[ApocExtractionLobbyPower] REGISTER_BEGIN id=extraction-lobby tile=" .. x .. "," .. y .. "," .. z)
    local ok, accepted = pcall(ApocBRManagedGenerators.registerGenerator, "extraction-lobby", x, y, z)
    if not ok or accepted ~= true then
        print("[ApocExtractionLobbyPower] CREATION_DENIED id=extraction-lobby tile=" .. x .. "," .. y .. "," .. z
            .. " reason=" .. (ok and "java_registration_rejected; see [ApocBRManagedGenerators] reason" or ("bridge_error detail=" .. valueLabel(accepted))))
        return
    end
    print("[ApocExtractionLobbyPower] REGISTERED id=extraction-lobby mode=managed_native_generator; Java logs READY after instantiation")
end
Events.OnServerStarted.Add(Power.start)

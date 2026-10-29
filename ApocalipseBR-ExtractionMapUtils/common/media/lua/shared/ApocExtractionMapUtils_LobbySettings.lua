-- Shared fallback values and advanced performance/assets configuration.
-- Lobby bounds, door count and protection switches come from SandboxVars.
-- Restart server/clients after changes. Moving a saved layout requires removal
-- or migration of its old assets/state first; never accept bounds from commands.
ApocExtractionMapUtils = ApocExtractionMapUtils or {}
ApocExtractionMapUtils.LobbyConfig = {
    X1 = 14260, Y1 = 11892,
    X2 = 14321, Y2 = 11812,
    Z = 0,
    DoorCount = 3, -- usable doors; sandbox range 0..3
    DoorWest = "fixtures_doors_01_68", DoorNorth = "fixtures_doors_01_69",
    DoorOpenWest = "fixtures_doors_01_70", DoorOpenNorth = "fixtures_doors_01_71",
    ExitCount = 6, -- clamped to 0..6; selected once per layout/save
    MaxEdgesPerTick = 4,
    MaxTickMilliseconds = 2,
    RescanMilliseconds = 60000,
    ExitCheckMilliseconds = 2000,
    FenceWest = "fencing_01_90", -- barbed military fence: WallWTrans + CantClimb
    FenceNorth = "fencing_01_88", -- barbed military fence: WallNTrans + CantClimb
}

-- Resolve after sandbox loading; shared guards and the server plan use the same
-- options. Server bounds are never accepted from a client command.
function ApocExtractionMapUtils.getLobbyConfig()
    local config = {}
    for key, value in pairs(ApocExtractionMapUtils.LobbyConfig) do config[key] = value end
    local options = ApocExtractionMapUtils.getOptions()
    for field, option in pairs({ X1 = "LobbyX1", Y1 = "LobbyY1", X2 = "LobbyX2",
        Y2 = "LobbyY2", Z = "LobbyFenceZ", DoorCount = "LobbyDoorCount" }) do
        if options[option] ~= nil then config[field] = options[option] end
    end
    return config
end

function ApocExtractionMapUtils.lobbyRuleEnabled(option)
    return ApocExtractionMapUtils.lobbyEnabled() and ApocExtractionMapUtils.getOptions()[option] ~= false
end

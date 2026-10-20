-- Shared configuration for client previews and server-owned enforcement. Install
-- the same mod configuration on both sides and restart after changes. Bounds
-- never come from client commands. Changing bounds does not
-- remove an old perimeter; remove old assets deliberately before moving it.
ApocExtractionMapUtils = ApocExtractionMapUtils or {}
ApocExtractionMapUtils.LobbyConfig = {
    X1 = 14260, Y1 = 11892,
    X2 = 14321, Y2 = 11812,
    Z = 0,
    ExitCount = 6, -- clamped to 0..6; selected once per layout/save
    MaxEdgesPerTick = 4,
    MaxTickMilliseconds = 2,
    RescanMilliseconds = 60000,
    ExitCheckMilliseconds = 2000,
    FenceWest = "fencing_01_90", -- barbed military fence: WallWTrans + CantClimb
    FenceNorth = "fencing_01_88", -- barbed military fence: WallNTrans + CantClimb
}

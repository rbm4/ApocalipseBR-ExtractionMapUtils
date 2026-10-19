-- Server-owned configuration. Restart after changes. Changing bounds does not
-- remove an old perimeter; remove old assets deliberately before moving it.
ApocExtractionMapUtils = ApocExtractionMapUtils or {}
ApocExtractionMapUtils.LobbyConfig = {
    Enabled = true,
    X1 = 14260, Y1 = 11892,
    X2 = 14321, Y2 = 11812,
    Z = 0,
    DoorCount = 6, -- clamped to 0..6; selected once per layout/save
    MaxEdgesPerTick = 4,
    MaxTickMilliseconds = 2,
    RescanMilliseconds = 60000,
    DoorCheckMilliseconds = 2000,
    WallWest = "constructedobjects_01_48",
    WallNorth = "constructedobjects_01_49",
    DoorWest = "fixtures_doors_01_68",
    DoorNorth = "fixtures_doors_01_69",
    DoorOpenWest = "fixtures_doors_01_70",
    DoorOpenNorth = "fixtures_doors_01_71",
}

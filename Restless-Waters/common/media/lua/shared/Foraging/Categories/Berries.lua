require "Foraging/forageSystem"

local function generateCustomBerryDefs()
    -- Define all default berry types to remove
    local defaultBerries = {
        "Base.BerryGeneric1", "Base.BerryGeneric2", "Base.BerryGeneric3", "Base.BerryGeneric4", "Base.BerryGeneric5",
        "Base.BerryPoisonIvy", "Base.BerryBlack", "Base.BerryBlue",
        "Base.BeautyBerry", "Base.WinterBerry", "Base.HollyBerry"
    }
    
    -- Remove all default berries
    for _, berryType in ipairs(defaultBerries) do
        forageSystem.removeItemDef({ type = berryType })
    end
    
    -- Custom seasonal berries with Atlantic Canada realism (from previous refinements)
    local berryItems = {
        -- Early Summer (May-Aug peak for raspberries, juneberries, etc.)
        early_summer = {
            xp = 2.5,
            months = { 5, 6, 7, 8 },
            bonusMonths = { 6, 7 },
            malusMonths = { 5, 8 },
            items = {
                Juneberry = "Base.Juneberry",
                Raspberry = "Base.Raspberry",
                Gooseberry = "Base.Gooseberry",
                Redcurrant = "Base.Redcurrant",
            },
        },
        -- Peak Summer (Jun-Sep: blueberries, blackberries)
        summer = {
            xp = 2,
            months = { 6, 7, 8, 9 },
            bonusMonths = { 7, 8 },
            malusMonths = { 6, 9 },
            items = {
                Blueberry = "Base.Blueberry",
                Blackberry = "Base.Blackberry",
                Blackcurrant = "Base.Blackcurrant",
                Cloudberry = "Base.Cloudberry",
                Bunchberry = "Base.Bunchberry",
            },
        },
        -- Late Summer/Early Fall (Aug-Oct: cranberries, elderberry)
        late_summer_fall = {
            xp = 2.5,
            months = { 8, 9, 10 },
            bonusMonths = { 9 },
            malusMonths = { 8, 10 },
            items = {
                Elderberry = "Base.Elderberry",
                Chokecherry = "Base.Chokecherry",
                Sumac = "Base.Sumac",
                Cranberry = "Base.Cranberry",
            },
        },
        -- Fall/Winter Persistents (Sep-Feb: lingonberry, etc.)
        fall_winter = {
            xp = 3,
            months = { 9, 10, 11, 12, 1, 2 },
            bonusMonths = { 10, 11 },
            malusMonths = { 12, 1, 2 },
            items = {
                Cranberry = "Base.Cranberry",
                Lingonberry = "Base.Lingonberry",
                Crowberry = "Base.Crowberry",
                Bearberry = "Base.Bearberry",
                Hawberry = "Base.Hawberry",
            },
        },
    }
    
    -- Biome-specific zone chances (higher in forests/bogs, low in urban)
    local berryZones = {
        BirchForest    = 75,
        DeepForest     = 85,
        Vegitation     = 70,
        OrganicForest  = 90,  -- Bogs for cranberries/cloudberries
        PHForest       = 60,
        PRForest       = 55,
        Forest         = 80,
        FarmLand       = 6,
        Farm           = 4,
        ForagingNav    = 1,
        TrailerPark    = 2,
        TownZone       = 1,
    }
    
    -- Common properties for all custom berries
    local commonProps = {
        perks = { "PlantScavenging" },
        snowChance = -30,
        rainChance = 5,
        hasRainedChance = 25,
        maxCount = 8,
        minCount = 1,
        categories = { "Berries" },
        zones = berryZones,
        spawnFuncs = { forageSystem.doWildFoodSpawn },
        canBeAboveFloor = true,
        poisonDetectionLevel = 7,  -- Higher for realism (cook/test needed)
        itemSizeModifier = 0.4,
        isItemOverrideSize = true,
    }
    
    -- Add custom berries
    for _, seasonData in pairs(berryItems) do
        for itemName, itemFullName in pairs(seasonData.items) do
            local def = {
                type = itemFullName,
                skill = 2,
                xp = seasonData.xp,
                months = seasonData.months,
                bonusMonths = seasonData.bonusMonths,
                malusMonths = seasonData.malusMonths,
            }
            -- Merge common props
            for key, value in pairs(commonProps) do
                def[key] = value
            end
            forageSystem.addForageDef(itemName, def)
        end
    end
end

-- Hook into the preAddItemDefs event (runs before base defs, perfect for override)
Events["preAddItemDefs"].Add(generateCustomBerryDefs)
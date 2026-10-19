require "Foraging/forageSystem"

-- Single event handler to ensure proper execution order
Events["preAddItemDefs"].Add(function()
    local seaweedItems = {
        -- Spring Seaweed (March-May): Early season growth
        spring = {
            xp = 2,
            months = { 3, 4, 5 },
            bonusMonths = { 4, 5 },
            malusMonths = { 3 },
            items = {
                Dulse = "Base.Dulse",
                IrishMoss = "Base.IrishMoss",
                SeaLettuce = "Base.SeaLettuce",
            },
        },
        -- Summer Seaweed (June-August): Peak growth season
        summer = {
            xp = 2,
            months = { 6, 7, 8 },
            bonusMonths = { 7, 8 },
            malusMonths = { 6 },
            items = {
                Dulse = "Base.Dulse",
                Rockweed = "Base.Rockweed",
                SugarKelp = "Base.SugarKelp",
                SeaLettuce = "Base.SeaLettuce",
                Kombu = "Base.Kombu",
            },
        },
        -- Fall Seaweed (September-November): Late season harvest
        fall = {
            xp = 2.5,
            months = { 9, 10, 11 },
            bonusMonths = { 10 },
            malusMonths = { 9, 11 },
            items = {
                Dulse = "Base.Dulse",
                Rockweed = "Base.Rockweed",
                SugarKelp = "Base.SugarKelp",
                Bladderwrack = "Base.Bladderwrack",
                SeaGrapes = "Base.SeaGrapes",
            },
        },
    }

    -- Biome-specific zone chances for seaweed
    local seaweedZones = {
        clay_lake = 100,  -- Clay lakebed areas are ideal for seaweed
        DeepForest = 5,
        Vegitation = 10,
        OrganicForest = 15,  -- Bogs and wetlands
        BirchForest = 5,
        PHForest = 5,
        PRForest = 5,
        Forest = 10,
        FarmLand = 5,
        Farm = 5,
        ForagingNav = 5,
        TrailerPark = 5,
        TownZone = 2,
    }

    -- Common properties for all seaweed
    local commonProps = {
        perks = { "PlantScavenging" },
        snowChance = -50,
        rainChance = 10,
        hasRainedChance = 30,
        maxCount = 6,
        minCount = 1,
        categories = { "Seaweed", "WildPlants" },
        zones = seaweedZones,
        spawnFuncs = {
            forageSystem.doWildFoodSpawn,
            forageSystem.doRandomAgeSpawn,
        },
        canBeAboveFloor = true,
        poisonDetectionLevel = 2,
        itemSizeModifier = 0.5,
        isItemOverrideSize = true,
    }

    -- Add custom seaweed items
    for _, seasonData in pairs(seaweedItems) do
        for itemName, itemFullName in pairs(seasonData.items) do
            local def = {
                type = itemFullName,
                skill = 1,
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
end)

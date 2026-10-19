require "Foraging/forageSystem"

-- Single event handler to ensure proper execution order
Events["preAddItemDefs"].Add(function()
    local shellfishItems = {
        -- Spring Shellfish (March-May): Early season
        spring = {
            xp = 3,
            months = { 3, 4, 5 },
            bonusMonths = { 4, 5 },
            malusMonths = { 3 },
            items = {
                SoftShellClam = "Base.SoftShellClam",
                BlueMussel = "Base.BlueMussel",
                Periwinkle = "Base.Periwinkle",
            },
        },
        -- Summer Shellfish (June-August): Peak season
        summer = {
            xp = 3,
            months = { 6, 7, 8 },
            bonusMonths = { 7, 8 },
            malusMonths = { 6 },
            items = {
                SoftShellClam = "Base.SoftShellClam",
                Quahog = "Base.Quahog",
                BlueMussel = "Base.BlueMussel",
                Oyster = "Base.Oyster",
                Scallop = "Base.Scallop",
                Periwinkle = "Base.Periwinkle",
                GreenCrab = "Base.GreenCrab",
            },
        },
        -- Fall Shellfish (September-November): Late season
        fall = {
            xp = 3.5,
            months = { 9, 10, 11 },
            bonusMonths = { 10 },
            malusMonths = { 9, 11 },
            items = {
                Quahog = "Base.Quahog",
                Oyster = "Base.Oyster",
                Scallop = "Base.Scallop",
                Periwinkle = "Base.Periwinkle",
                SnowCrab = "Base.SnowCrab",
            },
        },
        -- Winter Shellfish (December-February): Hardy species
        winter = {
            xp = 4,
            months = { 12, 1, 2 },
            bonusMonths = { 1, 2 },
            malusMonths = { 12 },
            items = {
                Quahog = "Base.Quahog",
                Oyster = "Base.Oyster",
                Scallop = "Base.Scallop",
                Periwinkle = "Base.Periwinkle",
                SnowCrab = "Base.SnowCrab",
                GreenCrab = "Base.GreenCrab",
                AtlanticLobster = "Base.AtlanticLobster",
            },
        },
    }

    -- Biome-specific zone chances for shellfish
    local shellfishZones = {
        clay_lake = 100,  -- Clay lakebed areas are ideal for shellfish
        DeepForest = 2,
        Vegitation = 5,
        OrganicForest = 10,  -- Bogs and wetlands
        BirchForest = 2,
        PHForest = 2,
        PRForest = 2,
        Forest = 5,
        FarmLand = 3,
        Farm = 2,
        ForagingNav = 5,
        TrailerPark = 3,
        TownZone = 1,
    }

    -- Common properties for all shellfish
    local commonProps = {
        perks = { "PlantScavenging" },
        snowChance = -40,
        rainChance = 15,
        hasRainedChance = 50,
        maxCount = 4,
        minCount = 1,
        categories = { "Shellfish", "WildPlants" },
        zones = shellfishZones,
        spawnFuncs = {
            forageSystem.doWildFoodSpawn,
            forageSystem.doRandomAgeSpawn,
        },
        canBeAboveFloor = true,
        itemSizeModifier = 0.5,
        isItemOverrideSize = true,
    }

    -- Add custom shellfish items
    for _, seasonData in pairs(shellfishItems) do
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
end)

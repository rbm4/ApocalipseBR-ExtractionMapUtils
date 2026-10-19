require "Foraging/forageDefinitions";
require "Foraging/forageSystem";

-- Define biome distributions for rock collecting
RockCollecting = RockCollecting or {}
RockCollecting.BiomeRocks = {
    DeepForest = {
        -- Ancient metamorphic bedrock + glacial erratics
        { type = "Base.GneissPebble", weight = 15 },
        { type = "Base.SchistPebble", weight = 14 },
        { type = "Base.QuartzitePebble", weight = 14 },
        { type = "Base.AmphibolitePebble", weight = 13 },
        { type = "Base.GranofelsPebble", weight = 12 },
        { type = "Base.GranitePebble", weight = 13 },
        { type = "Base.MicaPebble", weight = 12 },
        { type = "Base.BiotitePebble", weight = 11 },
        { type = "Base.FeldsparPebble", weight = 11 },
        { type = "Base.HornblendePebble", weight = 10 },
        { type = "Base.GarnetPebble", weight = 6 },
        { type = "Base.PhyllitePebble", weight = 6 },
        { type = "Base.LabradoritePebble", weight = 2 },
    },

    Forest = {
        -- General mixed forest: sedimentary + metamorphic + stream deposits
        { type = "Base.SandstonePebble", weight = 15 },
        { type = "Base.SlatePebble", weight = 14 },
        { type = "Base.QuartzPebble", weight = 13 },
        { type = "Base.ChertPebble", weight = 12 },
        { type = "Base.LimestonePebble", weight = 11 },
        { type = "Base.SiltstonePebble", weight = 11 },
        { type = "Base.CalcitePebble", weight = 10 },
        { type = "Base.AgatePebble", weight = 10 },
        { type = "Base.JasperPebble", weight = 9 },
        { type = "Base.ChalcedonyPebble", weight = 9 },
        { type = "Base.PyritePebble", weight = 8 },
    },

    BirchForest = {
        -- Acidic soils, pegmatite influence
        { type = "Base.GranitePebble", weight = 15 },
        { type = "Base.MuscovitePebble", weight = 13 },
        { type = "Base.BiotitePebble", weight = 12 },
        { type = "Base.OrthoclasePebble", weight = 12 },
        { type = "Base.FeldsparPebble", weight = 11 },
        { type = "Base.TourmalinePebble", weight = 6 },
        { type = "Base.BerylPebble", weight = 5 },
        { type = "Base.TopazPebble", weight = 2 },
        { type = "Base.SpodumenePebble", weight = 4 },
        { type = "Base.LepidolitePebble", weight = 4 },
        { type = "Base.AmazonitePebble", weight = 5 },
        { type = "Base.QuartzitePebble", weight = 10 },
    },

    OrganicForest = {
        -- Fossil-rich sedimentary, lowland/organic soils
        { type = "Base.LimestonePebble", weight = 15 },
        { type = "Base.SiltstonePebble", weight = 13 },
        { type = "Base.CalcitePebble", weight = 12 },
        { type = "Base.GypsumPebble", weight = 11 },
        { type = "Base.AnhydritePebble", weight = 10 },
        { type = "Base.SandstonePebble", weight = 11 },
        { type = "Base.DesertRosePebble", weight = 6 },
        { type = "Base.SelenitePebble", weight = 5 },
        { type = "Base.AragonitePebble", weight = 4 },
        { type = "Base.BaritePebble", weight = 4 },
    },

    PHForest = {
        -- Pine/Hemlock: volcanic/intrusive + ores
        { type = "Base.BasaltPebble", weight = 15 },
        { type = "Base.DioritePebble", weight = 13 },
        { type = "Base.GabbroPebble", weight = 12 },
        { type = "Base.PyritePebble", weight = 12 },
        { type = "Base.ChalcopyritePebble", weight = 11 },
        { type = "Base.MagnetitePebble", weight = 10 },
        { type = "Base.HematitePebble", weight = 10 },
        { type = "Base.GoethitePebble", weight = 9 },
        { type = "Base.HornblendePebble", weight = 10 },
        { type = "Base.SideritePebble", weight = 9 },
        { type = "Base.ManganitePebble", weight = 7 },
        { type = "Base.ArsenopyritePebble", weight = 5 },
    },

    PRForest = {
        -- Inland pine/ridge variant: glacial till + decorative minerals
        { type = "Base.GranitePebble", weight = 14 },
        { type = "Base.QuartzPebble", weight = 13 },
        { type = "Base.DioritePebble", weight = 12 },
        { type = "Base.SandstonePebble", weight = 11 },
        { type = "Base.AgatePebble", weight = 11 },
        { type = "Base.ChalcedonyPebble", weight = 10 },
        { type = "Base.JasperPebble", weight = 9 },
        { type = "Base.CarnelianPebble", weight = 9 },
        { type = "Base.BloodstonePebble", weight = 2 },
        { type = "Base.SmokeyQuartzPebble", weight = 8 },
        { type = "Base.TigersIronPebble", weight = 4 },
        { type = "Base.RedTigersEyePebble", weight = 6 },
        { type = "Base.HawksEyePebble", weight = 5 },
    },

    FarmLand = {
        -- Agricultural fields: disturbed glacial till + field stones
        { type = "Base.LimestonePebble", weight = 6 },
        { type = "Base.SandstonePebble", weight = 6 },
        { type = "Base.GranitePebble", weight = 6 },
        { type = "Base.QuartzitePebble", weight = 5 },
        { type = "Base.SiltstonePebble", weight = 5 },
        { type = "Base.ChertPebble", weight = 5 },
        { type = "Base.CalcitePebble", weight = 4 },
        { type = "Base.ArrowheadPebble", weight = 2 },
    },

    Vegitation = {
        -- Transition/mixed vegetation zones
        { type = "Base.SandstonePebble", weight = 13 },
        { type = "Base.QuartzPebble", weight = 12 },
        { type = "Base.ShalePebble", weight = 11 },
        { type = "Base.ChertPebble", weight = 11 },
        { type = "Base.LimestonePebble", weight = 10 },
        { type = "Base.SiltstonePebble", weight = 9 },
        { type = "Base.AgatePebble", weight = 7 },
    },

    PHMixForest = {
        -- PHForest dominant + Forest/DeepForest influence
        { type = "Base.BasaltPebble", weight = 14 },
        { type = "Base.GranitePebble", weight = 12 },
        { type = "Base.DioritePebble", weight = 11 },
        { type = "Base.PyritePebble", weight = 10 },
        { type = "Base.QuartzPebble", weight = 10 },
        { type = "Base.GneissPebble", weight = 9 },
        { type = "Base.SchistPebble", weight = 7 },
    },

    BirchMixForest = {
        -- BirchForest dominant + Forest influence
        { type = "Base.GranitePebble", weight = 14 },
        { type = "Base.MuscovitePebble", weight = 12 },
        { type = "Base.BiotitePebble", weight = 11 },
        { type = "Base.QuartzPebble", weight = 11 },
        { type = "Base.SandstonePebble", weight = 10 },
        { type = "Base.TourmalinePebble", weight = 6 },
    },

    FarmMixForest = {
        -- Vegitation/Farm/Forest mix
        { type = "Base.SandstonePebble", weight = 13 },
        { type = "Base.LimestonePebble", weight = 12 },
        { type = "Base.GranitePebble", weight = 11 },
        { type = "Base.QuartzitePebble", weight = 10 },
        { type = "Base.ChertPebble", weight = 9 },
    },

    FarmForest = {
        -- DeepForest + Farm + Forest mix
        { type = "Base.GranitePebble", weight = 13 },
        { type = "Base.LimestonePebble", weight = 12 },
        { type = "Base.QuartzitePebble", weight = 11 },
        { type = "Base.SandstonePebble", weight = 11 },
        { type = "Base.GneissPebble", weight = 9 },
    },

    clay_lake = {
        -- Clay lakebed: water-worn pebbles from shore deposits
        { type = "Base.SeaGlass", weight = 30 },
        { type = "Base.SeaPottery", weight = 15 },
        { type = "Base.BrickPebble", weight = 20 },
        { type = "Base.SandstonePebble", weight = 15 },
        { type = "Base.SlatePebble", weight = 30 },
        { type = "Base.CalcitePebble", weight = 8 },
        { type = "Base.AragonitePebble", weight = 7 },
        { type = "Base.ChertPebble", weight = 6 },
        { type = "Base.AgatePebble", weight = 5 },
        { type = "Base.ChalcedonyPebble", weight = 5 },
        { type = "Base.JasperPebble", weight = 4 },
    },
}

local function generatePebbleDefs()
    -- Build inverse mapping: rock type -> { biome = weight }
    local rockBiomeMap = {}

    for biome, rocks in pairs(RockCollecting.BiomeRocks) do
        for _, rock in ipairs(rocks) do
            if not rockBiomeMap[rock.type] then
                rockBiomeMap[rock.type] = {}
            end
            rockBiomeMap[rock.type][biome] = rock.weight
        end
    end

    -- Generate forage definitions for each rock type
    for rockType, biomes in pairs(rockBiomeMap) do
        -- Extract item name from type (e.g., "Base.GranitePebble" -> "GranitePebble")
        local itemName = rockType:match("Base%.(.+)") or rockType

        forageSystem.addForageDef(
            itemName,
            {
                type = rockType,
                skill = 0,
                xp = 2,
                categories = { "Junk", "Trash" },
                zones = biomes,
                spawnFuncs = { forageSystem.doGenericItemSpawn },
                forceOutside = false,
                canBeAboveFloor = true,
                itemSizeModifier = 0.5,
                isItemOverrideSize = true,
            }
        )
    end
end

-- Hook into preAddItemDefs event (runs before base defs, perfect for override)
Events["preAddItemDefs"].Add(generatePebbleDefs)

require "Foraging/forageSystem"

-- Single event handler to ensure proper execution order
Events["preAddItemDefs"].Add(function()
    -- Remove default mushrooms FIRST
    local removedMushrooms = {
        "Base.Mushrooms",
        "Base.MushroomGeneric1",
        "Base.MushroomGeneric2",
        "Base.MushroomGeneric3",
        "Base.MushroomGeneric4",
        "Base.MushroomGeneric5",
        "Base.MushroomGeneric6",
        "Base.MushroomGeneric7",
    }
    
    for _, mushroomType in ipairs(removedMushrooms) do
        forageSystem.removeItemDef({ type = mushroomType })
    end
    
    local mushroomItems = {
        -- Spring Mushrooms (March-May): Early season specialists
        spring = {
            xp = 2,
            months = { 3, 4, 5 },
            bonusMonths = { 4, 5 },
            malusMonths = { 3 },
            items = {
                MorchellaElata = "Base.lp_MorchellaElata",           -- Morels (classic spring)
                PhaeotremellaFoliacea = "Base.lp_PhaeotremellaFoliacea", -- Jelly Fungus (early spring)
                TremellaMesenterica = "Base.lp_TremellaMesenterica",   -- Witch's Butter (spring)
                AuriculariaAuricula = "Base.lp_AuriculariaAuricula",   -- Wood Ear (spring-early summer)
                LycogalaEpidendrum = "Base.lp_LycogalaEpidendrum",   -- Wolf's Milk (spring)
                AgaricusArvensis = "Base.lp_AgaricusArvensis",       -- Horse Mushroom (late spring)
                AgaricusCampestris = "Base.lp_AgaricusCampestris",   -- Field Mushroom (late spring)
                BoletusEdulis = "Base.lp_BoletusEdulis",             -- Porcini (late spring-summer)
            },
        },
        -- Summer Mushrooms (June-August): Warm weather species
        summer = {
            xp = 2,
            months = { 6, 7, 8 },
            bonusMonths = { 7, 8 },
            malusMonths = { 6 },
            items = {
                CantharellusCibarius = "Base.lp_CantharellusCibarius",       -- Golden Chanterelle
                CantharellulaUmbonata = "Base.lp_CantharellulaUmbonata", -- Cantharellula
                LactariusDeliciosus = "Base.lp_LactariusDeliciosus",   -- Saffron Milk Cap
                LactariusTabidus = "Base.lp_LactariusTabidus",         -- Lactarius
                SuillusGrevillei = "Base.lp_SuillusGrevillei",         -- Slippery Jack
                LaccariaLaccata = "Base.lp_LaccariaLaccata",           -- Laccaria
                ChlorophyllumRhacodes = "Base.lp_ChlorophyllumRhacodes", -- Shaggy Parasol
                LaetiporusSulphureus = "Base.lp_LaetiporusSulphureus", -- Chicken of the Woods
                MacrolepiotaProcera = "Base.lp_MacrolepiotaProcera",     -- Parasol
                MarasmiusOreades = "Base.lp_MarasmiusOreades",         -- Fairy Ring
                GomphidiusGlutinosus = "Base.lp_GomphidiusGlutinosus",   -- Gomphidius
                GomphidiusSubroseus = "Base.lp_GomphidiusSubroseus",   -- Gomphidius
                CollybiaNuda = "Base.lp_CollybiaNuda",                 -- Collybia
                ConocybeTenera = "Base.lp_ConocybeTenera",             -- Conocybe
                CyptotramaChrysopepla = "Base.lp_CyptotramaChrysopepla", -- Cyptotrama
                GenusGliophorus = "Base.lp_GenusGliophorus",             -- Gliophorus
                LepiotaBrunneoincarnata = "Base.lp_LepiotaBrunneoincarnata", -- Lepiota
                LepiotaClypeolaria = "Base.lp_LepiotaClypeolaria",       -- Lepiota
            },
        },
        -- Fall Mushrooms (September-November): Peak season with highest diversity
        fall = {
            xp = 2,
            months = { 9, 10, 11 },
            bonusMonths = { 10, 11 },
            malusMonths = { 9 },
            items = {
                AmanitaMuscaria = "Base.lp_AmanitaMuscaria",           -- Fly Agaric
                AmanitaPhalloides = "Base.lp_AmanitaPhalloides",       -- Death Cap
                AmanitaVirosa = "Base.lp_AmanitaVirosa",             -- Destroying Angel
                AmanitaBisporigera = "Base.lp_AmanitaBisporigera",   -- Destroying Angel
                AmanitaBrunnescens = "Base.lp_AmanitaBrunnescens",     -- Amanita
                CortinariusEvernius = "Base.lp_CortinariusEvernius",     -- Cortinarius
                CortinariusMucosus = "Base.lp_CortinariusMucosus",       -- Cortinarius
                CraterellusCornucopioides = "Base.lp_CraterellusCornucopioides", -- Black Trumpet
                CrepidotusCesatii = "Base.lp_CrepidotusCesatii",         -- Crepidotus
                GalerinaMarginata = "Base.lp_GalerinaMarginata",         -- Deadly Galerina
                GrifolaFondosa = "Base.lp_GrifolaFondosa",           -- Maitake
                GuepiniaHelvelloides = "Base.lp_GuepiniaHelvelloides",   -- Guepinia
                HericiumAmericanum = "Base.lp_HericiumAmericanum",       -- Lion's Mane
                HericiumCoralloides = "Base.lp_HericiumCoralloides",     -- Coral Tooth
                HericiumErinaceus = "Base.lp_HericiumErinaceus",       -- Lion's Mane
                HydnumRepandum = "Base.lp_HydnumRepandum",             -- Hedgehog
                HypholomaFasciculare = "Base.lp_HypholomaFasciculare", -- Sulfur Tuft
                HypomycesLactifluorum = "Base.lp_HypomycesLactifluorum", -- Lobster Mushroom
                LacrymariaLacrymabunda = "Base.lp_LacrymariaLacrymabunda", -- Lacrymaria
                LycoperdonPerlatum = "Base.lp_LycoperdonPerlatum",     -- Puffball
                MycenaGalopus = "Base.lp_MycenaGalopus",               -- Mycena
                OmphalotusIlludens = "Base.lp_OmphalotusIlludens",     -- Jack-o'-Lantern
                PanellusStipticus = "Base.lp_PanellusStipticus",       -- Bitter Oyster
                PhaeolusSchweinitzii = "Base.lp_PhaeolusSchweinitzii", -- Phaeolus
                PleurotusLevis = "Base.lp_PleurotusLevis",             -- Oyster
                PsilocybeSemilanceata = "Base.lp_PsilocybeSemilanceata", -- Liberty Cap
                RussulaClaroflava = "Base.lp_RussulaClaroflava",       -- Russula
                RussulaEmetica = "Base.lp_RussulaEmetica",             -- Sickener
                RussulaLutea = "Base.lp_RussulaLutea",                 -- Russula
                RussulaXerampelina = "Base.lp_RussulaXerampelina",       -- Russula
                SarcodonImbricatus = "Base.lp_SarcodonImbricatus",       -- Scaly Hedgehog
                SclerodermaCitrinum = "Base.lp_SclerodermaCitrinum",     -- Earthball
                TricholomopsisDecora = "Base.lp_TricholomopsisDecora",   -- Tricholomopsis
                TubariaFurfuracea = "Base.lp_TubariaFurfuracea",       -- Tubaria
                CalvatiaGigantea = "Base.lp_CalvatiaGigantea",         -- Giant Puffball
                CoprinellusMicaceus = "Base.lp_CoprinellusMicaceus",   -- Mica Ink Cap
                CoprinopsisAtramentaria = "Base.lp_CoprinopsisAtramentaria", -- Common Ink Cap
                CoprinusComatus = "Base.lp_CoprinusComatus",           -- Shaggy Ink Cap
                FomesExcavatus = "Base.lp_FomesExcavatus",             -- Polypore
                FomitopsisBetulina = "Base.lp_FomitopsisBetulina",       -- Polypore
                FomitopsisMounceae = "Base.lp_FomitopsisMounceae",       -- Polypore
                GanodermaApplanatum = "Base.lp_GanodermaApplanatum",     -- Reishi
                GanodermaTsugae = "Base.lp_GanodermaTsugae",           -- Reishi
                InonotusObliquus = "Base.lp_InonotusObliquus",         -- Chaga
                IrpexLacteus = "Base.lp_IrpexLacteus",                 -- Irpex
                TrametesOchracea = "Base.lp_TrametesOchracea",           -- Ochre Bracket
                TrametesVersicolor = "Base.lp_TrametesVersicolor",       -- Turkey Tail
            },
        },
        -- Winter Mushrooms (December-February): Hardy species and year-round fungi
        winter = {
            xp = 2,
            months = { 12, 1, 2 },
            bonusMonths = { 1, 2 },
            malusMonths = { 12 },
            items = {
                AuriculariaAuricula = "Base.lp_AuriculariaAuricula",   -- Wood Ear (persists in winter)
                TremellaMesenterica = "Base.lp_TremellaMesenterica",   -- Witch's Butter (mild winter)
                GanodermaApplanatum = "Base.lp_GanodermaApplanatum", -- Reishi (year-round)
                GanodermaTsugae = "Base.lp_GanodermaTsugae",       -- Reishi (year-round)
                InonotusObliquus = "Base.lp_InonotusObliquus",     -- Chaga (year-round)
                TrametesOchracea = "Base.lp_TrametesOchracea",     -- Turkey Tail (year-round)
                TrametesVersicolor = "Base.lp_TrametesVersicolor",   -- Turkey Tail (year-round)
                IrpexLacteus = "Base.lp_IrpexLacteus",           -- Irpex (year-round)
            },
        },
    }
    
    -- Common zone definitions for all mushrooms
    local commonZones = {
        BirchForest   = 70,
        DeepForest    = 100,
        Vegitation    = 30,
        FarmLand      = 30,
        Forest        = 70,
        OrganicForest = 40,
        PHForest      = 50,
        PRForest      = 50,
        TrailerPark   = 5,
        TownZone      = 1,
        ForagingNav   = 1,
    }
    
    -- Common spawn properties
    local commonSpawnProps = {
        perks = { "PlantScavenging" },
        snowChance = -20,
        rainChance = 5,
        hasRainedChance = 80, 
        maxCount = 2,
        minCount = 1,
        categories = { "Mushrooms" },
        zones = commonZones,
        spawnFuncs = { forageSystem.doWildFoodSpawn },
        canBeAboveFloor = true,
        poisonDetectionLevel = 6, 
        itemSizeModifier = 0.5,
        isItemOverrideSize = true,
    }
    
    -- Add all seasonal mushrooms
    for seasonName, seasonData in pairs(mushroomItems) do
        for itemName, itemFullName in pairs(seasonData.items) do
            local itemDef = {
                type = itemFullName,
                skill = 2,
                xp = seasonData.xp,
                months = seasonData.months,
                bonusMonths = seasonData.bonusMonths,
                malusMonths = seasonData.malusMonths,
            }
            -- Merge common properties
            for key, value in pairs(commonSpawnProps) do
                itemDef[key] = value
            end
            forageSystem.addForageDef(itemName, itemDef)
        end
    end
end)

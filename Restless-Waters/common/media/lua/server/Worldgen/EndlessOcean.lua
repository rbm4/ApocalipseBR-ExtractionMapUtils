require("WorldGen/WorldGen")

worldgen.selection.hygrometry = {
    FLOODING = { -1.0, 1.0 }, 
    RAIN = {},                 
    DRY = {}                  
}

local ocean_feature = {
    base = "dirt_0", 
    main = {
        "blends_natural_02_0",
        "blends_natural_02_5",
        "blends_natural_02_6",
        "blends_natural_02_7"
    }
}

worldgen.roads = {}
worldgen.veins = {}
worldgen.attachments = {}

for biome_name, biome_data in pairs(worldgen.biomes) do
    
    if biome_name ~= "water" and biome_name ~= "deep_water" then
        
        biome_data.features = {
            GROUND = {
                { f = ocean_feature, p = 1.0 }
            }
        }

        biome_data.params = {
            hygrometry = { "FLOODING" },
            zombies = 0.0,
            generate = false
        }
        
    end
end

worldgen.priorities = {
    "Water",
    "Clay",
    "Sand",
    "Dirt"
}
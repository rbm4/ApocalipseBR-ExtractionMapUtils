-- clay_lake biome (RGB 79,79,79) - clay/muddy lakebed area

-- Add zone definition using preAddZoneDefs event to ensure proper timing
Events.preAddZoneDefs.Add(function()
    forageSystem.addZoneDef({
        name = "clay_lake",
        densityMin = 3,
        densityMax = 5,
        refillPercent = 3,
        abundanceSetting = "NatureAbundance",
    }, true) -- true to overwrite if exists
end)

-- Debug: Check if zone is registered after init
Events.OnGameBoot.Add(function()
    -- Wait a bit for foraging system to initialize
    local checkZone = function()
        if forageSystem.zoneDefs.clay_lake then
            print("[DEBUG] clay_lake zone IS registered in forageSystem.zoneDefs");
            print("[DEBUG] Zone name:", forageSystem.zoneDefs.clay_lake.name);
        else
            -- print("[DEBUG] clay_lake zone NOT registered in forageSystem.zoneDefs");
            -- print("[DEBUG] Available zones in forageSystem.zoneDefs:");
            for name, def in pairs(forageSystem.zoneDefs) do
                print("  - " .. name);
            end
        end
    end
    checkZone();
end);

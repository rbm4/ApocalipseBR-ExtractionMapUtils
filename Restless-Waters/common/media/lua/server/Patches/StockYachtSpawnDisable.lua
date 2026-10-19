-- Disable Aquatsar Yacht Club's stock boat spawn zones

local function disableTsarAquaZones()
    if loadTsarZone then
        loadTsarZone = function() end
        print("[StockYachtSpawnDisable] Stubbed loadTsarZone")
    end
    if globalTsarZones and globalTsarZones["aquazones"] then
        globalTsarZones["aquazones"] = nil
        print("[StockYachtSpawnDisable] Cleared residual aquazones table")
    end
end

Events.OnLoadMapZones.Add(disableTsarAquaZones)
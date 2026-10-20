local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local Regions = { name = "Regions" }

-- Read-only adapter to the Regions mod's existing registeredZones contract.
-- Do not call addHotRegion/updateHotRegion: those persist/administer real zones.
function Regions.resolve(region)
    if region.bounds then return { status = "inline_preview", bounds = region.bounds } end
    local server = RegionManager and RegionManager.Server
    if not server or not server.registeredZones then return { status = "provider_unavailable" } end
    local zone = server.registeredZones[region.regionId]
    if not zone then return { status = "missing_region" } end
    return { status = "resolved", bounds = zone.bounds,
        z = zone.region and zone.region.z, properties = zone.properties }
end

function Regions.prepare(record)
    local plans = {}
    for _, region in ipairs(record.definition.parameters.regions) do
        local plan = { id = region.id, regionId = region.regionId, binding = Regions.resolve(region),
            pvp = region.pvp, population = region.population, tags = region.tags, properties = region.properties }
        plans[#plans + 1] = plan
        Log.log(Regions.name, "Would bind region and apply event policies", plan)
    end
    Log.log(Regions.name, "Region preview complete; world/zone configuration unchanged", { count = #plans })
    return plans
end

return Regions

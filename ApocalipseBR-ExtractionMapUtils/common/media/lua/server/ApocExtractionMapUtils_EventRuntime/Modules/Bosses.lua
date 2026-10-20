local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local Bosses = { name = "Bosses" }

function Bosses.prepare(record)
    local plans = {}
    for _, entity in ipairs(record.definition.parameters.entities) do
        if entity.type == "boss" then
            plans[#plans + 1] = entity
            Log.log(Bosses.name, "Would select boss provider and spawn entity", entity)
        else
            Log.log(Bosses.name, "Entity left for a future non-boss provider", { id = entity.id, type = entity.type })
        end
    end
    Log.log(Bosses.name, "Boss preview complete; no entities spawned", { count = #plans })
    return plans
end

return Bosses

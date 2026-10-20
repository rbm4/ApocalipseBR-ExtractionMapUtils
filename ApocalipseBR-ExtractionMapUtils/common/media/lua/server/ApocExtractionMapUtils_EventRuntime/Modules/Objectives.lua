local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local Objectives = { name = "Objectives" }

function Objectives.prepare(record)
    local plans = record.definition.parameters.objectives
    for _, objective in ipairs(plans) do
        Log.log(Objectives.name, "Would select objective handler and initialize progress", objective)
    end
    Log.log(Objectives.name, "Objective preview complete; no counters/listeners/rewards installed", { count = #plans })
    return plans
end

return Objectives

local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local Gameplay = { name = "Gameplay" }

function Gameplay.prepare(record)
    local definition = record.definition
    local plan = { gameType = definition.gameType, ruleset = definition.ruleset,
        durationMinutes = definition.durationMinutes, properties = definition.parameters.properties }
    Log.log(Gameplay.name, "Would select gameplay handler; duration remains informational", plan)
    return plan
end

return Gameplay

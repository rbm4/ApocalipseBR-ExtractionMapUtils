local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local Notification = { name = "Notification" }

function Notification.prepare(record)
    local plan = { eventId = record.eventId, revision = record.revision, name = record.name }
    Log.log(Notification.name, "Event preparing (console notification only)", plan)
    return plan
end

function Notification.activate(plan)
    Log.log(Notification.name, "Event activating (objectives enabled; other world handlers remain previews)", plan)
end

return Notification

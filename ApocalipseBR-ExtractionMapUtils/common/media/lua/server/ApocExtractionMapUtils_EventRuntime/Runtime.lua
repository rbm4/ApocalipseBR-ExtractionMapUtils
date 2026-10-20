-- Server-only preview orchestrator. Real gameplay and durable round state come later.
if not isServer() then return end
require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
if Utils.EventRuntime then return Utils.EventRuntime end
local Schema = require "ApocExtractionMapUtils_EventSchema"
local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local modules = {
    require "ApocExtractionMapUtils_EventRuntime/Modules/Notification",
    require "ApocExtractionMapUtils_EventRuntime/Modules/Gameplay",
    require "ApocExtractionMapUtils_EventRuntime/Modules/Regions",
    require "ApocExtractionMapUtils_EventRuntime/Modules/Bosses",
    (require "ApocExtractionMapUtils_EventRuntime/Modules/Objectives")
}
local Runtime = { mode = "preview" }
Utils.EventRuntime = Runtime
local current, release, replay

local function matches(record, id, revision)
    return record and record.eventId == id and record.revision == revision
end

local function activate()
    if not current or current.status ~= "prepared" or not matches(release, current.eventId, current.revision) then return end
    current.status = "activating"
    for _, module in ipairs(modules) do
        if module.activate then
            local ok = pcall(module.activate, Schema.copy(current.plans[module.name]))
            if not ok then
                current.status = "failed"
                Log.log(module.name, "Activation preview failed; no automatic retry")
                return
            end
        end
    end
    current.status = "preview_active"
    Log.log("Runtime", "Release accepted; all preview modules prepared (not an implemented gameplay round)",
        { eventId = current.eventId, revision = current.revision })
end

function Runtime.acceptDefinition(record)
    if not isServer() then return false end
    if record.isReplay then
        if not matches(replay, record.eventId, record.revision) then
            replay = { eventId = record.eventId, revision = record.revision }
            Log.log("Runtime", "Receipt replay observed; no fresh module activation", replay)
        end
        return false
    end
    if current and record.revision <= current.revision then
        return matches(current, record.eventId, record.revision) and current.status ~= "failed"
    end
    current = { eventId = record.eventId, revision = record.revision, status = "preparing", mode = "preview", plans = {} }
    for _, module in ipairs(modules) do
        -- Module-local copies prevent a future provider mutating another provider's input.
        local ok, plan = pcall(module.prepare, Schema.copy(record))
        if not ok or type(plan) ~= "table" then
            current.status = "failed"
            Log.log(module.name, "Preparation preview failed; no automatic retry")
            return false
        end
        current.plans[module.name] = Schema.copy(plan)
    end
    current.status = "prepared"
    Log.log("Runtime", "Definition prepared; waiting for matching lobby release acknowledgement",
        { eventId = current.eventId, revision = current.revision })
    activate()
    return current.status ~= "failed"
end

-- Called only after Lobby.releaseForEvent receives a successful engine acknowledgement.
-- This latch supports either order of the engine's independent Lua subscribers.
function Runtime.confirmRelease(eventId, revision)
    local bridge = ApocBREventControl
    if not isServer() or not bridge or not bridge.isDue or not bridge.isDue(eventId, revision) then return false end
    if release and revision < release.revision then return false end
    release = { eventId = eventId, revision = revision }
    activate()
    return true
end

function Runtime.getSnapshot()
    if not isServer() then return nil end
    return current and Schema.copy(current) or nil
end

return Runtime

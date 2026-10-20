-- Validated data intake; hands accepted records to the preview runtime.
if not isServer() then return end
require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
if Utils.EventDefinitions then return end
local Schema = require "ApocExtractionMapUtils_EventSchema"
local Runtime = require "ApocExtractionMapUtils_EventRuntime/Runtime"
local Definitions = {}
Utils.EventDefinitions = Definitions
local subscribed, latest, lastAttempt

function Definitions.getLatest()
    return latest and Schema.copy(latest) or nil
end

function Definitions.onEventDue(eventId, revision, context)
    local bridge = ApocBREventControl
    if not isServer() or not bridge or not bridge.getEventContext or type(context) ~= "table" then return false end
    -- Receipt-only replays cannot reconstruct a definition. Preserve the last
    -- parsed record; consumers must never interpret this as a new activation.
    if context.isReplay and context.metadataJson == nil then return false end
    if type(eventId) ~= "string" or type(revision) ~= "number" then return false end
    local current = bridge.getEventContext(eventId, revision)
    if not current or current.metadataJson ~= context.metadataJson then return false end
    if context.isReplay then
        if not bridge.isReleaseAuthorized(eventId, revision) then return false end
    elseif not bridge.isDue(eventId, revision) then return false end
    -- The Java contract forbids same-revision changes. Bound cache and logs to
    -- the most recent attempt, including failures; no growing event history.
    if lastAttempt and lastAttempt.eventId == eventId and lastAttempt.revision == revision
        and lastAttempt.json == context.metadataJson and lastAttempt.isReplay == context.isReplay then return lastAttempt.ok end
    local record, err = Schema.parseContext(eventId, revision, context)
    lastAttempt = { eventId = eventId, revision = revision, json = context.metadataJson,
        isReplay = context.isReplay, ok = record ~= nil }
    if not record then
        ApocExtractionMapUtils.debugLog("[ApocExtractionEventDefinitions] Definition rejected: " .. err)
        return false
    end
    latest = record
    Runtime.acceptDefinition(Schema.copy(record))
    return true
end

function Definitions.onStarted()
    if subscribed or not ApocBREventControl or not Events.OnApocBRLobbyEventDue then return end
    Events.OnApocBRLobbyEventDue.Add(Definitions.onEventDue)
    subscribed = true
    -- Do not synthesize activation from cached desired state: the engine hook
    -- distinguishes fresh deadline dispatch from prior receipt restoration.
end

Events.OnServerStarted.Add(Definitions.onStarted)
return Definitions

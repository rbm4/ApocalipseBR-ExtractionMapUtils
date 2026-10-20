if not isServer() then return end
local S = require "ApocExtractionMapUtils_Objectives/Service"
local K = {}
local queue, head, tail = {}, 1, 0
local seen = setmetatable({}, { __mode = "k" })
function K.onCreate(zombie) seen[zombie] = nil end
function K.onDead(zombie)
    local eventId, revision = S.identity()
    if not eventId or not zombie or seen[zombie] then return end
    local player = zombie:getAttackedBy()
    if not player or not instanceof(player, "IsoPlayer") or not S.connected(player) or not S.eligible(player) then return end
    local subject = S.captureSubject(player)
    seen[zombie] = true
    if tail - head + 1 >= 2048 then
        S.metrics.droppedKills = S.metrics.droppedKills + 1
        ApocExtractionMapUtils.debugLog("[ApocExtractionObjectives] Kill queue capacity reached")
        return
    end
    tail = tail + 1
    queue[tail] = { eventId = eventId, revision = revision, subject = subject, x = math.floor(zombie:getX()),
        y = math.floor(zombie:getY()), z = math.floor(zombie:getZ()), at = 1 }
end
function K.onTick()
    local start = getTimestampMs()
    for _ = 1, 64 do
        if head > tail then queue, head, tail = {}, 1, 0; return end
        local job = queue[head]
        local eventId, revision = S.identity()
        local ids = S.killObjectives()
        local id = ids[job.at]
        if job.eventId ~= eventId or job.revision ~= revision or not id then
            queue[head], head = nil, head + 1
        else
            if S.matchesKill(id, job.x, job.y, job.z) then S.creditKill(eventId, revision, id, job.subject) end
            job.at = job.at + 1
        end
        if getTimestampMs() - start >= 2 then return end
    end
end
function K.pending() return tail - head + 1 end
return K

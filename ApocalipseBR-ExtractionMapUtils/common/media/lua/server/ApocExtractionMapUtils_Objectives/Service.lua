if not isServer() then return end
require "ApocExtractionMapUtils"
if ApocExtractionMapUtils.Objectives then return ApocExtractionMapUtils.Objectives end
local C = require "ApocExtractionMapUtils_Objectives/Contract"
local JSON = require "ApocExtractionMapUtils_JSON"
local S = { generation = 0, definitionEpoch = 0, supported = { kill_zombies = true }, metrics = { droppedKills = 0 } }
ApocExtractionMapUtils.Objectives = S
local active, index, counters, killIds = nil, {}, {}, {}

function S.playerKey(player)
    return player and player:getUsername() or nil
end
function S.teamKey(player)
    local faction = player and Faction and Faction.getPlayerFaction(player)
    return faction and faction:getName() or nil
end
function S.connected(player)
    return player and getPlayerByOnlineID(player:getOnlineID()) == player
end
local function eligibleKey(key, row)
    return active ~= nil and key ~= nil and (not active.recipients or active.recipients[key] == true)
        and (not row or not row.recipients or row.recipients[key] == true)
end
function S.eligible(player, row) return eligibleKey(S.playerKey(player), row) end
function S.audienceSignature(player)
    return (S.playerKey(player) or "") .. ":" .. (S.teamKey(player) or "") .. ":" .. tostring(S.eligible(player))
end
local function owner(row, user, team)
    if row.scope == "event" then return "event" end
    if row.scope == "team" then return team and "team:" .. team end
    return user and "player:" .. user
end
local function value(row, user, team)
    local key = owner(row, user, team)
    return key and counters[row.id] and counters[row.id][key] or 0
end
local function status(row, user, team)
    if not S.supported[row.type] then return "unsupported" end
    if row.regionMissing or not owner(row, user, team) then return "unavailable" end
    for _, id in ipairs(row.dependsOn) do
        local dependency = index[id]
        if not dependency or not eligibleKey(user, dependency) or not S.supported[dependency.type]
            or value(dependency, user, team) < dependency.target then return "locked" end
    end
    return value(row, user, team) >= row.target and "complete" or "active"
end

function S.attach(plan)
    assert(type(plan) == "table" and #plan.objectives <= C.MAX, "invalid objective plan")
    if active and plan.definitionRevision <= active.definitionRevision then
        return plan.eventId == active.eventId and plan.definitionRevision == active.definitionRevision
    end
    -- Preserve only exactly unchanged objective plans within the same event UUID.
    local previous, previousIndex, previousCounters = active, index, counters
    active, index, counters, killIds = JSON.copy(plan), {}, {}, {}
    for _, row in ipairs(active.objectives) do
        index[row.id] = row
        local old = previousIndex[row.id]
        if previous and previous.eventId == plan.eventId and old and C.equal(old, row) then counters[row.id] = previousCounters[row.id] end
        if row.type == "kill_zombies" then killIds[#killIds + 1] = row.id end
    end
    S.generation = S.generation + 1
    S.definitionEpoch = S.definitionEpoch + 1
    return true
end
function S.detach(eventId)
    if not active or active.eventId ~= eventId then return false end
    active, index, counters, killIds = nil, {}, {}, {}
    S.generation = S.generation + 1
    S.definitionEpoch = S.definitionEpoch + 1
    return true
end
function S.registerType(typeId)
    assert(type(typeId) == "string" and #typeId > 0 and #typeId <= 80)
    S.supported[typeId] = true
    S.generation = S.generation + 1
end
function S.getDefinition(eventId, objectiveId)
    return active and active.eventId == eventId and JSON.copy(index[objectiveId]) or nil
end
local function setValue(row, user, team, amount)
    if not row or not eligibleKey(user, row) or not C.integer(amount, 0, 1000000) then return false end
    local currentStatus = status(row, user, team)
    if currentStatus ~= "active" and currentStatus ~= "complete" then return false end
    local key, nextValue = owner(row, user, team), math.min(row.target, amount)
    counters[row.id] = counters[row.id] or {}
    if (counters[row.id][key] or 0) == nextValue then return false end
    counters[row.id][key] = nextValue
    S.generation = S.generation + 1
    return true
end
function S.setProgress(eventId, objectiveId, player, amount)
    if not isServer() or not active or active.eventId ~= eventId or not S.connected(player) then return false end
    return setValue(index[objectiveId], S.playerKey(player), S.teamKey(player), amount)
end
function S.increment(eventId, objectiveId, player, amount)
    local row = index[objectiveId]
    if not row or not C.integer(amount, 1, 1000000) then return false end
    return S.setProgress(eventId, objectiveId, player, value(row, S.playerKey(player), S.teamKey(player)) + amount)
end
-- Internal server death evidence: primitives only, no zombie/player references in the queue.
function S.captureSubject(player)
    if not S.connected(player) or not S.eligible(player) then return nil end
    return { user = S.playerKey(player), team = S.teamKey(player) }
end
function S.creditKill(eventId, revision, objectiveId, subject)
    if not isServer() or not active or active.eventId ~= eventId or active.definitionRevision ~= revision then return false end
    local row = index[objectiveId]
    if not row or row.type ~= "kill_zombies" then return false end
    return setValue(row, subject.user, subject.team, value(row, subject.user, subject.team) + 1)
end
function S.projection(player)
    local user, team = S.playerKey(player), S.teamKey(player)
    local signature = S.audienceSignature(player)
    local view = { eventId = "", definitionRevision = 0, title = "", titleKey = "", visibleRows = 6, rows = {} }
    if not S.eligible(player) then return view, signature end
    view.eventId, view.definitionRevision = active.eventId, active.definitionRevision
    view.title, view.titleKey, view.visibleRows = active.title, active.titleKey, active.visibleRows
    for _, row in ipairs(active.objectives) do
        if S.eligible(player, row) then
            view.rows[#view.rows + 1] = { id = row.id, title = row.title, titleKey = row.titleKey,
                type = row.type, scope = row.scope, required = row.required, target = row.target,
                count = value(row, user, team), status = status(row, user, team) }
        end
    end
    return view, signature
end
function S.identity()
    return active and active.eventId, active and active.definitionRevision
end
function S.killObjectives() return killIds end
function S.matchesKill(objectiveId, x, y, z)
    local row = index[objectiveId]
    if not row or row.regionMissing then return false end
    if #row.regions == 0 then return true end
    for _, b in ipairs(row.regions) do
        if x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY and z >= b.minZ and z <= b.maxZ then return true end
    end
    return false
end
return S

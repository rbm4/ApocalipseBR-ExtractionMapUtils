if not isServer() then return end
local C = require "ApocExtractionMapUtils_Objectives/Contract"
local S = require "ApocExtractionMapUtils_Objectives/Service"
local Sync = {}
local sessions, byId, cursor, serial = {}, {}, 0, 0
local function now() return getTimestampMs() end
local function emit(s, command, args)
    args.protocol, args.requestId, args.streamId = C.VERSION, s.requestId, s.streamId
    args.recipient = s.player:getOnlineID()
    sendServerCommand(s.player, C.MODULE, command, args)
end
local function snapshot(s, view, signature)
    serial = serial + 1
    s.streamId, s.version = serial, 0
    s.job = { view = view, signature = signature, generation = S.generation, part = -1 }
    s.changes = nil
    s.epoch, s.audience = S.definitionEpoch, signature
end
function Sync.onClientCommand(module, command, player, args)
    if module ~= C.MODULE or command ~= "RequestSnapshot" or not S.connected(player) or type(args) ~= "table"
        or args.protocol ~= C.VERSION or type(args.requestId) ~= "string" or #args.requestId < 1 or #args.requestId > 80 then return end
    local id, time = player:getOnlineID(), now()
    local s = byId[id]
    if s and s.player == player and time < s.nextRequest then return end
    if not s or s.player ~= player then
        if #sessions >= 1024 then return end
        s = { player = player, onlineId = id }
        sessions[#sessions + 1], byId[id] = s, s
    end
    s.requestId, s.nextRequest, s.nextScan = args.requestId, time + 1000, 0
    local view, signature = S.projection(player)
    snapshot(s, view, signature)
end
local function pump(s)
    if not s.job and not s.changes and s.epoch == S.definitionEpoch and now() < (s.nextScan or 0) then return end
    -- Recheck scope before every queued packet, including a partially sent snapshot.
    -- A player leaving a faction must not receive the previous faction's queued totals.
    local audience = S.audienceSignature(s.player)
    if s.epoch ~= S.definitionEpoch or s.audience ~= audience then
        local view, signature = S.projection(s.player)
        snapshot(s, view, signature)
    end
    if s.job then
        local j, v = s.job, s.job.view
        local parts = math.ceil(#v.rows / C.PAGE)
        if j.part == -1 then
            emit(s, "SnapshotBegin", { eventId = v.eventId, definitionRevision = v.definitionRevision,
                title = v.title, titleKey = v.titleKey, visibleRows = v.visibleRows,
                count = #v.rows, parts = parts, version = 0 })
            j.part = 0
        elseif j.part < parts then
            local rows = {}
            for i = j.part * C.PAGE + 1, math.min(#v.rows, (j.part + 1) * C.PAGE) do rows[#rows + 1] = v.rows[i] end
            emit(s, "SnapshotRows", { part = j.part + 1, rows = rows })
            j.part = j.part + 1
        else
            emit(s, "SnapshotCommit", { version = 0 })
            s.view, s.signature, s.generation = v, j.signature, j.generation
            s.job, s.nextScan, s.lastWatermark = nil, now() + 500, now()
        end
        return
    end
    if s.changes then
        local batch = {}
        for _ = 1, C.PAGE do
            local row = s.changes.rows[s.changes.at]
            if not row then break end
            batch[#batch + 1] = { id = row.id, count = row.count, status = row.status }
            s.changes.at = s.changes.at + 1
        end
        emit(s, "Progress", { eventId = s.view.eventId, definitionRevision = s.view.definitionRevision,
            fromVersion = s.version, toVersion = s.version + 1, rows = batch })
        s.version = s.version + 1
        s.lastWatermark = now()
        if s.changes.at > #s.changes.rows then s.changes = nil end
        return
    end
    if s.view and now() - (s.lastWatermark or 0) >= 10000 then
        emit(s, "Heartbeat", { eventId = s.view.eventId, definitionRevision = s.view.definitionRevision, version = s.version })
        s.lastWatermark = now()
        return
    end
    if now() < (s.nextScan or 0) then return end
    s.nextScan = now() + 500
    if s.generation == S.generation then return end
    local view, signature = S.projection(s.player)
    if not s.view or view.eventId ~= s.view.eventId or view.definitionRevision ~= s.view.definitionRevision
        or signature ~= s.signature or #view.rows ~= #s.view.rows then
        snapshot(s, view, signature)
        return
    end
    local changes = {}
    for i, row in ipairs(view.rows) do
        if row.id ~= s.view.rows[i].id then snapshot(s, view, signature); return end
        if not C.sameProgress(row, s.view.rows[i]) then changes[#changes + 1] = row end
    end
    s.view, s.generation = view, S.generation
    if #changes > 0 then s.changes = { rows = changes, at = 1 } end
end
function Sync.onTick()
    -- Four bounded recipient jobs/messages per tick, no broadcast and no world/player scans.
    for _ = 1, 4 do
        if #sessions == 0 then return end
        cursor = cursor % #sessions + 1
        local s = sessions[cursor]
        if not S.connected(s.player) then
            local id = s.onlineId
            if byId[id] == s then byId[id] = nil end
            table.remove(sessions, cursor)
            cursor = cursor - 1
        else pump(s) end
    end
end
return Sync

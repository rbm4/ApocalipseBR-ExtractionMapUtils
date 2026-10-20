-- Pure client replica. No gameplay progress calculation and no outgoing commands.
local C = require "ApocExtractionMapUtils_Objectives/Contract"
local Store = {}
function Store.new()
    return setmetatable({ ready = false, needsSnapshot = true, rows = {}, byId = {}, version = 0,
        streamId = 0, generation = 0, offset = 0, visibleRows = 6, toasts = {}, visible = {}, completed = 0 }, { __index = Store })
end
function Store:resync()
    self.needsSnapshot, self.incoming, self.nextRequestAt = true, nil, 0
end
function Store:cache()
    local limit = math.min(self.visibleRows, self.windowRows or C.VISIBLE)
    self.offset = math.max(0, math.min(self.offset, math.max(0, #self.rows - limit)))
    self.visible, self.completed, self.requiredCount = {}, 0, 0
    for _, row in ipairs(self.rows) do
        if row.required then
            self.requiredCount = self.requiredCount + 1
            if row.status == "complete" then self.completed = self.completed + 1 end
        end
    end
    for i = self.offset + 1, math.min(#self.rows, self.offset + limit) do self.visible[#self.visible + 1] = self.rows[i] end
    self.generation = self.generation + 1
end
function Store:scroll(delta)
    self.offset = self.offset + delta
    self:cache()
end
local function validHeader(a)
    return type(a.eventId) == "string" and #a.eventId <= 36 and C.integer(a.definitionRevision, 0, 9007199254740991)
        and type(a.title) == "string" and #a.title <= 192 and type(a.titleKey) == "string" and #a.titleKey <= 192
        and C.integer(a.visibleRows, 1, C.VISIBLE) and C.integer(a.count, 0, C.MAX)
        and a.parts == math.ceil(a.count / C.PAGE) and a.version == 0
        and (a.eventId == "" and a.definitionRevision == 0 and a.count == 0 or #a.eventId == 36 and a.definitionRevision >= 1)
end
function Store:install()
    local j = self.incoming
    if not j or not j.committed or j.received ~= j.header.parts then return end
    local rows, byId = {}, {}
    for part = 1, j.header.parts do
        for _, row in ipairs(j.parts[part]) do
            if byId[row.id] then self:resync(); return end
            rows[#rows + 1], byId[row.id] = row, row
        end
    end
    if #rows ~= j.header.count then self:resync(); return end
    local a = j.header
    self.eventId, self.definitionRevision, self.title, self.titleKey = a.eventId, a.definitionRevision, a.title, a.titleKey
    self.visibleRows, self.rows, self.byId = a.visibleRows, rows, byId
    self.streamId, self.version, self.incoming = a.streamId, 0, nil
    self.ready, self.needsSnapshot, self.backoff = true, false, 1000
    self.toasts = {} -- reconnect/resync is a baseline, never a replay of completion notifications
    self:cache()
end
function Store:receive(command, a, time)
    if type(a) ~= "table" or a.protocol ~= C.VERSION or a.requestId ~= self.requestId
        or not C.integer(a.streamId, 1, 9007199254740991) then return end
    if command == "SnapshotBegin" then
        if a.streamId <= self.streamId or self.incoming and a.streamId <= self.incoming.header.streamId then return end
        if not validHeader(a) then self:resync(); return end
        self.incoming = { header = C.copy(a), parts = {}, received = 0, deadline = time + 30000 }
        self.needsSnapshot, self.nextRequestAt = true, time + 30000
    elseif command == "SnapshotRows" or command == "SnapshotCommit" then
        local j = self.incoming
        if not j or j.header.streamId ~= a.streamId then return end
        if command == "SnapshotCommit" then
            if a.version ~= 0 then self:resync(); return end
            j.committed = true
        else
            if not C.integer(a.part, 1, j.header.parts) or type(a.rows) ~= "table" or #a.rows > C.PAGE then self:resync(); return end
            if j.parts[a.part] then
                if not C.equal(j.parts[a.part], a.rows) then self:resync() end
                return
            end
            local expected = math.min(C.PAGE, j.header.count - (a.part - 1) * C.PAGE)
            if #a.rows ~= expected then self:resync(); return end
            for _, row in ipairs(a.rows) do if not C.validRow(row) then self:resync(); return end end
            j.parts[a.part], j.received = C.copy(a.rows), j.received + 1
        end
        self:install()
    elseif command == "Heartbeat" then
        if not self.ready or self.needsSnapshot or a.streamId < self.streamId then return end
        if a.streamId ~= self.streamId or a.eventId ~= self.eventId or a.definitionRevision ~= self.definitionRevision
            or not C.integer(a.version, 0, 9007199254740991) or a.version > self.version then self:resync() end
    elseif command == "Progress" then
        if self.needsSnapshot or not self.ready or a.streamId < self.streamId then return end
        if a.streamId ~= self.streamId or a.eventId ~= self.eventId or a.definitionRevision ~= self.definitionRevision then self:resync(); return end
        if not C.integer(a.toVersion, 1, 9007199254740991) or not C.integer(a.fromVersion, 0, 9007199254740991) then self:resync(); return end
        if a.toVersion <= self.version then return end
        if a.fromVersion ~= self.version or a.toVersion ~= a.fromVersion + 1 or type(a.rows) ~= "table" or #a.rows > C.PAGE then self:resync(); return end
        local seen = {}
        for _, change in ipairs(a.rows) do
            if type(change) ~= "table" then self:resync(); return end
            local row = self.byId[change.id]
            if not row or seen[change.id] or not C.integer(change.count, 0, row.target) or not C.statuses[change.status]
                or change.status == "complete" and change.count ~= row.target then self:resync(); return end
            seen[change.id] = true
        end
        for _, change in ipairs(a.rows) do
            local row = self.byId[change.id]
            if change.status == "complete" and row.status ~= "complete" then
                self.toasts[#self.toasts + 1] = { id = row.id, title = row.title, titleKey = row.titleKey, born = time }
                if #self.toasts > 4 then table.remove(self.toasts, 1) end
            end
            row.count, row.status = change.count, change.status
        end
        self.version = a.toVersion
        self:cache()
    end
end
return Store

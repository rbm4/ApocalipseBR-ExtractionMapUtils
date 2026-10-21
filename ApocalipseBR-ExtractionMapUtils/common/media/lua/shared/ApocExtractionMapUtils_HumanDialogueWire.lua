-- Bounded roster frames on the existing HumanList command. No JSON parser or
-- executable data. Large graphs split into actor/node/choice records.
local W = { MAX_FRAME = 32000, MAX_TOTAL = 1048576, MAX_PARTS = 128 }
local function size(value, depth)
    depth = depth or 0
    assert(depth <= 12, "Dialogue payload nesting limit")
    if type(value) == "string" then return #value + 8 end
    if type(value) ~= "table" then return 16 end
    local bytes = 8
    for key, child in pairs(value) do bytes = bytes + size(key, depth + 1) + size(child, depth + 1) end
    return bytes
end
W.size = size
function W.pack(actors, revision)
    local total = size(actors)
    assert(total <= W.MAX_TOTAL, "Dialogue roster exceeds byte limit")
    if total < W.MAX_FRAME then return { { actors = actors, revision = revision, protocol = 2 } } end
    local records = {}
    for _, actor in ipairs(actors) do
        local header = {}
        for key, value in pairs(actor) do if key ~= "dialogue" and key ~= "options" then header[key] = value end end
        records[#records + 1] = { kind = "actor", actor = header }
        if actor.dialogue then
            local graph = actor.dialogue
            records[#records + 1] = { kind = "graph", actorId = actor.id, id = graph.id, revision = graph.revision,
                schema = graph.schema, entryNode = graph.entryNode, rootNode = graph.rootNode, fallbackLocale = graph.fallbackLocale, locale = graph.locale, labels = graph.labels }
            for id, node in pairs(graph.nodes) do
                records[#records + 1] = { kind = "node", actorId = actor.id, id = id, texts = node.texts, text = node.text }
                for _, option in ipairs(node.options) do
                    records[#records + 1] = { kind = "choice", actorId = actor.id, nodeId = id, option = option }
                end
            end
        else
            for _, option in ipairs(actor.options or {}) do
                records[#records + 1] = { kind = "choice", actorId = actor.id, option = option }
            end
        end
    end
    local frames, frame, bytes = {}, {}, 0
    for _, record in ipairs(records) do
        local count = size(record)
        assert(count < W.MAX_FRAME - 1024, "Dialogue record exceeds frame limit")
        if bytes + count > W.MAX_FRAME - 1024 then frames[#frames + 1] = frame; frame, bytes = {}, 0 end
        frame[#frame + 1], bytes = record, bytes + count
    end
    if #frame > 0 then frames[#frames + 1] = frame end
    assert(#frames <= W.MAX_PARTS, "Dialogue roster exceeds part limit")
    local result = {}
    for i, recordsPart in ipairs(frames) do
        result[i] = { protocol = 2, revision = revision, part = i, parts = #frames, records = recordsPart }
    end
    return result
end
function W.receive(pending, data)
    if not data.part then return nil, data.actors or {} end
    if type(data.part) ~= "number" or type(data.parts) ~= "number" or data.part % 1 ~= 0 or data.parts % 1 ~= 0
        or type(data.revision) ~= "number" or type(data.records) ~= "table"
        or data.parts < 1 or data.parts > W.MAX_PARTS or data.part < 1 or data.part > data.parts then return pending end
    if pending and pending.revision > data.revision then return pending end
    if not pending or pending.revision ~= data.revision then
        pending = { revision = data.revision, parts = data.parts, received = {}, count = 0, bytes = 0 }
    end
    if pending.parts ~= data.parts or pending.received[data.part] then return pending end
    local bytes = size(data.records)
    if bytes > W.MAX_FRAME or pending.bytes + bytes > W.MAX_TOTAL then return nil end
    pending.received[data.part], pending.count, pending.bytes = data.records, pending.count + 1, pending.bytes + bytes
    if pending.count ~= pending.parts then return pending end
    local actors, byId = {}, {}
    for i = 1, pending.parts do
        for _, record in ipairs(pending.received[i]) do
            if record.kind == "actor" then
                local actor = {}
                for key, value in pairs(record.actor) do actor[key] = value end
                actor.options = {}
                actors[#actors + 1], byId[actor.id] = actor, actor
            else
                local actor = byId[record.actorId]
                if not actor then return nil end
                if record.kind == "graph" then
                    actor.dialogue = { schema = record.schema, id = record.id, revision = record.revision,
                        entryNode = record.entryNode, rootNode = record.rootNode, fallbackLocale = record.fallbackLocale, locale = record.locale, labels = record.labels, nodes = {} }
                elseif record.kind == "node" then
                    actor.dialogue.nodes[record.id] = { id = record.id, texts = record.texts, text = record.text, options = {} }
                elseif record.kind == "choice" then
                    local options = record.nodeId and actor.dialogue.nodes[record.nodeId].options or actor.options
                    options[#options + 1] = record.option
                end
            end
        end
    end
    for _, actor in ipairs(actors) do
        if actor.dialogue then actor.options = actor.dialogue.nodes[actor.dialogue.entryNode].options end
    end
    return nil, actors
end
return W

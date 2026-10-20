package.path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/?.lua;ApocalipseBR-ExtractionMapUtils/common/media/lua/server/?.lua;" .. package.path
local JSON = require "ApocExtractionMapUtils_JSON"
local Schema = require "ApocExtractionMapUtils_EventSchema"
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local sample = dofile("tests/fixtures/event-definition-v1.lua")
local full, err = Schema.parse(sample)
check(full ~= nil, err)
check(#full.parameters.objectives == 5 and #full.parameters.entities == 3, "multi-system definition")
check(full.parameters.properties.friendlyFire == false, "preserve booleans")
check(full.parameters.objectives[1].required and not full.parameters.objectives[5].required, "required defaults preserve false")
check(full.parameters.regions[1].properties ~= nil and #full.parameters.objectives[1].dependsOn == 0, "normalized containers")
local base = '{"schemaVersion":1,"gameType":"extraction","ruleset":"default","durationMinutes":60,"parameters":PARAMS}'
local function envelope(params) return (base:gsub("PARAMS", function() return params end)) end
local function invalid(params, expected)
    local parsed, problem = Schema.parse(envelope(params))
    check(parsed == nil and problem and problem:find(expected, 1, true), tostring(problem) .. " expected " .. expected)
end
check(Schema.parse(envelope('{}')) ~= nil, "empty parameters remains compatible")
invalid('[]', 'expected_object')
invalid('{"schemaVersion":2}', 'unsupported_version')
invalid('{"objectves":[]}', 'unknown_field')
invalid('{"regions":{}}', 'expected_array')
invalid('{"properties":null}', 'expected_object')
invalid('{"regions":[{"id":"a"}]}', 'choose_one_source')
invalid('{"regions":[{"id":"a","regionId":"global","bounds":{"minX":0,"minY":0,"maxX":1,"maxY":1,"minZ":0,"maxZ":0}}]}', 'choose_one_source')
invalid('{"regions":[{"id":"a","regionId":"global","pvp":true}]}', 'expected_string')
invalid('{"regions":[{"id":"a","regionId":"global","pvp":"enable"}]}', 'invalid_choice')
invalid('{"regions":[{"id":"a","regionId":"global","tags":["x","x"]}]}', 'duplicate_reference')
invalid('{"regions":[{"id":"a","regionId":"global","population":{"minAlive":10,"maxAlive":2}}]}', 'inverted_population')
invalid('{"regions":[{"id":"a","regionId":"global","population":{"minAlive":1,"maxAlive":5,"refillCooldownSeconds":0}}]}', 'out_of_range')
invalid('{"regions":[{"id":"a","bounds":{"minX":2,"minY":0,"maxX":1,"maxY":1,"minZ":0,"maxZ":0}}]}', 'inverted_bounds')
invalid('{"regions":[{"id":"a","regionId":"global"},{"id":"a","regionId":"other"}]}', 'duplicate_id')
invalid('{"objectives":[{"id":"a","type":"kill_zombies","scope":"player","regionIds":["missing"]}]}', 'unknown_reference')
invalid('{"objectives":[{"id":"a","type":"kill_zombies","scope":"player","entityIds":["missing"]}]}', 'unknown_reference')
invalid('{"objectives":[{"id":"a","type":"rescue","scope":"player","dependsOn":["a"]}]}', 'dependency_cycle')
invalid('{"objectives":[{"id":"a","type":"rescue","scope":"player","dependsOn":["b"]},{"id":"b","type":"rescue","scope":"player","dependsOn":["a"]}]}', 'dependency_cycle')
invalid('{"objectives":[{"id":"a","type":"kill_zombies","scope":"player","target":1.5}]}', 'expected_integer')
invalid('{"objectives":[{"id":"a","type":"kill_zombies","scope":"player","target":0}]}', 'out_of_range')
invalid('{"entities":[{"id":"a","type":"boss","regionId":"missing"}]}', 'unknown_region')
invalid('{"regions":[{"id":"a","bounds":{"minX":0,"minY":0,"maxX":1,"maxY":1,"minZ":0,"maxZ":0}}],"entities":[{"id":"b","type":"boss","regionId":"a","position":{"x":1,"y":1,"z":1}}]}', 'outside_region')
check(Schema.parse(envelope('{"objectives":[{"id":"a","type":"custom.quest-v2","scope":"event","properties":{"newSetting":true}}]}')), "extensible type and properties")
invalid('{"objectives":[{"id":"bad/id","type":"boss","scope":"event"}]}', 'invalid_identifier')
local many = {}
for i = 1, 129 do many[i] = '{"id":"a' .. i .. '","type":"custom","scope":"event"}' end
invalid('{"objectives":[' .. table.concat(many, ',') .. ']}', 'too_many_items')
-- Long valid dependency chain exercises bounded graph traversal.
many = {}
for i = 1, 128 do
    many[i] = '{"id":"a' .. i .. '","type":"custom","scope":"event"' ..
        (i > 1 and ',"dependsOn":["a' .. (i - 1) .. '"]' or '') .. '}'
end
check(Schema.parse(envelope('{"objectives":[' .. table.concat(many, ',') .. ']}')), "128-objective DAG")
for _, text in ipairs({ '{} trailing', '{"x":1,}', '[1,]', '{"x":1,"x":2}', '{"x":null,"x":2}',
    '01', '+1', '.1', '1.', '1e', '1e999', '9007199254740992', 'NaN', '"\\q"', '"\\uD800"', '"\\uDC00"',
    '"line\nfeed"', '"unterminated', '{"x":true false}', string.rep('[', 25) .. '0' .. string.rep(']', 25),
    '"' .. string.char(192, 128) .. '"', '"' .. string.char(237, 160, 128) .. '"',
    '"' .. string.rep('x', 32768) .. '"', '[' .. string.rep('0,', 8192) .. '0]' }) do
    local decoded, problem = JSON.decode(text)
    check(decoded == nil and problem == "invalid_json", "reject malformed or unbounded JSON")
end
for _, text in ipairs({ 'false', 'true', 'null', '[]', '1', '"x"' }) do
    local parsed, problem = Schema.parse(text)
    check(parsed == nil and problem ~= nil, "non-object envelope has diagnostics")
end
local data = assert(JSON.decode('{"a":false,"b":[null,1],"text":"\\u00e1\\uD83D\\uDE00","v":-1.25e2}'))
check(data.a == false and data.b[1] == JSON.null and #data.b == 2 and data.v == -125, "lossless scalar/null handling")
check(data.text == string.char(195, 161, 240, 159, 152, 128), "Unicode surrogate pair")
check(JSON.kind(assert(JSON.decode('[]'))) == 'array' and JSON.kind(assert(JSON.decode('{}'))) == 'object', "empty container distinction")
local copied = JSON.copy(data)
copied.b[2] = 99
check(data.b[2] == 1 and copied.b[1] == JSON.null, "deep copy preserves null")
local id, revision = '12345678-1234-1234-1234-123456789abc', 9
local context = { eventId = id, revision = revision, isReplay = false, name = 'Operation', startsAtMillis = 1000, state = 'scheduled', metadataJson = sample }
local record = assert(Schema.parseContext(id, revision, context))
check(record.definition.gameType == 'extraction' and not record.isReplay, "context produces typed record")
check(Schema.parseContext(id, revision + 1, context) == nil, "mismatched revision")
check(Schema.parseContext('not-a-uuid', revision, context) == nil, "invalid identity")
check(Schema.parseContext(id, 0/0, context) == nil, "NaN revision")
local replay = { eventId = id, revision = revision, isReplay = true }
local missing, reason = Schema.parseContext(id, revision, replay)
check(missing == nil and reason == 'replay_without_definition', "receipt-only replay is explicit")
context.isReplay = true
check(assert(Schema.parseContext(id, revision, context)).isReplay, "matching replay remains marked")
context.isReplay = false

local server, started, dueHooks, logs = false, {}, {}, 0
function isServer() return server end
Events = { OnServerStarted = { Add = function(f) started[#started + 1] = f end } }
local serverFile = 'ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_EventDefinitions.lua'
dofile(serverFile)
check(#started == 0, "no server listener on client")
server = true
dofile(serverFile); dofile(serverFile)
check(#started == 1, "load guard")
local Definitions = ApocExtractionMapUtils.EventDefinitions
Definitions.onStarted()
check(Definitions.getLatest() == nil, "unpatched server remains supported")
local fresh, due, authorized = true, true, true
ApocBREventControl = {
    getEventContext = function(e, r) if fresh and e == id and r == revision then return { metadataJson = context.metadataJson } end end,
    isDue = function() return due end,
    isReleaseAuthorized = function() return authorized end
}
Events.OnApocBRLobbyEventDue = { Add = function(f) dueHooks[#dueHooks + 1] = f end }
Definitions.onStarted(); Definitions.onStarted()
check(#dueHooks == 1, "subscribe once")
fresh = false
check(not dueHooks[1](id, revision, context), "stale bridge")
fresh, due = true, false
check(not dueHooks[1](id, revision, context), "not due")
due = true
check(dueHooks[1](id, revision, context), "hook parses definition")
local latest = Definitions.getLatest()
latest.definition.parameters.regions[1].id = 'tampered'
check(Definitions.getLatest().definition.parameters.regions[1].id == 'docks', "getter isolation")
context.isReplay = true
check(dueHooks[1](id, revision, context) and Definitions.getLatest().isReplay, "same definition replay updates source flag")
context.isReplay = false
check(dueHooks[1](id, revision, context) and not Definitions.getLatest().isReplay, "fresh dispatch remains distinguishable")
check(not dueHooks[1](id, revision, replay), "receipt-only replay leaves prior record")
check(Definitions.getLatest().definition.gameType == 'extraction', "missing replay preserves record")
-- Malformed definitions never replace accepted data; repeated attempts do not
-- flood logs. Context text is never logged.
SandboxVars = { ApocExtractionMapUtils = { debugLog = true } }
local originalPrint = print
print = function(message) logs = logs + 1; assert(not message:find('SECRET', 1, true)) end
context.metadataJson = '{"SECRET":1}'
check(not dueHooks[1](id, revision, context), "invalid schema rejected")
check(not dueHooks[1](id, revision, context) and logs == 1, "bounded repeat diagnostics")
check(Definitions.getLatest().definition.gameType == 'extraction', "failed parse is atomic")
context.metadataJson, context.isReplay = sample, true
authorized = false
check(not dueHooks[1](id, revision, context), "unauthorized receipt")
authorized = true
check(dueHooks[1](id, revision, context) and Definitions.getLatest().isReplay, "replay data carries replay flag")
server = false
check(not dueHooks[1](id, revision, context), "client cannot consume server hook")
print = originalPrint
print('PASS: ' .. checks .. ' event JSON/schema/context/listener assertions')

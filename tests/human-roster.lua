-- Real server subscription/cache flow; only Java/network/event boundaries mocked.
package.path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/?.lua;" .. package.path
local checks, now, messages, scans = 0, 1000, {}, 0
local function check(v, message) checks = checks + 1; assert(v, message) end
local function event()
    local e = { callbacks = {} }
    function e.Add(fn) e.callbacks[#e.callbacks + 1] = fn end
    function e.fire(...) for _, fn in ipairs(e.callbacks) do fn(...) end end
    return e
end
Events = { OnClientCommand = event(), OnTick = event(), OnApocBRHumanRosterChanged = event(),
    OnApocBRHumanDialogueClosed = event() }
function isServer() return true end
function getTimestampMs() return now end
function getText(key) return key end
local function player(id) return { getOnlineID = function() return id end } end
local p, q = player(1), player(2)
local online = { [1] = p, [2] = q }
function getPlayerByOnlineID(id) return online[id] end
function sendServerCommand(target, module, command, data)
    check(module == "ApocExtractionMapUtils" and data.recipient == target:getOnlineID(), "target authenticated subscriber")
    messages[#messages + 1] = { player = target, command = command, data = data }
end
dofile("ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_HumanDialogsServer.lua")
local D = ApocExtractionMapUtils.HumanDialogs
local function request(target, command, args)
    Events.OnClientCommand.fire(D.MODULE, command or "HumanList", target, args)
end
request(p)
check(#messages == 0, "initial request retained while bridge is unavailable")
local actors = { { id = 1024, key = "guide", name = "Guide", x = 100, y = 200, z = 0 } }
ApocBRHumanAPI = {
    roster = function() scans = scans + 1; return actors end,
    list = function() return {} end,
    begin = function() error("out-of-range actor must not reserve") end,
}
Events.OnTick.fire()
check(#messages == 1 and messages[1].command == "HumanList", "bridge readiness pushes deferred roster")
check(#messages[1].data.actors == 1 and messages[1].data.actors[1].x == nil,
    "public snapshot includes stable identity and options, omits positions")
check(messages[1].data.actors[1].options[1].onSelect == nil, "callbacks never leave server")
request(q)
check(#messages == 2 and scans == 1 and messages[1].data.catalogRevision == messages[2].data.catalogRevision,
    "second subscriber reuses snapshot without rescanning actors")
local sentAt = #messages
for i = 1, 1000 do now = now + 1000; Events.OnTick.fire() end
check(#messages == sentAt and scans == 1, "steady-state ticks produce no scans or messages")
request(p, "HumanBegin", { id = 1024, request = 1, option = "hello" })
check(messages[#messages].command == "HumanRejected", "world roster does not bypass nearby start validation")
actors[#actors + 1] = { id = 1025, key = "unknown", name = "Unknown" }
Events.OnApocBRHumanRosterChanged.fire(); Events.OnApocBRHumanRosterChanged.fire()
sentAt = #messages
check(scans == 1, "lifecycle notifications only mark roster dirty")
Events.OnTick.fire()
check(scans == 2 and #messages == sentAt + 2, "multiple notifications coalesce into one scan and one push per subscriber")
check(#messages[#messages].data.actors == 1, "unregistered NPCs excluded")
D.register("unknown", { options = { { id = "hello", textKey = "hello", responseKey = "reply" } } })
Events.OnTick.fire()
check(scans == 3 and #messages[#messages].data.actors == 2, "dialogue registration updates already connected clients")
local oldSnapshot = messages[#messages].data
actors = {}
Events.OnApocBRHumanRosterChanged.fire(); Events.OnTick.fire()
check(#messages[#messages].data.actors == 0 and messages[#messages].data.revision > oldSnapshot.revision,
    "despawn broadcasts a newer empty replacement snapshot")
check(#oldSnapshot.actors == 2, "previous snapshot remains immutable")
online[2] = player(2)
sentAt = #messages
D.pushRoster(); Events.OnTick.fire()
check(#messages == sentAt + 1 and messages[#messages].player == p,
    "old subscriber cannot push to replacement player sharing an online ID")
now = now + 1000
request(online[2])
check(messages[#messages].player == online[2], "replacement subscribes independently")
online[1], online[2] = nil, nil
now = now + 10000; Events.OnTick.fire()
sentAt = #messages
D.pushRoster(); Events.OnTick.fire()
check(#messages == sentAt, "disconnected subscriptions cleaned up")
print("PASS: " .. checks .. " NPC roster bootstrap, cache, push, lifecycle and authority assertions")

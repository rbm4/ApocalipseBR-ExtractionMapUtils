-- Mock only engine boundaries; execute the real registry, server routing and client actions.
package.path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/?.lua;"
    .. "ApocalipseBR-ExtractionMapUtils/common/media/lua/client/?.lua;" .. package.path
local checks = 0
local originalPrint, logs = print, {}
print = function(message) logs[#logs + 1] = message end
local function logged(text)
    for _, line in ipairs(logs) do if line:find(text, 1, true) then return true end end
    return false
end
local function check(value, message) checks = checks + 1; assert(value, message) end
local function event()
    local e = { callbacks = {} }
    function e.Add(fn) e.callbacks[#e.callbacks + 1] = fn end
    function e.fire(...) for _, fn in ipairs(e.callbacks) do fn(...) end end
    return e
end
Events = { OnClientCommand = event(), OnTick = event(), OnServerCommand = event(),
    OnPreFillWorldObjectContextMenu = event(), OnApocBRHumanDialogueClosed = event() }
local server, now, sent, playerX = true, 10000, {}, 101
function isServer() return server end
function isClient() return not server end
function getTimestampMs() return now end
function getText(key, value) return key .. (value and (":" .. value) or "") end
local player = { getOnlineID = function() return 3 end, getPlayerNum = function() return 0 end,
    getX = function() return playerX end, getY = function() return 200 end, getZ = function() return 0 end,
    isDead = function() return false end, faceThisObject = function() end, Say = function() end }
function getPlayerByOnlineID(id) if id == 3 then return player end end
function sendServerCommand(p, module, command, data)
    check(p == player and module == "ApocExtractionMapUtils", "target the authenticated player's connection")
    sent[#sent + 1] = { command = command, data = data }
end
local serverFile = "ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_HumanDialogsServer.lua"
dofile(serverFile); dofile(serverFile)
check(#Events.OnClientCommand.callbacks == 1, "server hook installs once")
local D = ApocExtractionMapUtils.HumanDialogs
local commands, reacted, beginCalls = Events.OnClientCommand, {}, 0
local function command(name, data)
    -- GameClient.sendClientCommand omits nil/empty tables on the wire;
    -- GameServer.receiveClientCommand then passes nil to OnClientCommand.
    if type(data) == "table" and next(data) == nil then data = nil end
    commands.fire(D.MODULE, "Human" .. name, player, data)
end
command("List")
check(#sent > 0 and sent[#sent].command == "HumanRejected", "payload-free discovery reaches missing-patch rejection")
check(#logs == 0, "module load and missing bridge stay silent with debugLog absent")
SandboxVars = { ApocExtractionMapUtils = { debugLog = true } }
Events.OnTick.fire()
check(logged("bridge_status status=missing"), "debug identifies a missing server patch bridge")
local actor = { id = 1024, key = "guide", name = "NPC", x = 100, y = 200, z = 0 }
local allowArrival = false
ApocBRHumanAPI = {
    list = function() return { actor } end,
    begin = function() beginCalls = beginCalls + 1; return { id = 1024, key = "guide", name = "NPC", x = 100, y = 200, z = 0, token = 8 } end,
    arrive = function() return allowArrival end,
    react = function(p, id, token, text, emote) reacted[#reacted + 1] = { text = text, emote = emote }; return true end,
    finish = function() Events.OnApocBRHumanDialogueClosed.fire(player, { id = 1024, token = 8 }); return true end,
}
Events.OnTick.fire()
command("List")
check(sent[#sent].command == "HumanList" and #sent[#sent].data.actors[1].options == 3, "discover only registered NPC profiles")
check(logged("argsType=nil command=HumanList"), "native payload-free discovery reaches server receive logging")
local beforeInvalid = #sent
for _, badArgs in ipairs({ false, 12, "invalid" }) do command("List", badArgs) end
command("Begin")
command("Arrive")
command("Select")
command("Close")
check(#sent == beforeInvalid and beginCalls == 0 and logged("reason=invalid_args"),
    "only discovery accepts nil; invalid payload types and payload-free mutations stay rejected")
check(logged("bridge_status status=ready") and logged("discovered_actor") and logged("roster_ready"),
    "server discovery records bridge readiness and registered actors")
check(sent[#sent].data.recipient == 3 and sent[#sent].data.actors[1].options[1].onSelect == nil, "public metadata excludes callbacks")
local selected, opened, closed, callbacks = 0, 0, 0, 0
D.on("selected", function(p, data) selected = selected + 1 end)
D.on("opened", function() opened = opened + 1 end)
D.on("closed", function() closed = closed + 1 end)
D.on("selected", function() error("extension failure") end)
D.register("guide", { options = {
    { id = "hello", textKey = "hello-label", responseKey = "hello-response", emote = "wavehi",
        onSelect = function() callbacks = callbacks + 1 end },
    { id = "help", textKey = "help-label", responseKey = "help-response" },
} })
check(not pcall(D.register, "bad", { options = {} }), "empty profiles rejected")
check(not pcall(D.register, "bad", { options = {
    { id = "same", textKey = "x", responseKey = "x" }, { id = "same", textKey = "x", responseKey = "x" } } }), "duplicate option IDs rejected")
command("Begin", { id = 1024, request = 1, option = "injected" })
check(beginCalls == 0, "unknown options never reserve an actor")
now = now + 300
command("Begin", { id = 1024, request = 2, option = "hello", x = 99999 })
check(beginCalls == 1 and sent[#sent].command == "HumanReserved" and #reacted == 0, "selection reserves before any reaction")
command("Select", { id = 1024, token = 8, option = "hello", sequence = 1 })
check(#reacted == 0, "cannot bypass approach with Select")
command("Arrive", { id = 1024, token = 9 })
check(#reacted == 0 and opened == 0, "wrong lease token rejected")
allowArrival = true
command("Arrive", { id = 1024, token = 8 })
check(opened == 1 and #reacted == 1 and reacted[1].text == "hello-response"
    and reacted[1].emote == "wavehi" and callbacks == 1 and selected == 1, "arrival executes the registered reaction and extension once")
command("Arrive", { id = 1024, token = 8 })
command("Select", { id = 1024, token = 8, option = "hello", sequence = 1 })
check(#reacted == 1, "arrival and selection replays cannot repeat reactions")
now = now + 600
command("Select", { id = 1024, token = 8, option = "help", sequence = 2, responseKey = "injected" })
check(#reacted == 2 and reacted[2].text == "help-response" and not reacted[2].emote, "different choices use only server-registered reactions")
command("Close", { id = 1024, token = 8 })
check(closed == 1 and sent[#sent].command == "HumanClosed", "engine closure releases Lua session and notifies client")
command("Select", { id = 1024, token = 8, option = "hello", sequence = 3 })
check(#reacted == 2, "closed sessions cannot execute choices")

now = now + 1000
command("Begin", { id = 1024, request = 3, option = "hello" })
local savedLookup = getPlayerByOnlineID
function getPlayerByOnlineID() return nil end
now = now + 10000
Events.OnTick.fire()
ApocBRHumanAPI.finish(player, 1024, 8)
check(closed == 2, "disconnect throttle cleanup preserves the engine's final close hook")
getPlayerByOnlineID = savedLookup

-- Client boundaries and vanilla timed-action queue are mocked below.
server, sent = false, {}
local function derive(base, name)
    local class = { Type = name }; class.__index = class; setmetatable(class, { __index = base })
    function class:derive(child) return derive(self, child) end
    return class
end
ISBaseTimedAction = derive({}, "ISBaseTimedAction")
function ISBaseTimedAction.new(class, p) return setmetatable({ character = p }, class) end
function ISBaseTimedAction:stop() self.stopped = true end
function ISBaseTimedAction:perform() self.completed = true end
ISPathFindAction = ISBaseTimedAction:derive("ISPathFindAction")
function ISPathFindAction:pathToNearest(p, locations)
    local o = ISBaseTimedAction.new(self, p); o.locations = locations; return o
end
local queue = {}
ISTimedActionQueue = { add = function(action) queue[#queue + 1] = action end }
ApocHumanDialogPanel = {}
function ApocHumanDialogPanel:new(p, name, options, greeting, select, close)
    local panel = { name = name, options = options, select = select, close = close }
    function panel:initialise() end
    function panel:addToUIManager() self.visible = true end
    function panel:removeFromUIManager() self.visible = false end
    function panel:setMessage(key) self.message = key end
    function panel:setPending(value) self.pending = value end
    return panel
end
for _, module in ipairs({ "ApocExtractionMapUtils_HumanDialogPanel", "Vehicles/TimedActions/ISPathFindAction",
    "TimedActions/ISTimedActionQueue" }) do package.loaded[module] = true end
local npc = { getOnlineID = function() return 1024 end, getX = function() return 100 end,
    getY = function() return 200 end, getZ = function() return 0 end, class = "IsoPlayer" }
function getPlayerByOnlineID(id) if id == 1024 then return npc elseif id == 3 then return player end end
function getNumActivePlayers() return 1 end
function getSpecificPlayer(index) if index == 0 then return player end end
function instanceof(object, class) return object.class == class end
function getCell() return { getGridSquare = function() return {} end } end
function sendClientCommand(p, module, name, args) sent[#sent + 1] = { command = name, data = args } end
ISWorldObjectContextMenu = { fetchVars = {}, setTest = function() return true end }
local context = { options = {} }
function context:addOption(label, target, callback, ...) local o = { label = label, target = target, callback = callback, args = { ... } }; self.options[#self.options + 1] = o; return o end
function context:addSubMenu(option, submenu) option.submenu = submenu end
ISContextMenu = { getNew = function() return setmetatable({ options = {} }, { __index = context }) end }
local clientFile = "ApocalipseBR-ExtractionMapUtils/common/media/lua/client/ApocExtractionMapUtils_HumanDialogsClient.lua"
dofile(clientFile); dofile(clientFile)
check(#Events.OnServerCommand.callbacks == 1, "client hooks install once")
local C = D.client
check(logged("[client] loaded"), "client Lua reports loading when debug is enabled")
Events.OnTick.fire()
check(sent[#sent].command == "HumanList" and logged("[client] send command=HumanList"), "roster poll is logged")
now = now + 5000
Events.OnTick.fire()
check(logged("list_waiting"), "missing roster replies have an elapsed-wait diagnostic")
Events.OnPreFillWorldObjectContextMenu.fire(0, context, {}, false)
check(logged("reason=no_clicked_player"), "empty character picking is diagnosed")
Events.OnPreFillWorldObjectContextMenu.fire(0, context, { npc }, false)
check(logged("reason=target_not_in_roster"), "NPC picked before discovery is diagnosed")
local function reply(name, args) args.recipient = args.recipient or 3; Events.OnServerCommand.fire(D.MODULE, "Human" .. name, args) end
actor.options = { { id = "hello", textKey = "hello-label" }, { id = "help", textKey = "help-label" } }
reply("List", { actors = { actor }, recipient = 99 })
check(C.roster[0] == nil, "ignore another split-screen recipient")
reply("List", { actors = { actor } })
check(C.listPendingAt[0] == nil and logged("roster_actor") and logged("roster_updated"), "matching roster response clears pending poll")
local beforeProbe = #logs
Events.OnPreFillWorldObjectContextMenu.fire(0, context, { npc }, true)
check(#logs == beforeProbe, "menu test probes do not spam debug output")
check(#context.options == 0 and not C.states[0], "test menu probe has no commands or reservations")
Events.OnPreFillWorldObjectContextMenu.fire(0, context, { npc }, false)
check(#context.options == 1 and #context.options[1].submenu.options == 2, "specific registered NPC exposes its choices")
check(logged("menu_target") and logged("source=worldobjects") and logged("menu_added"), "character hit and menu creation are logged")
context.options = {}
ISWorldObjectContextMenu.fetchVars.clickedPlayer = npc
Events.OnPreFillWorldObjectContextMenu.fire(0, context, {}, false)
check(#context.options == 1 and logged("source=fetch.clickedPlayer"), "native fetch fallback is logged")
ISWorldObjectContextMenu.fetchVars.clickedPlayer = nil
context.options = {}
Events.OnPreFillWorldObjectContextMenu.fire(0, context, { { class = "IsoPlayer", getOnlineID = function() return 9 end } }, false)
check(#context.options == 0, "ordinary players do not get NPC menus")
C.begin(player, actor, actor.options[1]); local state = C.states[0]
check(sent[#sent].command == "HumanBegin" and #queue == 0, "wait for server reservation before walking")
reply("Reserved", { id = 1024, request = state.request + 1, token = 7, x = 100, y = 200, z = 0 })
check(#queue == 0, "ignore stale reservation responses")
reply("Reserved", { id = 1024, request = state.request, token = 8, x = 100, y = 200, z = 0 })
check(#queue == 2 and queue[1].locations and queue[2].dialogue == state, "queue native pathfinding followed by talk timed action")
queue[2]:perform()
check(sent[#sent].command == "HumanArrive", "timed action asks server to validate arrival")
reply("Opened", { id = 1024, token = 8, options = actor.options, greetingKey = "greeting" })
reply("Selected", { id = 1024, token = 8, sequence = 1, responseKey = "hello-response" })
check(state.panel.visible and state.panel.message == "hello-response", "show response and follow-up dialogue options")
now = now + 700
state.panel.select("help")
check(sent[#sent].command == "HumanSelect" and sent[#sent].data.sequence == 2, "follow-up click sends option ID and next sequence")
local count = #sent
state.panel.select("help")
check(#sent == count, "pending choice cannot be submitted twice")
C.close(player)
check(not state.panel.visible and not C.states[0] and sent[#sent].command == "HumanClose", "closing panel releases actor")
C.begin(player, actor, actor.options[1]); state = C.states[0]
reply("Reserved", { id = 1024, request = state.request, token = 10, x = 100, y = 200, z = 0 })
queue[#queue - 1]:stop()
check(not C.states[0] and sent[#sent].command == "HumanClose", "path failure/manual cancellation releases NPC")
C.begin(player, actor, actor.options[1]); state = C.states[0]
reply("Reserved", { id = 1024, request = state.request, token = 11, x = 100, y = 200, z = 0 })
local queued = #queue
reply("Reserved", { id = 1024, request = state.request, token = 11, x = 100, y = 200, z = 0 })
check(#queue == queued, "duplicate reservation does not queue movement twice")
queue[#queue]:forceCancel()
check(not C.states[0] and sent[#sent].command == "HumanClose", "clearing a queued action releases the reservation")
check(loadfile("ApocalipseBR-ExtractionMapUtils/common/media/lua/client/ApocExtractionMapUtils_HumanDialogPanel.lua") ~= nil,
    "dialogue panel parses as Lua")
check(logged("reserved") and logged("arrival_validated") and logged("selected") and logged("closed")
    and logged("walk") and logged("panel_opened") and logged("reply_ignored"), "dialogue lifecycle and ignored replies are diagnosed")
SandboxVars.ApocExtractionMapUtils.debugLog = false
local disabledAt = #logs
D.emit("selected", player, {})
Events.OnPreFillWorldObjectContextMenu.fire(0, context, { npc }, false)
now = now + 5000
Events.OnTick.fire()
check(#logs == disabledAt, "disabling debugLog suppresses callback failures, menu and periodic diagnostics")
print = originalPrint
print("Passed " .. checks .. " NPC dialogue registration, server routing and client flow assertions.")

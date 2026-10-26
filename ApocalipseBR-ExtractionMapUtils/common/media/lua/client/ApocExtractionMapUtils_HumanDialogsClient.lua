if not isClient() then return end
require "ApocExtractionMapUtils_HumanDialogs"
require "ApocExtractionMapUtils_HumanDialogPanel"
require "Vehicles/TimedActions/ISPathFindAction"
require "TimedActions/ISTimedActionQueue"
local D = ApocExtractionMapUtils.HumanDialogs
local G = require "ApocExtractionMapUtils_HumanDialogueGraph"
local W = require "ApocExtractionMapUtils_HumanDialogueWire"
if D.clientLoaded then return end
D.clientLoaded = true
local C = { states = {}, roster = {}, byKey = {}, sequence = 0, requestedFor = {}, requestedID = {},
    revisions = {}, listPendingAt = {}, listWarned = {}, incomingRoster = {},
    repairCounts = {}, nextRepairAt = {}, incomingAt = {} }
D.client = C
D.log("client", "loaded")
local function send(player, command, data)
    D.log("client", "send", { command = "Human" .. command, player = player:getOnlineID(),
        id = data.id, option = data.option, request = data.request, sequence = data.sequence })
    sendClientCommand(player, D.MODULE, "Human" .. command, data)
end
local function notify(player, key)
    player:Say(getText(key or "IGUI_ApocExtractionMapUtils_DialogUnavailable"))
end
local function sameBinding(a, b)
    return a and b and a.id == b.id and (not a.key or not b.key or a.key == b.key)
        and (not a.incarnation or not b.incarnation or a.incarnation == b.incarnation)
end
-- Bounded recovery for startup, incomplete frames and stale native references.
-- Successful idle subscriptions never poll or resend the roster.
function C.resync(player, reason)
    local index, now = player:getPlayerNum(), getTimestampMs()
    if player:isDead() or player:getOnlineID() < 0 or now < (C.nextRepairAt[index] or 0)
        or (C.repairCounts[index] or 0) >= 3 then return false end
    C.repairCounts[index] = (C.repairCounts[index] or 0) + 1
    C.nextRepairAt[index], C.listPendingAt[index], C.listWarned[index] = now + 2000, now, nil
    D.log("client", "roster_resync", { reason = reason, attempt = C.repairCounts[index] })
    send(player, "List", { protocol = 2 })
    return true
end
function C.close(player)
    local index = player:getPlayerNum()
    local state = C.states[index]
    if not state then return end
    D.log("client", "close", { player = player:getOnlineID(), id = state.id, opened = state.opened == true })
    C.states[index] = nil
    if state.panel then state.panel:removeFromUIManager() end
    if state.token then send(player, "Close", { id = state.id, token = state.token }) end
end
local function valid(player, state)
    return C.states[player:getPlayerNum()] == state and not player:isDead()
        and sameBinding(state, (C.roster[player:getPlayerNum()] or {})[state.id])
        and getPlayerByOnlineID(state.id) ~= nil
end

-- Inherit vanilla path cancellation/door handling; release the NPC on interruption.
ApocHumanWalkAction = ISPathFindAction:derive("ApocHumanWalkAction")
function ApocHumanWalkAction:stop()
    ISPathFindAction.stop(self)
    if C.states[self.character:getPlayerNum()] == self.dialogue then C.close(self.character) end
end
function ApocHumanWalkAction:forceCancel()
    if C.states[self.character:getPlayerNum()] == self.dialogue then C.close(self.character) end
end
function ApocHumanWalkAction:isValid()
    return valid(self.character, self.dialogue)
end

ApocHumanTalkAction = ISBaseTimedAction:derive("ApocHumanTalkAction")
function ApocHumanTalkAction:isValid()
    if not valid(self.character, self.dialogue) then return false end
    local npc = getPlayerByOnlineID(self.dialogue.id)
    local dx, dy = self.character:getX() - npc:getX(), self.character:getY() - npc:getY()
    return self.character:getZ() == npc:getZ() and dx * dx + dy * dy <= 6.25
end
function ApocHumanTalkAction:waitToStart() return false end
function ApocHumanTalkAction:start()
    local npc = getPlayerByOnlineID(self.dialogue.id)
    if npc then self.character:faceThisObject(npc) end
end
function ApocHumanTalkAction:update() end
function ApocHumanTalkAction:stop()
    ISBaseTimedAction.stop(self)
    if C.states[self.character:getPlayerNum()] == self.dialogue then C.close(self.character) end
end
function ApocHumanTalkAction:forceCancel()
    if C.states[self.character:getPlayerNum()] == self.dialogue then C.close(self.character) end
end
function ApocHumanTalkAction:perform()
    if self:isValid() then
        send(self.character, "Arrive", { id = self.dialogue.id, token = self.dialogue.token })
    else C.close(self.character) end
    ISBaseTimedAction.perform(self)
end
function ApocHumanTalkAction:new(player, state)
    local o = ISBaseTimedAction.new(self, player)
    o.dialogue, o.maxTime, o.stopOnWalk, o.stopOnRun = state, 1, true, true
    return o
end
function C.walk(player, state)
    local locations = {}
    for _, offset in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {-1,-1}, {-1,1}, {1,-1} }) do
        local x, y = math.floor(state.x) + offset[1], math.floor(state.y) + offset[2]
        if getCell():getGridSquare(x, y, state.z) then
            locations[#locations + 1], locations[#locations + 2], locations[#locations + 3] = x + 0.5, y + 0.5, state.z
        end
    end
    D.log("client", "walk", { id = state.id, destinations = #locations / 3 })
    if #locations == 0 then C.close(player); notify(player); return end
    local walk = ApocHumanWalkAction:pathToNearest(player, locations)
    walk.dialogue = state
    ISTimedActionQueue.add(walk)
    ISTimedActionQueue.add(ApocHumanTalkAction:new(player, state))
end
function C.begin(player, actor, option)
    if C.states[player:getPlayerNum()] then return end
    local index = player:getPlayerNum()
    local current = actor.key and (C.byKey[index] or {})[actor.key] or (C.roster[index] or {})[actor.id]
    if not current then C.resync(player, "stale_menu"); return end
    local available
    for _, candidate in ipairs(current.options or {}) do if candidate.id == option.id then available = candidate; break end end
    if not available then notify(player); return end
    actor, option = current, available
    C.sequence = C.sequence + 1
    local state = { id = actor.id, key = actor.key, incarnation = actor.incarnation, name = actor.name,
        request = C.sequence, deadline = getTimestampMs() + 35000 }
    C.states[player:getPlayerNum()] = state
    send(player, "Begin", { id = actor.id, option = option.id, request = state.request,
        node = actor.dialogue and actor.dialogue.entryNode,
        dialogueRevision = actor.dialogue and actor.dialogue.revision })
end
function C.select(player, state, option)
    if not valid(player, state) or state.pending or getTimestampMs() < (state.nextChoice or 0) then return end
    state.pending = true
    state.panel:setPending(true)
    send(player, "Select", { id = state.id, token = state.token, option = option, sequence = state.sequence + 1,
        node = state.node, dialogueRevision = state.dialogueRevision })
end
local function onServerCommand(module, command, args)
    if module ~= D.MODULE or type(args) ~= "table" or type(command) ~= "string" then return end
    if command:sub(1, 5) ~= "Human" then return end
    D.log("client", "receive", { command = command, recipient = args.recipient, id = args.id,
        error = args.error, request = args.request, sequence = args.sequence })
    for index = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(index)
        if player and args.recipient == player:getOnlineID() then
            if command == "HumanList" then
                local revision = args.revision or 0
                if C.revisions[index] and revision <= C.revisions[index] then
                    D.log("client", "reply_ignored", { reason = "stale_roster", revision = revision }); return
                end
                if C.incomingRoster[index] and C.incomingRoster[index].revision > revision then return end
                local actors
                if not C.incomingRoster[index] or C.incomingRoster[index].revision ~= revision then C.incomingAt[index] = getTimestampMs() end
                C.incomingRoster[index], actors = W.receive(C.incomingRoster[index], args)
                if not actors then return end
                local roster, byKey = {}, {}
                for _, actor in ipairs(actors) do
                    roster[actor.id] = actor
                    if actor.key then byKey[actor.key] = actor end
                    D.log("client", "roster_actor", { id = actor.id, key = actor.key, name = actor.name,
                        options = #(actor.options or {}) })
                end
                C.roster[index] = roster
                C.byKey[index] = byKey
                local active = C.states[index]
                local binding = active and (active.key and byKey[active.key] or roster[active.id])
                if active and not sameBinding(active, binding) then
                    D.log("client", "binding_changed", { key = active.key, oldId = active.id, newId = binding and binding.id })
                    C.close(player)
                end
                C.revisions[index] = revision
                C.listPendingAt[index] = nil
                C.listWarned[index] = nil
                C.incomingAt[index], C.repairCounts[index] = nil, 0
                D.log("client", "roster_updated", { player = player:getOnlineID(), actors = #actors,
                    revision = revision })
                return
            end
            local state = C.states[index]
            if not state or state.id ~= args.id or command == "HumanReserved" and state.request ~= args.request then
                D.log("client", "reply_ignored", { reason = "no_matching_session", command = command, id = args.id })
                if command == "HumanReserved" then send(player, "Close", { id = args.id, token = args.token }) end
                return
            end
            if command == "HumanReserved" then
                if state.token then return end
                state.token, state.x, state.y, state.z = args.token, args.x, args.y, args.z
                C.walk(player, state)
            elseif command == "HumanRejected" then
                if args.token and args.token ~= state.token or args.request and args.request ~= state.request then return end
                C.close(player)
                if args.message then player:Say(args.message)
                else notify(player, args.error == "busy" and "IGUI_ApocExtractionMapUtils_DialogBusy" or nil) end
            elseif args.token == state.token then
                if args.sequence and args.sequence <= (state.sequence or 0) then return end
                if args.contentFrame then
                    state.contentFrames = state.contentFrames or {}
                    local slot = command .. ":" .. tostring(args.sequence or 0)
                    local actors
                    state.contentFrames[slot], actors = W.receive(state.contentFrames[slot], args.contentFrame)
                    if not actors then return end
                    local graph = actors[1].dialogue
                    args.dialogue, args.options = graph, graph.nodes[graph.entryNode].options
                    args.node, args.dialogueRevision = graph.entryNode, graph.revision
                    args.nodeTexts, args.fallbackLocale = graph.nodes[graph.entryNode].texts, graph.fallbackLocale
                    args.nodeText = graph.nodes[graph.entryNode].text
                    args.labels = graph.labels
                    local actor = (C.roster[index] or {})[state.id]
                    if actor and graph.rootNode then
                        local menuGraph = {}
                        for key, value in pairs(graph) do menuGraph[key] = value end
                        menuGraph.entryNode = graph.rootNode
                        C.roster[index][state.id] = { id = actor.id, key = actor.key, incarnation = actor.incarnation, name = actor.name,
                            dialogue = menuGraph, options = graph.nodes[graph.rootNode].options }
                        if actor.key then C.byKey[index][actor.key] = C.roster[index][state.id] end
                    end
                end
                if command == "HumanOpened" then
                    if state.panel then return end
                    state.opened, state.sequence, state.deadline = true, 0, getTimestampMs() + 65000
                    state.panel = ApocHumanDialogPanel:new(player, state.name, args.options or {}, args.greetingKey,
                        function(option) C.select(player, state, option) end, function() C.close(player) end, args.labels)
                    state.panel:initialise(); state.panel:addToUIManager()
                    state.node, state.dialogueRevision = args.node, args.dialogueRevision
                    if args.nodeTexts then state.panel:setNode(args.options, args.nodeTexts, args.fallbackLocale) end
                    if args.nodeText then state.panel:setResolvedNode(args.options, args.nodeText) end
                    if args.greetingText then state.panel:setResponse(args.greetingText) end
                    D.log("client", "panel_opened", { id = state.id, options = #(args.options or {}) })
                elseif command == "HumanSelected" then
                    state.sequence, state.pending, state.nextChoice = args.sequence, false, getTimestampMs() + 600
                    state.deadline = getTimestampMs() + 65000
                    state.node, state.dialogueRevision = args.node, args.dialogueRevision
                    if state.panel then
                        if args.nodeTexts then state.panel:setNode(args.options, args.nodeTexts, args.fallbackLocale) end
                        if args.nodeText then state.panel:setResolvedNode(args.options, args.nodeText) end
                        if args.response ~= nil then state.panel:setResponse(args.response)
                        elseif args.responseTexts then
                            state.panel:setResponse(G.text(args.responseTexts, G.locale(), args.fallbackLocale).response)
                        else state.panel:setMessage(args.responseKey) end
                        state.panel:setPending(false)
                    end
                elseif command == "HumanClosed" then C.close(player) end
            else
                D.log("client", "reply_ignored", { reason = "token_mismatch", command = command, id = args.id })
            end
            return
        end
    end
    D.log("client", "reply_ignored", { reason = "recipient_mismatch", command = command, recipient = args.recipient })
end
Events.OnServerCommand.Add(onServerCommand)

local function menu(playerIndex, context, worldobjects, test)
    local player = getSpecificPlayer(playerIndex)
    if not player or player:isDead() then
        if not test then D.log("client", "menu_skipped", { reason = "no_live_player", index = playerIndex }) end
        return
    end
    local clicked = ISWorldObjectContextMenu.fetchVars and ISWorldObjectContextMenu.fetchVars.clickedPlayer
    local source = "fetch.clickedPlayer"
    -- Prefer an explicit character hit; native fetch may also resolve a nearby player.
    for _, object in ipairs(worldobjects) do
        if instanceof(object, "IsoPlayer") then clicked = object; source = "worldobjects"; break end
    end
    if not clicked then
        if not test then D.log("client", "menu_skipped", { reason = "no_clicked_player", worldobjects = #worldobjects,
            rosterReceived = C.roster[playerIndex] ~= nil }) end
        return
    end
    local actor = (C.roster[playerIndex] or {})[clicked:getOnlineID()]
    if not test then
        D.log("client", "menu_target", { id = clicked:getOnlineID(), source = source,
            rosterReceived = C.roster[playerIndex] ~= nil, registered = actor ~= nil,
            options = actor and #(actor.options or {}) or 0 })
    end
    if not actor or not actor.options or #actor.options == 0 then
        if not actor and not test and clicked:getOnlineID() >= 1024 then C.resync(player, "unknown_npc_binding") end
        if not test then D.log("client", "menu_skipped", { reason = not actor and "target_not_in_roster" or "no_options" }) end
        return
    end
    if test then return ISWorldObjectContextMenu.setTest() end
    D.log("client", "menu_added", { id = actor.id, key = actor.key, name = actor.name, options = #actor.options })
    local labels = actor.dialogue and actor.dialogue.labels
    local title = labels and labels.talk and labels.talk:gsub("%%1", function() return actor.name end)
        or getText("IGUI_ApocExtractionMapUtils_DialogTalk", actor.name)
    local root = context:addOption(title, nil, nil)
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, submenu)
    for _, option in ipairs(actor.options) do
        submenu:addOption(G.label(option, actor.dialogue and actor.dialogue.fallbackLocale), player, C.begin, actor, option)
    end
end
Events.OnPreFillWorldObjectContextMenu.Add(menu)
-- Called by ExtractionMapUtils' Lua login hook after an online ID exists.
function C.requestRoster(player)
    local index = player:getPlayerNum()
    if player:isDead() or player:getOnlineID() < 0 then return false end
    if C.requestedFor[index] == player and C.requestedID[index] == player:getOnlineID() then return false end
    if C.states[index] then C.close(player) end
    C.requestedFor[index], C.requestedID[index] = player, player:getOnlineID()
    C.roster[index], C.byKey[index], C.revisions[index], C.incomingRoster[index] = nil, nil, nil, nil
    C.incomingAt[index], C.repairCounts[index], C.nextRepairAt[index] = nil, 0, 0
    C.resync(player, "login")
    return true
end
Events.OnTick.Add(function()
    local now = getTimestampMs()
    for index = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(index)
        if player then
            local state = C.states[index]
            if state and (now >= state.deadline or player:isDead()) then
                D.log("client", "session_expired", { id = state.id, dead = player:isDead() })
                C.close(player)
            end
            if C.listPendingAt[index] and not C.listWarned[index] and now - C.listPendingAt[index] >= 10000 then
                C.listWarned[index] = true
                D.log("client", "list_waiting", { player = player:getOnlineID(), elapsedMs = now - C.listPendingAt[index] })
                C.resync(player, "reply_timeout")
            end
            if C.incomingAt[index] and now - C.incomingAt[index] >= 10000 then
                C.incomingRoster[index], C.incomingAt[index] = nil, nil
                C.resync(player, "frame_timeout")
            end
        else
            C.requestedFor[index], C.requestedID[index] = nil, nil
            C.roster[index], C.byKey[index], C.revisions[index] = nil, nil, nil
            C.incomingRoster[index] = nil
            C.incomingAt[index], C.repairCounts[index], C.nextRepairAt[index] = nil, nil, nil
            C.listPendingAt[index], C.listWarned[index] = nil, nil
        end
    end
end)

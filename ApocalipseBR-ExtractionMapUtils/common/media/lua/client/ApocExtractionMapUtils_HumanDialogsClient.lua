if not isClient() then return end
require "ApocExtractionMapUtils_HumanDialogs"
require "ApocExtractionMapUtils_HumanDialogPanel"
require "Vehicles/TimedActions/ISPathFindAction"
require "TimedActions/ISTimedActionQueue"
local D = ApocExtractionMapUtils.HumanDialogs
if D.clientLoaded then return end
D.clientLoaded = true
local C = { states = {}, roster = {}, sequence = 0, refreshAt = {}, listPendingAt = {} }
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
    C.sequence = C.sequence + 1
    local state = { id = actor.id, name = actor.name, request = C.sequence, deadline = getTimestampMs() + 35000 }
    C.states[player:getPlayerNum()] = state
    send(player, "Begin", { id = actor.id, option = option.id, request = state.request })
end
function C.select(player, state, option)
    if not valid(player, state) or state.pending or getTimestampMs() < (state.nextChoice or 0) then return end
    state.pending = true
    state.panel:setPending(true)
    send(player, "Select", { id = state.id, token = state.token, option = option, sequence = state.sequence + 1 })
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
                local roster = {}
                for _, actor in ipairs(args.actors or {}) do
                    roster[actor.id] = actor
                    D.log("client", "roster_actor", { id = actor.id, key = actor.key, name = actor.name,
                        options = #(actor.options or {}) })
                end
                C.roster[index] = roster
                C.listPendingAt[index] = nil
                D.log("client", "roster_updated", { player = player:getOnlineID(), actors = #(args.actors or {}) })
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
                notify(player, args.error == "busy" and "IGUI_ApocExtractionMapUtils_DialogBusy" or nil)
            elseif args.token == state.token then
                if command == "HumanOpened" then
                    if state.panel then return end
                    state.opened, state.sequence, state.deadline = true, 0, getTimestampMs() + 65000
                    state.panel = ApocHumanDialogPanel:new(player, state.name, args.options or {}, args.greetingKey,
                        function(option) C.select(player, state, option) end, function() C.close(player) end)
                    state.panel:initialise(); state.panel:addToUIManager()
                    D.log("client", "panel_opened", { id = state.id, options = #(args.options or {}) })
                elseif command == "HumanSelected" then
                    state.sequence, state.pending, state.nextChoice = args.sequence, false, getTimestampMs() + 600
                    state.deadline = getTimestampMs() + 65000
                    if state.panel then state.panel:setMessage(args.responseKey); state.panel:setPending(false) end
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
        if not test then D.log("client", "menu_skipped", { reason = not actor and "target_not_in_roster" or "no_options" }) end
        return
    end
    if test then return ISWorldObjectContextMenu.setTest() end
    D.log("client", "menu_added", { id = actor.id, key = actor.key, name = actor.name, options = #actor.options })
    local root = context:addOption(getText("IGUI_ApocExtractionMapUtils_DialogTalk", actor.name), nil, nil)
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(root, submenu)
    for _, option in ipairs(actor.options) do
        submenu:addOption(getText(option.textKey), player, C.begin, actor, option)
    end
end
Events.OnPreFillWorldObjectContextMenu.Add(menu)
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
            if now >= (C.refreshAt[index] or 0) and not C.states[index] then
                C.refreshAt[index] = now + 5000
                if C.listPendingAt[index] then
                    D.log("client", "list_waiting", { player = player:getOnlineID(), elapsedMs = now - C.listPendingAt[index] })
                else C.listPendingAt[index] = now end
                send(player, "List", {})
            end
        end
    end
end)

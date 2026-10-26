if not isServer() then return end
require "ApocExtractionMapUtils_HumanDialogs"
local D = ApocExtractionMapUtils.HumanDialogs
local G = require "ApocExtractionMapUtils_HumanDialogueGraph"
local W = require "ApocExtractionMapUtils_HumanDialogueWire"
if D.serverLoaded then return end
D.serverLoaded = true
local sessions, throttles = {}, {}
local subscribers, rosterCache, rosterRevision, rosterDirty = {}, nil, 0, true
local database, databaseReady = false, true
local rosterDefinitions = {}
local deliveryRevision = 0
local bridgeRevision, cachedBridgeRevision
local function currentBridgeRevision()
    return ApocBRHumanAPI and ApocBRHumanAPI.rosterRevision and ApocBRHumanAPI.rosterRevision() or nil
end
D.log("server", "loaded")
local function serverText(key)
    return ApocBRHumanAPI and ApocBRHumanAPI.text and ApocBRHumanAPI.text(key) or getText(key)
end

local function integer(value)
    return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= 2147483647
end
local function send(player, command, args)
    args.recipient = player:getOnlineID()
    D.log("server", "send", { command = "Human" .. command, recipient = args.recipient,
        id = args.id, error = args.error, request = args.request, sequence = args.sequence })
    sendServerCommand(player, D.MODULE, "Human" .. command, args)
end
local function publicOptions(definition, node, flags)
    local result = {}
    for _, option in ipairs(G.options(definition, node, flags)) do
        result[#result + 1] = option.textKey and { id = option.id, title = serverText(option.textKey) } or G.publicOption(option)
    end
    return result
end
local function sendContent(player, command, data, definition, node, flags)
    if not definition.graph then send(player, command, data); return true end
    local graph = G.public(definition, node, flags)
    local ok, frames = pcall(W.pack, { { id = data.id, dialogue = graph } }, data.sequence or 0)
    if not ok then return false end
    data.options, data.dialogue = nil, nil
    for _, frame in ipairs(frames) do
        local envelope = {}
        for key, value in pairs(data) do envelope[key] = value end
        envelope.contentFrame = frame
        send(player, command, envelope)
    end
    return true
end
local function definitionFor(actor)
    return D.definitions[actor.key]
end
local function flagsFor(player, key, existing, actorId, definition)
    local flags = {}
    if definition and definition.graph and ApocBRHumanAPI.dialogueFlags then
        for flag, value in pairs(ApocBRHumanAPI.dialogueFlags(player, actorId, definition.id) or {}) do
            if value == true then flags[flag] = true end
        end
    end
    -- Extension point for cached quest/account context. Never trust client flags.
    if D.contextProvider then
        local ok, context = pcall(D.contextProvider, player, key)
        if ok and type(context) == "table" then
            for flag, value in pairs(context) do if value == true then flags[flag] = true end end
        end
    end
    for flag, value in pairs(existing or {}) do flags[flag] = value end
    return flags
end

-- Server-only integration point. Multiple changes in a tick become one snapshot.
function D.pushRoster()
    rosterCache, rosterDirty = nil, true
end
-- Trusted server integration: queue one personalized snapshot for one character.
-- Does not grant choices or change any database dialogue definitions.
function D.refreshRoster(player)
    if not player or getPlayerByOnlineID(player:getOnlineID()) ~= player then return false end
    local id = player:getOnlineID()
    local subscriber = subscribers[id]
    if not subscriber or subscriber.player ~= player then subscriber = { player = player }; subscribers[id] = subscriber end
    subscriber.pending, subscriber.nextSendAt = true, 0
    return true
end
local function roster()
    if not ApocBRHumanAPI or not ApocBRHumanAPI.roster then return nil end
    if rosterCache then return rosterCache end
    local before = currentBridgeRevision()
    if ApocBRHumanAPI.dialogues then
        local catalog = ApocBRHumanAPI.dialogues()
        database, databaseReady = catalog.database == true, catalog.ready == true
        if not databaseReady then return nil end
    end
    local actors = {}
    rosterDefinitions = {}
    for _, actor in ipairs(ApocBRHumanAPI.roster()) do
        local definition = definitionFor(actor)
        D.log("server", "discovered_actor", { id = actor.id, key = actor.key, name = actor.name,
            registered = definition ~= nil })
        if database and ApocBRHumanAPI.dialogueRoster then
            actors[#actors + 1] = { id = actor.id, key = actor.key, name = actor.name, incarnation = actor.incarnation }
        elseif definition then
            rosterDefinitions[actor.id] = definition
            actors[#actors + 1] = { id = actor.id, key = actor.key, name = actor.name, incarnation = actor.incarnation,
                options = publicOptions(definition, definition.entryNode, {}),
                dialogue = G.public(definition, definition.entryNode, {}) }
        end
    end
    if before ~= currentBridgeRevision() then return nil end
    cachedBridgeRevision = before
    rosterCache, rosterRevision = actors, rosterRevision + 1
    return actors
end
local function sendRoster(subscriber, actors)
    D.log("server", "roster_ready", { player = subscriber.player:getOnlineID(), actors = #actors,
        revision = rosterRevision })
    local personalized = {}
    if database then
        if not ApocBRHumanAPI.dialogueRoster then return end
        personalized = ApocBRHumanAPI.dialogueRoster(subscriber.player)
    else for _, actor in ipairs(actors) do
        local definition = rosterDefinitions[actor.id]
        if definition and definition.graph then
            local flags = flagsFor(subscriber.player, actor.key, {}, actor.id, definition)
            personalized[#personalized + 1] = { id = actor.id, key = actor.key, name = actor.name, incarnation = actor.incarnation,
                options = publicOptions(definition, definition.entryNode, flags),
                dialogue = G.public(definition, definition.entryNode, flags) }
        else personalized[#personalized + 1] = actor end
    end end
    if cachedBridgeRevision ~= currentBridgeRevision() then D.pushRoster(); return false end
    local ok, frames = pcall(W.pack, personalized, deliveryRevision + 1)
    if not ok then
        D.log("server", "roster_rejected", { reason = "payload_limit" }); return
    end
    deliveryRevision = deliveryRevision + 1
    for _, frame in ipairs(frames) do
        frame.catalogRevision = rosterRevision
        local sent = pcall(send, subscriber.player, "List", frame)
        if not sent then
            D.log("server", "roster_rejected", { reason = "send_failed", revision = deliveryRevision })
            return false
        end
    end
    subscriber.revision = rosterRevision
    subscriber.pending = false
    return true
end
local function reject(player, args, reason)
    D.log("server", "rejected", { player = player:getOnlineID(), id = args.id, reason = reason })
    send(player, "Rejected", { request = args.request, id = args.id, token = args.token, error = reason,
        message = serverText(reason == "busy" and "IGUI_ApocExtractionMapUtils_DialogBusy" or "IGUI_ApocExtractionMapUtils_DialogUnavailable") })
end
local function sendResolved(player, command, data, graph)
    local ok, frames = pcall(W.pack, { { id = data.id, dialogue = graph } }, data.sequence or 0)
    if not ok then return false end
    for _, frame in ipairs(frames) do
        local envelope = {}
        for key, value in pairs(data) do envelope[key] = value end
        envelope.contentFrame = frame
        send(player, command, envelope)
    end
    return true
end
-- SQL graph progression belongs to the engine. This adapter sends identifiers only;
-- actor ownership, facts, revision/cursor/order, language and effects are engine-owned.
local function engineCommand(command, player, args)
    if command == "HumanBegin" then
        if not integer(args.request) or not integer(args.dialogueRevision) then return end
        local result = ApocBRHumanAPI.dialogueBegin(player, args.id, args.dialogueRevision, args.node, args.option)
        if not result or result.error then reject(player, args, result and result.error or "unavailable"); return end
        sessions[player] = { player = player, id = result.id, token = result.token, key = result.key,
            selected = args.option, engine = true, opened = false }
        result.request = args.request
        send(player, "Reserved", result); D.emit("reserved", player, result)
        return
    end
    local session = sessions[player]
    if not session or session.id ~= args.id or session.token ~= args.token then return end
    if command == "HumanClose" then ApocBRHumanAPI.finish(player, args.id, args.token); return end
    if command == "HumanArrive" then
        if session.opened then return end
        if not ApocBRHumanAPI.arrive(player, args.id, args.token) then
            reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token); return
        end
        local view = ApocBRHumanAPI.dialogueView(player, args.id, args.token)
        if not view or view.error or not sendResolved(player, "Opened", { id = args.id, token = args.token }, view) then
            reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token); return
        end
        session.opened = true
        D.emit("opened", player, { key = session.key, id = args.id, token = args.token })
        args.option, args.sequence = session.selected, 1
        args.node, args.dialogueRevision = view.entryNode, view.revision
        command = "HumanSelect"
    end
    if command ~= "HumanSelect" or not session.opened or not integer(args.sequence) or not integer(args.dialogueRevision) then return end
    local result = ApocBRHumanAPI.dialogueSelect(player, args.id, args.token, args.node, args.dialogueRevision, args.option, args.sequence)
    if not result or result.error then reject(player, args, result and result.error or "unavailable"); return end
    local data = { id = args.id, token = args.token, key = session.key, option = result.option,
        sequence = result.sequence, response = result.response }
    D.emit("selected", player, data)
    if not sendResolved(player, "Selected", data, result.dialogue) then
        ApocBRHumanAPI.finish(player, args.id, args.token); return
    end
    if result.close then ApocBRHumanAPI.finish(player, args.id, args.token) end
end
local function onCommand(module, command, player, args)
    if module ~= D.MODULE or type(command) ~= "string" or command:sub(1, 5) ~= "Human" then return end
    if not player then return end
    local argsType = type(args)
    -- The native ClientCommand transport omits empty tables. Discovery has no
    -- required payload; other commands must still supply a structured request.
    if command == "HumanList" and args == nil then args = {} end
    if type(args) ~= "table" then
        D.log("server", "request_ignored", { command = command, reason = "invalid_args", argsType = argsType })
        return
    end
    D.log("server", "receive", { command = command, player = player:getOnlineID(),
        id = args.id, option = args.option, request = args.request, sequence = args.sequence, argsType = argsType })
    local now, playerId = getTimestampMs(), player:getOnlineID()
    local limit = throttles[playerId]
    if not limit or limit.player ~= player then limit = { player = player }; throttles[playerId] = limit end
    if command == "HumanList" or command == "HumanBegin" then
        if now < (limit[command] or 0) then
            D.log("server", "request_ignored", { command = command, reason = "throttled", player = playerId })
            return
        end
        limit[command] = now + (command == "HumanList" and 1000 or 250)
    end
    if command == "HumanList" then
        local subscriber = subscribers[playerId]
        if not subscriber or subscriber.player ~= player then
            subscriber = { player = player }; subscribers[playerId] = subscriber
        end
        subscriber.pending = true
        local actors = roster()
        if actors then sendRoster(subscriber, actors)
        else
            D.log("server", "roster_deferred", { player = playerId, reason = "roster_api_unavailable" })
        end
        return
    end
    if not ApocBRHumanAPI then reject(player, args, "unavailable"); return end
    if not integer(args.id) then
        D.log("server", "request_ignored", { command = command, reason = "invalid_id" }); return
    end
    if database or sessions[player] and sessions[player].engine then
        if not ApocBRHumanAPI.dialogueBegin or not ApocBRHumanAPI.dialogueSelect then reject(player, args, "unavailable"); return end
        engineCommand(command, player, args); return
    end
    if command == "HumanBegin" then
        if not integer(args.request) then
            D.log("server", "request_ignored", { command = command, reason = "invalid_request" }); return
        end
        local definition, npcKey
        for _, actor in ipairs(ApocBRHumanAPI.list(player)) do
            if actor.id == args.id then definition, npcKey = definitionFor(actor), actor.key; break end
        end
        local flags = flagsFor(player, npcKey, {}, args.id, definition)
        if not definition or definition.graph and (args.dialogueRevision ~= definition.revision or args.node ~= definition.entryNode)
            or not G.find(definition, definition.entryNode, flags, args.option) then
            reject(player, args, "unavailable"); return
        end
        local result = ApocBRHumanAPI.begin(player, args.id)
        if not result or result.error then reject(player, args, result and result.error or "unavailable"); return end
        sessions[player] = { player = player, id = result.id, token = result.token,
            request = args.request, definition = definition, selected = args.option, key = result.key, sequence = 0,
            node = definition.entryNode, flags = flags,
            locale = ApocBRHumanAPI.language and ApocBRHumanAPI.language() or "PTBR" }
        result.request = args.request
        D.log("server", "reserved", { player = playerId, id = result.id, key = result.key })
        send(player, "Reserved", result)
        D.emit("reserved", player, result)
        return
    end
    local session = sessions[player]
    if not session or session.player ~= player or session.id ~= args.id or session.token ~= args.token then
        D.log("server", "request_ignored", { command = command, id = args.id, reason = "session_mismatch" }); return
    end
    if command == "HumanClose" then ApocBRHumanAPI.finish(player, args.id, args.token); return end
    if command == "HumanArrive" then
        if session.opened then
            D.log("server", "request_ignored", { command = command, id = args.id, reason = "already_opened" }); return
        end
        if not ApocBRHumanAPI.arrive(player, args.id, args.token) then
            reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token); return
        end
        session.opened = true
        D.log("server", "arrival_validated", { player = playerId, id = args.id, key = session.key })
        sendContent(player, "Opened", { id = args.id, token = args.token,
            options = publicOptions(session.definition, session.node, session.flags),
            dialogue = G.public(session.definition, session.node, session.flags), node = session.node,
            greetingText = session.definition.greetingKey and serverText(session.definition.greetingKey) }, session.definition, session.node, session.flags)
        D.emit("opened", player, { key = session.key, id = args.id, token = args.token })
        -- The option chosen in the right-click menu runs only after reaching the NPC.
        args.option, args.sequence = session.selected, 1
        args.node, args.dialogueRevision = session.node, session.definition.revision
        command = "HumanSelect"
    end
    if command == "HumanSelect" then
        if not session.opened or not integer(args.sequence) or args.sequence ~= session.sequence + 1
            or (session.nextChoice and now < session.nextChoice) then
            D.log("server", "request_ignored", { command = command, id = args.id, reason = "selection_order_or_cooldown" }); return
        end
        if session.definition.graph and (args.node ~= session.node or args.dialogueRevision ~= session.definition.revision) then
            reject(player, args, "unavailable"); return
        end
        session.flags = flagsFor(player, session.key, session.flags, session.id, session.definition)
        local option = G.find(session.definition, session.node, session.flags, args.option)
        if not option then
            D.log("server", "request_ignored", { command = command, reason = "unknown_option" })
            if session.definition.graph then
                reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token)
            end
            return
        end
        local speech = G.text(option.texts, session.locale, session.definition.fallbackLocale)
        local response = option.responseKey and serverText(option.responseKey) or speech.speech
        if response == "" then response = nil end
        if not ApocBRHumanAPI.react(player, args.id, args.token, response, option.emote) then
            reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token); return
        end
        session.sequence, session.nextChoice = args.sequence, now + 500
        if session.definition.graph then
            if option.setFlag and database and (not ApocBRHumanAPI.remember
                or not ApocBRHumanAPI.remember(player, args.id, args.token, session.definition.id, option.setFlag)) then
                reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token); return
            end
            if option.setFlag then session.flags[option.setFlag] = true end
            session.node = option.nextNode
        end
        local responseTexts
        if option.texts then
            responseTexts = {}
            for locale, text in pairs(option.texts) do responseTexts[locale] = { response = text.response } end
        end
        local data = { id = args.id, token = args.token, key = session.key,
            option = option.id, response = option.responseKey and response or speech.response, sequence = session.sequence,
            node = session.node, dialogueRevision = session.definition.revision,
            responseTexts = responseTexts, fallbackLocale = session.definition.fallbackLocale,
            options = publicOptions(session.definition, session.node, session.flags) }
        if option.onSelect then
            local ok = pcall(option.onSelect, player, data)
            if not ok then ApocExtractionMapUtils.debugLog("[ApocExtractionMapUtils] NPC option callback failed: " .. option.id) end
        end
        D.emit("selected", player, data)
        D.log("server", "selected", { player = playerId, id = args.id, key = session.key,
            option = option.id, sequence = session.sequence })
        sendContent(player, "Selected", data, session.definition, session.node, session.flags)
        if option.close then ApocBRHumanAPI.finish(player, args.id, args.token) end
    end
end
Events.OnClientCommand.Add(onCommand)

-- The Java API and custom events become available on the first server simulation tick.
local bound, cleanupAt = false, 0
local rosterBound, rosterAPI
local lastBridgeStatus
Events.OnTick.Add(function()
    if ApocExtractionMapUtils.debugLogEnabled() then
        local status = ApocBRHumanAPI and "ready" or "missing"
        if status ~= lastBridgeStatus then
            D.log("server", "bridge_status", { status = status, version = ApocBRHumanAPI and ApocBRHumanAPI.version })
            lastBridgeStatus = status
        end
    else lastBridgeStatus = nil end
    if Events.OnApocBRHumanRosterChanged and not rosterBound then
        Events.OnApocBRHumanRosterChanged.Add(D.pushRoster)
        rosterBound = true
        D.log("server", "roster_hook_bound")
    end
    if ApocBRHumanAPI and ApocBRHumanAPI.roster and rosterAPI ~= ApocBRHumanAPI then
        rosterAPI = ApocBRHumanAPI
        D.pushRoster()
    end
    local revision = currentBridgeRevision()
    if revision ~= bridgeRevision then
        bridgeRevision = revision
        D.log("server", "bridge_roster_changed", { revision = revision })
        D.pushRoster()
    end
    if rosterDirty then
        local actors = roster()
        if actors then
            rosterDirty = false
            for id, subscriber in pairs(subscribers) do
                if getPlayerByOnlineID(id) ~= subscriber.player then subscribers[id] = nil
                elseif subscriber.revision ~= rosterRevision then subscriber.pending, subscriber.nextSendAt = true, 0 end
            end
        end
    end
    local deliveryNow = getTimestampMs()
    for id, subscriber in pairs(subscribers) do
        if getPlayerByOnlineID(id) ~= subscriber.player then subscribers[id] = nil
        elseif subscriber.pending and deliveryNow >= (subscriber.nextSendAt or 0) then
            subscriber.nextSendAt = deliveryNow + 1000
            local actors = roster()
            if actors then sendRoster(subscriber, actors) end
        end
    end
    if not bound and ApocBRHumanAPI and Events.OnApocBRHumanDialogueClosed then
        bound = true
        D.log("server", "close_hook_bound")
        Events.OnApocBRHumanDialogueClosed.Add(function(player, data)
            local session = sessions[player]
            if session and session.player == player and session.token == data.token then
                D.log("server", "closed", { player = player:getOnlineID(), id = data.id, reason = data.reason })
                sessions[player] = nil
                send(player, "Closed", data)
                D.emit("closed", player, data)
            end
        end)
    end
    local now = getTimestampMs()
    if now < cleanupAt then return end
    cleanupAt = now + 10000
    for id, limit in pairs(throttles) do
        if getPlayerByOnlineID(id) ~= limit.player then throttles[id] = nil end
    end
    for id, subscriber in pairs(subscribers) do
        if getPlayerByOnlineID(id) ~= subscriber.player then subscribers[id] = nil end
    end
end)

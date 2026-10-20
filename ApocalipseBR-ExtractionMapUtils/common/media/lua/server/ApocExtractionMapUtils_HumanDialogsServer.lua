if not isServer() then return end
require "ApocExtractionMapUtils_HumanDialogs"
local D = ApocExtractionMapUtils.HumanDialogs
if D.serverLoaded then return end
D.serverLoaded = true
local sessions, throttles = {}, {}

local function integer(value)
    return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= 2147483647
end
local function send(player, command, args)
    args.recipient = player:getOnlineID()
    sendServerCommand(player, D.MODULE, "Human" .. command, args)
end
local function publicOptions(definition)
    local result = {}
    for _, option in ipairs(definition.options) do
        result[#result + 1] = { id = option.id, textKey = option.textKey }
    end
    return result
end
local function reject(player, args, reason)
    send(player, "Rejected", { request = args.request, id = args.id, token = args.token, error = reason })
end
local function onCommand(module, command, player, args)
    if module ~= D.MODULE or type(command) ~= "string" or command:sub(1, 5) ~= "Human" then return end
    if not player or type(args) ~= "table" then return end
    if not ApocBRHumanAPI then reject(player, args, "unavailable"); return end
    local now, playerId = getTimestampMs(), player:getOnlineID()
    local limit = throttles[playerId]
    if not limit or limit.player ~= player then limit = { player = player }; throttles[playerId] = limit end
    if command == "HumanList" or command == "HumanBegin" then
        if now < (limit[command] or 0) then return end
        limit[command] = now + (command == "HumanList" and 1000 or 250)
    end
    if command == "HumanList" then
        local actors = {}
        for _, actor in ipairs(ApocBRHumanAPI.list(player)) do
            local definition = D.definitions[actor.key]
            if definition then
                actor.options = publicOptions(definition)
                actors[#actors + 1] = actor
            end
        end
        send(player, "List", { actors = actors }); return
    end
    if not integer(args.id) then return end
    if command == "HumanBegin" then
        if not integer(args.request) then return end
        local definition
        for _, actor in ipairs(ApocBRHumanAPI.list(player)) do
            if actor.id == args.id then definition = D.definitions[actor.key]; break end
        end
        if not definition or not definition.byId[args.option] then reject(player, args, "unavailable"); return end
        local result = ApocBRHumanAPI.begin(player, args.id)
        if not result or result.error then reject(player, args, result and result.error or "unavailable"); return end
        sessions[player] = { player = player, id = result.id, token = result.token,
            request = args.request, definition = definition, selected = args.option, key = result.key, sequence = 0 }
        result.request = args.request
        send(player, "Reserved", result)
        D.emit("reserved", player, result)
        return
    end
    local session = sessions[player]
    if not session or session.player ~= player or session.id ~= args.id or session.token ~= args.token then return end
    if command == "HumanClose" then ApocBRHumanAPI.finish(player, args.id, args.token); return end
    if command == "HumanArrive" then
        if session.opened then return end
        if not ApocBRHumanAPI.arrive(player, args.id, args.token) then
            reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token); return
        end
        session.opened = true
        send(player, "Opened", { id = args.id, token = args.token, options = publicOptions(session.definition),
            greetingKey = session.definition.greetingKey })
        D.emit("opened", player, { key = session.key, id = args.id, token = args.token })
        -- The option chosen in the right-click menu runs only after reaching the NPC.
        args.option, args.sequence = session.selected, 1
        command = "HumanSelect"
    end
    if command == "HumanSelect" then
        if not session.opened or not integer(args.sequence) or args.sequence ~= session.sequence + 1
            or (session.nextChoice and now < session.nextChoice) then return end
        local option = session.definition.byId[args.option]
        if not option then return end
        local response = getText(option.responseKey)
        if not ApocBRHumanAPI.react(player, args.id, args.token, response, option.emote) then
            reject(player, args, "unavailable"); ApocBRHumanAPI.finish(player, args.id, args.token); return
        end
        session.sequence, session.nextChoice = args.sequence, now + 500
        local data = { id = args.id, token = args.token, key = session.key,
            option = option.id, responseKey = option.responseKey, sequence = session.sequence }
        if option.onSelect then
            local ok = pcall(option.onSelect, player, data)
            if not ok then print("[ApocExtractionMapUtils] NPC option callback failed: " .. option.id) end
        end
        D.emit("selected", player, data)
        send(player, "Selected", data)
    end
end
Events.OnClientCommand.Add(onCommand)

-- The Java API and custom events become available on the first server simulation tick.
local bound, cleanupAt = false, 0
Events.OnTick.Add(function()
    if not bound and ApocBRHumanAPI and Events.OnApocBRHumanDialogueClosed then
        bound = true
        Events.OnApocBRHumanDialogueClosed.Add(function(player, data)
            local session = sessions[player]
            if session and session.player == player and session.token == data.token then
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
end)

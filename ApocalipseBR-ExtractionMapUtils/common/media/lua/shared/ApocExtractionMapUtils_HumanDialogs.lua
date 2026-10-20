require "ApocExtractionMapUtils"

-- Registration is shared; callbacks execute only in server Lua after validation.
local D = ApocExtractionMapUtils.HumanDialogs or { definitions = {}, hooks = {} }
ApocExtractionMapUtils.HumanDialogs = D
D.MODULE = "ApocExtractionMapUtils"

function D.register(npcKey, definition)
    assert(type(npcKey) == "string" and #npcKey > 0 and #npcKey <= 128, "Invalid NPC key")
    assert(type(definition) == "table" and type(definition.options) == "table"
        and #definition.options > 0 and #definition.options <= 12, "Expected 1-12 dialogue options")
    local copy = { greetingKey = definition.greetingKey, options = {}, byId = {} }
    for _, option in ipairs(definition.options) do
        assert(type(option.id) == "string" and option.id:match("^[%w_]+$") and #option.id <= 48
            and not copy.byId[option.id], "Invalid or duplicate dialogue option")
        assert(type(option.textKey) == "string" and type(option.responseKey) == "string", "Expected translation keys")
        assert(option.onSelect == nil or type(option.onSelect) == "function", "Expected callback")
        assert(option.emote == nil or type(option.emote) == "string"
            and option.emote:match("^[%w_]+$") and #option.emote <= 40, "Invalid emote")
        local saved = { id = option.id, textKey = option.textKey, responseKey = option.responseKey,
            emote = option.emote, onSelect = option.onSelect }
        copy.options[#copy.options + 1], copy.byId[saved.id] = saved, saved
    end
    D.definitions[npcKey] = copy
end

function D.on(event, callback)
    assert(event == "reserved" or event == "opened" or event == "selected" or event == "closed", "Unknown dialogue event")
    assert(type(callback) == "function", "Expected callback")
    D.hooks[event] = D.hooks[event] or {}
    table.insert(D.hooks[event], callback)
end

function D.emit(event, player, data)
    for _, callback in ipairs(D.hooks[event] or {}) do
        local ok = pcall(callback, player, data)
        if not ok then print("[ApocExtractionMapUtils] NPC dialogue hook failed: " .. event) end
    end
end

-- A working starter profile. Other mods can register different keys or replace it.
D.register("guide", { greetingKey = "IGUI_ApocExtractionMapUtils_DialogGreeting", options = {
    { id = "hello", textKey = "IGUI_ApocExtractionMapUtils_DialogHello",
        responseKey = "IGUI_ApocExtractionMapUtils_DialogHelloReply", emote = "wavehi" },
    { id = "help", textKey = "IGUI_ApocExtractionMapUtils_DialogHelp",
        responseKey = "IGUI_ApocExtractionMapUtils_DialogHelpReply" },
    { id = "thanks", textKey = "IGUI_ApocExtractionMapUtils_DialogThanks",
        responseKey = "IGUI_ApocExtractionMapUtils_DialogThanksReply", emote = "thumbsup" },
} })

return D

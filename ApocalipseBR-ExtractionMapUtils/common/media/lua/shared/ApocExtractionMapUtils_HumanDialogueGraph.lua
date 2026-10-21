-- Data-only dialogue graphs. Conditions and advancement run on the server.
local G = {}
function G.locale()
    return Translator and Translator.getLanguage():name() or "EN"
end
function G.text(texts, locale, fallback)
    return texts and (texts[locale] or texts[fallback or "EN"]) or {}
end
function G.allowed(option, flags)
    return (not option.requiredFlag or flags[option.requiredFlag] == true)
        and (not option.forbiddenFlag or flags[option.forbiddenFlag] ~= true)
end
function G.options(definition, node, flags)
    if not definition.graph then return definition.options end
    local options = {}
    for _, option in ipairs(definition.nodes[node].options or {}) do
        if G.allowed(option, flags or {}) then options[#options + 1] = option end
    end
    return options
end
function G.find(definition, node, flags, id)
    for _, option in ipairs(G.options(definition, node, flags)) do
        if option.id == id then return option end
    end
end
function G.publicOption(option)
    if option.textKey then return { id = option.id, textKey = option.textKey } end
    local texts = {}
    for locale, text in pairs(option.texts) do
        texts[locale] = { title = text.title, description = text.description, response = text.response }
    end
    return { id = option.id, nextNode = option.nextNode, texts = texts, close = option.close }
end
function G.public(definition, current, flags)
    if not definition.graph then return nil end
    local result = { schema = 1, id = definition.id, revision = definition.revision,
        entryNode = current, rootNode = definition.entryNode, fallbackLocale = definition.fallbackLocale, nodes = {} }
    local queue, seen = { current }, { [current] = true }
    if current ~= definition.entryNode then queue[2], seen[definition.entryNode] = definition.entryNode, true end
    for i = 1, 32 do
        local id = queue[i]
        if not id then break end
        do
            local source = definition.nodes[id]
            local node = { id = id, texts = source.texts, options = {} }
            result.nodes[id] = node
            for _, option in ipairs(G.options(definition, id, flags)) do
                node.options[#node.options + 1] = G.publicOption(option)
                if not seen[option.nextNode] then
                    seen[option.nextNode] = true
                    queue[#queue + 1] = option.nextNode
                end
            end
        end
    end
    return result
end
function G.prepare(graph)
    -- SQL/Java validate bounds; retain a fresh outer definition for session pinning.
    return { graph = true, id = graph.id, revision = graph.revision, entryNode = graph.entryNode,
        fallbackLocale = graph.fallbackLocale, nodes = graph.nodes }
end
function G.label(option, fallback)
    return option.title or (option.textKey and getText(option.textKey)) or G.text(option.texts, G.locale(), fallback).title or ""
end
return G

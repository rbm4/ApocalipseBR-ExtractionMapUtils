if not isServer() then return end
require "ApocExtractionMapUtils_HumanDialogs"
local D = ApocExtractionMapUtils.HumanDialogs
D.actions = D.actions or {}

-- Installed server code owns actions. Database/client payloads never contain code.
function D.registerAction(id, callback)
    assert(type(id) == "string" and #id <= 100 and id:match("^[%w_.-]+$"), "Invalid action id")
    assert(type(callback) == "function" and not D.actions[id], "Invalid or duplicate action handler")
    D.actions[id] = callback
end

function D.executeAction(player, context, action)
    local fallback = { success = false, responsePool = action.responsePrefix .. ".unavailable", close = false }
    local handler = D.actions[action.id]
    if not handler then return fallback end
    local ok, result = pcall(handler, { player = player, npcKey = context.key, npcId = context.id,
        option = context.option, sequence = context.sequence })
    if not ok or type(result) ~= "table" or type(result.responsePool) ~= "string" then
        D.log("server", "action_failed", { action = action.id })
        return fallback
    end
    return result
end
return D

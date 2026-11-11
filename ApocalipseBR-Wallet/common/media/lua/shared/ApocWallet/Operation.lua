require "ApocWallet/Protocol"
local Operation = {}
local function noop() end

function Operation.copy(state)
    local result = {}
    for key, value in pairs(state) do result[key] = value end
    return result
end

function Operation.deliver(callback, state)
    if callback then pcall(callback, Operation.copy(state)) end
end

function Operation.new()
    return { listeners = {}, count = 0, settled = false }
end

function Operation.subscribe(operation, callback)
    if not callback then return noop end
    assert(type(callback) == "function", "Wallet callback must be a function")
    if operation.count >= 32 then
        Operation.deliver(callback, { status = "error", error = "CALLBACK_LIMIT" })
        return noop
    end
    local ticket = {}
    operation.listeners[ticket], operation.count = callback, operation.count + 1
    -- Unsubscribe only this observer; other callers still need the shared request.
    return function()
        if operation.listeners[ticket] then
            operation.listeners[ticket], operation.count = nil, operation.count - 1
        end
    end
end

function Operation.resolve(operation, state)
    if operation.settled then return end
    operation.settled = true
    local listeners = operation.listeners
    for ticket, callback in pairs(listeners) do
        listeners[ticket], operation.count = nil, operation.count - 1
        Operation.deliver(callback, state)
    end
    operation.listeners, operation.count = {}, 0
end

return Operation

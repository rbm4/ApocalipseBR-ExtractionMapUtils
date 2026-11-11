-- Reject before native complete() grants items or mutates the generator.
if not isServer() then return end
require "TimedActions/ISActivateGenerator"
require "TimedActions/ISPlugGenerator"
require "TimedActions/ISTakeGenerator"
local function managed(action)
    return action.generator and ApocBRManagedGenerators
        and ApocBRManagedGenerators.isManagedGenerator(action.generator)
end
local function wrap(class, blocked)
    local valid, complete = class.isValid, class.complete
    class.isValid = function(self, ...)
        if managed(self) and blocked(self) then return false end
        return valid(self, ...)
    end
    class.complete = function(self, ...)
        if managed(self) and blocked(self) then
            print("[ApocExtractionManagedGenerator] ACTION_REJECTED type=" .. tostring(self.Type))
            return false
        end
        return complete(self, ...)
    end
end
wrap(ISActivateGenerator, function(action) return action.activate ~= true end)
wrap(ISPlugGenerator, function(action) return action.plug ~= true end)
wrap(ISTakeGenerator, function() return true end)

local path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/server/"
function isServer() return true end
function require() end
local granted, changes = 0, 0
ISActivateGenerator = { isValid = function() return true end, complete = function() changes=changes+1; return true end }
ISPlugGenerator = { isValid = function() return true end, complete = function() changes=changes+1; return true end }
ISTakeGenerator = { isValid = function() return true end, complete = function() granted=granted+1; return true end }
ApocBRManagedGenerators = { isManagedGenerator = function(object) return object.managed == true end }
dofile(path .. "ApocExtractionMapUtils_ManagedGeneratorProtection.lua")
local managed, ordinary = { managed=true }, { managed=false }
assert(not ISActivateGenerator.isValid({generator=managed,activate=false}))
assert(not ISActivateGenerator.complete({generator=managed,activate=false}))
assert(not ISPlugGenerator.complete({generator=managed,plug=false}))
assert(not ISTakeGenerator.isValid({generator=managed}))
assert(not ISTakeGenerator.complete({generator=managed}))
assert(granted==0 and changes==0)
assert(ISActivateGenerator.complete({generator=managed,activate=true}))
assert(ISPlugGenerator.complete({generator=managed,plug=true}))
assert(ISTakeGenerator.complete({generator=ordinary}) and granted==1)
assert(ISActivateGenerator.complete({generator=ordinary,activate=false}))
assert(changes==3)
print("managed generator Lua protection tests passed")

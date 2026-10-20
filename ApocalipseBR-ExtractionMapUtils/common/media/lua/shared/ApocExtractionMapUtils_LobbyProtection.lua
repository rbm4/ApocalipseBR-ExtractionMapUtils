require "ApocExtractionMapUtils"
require "ApocExtractionMapUtils_LobbySettings"

local Utils = ApocExtractionMapUtils
if Utils.LobbyProtection then return end

-- These B42 classes are shared: complete() and scrap helpers also run on the
-- dedicated server. Do not install only in the client's OnGameStart event.
require "Moveables/ISMoveablesAction"
require "Moveables/ISMoveableSpriteProps"
require "TimedActions/ISDismantleAction"
require "TimedActions/ISDestroyStuffAction"
require "BuildingObjects/TimedActions/ISShovelGround"

local Protection = {}
Utils.LobbyProtection = Protection

function Protection.isProtectedPosition(x, y, z)
    local config = Utils.LobbyConfig
    if not Utils.lobbyEnabled() or z ~= config.Z or type(x) ~= "number" or type(y) ~= "number" then return false end
    local xmin, xmax = math.min(config.X1, config.X2), math.max(config.X1, config.X2)
    local ymin, ymax = math.min(config.Y1, config.Y2), math.max(config.Y1, config.Y2)
    -- Protect every interior square plus the actual east/south fence squares.
    -- The unused southeast diagonal square is outside the protected footprint.
    return (x >= xmin and x <= xmax and y >= ymin and y <= ymax)
        or (x == xmax + 1 and y >= ymin and y <= ymax)
        or (y == ymax + 1 and x >= xmin and x <= xmax)
end

function Protection.isProtectedSquare(square)
    return square ~= nil and Protection.isProtectedPosition(square:getX(), square:getY(), square:getZ())
end

local function protectedObject(object)
    return object and object.getSquare and Protection.isProtectedSquare(object:getSquare())
end

local function protectedProps(props)
    if not props then return false end
    if protectedObject(props.object) then return true end
    -- A multi-tile object selected outside can still have a member inside.
    if props.isMultiSprite and props.object and props.getSpriteGridInfo then
        local square = props.object:getSquare()
        local grid = square and props:getSpriteGridInfo(square, true)
        for _, member in ipairs(grid or {}) do
            if protectedObject(member.object) or Protection.isProtectedSquare(member.square) then return true end
        end
    end
    return false
end

function Protection.isProtectedAction(action)
    return action and (protectedObject(action.thumpable) or protectedObject(action.object)
        or protectedProps(action.moveProps) or Protection.isProtectedSquare(action.square)) or false
end

-- Pickup also removes chairs and floor tiles, and can break furniture for parts.
local destructiveModes = { scrap = true, dismantle = true, disassemble = true, pickup = true }
local function blockedMoveableAction(action)
    return destructiveModes[action.mode] and Protection.isProtectedAction(action)
end

local function wrapAction(class, blocked)
    local oldIsValid, oldComplete = class.isValid, class.complete
    class.isValid = function(self, ...)
        if blocked(self) then return false end
        return oldIsValid(self, ...)
    end
    class.complete = function(self, ...)
        if blocked(self) then return false end
        return oldComplete(self, ...)
    end
    -- Keep native perform() intact: B42 uses it to clean up highlights/sounds
    -- and advance the queue. World mutation is guarded in complete()/helpers.
end

wrapAction(ISMoveablesAction, blockedMoveableAction)
wrapAction(ISDismantleAction, Protection.isProtectedAction)
wrapAction(ISDestroyStuffAction, function(action)
    -- This class stores the WORLD target in item, not object/thumpable.
    return protectedObject(action.item)
end)
wrapAction(ISShovelGround, function(action)
    -- ISShovelGround.item is a boolean; sandTile is the world target.
    return protectedObject(action.sandTile)
end)

local oldShovelGround = ISShovelGround.shovelGround
ISShovelGround.shovelGround = function(self, square, ...)
    if protectedObject(self.sandTile) or Protection.isProtectedSquare(square) then return false end
    return oldShovelGround(self, square, ...)
end

local oldCanPickUp = ISMoveableSpriteProps.canPickUpMoveable
ISMoveableSpriteProps.canPickUpMoveable = function(self, character, square, object, ...)
    if protectedProps(self) or protectedObject(object) or Protection.isProtectedSquare(square) then return false end
    return oldCanPickUp(self, character, square, object, ...)
end

local oldPickupCursor = ISMoveableSpriteProps.pickUpMoveableViaCursor
ISMoveableSpriteProps.pickUpMoveableViaCursor = function(self, character, square, ...)
    if protectedProps(self) or Protection.isProtectedSquare(square) then return end
    return oldPickupCursor(self, character, square, ...)
end

local oldPickupInternal = ISMoveableSpriteProps.pickUpMoveableInternal
ISMoveableSpriteProps.pickUpMoveableInternal = function(self, character, square, object, sprInstance, spriteName, createItem, rotating, ...)
    -- Vanilla rotation reuses this helper with rotating=true and restores the
    -- object. Preserve it; ordinary pickup must stop before break tests/rewards.
    if not rotating and (protectedProps(self) or protectedObject(object) or Protection.isProtectedSquare(square)) then return end
    return oldPickupInternal(self, character, square, object, sprInstance, spriteName, createItem, rotating, ...)
end

local oldCanScrapInternal = ISMoveableSpriteProps.canScrapObjectInternal
ISMoveableSpriteProps.canScrapObjectInternal = function(self, result, object, ...)
    if protectedObject(object) or protectedProps(self) then
        if result then result.canScrap = false end
        return false
    end
    return oldCanScrapInternal(self, result, object, ...)
end

local oldScrapInternal = ISMoveableSpriteProps.scrapObjectInternal
ISMoveableSpriteProps.scrapObjectInternal = function(self, character, scrapDef, square, object, ...)
    if protectedObject(object) or Protection.isProtectedSquare(square) or protectedProps(self) then return 0 end
    return oldScrapInternal(self, character, scrapDef, square, object, ...)
end

-- ISThumpableSpriteProps overrides the base scrap implementation, so guard its
-- own entry points as well. These checks never touch native fence removal used
-- by the authorized RCON release command.
for _, class in ipairs({ ISMoveableSpriteProps, ISThumpableSpriteProps }) do
    local oldCanScrap, oldViaCursor, oldStart = class.canScrapObject, class.scrapObjectViaCursor, class.startScrapAction
    class.canScrapObject = function(self, ...)
        if protectedProps(self) then return { canScrap = false }, 0, nil end
        return oldCanScrap(self, ...)
    end
    class.scrapObjectViaCursor = function(self, character, square, ...)
        if protectedProps(self) or Protection.isProtectedSquare(square) then return end
        return oldViaCursor(self, character, square, ...)
    end
    class.startScrapAction = function(self, action, ...)
        if protectedProps(self) or Protection.isProtectedAction(action) then return false end
        return oldStart(self, action, ...)
    end
end

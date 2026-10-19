local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. package.path

local function square(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z or 0 end }
end
local function object(sq) return { getSquare = function() return sq end } end
local function props(sq) return { object = object(sq) } end
local inside = square(14280, 11840)
local outside = square(14259, 11840)

-- Shared hooks must load and reject work without any client-only startup event.
for _, realm in ipairs({ "client", "server" }) do
    ApocExtractionMapUtils = nil
    for _, name in ipairs({ "ApocExtractionMapUtils", "ApocExtractionMapUtils_LobbySettings" }) do package.loaded[name] = nil end
    function isClient() return realm == "client" end
    function isServer() return realm == "server" end
    local calls = {}
    local function native(name, result)
        return function(self, ...)
            calls[name] = (calls[name] or 0) + 1
            calls.args = { self, ... }
            return result, nil, "native-third-result"
        end
    end
    package.preload["Moveables/ISMoveablesAction"] = function()
        ISMoveablesAction = { isValid = native("valid", true), complete = native("complete", true), perform = native("cleanup", true) }
    end
    package.preload["TimedActions/ISDismantleAction"] = function()
        ISDismantleAction = { isValid = native("dismantleValid", true), complete = native("dismantleComplete", true), perform = native("dismantleCleanup", true) }
    end
    package.preload["Moveables/ISMoveableSpriteProps"] = function()
        ISMoveableSpriteProps = {
            canScrapObjectInternal = native("canInternal", true),
            scrapObjectInternal = native("scrapInternal", 7),
            canScrapObject = native("canBase", { canScrap = true }),
            scrapObjectViaCursor = native("cursorBase", 7),
            startScrapAction = native("startBase", true),
        }
        ISThumpableSpriteProps = {
            canScrapObject = native("canThump", { canScrap = true }),
            scrapObjectViaCursor = native("cursorThump", 7),
            startScrapAction = native("startThump", true),
        }
    end
    for _, name in ipairs({ "Moveables/ISMoveablesAction", "Moveables/ISMoveableSpriteProps", "TimedActions/ISDismantleAction" }) do package.loaded[name] = nil end
    dofile(media .. "shared/ApocExtractionMapUtils_LobbyProtection.lua")
    local protection = ApocExtractionMapUtils.LobbyProtection
    local config = ApocExtractionMapUtils.LobbyConfig
    assert(protection.isProtectedSquare(inside))
    for _, position in ipairs({ {14260,11812}, {14321,11892}, {14322,11812}, {14322,11892}, {14260,11893}, {14321,11893} }) do
        assert(protection.isProtectedSquare(square(position[1], position[2])), "all fence squares must be protected")
    end
    for _, sq in ipairs({ outside, square(14322,11893), square(14323,11840), square(14280,11811), square(14280,11894), square(14280,11840,1) }) do
        assert(not protection.isProtectedSquare(sq), "do not expand protection beyond the configured footprint/floor")
    end
    assert(not protection.isProtectedSquare(nil))
    local originalValid = ISMoveablesAction.isValid
    dofile(media .. "shared/ApocExtractionMapUtils_LobbyProtection.lua")
    assert(originalValid == ISMoveablesAction.isValid, "reload must not stack guards")

    for _, mode in ipairs({ "scrap", "dismantle", "disassemble" }) do
        local action = { square = inside, mode = mode, moveProps = props(inside) }
        assert(ISMoveablesAction.isValid(action) == false)
        assert(ISMoveablesAction.complete(action) == false)
        -- B42 perform owns queue/sound/highlight cleanup, not world deletion.
        assert(ISMoveablesAction.perform(action) == true)
    end
    assert(not calls.valid and not calls.complete, "blocked work must never reach native mutation")
    assert(calls.cleanup == 3)
    -- Trusted target position wins even when caller supplies an outside square.
    local forged = { square = outside, mode = "scrap", moveProps = props(inside) }
    assert(ISMoveablesAction.complete(forged) == false)
    local old = { thumpable = object(inside), square = outside }
    assert(ISDismantleAction.isValid(old) == false and ISDismantleAction.complete(old) == false)
    assert(ISDismantleAction.perform(old))
    assert(not calls.dismantleValid and not calls.dismantleComplete)

    for _, class in ipairs({ ISMoveableSpriteProps, ISThumpableSpriteProps }) do
        local p = props(inside)
        local result, chance = class.canScrapObject(p, {})
        assert(result.canScrap == false and chance == 0, "disassembly menu must see no permitted scrap action")
        assert(class.scrapObjectViaCursor(p, {}, outside) == nil)
        assert(class.startScrapAction(p, forged) == false)
    end
    local result = { canScrap = true }
    assert(ISMoveableSpriteProps.canScrapObjectInternal(props(outside), result, object(inside)) == false)
    assert(result.canScrap == false)
    assert(ISMoveableSpriteProps.scrapObjectInternal(props(outside), {}, {}, outside, object(inside), {}, 100, "MetalWelding") == 0)
    assert(not calls.scrapInternal, "direct welding completion must give no scrap, XP, fuel consumption or object removal")
    -- A multi-tile target selected outside must not dismantle its member inside.
    local multi = props(outside)
    multi.isMultiSprite = true
    multi.getSpriteGridInfo = function() return { { object = object(inside), square = inside } } end
    assert(ISMoveablesAction.complete({ mode = "scrap", square = outside, moveProps = multi }) == false)
    assert(ISMoveableSpriteProps.scrapObjectInternal(multi, {}, {}, outside, object(outside)) == 0)

    -- Outside target remains valid even when the character stands in the lobby.
    local allowed = { square = outside, mode = "scrap", moveProps = props(outside), character = object(inside) }
    local one, two, three = ISMoveablesAction.complete(allowed, "keep-argument")
    assert(one == true and two == nil and three == "native-third-result")
    assert(calls.args[1] == allowed and calls.args[2] == "keep-argument")
    assert(ISMoveablesAction.isValid(allowed))
    assert(ISDismantleAction.complete({ thumpable = object(outside) }))
    assert(ISMoveableSpriteProps.scrapObjectInternal(props(outside), {}, {}, outside, object(outside)) == 7)
    for _, class in ipairs({ ISMoveableSpriteProps, ISThumpableSpriteProps }) do
        assert(class.canScrapObject(props(outside), {}).canScrap)
        assert(class.scrapObjectViaCursor(props(outside), {}, outside) == 7)
        assert(class.startScrapAction(props(outside), allowed))
    end
    -- Protect only disassembly: ordinary interior activities still delegate.
    for _, mode in ipairs({ "repair", "pickup", "place", "rotate" }) do
        assert(ISMoveablesAction.complete({ square = inside, mode = mode, moveProps = props(inside) }))
    end
    -- Configuration is read dynamically on both sides, including custom bounds.
    config.Enabled = false
    assert(ISMoveablesAction.complete(forged))
    assert(ISDismantleAction.complete(old))
    config.Enabled = true
    config.X1, config.X2, config.Y1, config.Y2 = 210, 200, 310, 300
    assert(not protection.isProtectedSquare(inside) and protection.isProtectedSquare(square(205,305)))
    assert(ISMoveablesAction.complete(forged))
end
print("PASS: lobby disassembly client/server guards, all interior/perimeter squares, welding helpers, thumpable overrides, queued completion, multi-tile targets, trusted target bounds, native cleanup/returns, reload and disabled/outside behavior")

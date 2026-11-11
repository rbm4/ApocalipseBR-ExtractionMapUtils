require "ApocWallet/Protocol"
local Device = {}

function Device.data(device)
    if not device then return nil end
    local ok, data = pcall(function() return device:getDeviceData() end)
    return ok and data or nil
end

-- Adapted from RadioTraders RT_Shared radio identification. No equipment/money scans.
function Device.isRadio(device, data)
    if not device then return false end
    if not (instanceof(device, "Radio") or instanceof(device, "IsoWaveSignal")
        or instanceof(device, "VehiclePart")) then return false end
    data = data or Device.data(device)
    local ok, twoWay = pcall(function() return data and data:getIsTwoWay() end)
    return ok and twoWay == true
end

function Device.kind(device)
    if not instanceof(device, "InventoryItem") then return "ham" end
    local ok, fullType = pcall(function() return device:getFullType() end)
    fullType = ok and string.lower(fullType or "") or ""
    return (fullType:find("ham",1,true) or fullType:find("basestation",1,true)) and "ham" or "walkie"
end

-- Follow container ownership, including bags, without scanning inventory contents.
function Device.carriedBy(player, device)
    if not player or not instanceof(device,"InventoryItem") then return false end
    local ok, owned = pcall(function()
        local container = device:getContainer()
        return container ~= nil and container:getOutermostContainer() == player:getInventory()
    end)
    return ok and owned == true
end

function Device.square(device)
    local ok, square = pcall(function()
        if instanceof(device,"InventoryItem") then
            local world = device:getWorldItem()
            if world then return world:getWorldObjectIndex() >= 0 and world:getSquare() or nil end
            local container = device:getContainer()
            local outer = container and container:getOutermostContainer()
            local parent = outer and outer:getParent()
            -- Another character's inventory is not a public radio target.
            if parent and instanceof(parent,"IsoGameCharacter") then return nil end
            return outer and outer:getSquare() or nil
        elseif instanceof(device,"VehiclePart") then
            local vehicle = device:getVehicle()
            return vehicle and vehicle:getSquare() or nil
        end
        if device:getObjectIndex() < 0 then return nil end
        return device:getSquare()
    end)
    return ok and square or nil
end

function Device.canUse(player, device)
    if Device.carriedBy(player,device) then return true end
    local ok, reachable = pcall(function()
        if instanceof(device,"VehiclePart") and device:getVehicle()
            and player:getVehicle() == device:getVehicle() then return true end
        local square = Device.square(device)
        local here = player:getCurrentSquare()
        -- Match native luautils.walkAdj's near check, including walls/doors/Z.
        return square ~= nil and here ~= nil
            and math.abs(square:getX()+0.5-player:getX()) <= 1.6
            and math.abs(square:getY()+0.5-player:getY()) <= 1.6
            and here:canReachTo(square)
    end)
    return ok and reachable == true
end

return Device

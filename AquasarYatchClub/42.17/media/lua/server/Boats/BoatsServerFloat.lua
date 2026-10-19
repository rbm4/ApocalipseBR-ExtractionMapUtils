require 'AquaSwimShared'

-- Multiplayer: the server has no Bullet world. A boat it creates (natural spawn, launch from a trailer, load of
-- a boat nobody has driven yet) keeps the vanilla spawn height, wheels or hull on the land floor
-- (CarController: yacht 0.00 m, BoatMotor 0.23 m), about 2 m under its waterline. The server saves that height
-- and sends it to the clients, which show the boat there: a parked boat is not theirs to simulate.
-- Single player never sees it: Bullet lifts the hull onto the water blocks as soon as the boat exists.
-- Here the boat is put at the height where it rests afloat in single player (debugZ, bench 2026-10-12).
-- OnSpawnVehicleEnd is fired by BaseVehicle.createPhysics, on the server too, for a new vehicle and for one
-- loaded from vehicles.db, before any client receives it.
local FLOAT_Z = {
    BoatSailingYacht = 0.80,
    BoatMotor = 0.89,
    AMC_Waverunner = 0.93,--Autotsar Motorclub jet-ski (boat of AquaConfig)
}

local function onSpawnVehicleEnd(vehicle)
    if not isServer() or not vehicle then return end
    local script = vehicle:getScript()
    local floatZ = script and FLOAT_Z[script:getName()]
    if not floatZ or vehicle:getDebugZ() >= floatZ - 0.1 then return end
    local square = getCell():getGridSquare(vehicle:getX(), vehicle:getY(), 0)
    if not AquatsarYachts.Swim.isWater(square) then return end
    vehicle:setDebugZ(floatZ)
end

Events.OnSpawnVehicleEnd.Add(onSpawnVehicleEnd)

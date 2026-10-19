--*************************************************************
--**              Developers: IBrRus n Aiteron               **
--*************************************************************

require 'AquaConfig'

if AquaPhysics == nil then AquaPhysics = {} end
AquaPhysics.Utils = {}
AquaPhysics.Wind = {}
AquaPhysics.Water = {}

-----------------------------
-- Util variables/functions
-----------------------------

local tempVec1 = Vector3f.new()
local tempVec2 = Vector3f.new()
local tempIsoObj = IsoObject.new()
local tempSquare = IsoGridSquare.new(getCell(), nil, 0, 0, 0)

local frontVector = Vector3f.new()
local rearVector = Vector3f.new()
local collisionPosVector2 = Vector3.fromLengthDirection(1, 1)
local boatDirVector = Vector3f.new()

-------------------------------------
-- Pushes
-------------------------------------
-- BaseVehicle.addImpulse keeps ONE pending impulse per vehicle: a second, stronger one in the same frame
-- cancels both, a weaker one is dropped. The pending impulse is then applied during a single 10 ms
-- physics substep, whatever the frame length. So every push of a frame is summed here (force, and torque
-- about the centre of mass), sent once by AquaPhysics.flushPushes, and scaled by the frame length
-- (frameScale = 1 at 60 fps, the frame rate the forces were tuned at).
-- Vectors are in Bullet axes: x = iso x, y = up, z = iso y; relPos is relative to the vehicle centre.

local pushes = {}
local frameScale = 1
local frameNumber = 0
local pushForce = Vector3f.new()
local pushRelPos = Vector3f.new()

function AquaPhysics.beginFrame()
    frameScale = getGameTime():getPhysicsSecondsSinceLastUpdate() * 60
    frameNumber = frameNumber + 1
end

function AquaPhysics.getFrameScale()
    return frameScale
end

local function addPush(boat, fx, fy, fz, relPos)
    local p = pushes[boat]
    if not p then
        p = { fx = 0, fy = 0, fz = 0, tx = 0, ty = 0, tz = 0 }
        pushes[boat] = p
    end
    p.fx, p.fy, p.fz = p.fx + fx, p.fy + fy, p.fz + fz
    if relPos then--torque = relPos x force (BaseVehicle.update)
        local rx, ry, rz = relPos:x(), relPos:y(), relPos:z()
        p.tx = p.tx + ry * fz - rz * fy
        p.ty = p.ty + rz * fx - rx * fz
        p.tz = p.tz + rx * fy - ry * fx
    end
end

-- force per 60 fps frame, scaled to the current frame length
function AquaPhysics.push(boat, force, relPos)
    addPush(boat, force:x() * frameScale, force:y() * frameScale, force:z() * frameScale, relPos)
end

-- force for the next physics substep only (not scaled)
function AquaPhysics.pushNow(boat, force, relPos)
    addPush(boat, force:x(), force:y(), force:z(), relPos)
end

-- One addImpulse per boat. A torque can only be sent as relPos x force: relPos = (F x T) / |F|^2, exact
-- when T is perpendicular to F (horizontal forces with horizontal lever arms). A pure couple (rotation in
-- place: forces summing to ~0) gets a 1 N horizontal carrier force with a long lever arm.
function AquaPhysics.flushPushes()
    for boat, p in pairs(pushes) do
        local fx, fy, fz, tx, ty, tz = p.fx, p.fy, p.fz, p.tx, p.ty, p.tz
        local rx, ry, rz = 0, 0, 0
        if tx * tx + ty * ty + tz * tz > 1e-6 then
            local f2 = fx * fx + fy * fy + fz * fz
            if f2 < 1 then
                if math.abs(ty) >= math.abs(tx) then fx = fx + 1 else fz = fz + 1 end
                f2 = fx * fx + fy * fy + fz * fz
            end
            rx = (fy * tz - fz * ty) / f2
            ry = (fz * tx - fx * tz) / f2
            rz = (fx * ty - fy * tx) / f2
        end
        pushForce:set(fx, fy, fz)
        pushRelPos:set(rx, ry, rz)
        boat:setPhysicsActive(true)
        boat:addImpulse(pushForce, pushRelPos)
    end
    pushes = {}
end

function AquaPhysics.Wind.getWindSpeed()
    return getClimateManager():getWindspeedKph()
end

-- function AquaPhysics.Wind.fromWindDirection()    
    -- local angle = getClimateManager():getWindAngleDegrees()    
    -- local windAngles = { 22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5, 382.5 }    
    -- local windAngleStr = { "N", "NW", "W", "SW", "S", "SE", "E", "NE", "N" }    
    -- for b = 1, #windAngles do    
        -- if (angle < windAngles[b]) then    
            -- return windAngleStr[b]    
        -- end    
    -- end    
    -- return windAngleStr[#windAngleStr - 1];    
-- end

function AquaPhysics.Wind.inWindDirection()
    local angle = getClimateManager():getWindAngleDegrees()
    local windAngles = { 22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5, 382.5 }
    local windAngleStr = { "S", "SE", "E", "NE", "N", "NW", "W", "SW", "S" }
    for b = 1, #windAngles do
        if (angle < windAngles[b]) then
            return windAngleStr[b]
        end
    end
    return windAngleStr[#windAngleStr - 1];
end

-------------------------------------
-- Water Physics
-------------------------------------

function AquaPhysics.Water.getCollisionSquaresAround(dx, dy, square)
    local squares = {}
    if square == nil then return squares end
    
    local refX = square:getX()
    local refY = square:getY()
    --local refZ = square:getZ()
    for y=refY - dy, refY + dy do
        for x=refX - dx, refX + dx do
            local square2 = getCell():getGridSquare(x, y, 0)--TODO refZ
            if square2 and not AquatsarYachts.Swim.isWater(square2) then
                table.insert(squares, square2)
            end
        end
    end
    return squares
end

-- Shore bumper. For physics the water squares are solid blocks and the land/pier floors are lower: a boat
-- going over the edge drops, tilts and gets stuck. For the land squares the hull touches, n = unit vector
-- land -> boat; when the boat moves towards them (v.n < 0) the push removes that approach speed in the
-- next physics substep. Nothing pushes the boat away from the shore otherwise.
-- getLinearVelocity is one frame late on the pushes: in the frame after a bump it still shows the approach
-- speed the bump is removing. That speed is deducted, else the boat is pushed twice and bounces back as
-- fast as it came (motor boat: 34 km/h in, -34 km/h out).
local bumperVel = Vector3f.new()
local bumperForce = Vector3f.new()
local bumperPending = {}--[boat] = { frame, dv (m/s removed), nx, ny }
function AquaPhysics.Water.Borders(boat)
    local boatSquare = boat:getSquare()
    if AquatsarYachts.Swim.isWater(boatSquare) then
        local notWaterSquares = AquaPhysics.Water.getCollisionSquaresAround(5, 5, boatSquare)
        local nx, ny = 0, 0
        local collisionWithGround = false
        for _, square in ipairs(notWaterSquares) do
            tempSquare:setX(square:getX())
            tempSquare:setY(square:getY())
            tempSquare:setZ(0.8)
            tempIsoObj:setSquare(tempSquare)
            if boat:testCollisionWithObject(tempIsoObj, 0.5, collisionPosVector2) then
                collisionWithGround = true
                local dx = boat:getX() - (square:getX() + 0.5)
                local dy = boat:getY() - (square:getY() + 0.5)
                local d = math.sqrt(dx * dx + dy * dy)
                if d > 0.01 then
                    nx, ny = nx + dx / d, ny + dy / d
                end
            end
        end
        local n = math.sqrt(nx * nx + ny * ny)
        if n > 0.01 then
            nx, ny = nx / n, ny / n
            local v = boat:getLinearVelocity(bumperVel)
            local approach = v:x() * nx + v:z() * ny
            local pending = bumperPending[boat]
            if pending and pending.frame == frameNumber - 1 then
                approach = approach + pending.dv * (pending.nx * nx + pending.ny * ny)
            end
            bumperPending[boat] = nil
            if approach < 0 then
                local f = -approach * boat:getMass() / 0.01
                bumperForce:set(nx * f, 0, ny * f)
                AquaPhysics.pushNow(boat, bumperForce, nil)
                bumperPending[boat] = { frame = frameNumber, dv = -approach, nx = nx, ny = ny }
            end
        else
            bumperPending[boat] = nil
        end
        return collisionWithGround
    end
end

-------------------------------------
-- Wind Physics
-------------------------------------

function AquaPhysics.Wind.windImpulse(boat, collisionWithGround)
    local boatScriptName = boat:getScript():getName()
    local boatSpeedKPH = boat:getCurrentSpeedKmHour()
    boat:getAttachmentWorldPos("trailerfront", frontVector)
    boat:getAttachmentWorldPos("trailer", rearVector)
    local x = frontVector:x() - rearVector:x()
    local y = frontVector:y() - rearVector:y()
    local windSpeedKPH = AquaPhysics.Wind.getWindSpeed()

    -- AUD.insp("Boat", "boatSpeed (MPH):", boat:getCurrentSpeedKmHour() / 1.60934)
    -- AUD.insp("Boat", " ", " ")
    boatDirVector:set(x, 0, y):normalize()
    -- boatDirVector = boat:getWorldPos(0, 0, 1, boatDirVector):add(-boat:getX(), -boat:getY(), -boat:getZ())
    -- boatDirVector:set(boatDirVector:x(), 0, boatDirVector:y())
    -- boatDirVector:normalize()
    local boatDirection = math.atan2(x,y) * 57.2958 + 180
    local sailAngle = boat:getModData()["sailAngle"]
    local sails = boat:getPartById("Sails")
    if sailAngle == nil then
        sailAngle = 0
        boat:getModData()["sailAngle"] = 0
    end
    
    local wind = getClimateManager():getWindAngleDegrees()
    local windOnBoat = 0
    if wind > boatDirection then
        windOnBoat = wind - boatDirection
    else
        windOnBoat = 360 - (boatDirection - wind)
    end
    
    local windForceByDirection = 0
    if windSpeedKPH < AquaConfig.windVeryLight then
        windForceByDirection = 0
    elseif windSpeedKPH < AquaConfig.windLight then
        if windOnBoat > 85 and windOnBoat < 275 then
            windForceByDirection = 7 * math.sqrt(1 * math.cos(math.rad(2*(windOnBoat + 90))) + 1.3) * AquaConfig.Boats[boatScriptName].windInfluence
        end
    elseif windSpeedKPH < AquaConfig.windMedium then
        if windOnBoat > 20 and windOnBoat < 340 then
            windForceByDirection = 10 * math.sqrt(1 * math.cos(math.rad(2*(windOnBoat + 90))) + 1.3) * AquaConfig.Boats[boatScriptName].windInfluence
        end
    elseif windSpeedKPH < AquaConfig.windStrong then
        if windOnBoat > 20 and windOnBoat < 340 then
            windForceByDirection = 12 * math.sqrt(1 * math.cos(math.rad(2*(windOnBoat + 90))) + 1.3) * AquaConfig.Boats[boatScriptName].windInfluence
        end
    elseif windSpeedKPH < AquaConfig.windVeryStrong then
        if windOnBoat > 85 and windOnBoat < 275 then
            windForceByDirection = 14 * math.sqrt(1 * math.cos(math.rad(2*(windOnBoat + 90))) + 1.3) * AquaConfig.Boats[boatScriptName].windInfluence
        end
    else
        if windOnBoat > 100 and windOnBoat < 260 then
            windForceByDirection = 15 * math.sqrt(1 * math.cos(math.rad(2*(windOnBoat + 90))) + 1.3) * AquaConfig.Boats[boatScriptName].windInfluence
        end
    end
    
    -- AUD.insp("Boat", "windSpeedKPH (MPH):", windSpeedKPH / 1.60934)
    -- AUD.insp("Boat", "windForceByDirection154:", windForceByDirection)
    local coefficientSailAngle = 0
    local requiredSailAngle = 0
    if windOnBoat >= 150 and windOnBoat <= 210 then
        if sails:getModData().sailCode == 1 and sailAngle < 0 then
            windForceByDirection = windForceByDirection * (sailAngle / -90)
            requiredSailAngle = "Any < 0"
        elseif sails:getModData().sailCode == 2 and sailAngle > 0 then
            windForceByDirection = windForceByDirection * (sailAngle / 90)
            requiredSailAngle = "Any > 0"
        else 
            windForceByDirection = 0
            requiredSailAngle = "Another direction"
        end
    elseif windOnBoat < 150 and sails:getModData().sailCode == 2 and sailAngle < 0 then
        requiredSailAngle = windOnBoat/2
        local deltaAngle = math.abs(sailAngle) - requiredSailAngle
        if deltaAngle > 10 then
            local y2 = 0.44
            local x2 = requiredSailAngle+10
            local x1 = 90
            local y1 = 0
            local m = y2/(x2-x1)
            coefficientSailAngle = m * (math.abs(sailAngle)-90)
        elseif deltaAngle < -10 then
            local y2 = 0.44
            local x2 = requiredSailAngle - 10
            if x2 <= 0 then x2 = 0.01 end
            local m = y2/x2
            coefficientSailAngle = m * math.abs(sailAngle)
        else
            coefficientSailAngle = -0.005 * deltaAngle^2 + 1
        end
        if coefficientSailAngle > 0 then
            windForceByDirection = coefficientSailAngle * windForceByDirection
        else
            windForceByDirection = 0
        end
    elseif windOnBoat > 210 and sails:getModData().sailCode == 1 and sailAngle > 0 then
        requiredSailAngle = (360 - windOnBoat)/2
        local deltaAngle = math.abs(sailAngle) - requiredSailAngle
        if deltaAngle > 10 then
            local y2 = 0.44
            local x2 = requiredSailAngle+10
            local x1 = 90
            local y1 = 0
            local m = y2/(x2-x1)
            coefficientSailAngle = m * (math.abs(sailAngle)-90)
        elseif deltaAngle < -10 then
            local y2 = 0.44
            local x2 = requiredSailAngle - 10
            if x2 <= 0 then x2 = 0.01 end
            local m = y2/x2
            coefficientSailAngle = m * math.abs(sailAngle)
        else
            coefficientSailAngle = -0.005 * deltaAngle^2 + 1
        end
        if coefficientSailAngle > 0 then
            windForceByDirection = coefficientSailAngle * windForceByDirection
        else
            windForceByDirection = 0
        end
    else
        windForceByDirection = 0
        requiredSailAngle = "Another direction"
    end
    
    -- AUD.insp("Boat", "Name: ", boatScriptName)
    -- AUD.insp("Boat", "Boat Speed: ", boatSpeedKPH)
    -- AUD.insp("Boat", "Mass: ", boat:getMass())
    -- AUD.insp("Boat", " ", " ")        
    -- AUD.insp("Boat", "windOnBoat:", windOnBoat)
    -- AUD.insp("Boat", "SailAngle:", sailAngle)
    -- AUD.insp("Boat", "RequiredSailAngle (absolute value):", requiredSailAngle)
    -- AUD.insp("Boat", "coefficientSailAngle:", coefficientSailAngle)
    -- AUD.insp("Boat", "windForceByDirection:", windForceByDirection)
    --print("Boat wind internals", " Name=", boatScriptName, " getDebugZ=", boat:getDebugZ(), " BoatSpeed=", boatSpeedKPH, " BoatMass=", boat:getMass(), " windOnBoat=", tostring(windOnBoat), " sailAngle=", tostring(sailAngle), " requiredSailAngle=", tostring(requiredSailAngle), " coefficientSailAngle=", tostring(coefficientSailAngle), " windForceByDirection=", tostring(windForceByDirection))
    
    boat:getAttachmentWorldPos("checkFront", frontVector)
    
    local savedWindForce = boat:getModData()["windForceByDirection"]
    if savedWindForce == nil then
        savedWindForce = 0
    end

    -- only the local driver's Backward key furls this boat's sail
    local driver = boat:getDriver()
    local backward = driver and instanceof(driver, "IsoPlayer") and driver:isLocalPlayer() and isKeyDown(getCore():getKey("Backward"))
    if backward then
        savedWindForce = 0
    elseif collisionWithGround then
        savedWindForce = 0
    elseif savedWindForce < windForceByDirection then
        savedWindForce = (savedWindForce + 0.2 * frameScale)
    elseif savedWindForce >= windForceByDirection then
        savedWindForce = (savedWindForce - 0.08 * frameScale)
    end
    
    boat:getModData()["windForceByDirection"] = savedWindForce
    -- AUD.insp("Boat", "savedWindForce:", savedWindForce)

    local squareFrontVehicle = getCell():getGridSquare(frontVector:x(), frontVector:y(), 0)
    local doWindImpulse = false
    if AquatsarYachts.Swim.isWater(squareFrontVehicle) then
        if savedWindForce > 1 and boatSpeedKPH < (savedWindForce * 1.60934) and boatSpeedKPH < windSpeedKPH and not backward then
            -- print("squareFrontVehicle")
            local startCoeff = 1
            if boatSpeedKPH < 5 * 1.60934 then
                startCoeff = 10
            end
            if collisionWithGround then 
                boatDirVector:mul(150 * savedWindForce)
            else
                boatDirVector:mul(1000 * savedWindForce * startCoeff)
            end
            AquaPhysics.push(boat, boatDirVector, nil)
            --print("Boat Force DirVector", " x=", boatDirVector:x(), " z=", boatDirVector:y(), " y=", boatDirVector:z())
            doWindImpulse = true
        end
    end
    if not doWindImpulse then
        --print("Boat no wind impulse", " savedWindForce=", savedWindForce, " boatSpeedKPH=", boatSpeedKPH, " windSpeedKPH=", windSpeedKPH, " isWater(squareFrontVehicle)=", tostring(squareFrontVehicle ~= nil and isWater(squareFrontVehicle)))
    end
    -- if boat:getDriver() then -- TODO исправить для онлайна
        -- if isKeyDown(getCore():getKey("Left")) then
            -- -- boat:update()
            -- forceVector = boat:getWorldPos(-1, 0, 0, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ())
            -- forceVector:mul(4000)
            -- forceVector:set(forceVector:x(), 0, forceVector:y())
            
            -- boat:getWorldPos(0, 0, -3, tempVec2):add(-boat:getX(), -boat:getY(), -boat:getZ())
            -- tempVec2:set(tempVec2:x(), tempVec2:z(), tempVec2:y())
            -- boat:addImpulse(forceVector, tempVec2)   
        -- elseif isKeyDown(getCore():getKey("Right")) then
            -- -- boat:update()
            -- forceVector = boat:getWorldPos(1, 0, 0, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ())
            -- forceVector:mul(4000)
            -- forceVector:set(forceVector:x(), 0, forceVector:y())
            
            -- boat:getWorldPos(0, 0, -3, tempVec2):add(-boat:getX(), -boat:getY(), -boat:getZ())
            -- tempVec2:set(tempVec2:x(), tempVec2:z(), tempVec2:y())
            -- boat:addImpulse(forceVector, tempVec2)
        -- end
    -- end
end


-------------------------------------
-- Physics
-------------------------------------

function AquaPhysics.boatEngineShutDownOnGround(veh)
    local sq = veh:getSquare()
    if sq and not AquatsarYachts.Swim.isWater(sq) then
        if veh:isEngineRunning() then
            veh:engineDoStalling()
        end
    end
end

function AquaPhysics.inertiaFix(boat)    
    if AquatsarYachts.Swim.isWater(boat:getSquare()) then
        local speed = math.abs(boat:getCurrentSpeedKmHour())
        if speed < 1 then
            boat:setMass(100)
        elseif speed < 10 then
            boat:setMass(100*speed)
        else
            if boat:getMass() ~= 1000 then 
                boat:setMass(1000)
            end
        end
    end
end

-- The reverse speed is limited by the vanilla maxSpeedReverse of the boat scripts (42.17/media/scripts):
-- CarController.control_Reverse cuts the engine below -maxSpeedReverse / 1.5 km/h. The former
-- reverseSpeedFix pushed with at most ~5900 per frame and let the yacht reach -19 km/h (limit 6).

function AquaPhysics.heightFix(character, boat)
    -- print("AquaPhysics.heightFix")
    local squareUnderVehicle = getCell():getGridSquare(boat:getX(), boat:getY(), 0)
    -- AUD.insp("Boat", "getDebugZ:", boat:getDebugZ())
    if squareUnderVehicle ~= nil then
        if AquatsarYachts.Swim.isWater(squareUnderVehicle) then
            -- AUD.insp("Boat", "getDebugZ:", boat:getDebugZ())
            if boat:getDebugZ() < 0.30 and math.abs(boat:getCurrentSpeedKmHour()) < 2 then --0.62
                tempVec1:set(0, 5000, 0)
                AquaPhysics.push(boat, tempVec1, nil)
            end
            return true
        else
            sendClientCommand(character, 'aquatsar', 'boatOnGround', {boat = boat:getId(), })
            return false
        end
    else
        --print("squareUnderVehicle = nil")
        return false
    end
end

function AquaPhysics.addImpulseGetWorldPos(boat, force)
    tempVec1:set(0, 0, 0)
    local forceVector = boat:getWorldPos(0, 0, 1, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ())
    
    -- AUD.insp("Boat", "addImpulseGetWorldPos:", forceVector:x(),   forceVector:y())
    forceVector:mul(force)
    -- AUD.insp("Boat", "addImpulseGetWorldPosforce:", forceVector:x(), forceVector:y())
    forceVector:set(forceVector:x(), 0, forceVector:y())
    tempVec2:set(0, 0, 0)
    boat:addImpulse(forceVector, tempVec2)
end

function AquaPhysics.addImpulseXY(boat, force)
    frontVector:set(0,0,0)
    rearVector:set(0,0,0)
    boat:getAttachmentWorldPos("trailerfront", frontVector)
    boat:getAttachmentWorldPos("trailer", rearVector)
    local x = frontVector:x() - rearVector:x()
    local y = frontVector:y() - rearVector:y()
    local forceVector = boatDirVector
    
    -- AUD.insp("Boat", "addImpulseXY:", forceVector:x(),   forceVector:y())
    forceVector:mul(force)
    -- AUD.insp("Boat", "addImpulseXYforce:", forceVector:x(), forceVector:y())
    forceVector:set(forceVector:x(), 0, forceVector:y())
    tempVec2:set(0, 0, 0)
    boat:addImpulse(forceVector, tempVec2)
end


function AquaPhysics.waterFlowRotation(boat, force, playerObj)
    if not playerObj or not (boat:getDriver() == playerObj) then return end
    if boat:getDriver() and boat:getPartById("Propeller") and boat:getPartById("Propeller"):getInventoryItem() and (not boat:getPartById("BoatAnchor") or not boat:getPartById("BoatAnchor"):getInventoryItem()) then
        local lenHalf = boat:getScript():getPhysicsChassisShape():z()/2
        if isKeyDown(getCore():getKey("Right")) and 
                not isKeyDown(getCore():getKey("Forward")) and 
                not isKeyDown(getCore():getKey("Backward")) then
            -- bow pushed one way, stern the other: a couple, summed with the frame's other pushes
            local forceVector = boat:getWorldPos(-1, 0, 0, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ())
            local pushPoint = boat:getWorldPos(0, 0, lenHalf, tempVec2):add(-boat:getX(), -boat:getY(), -boat:getZ())
            pushPoint:set(pushPoint:x(), 0, pushPoint:y())

            forceVector:mul(force)
            forceVector:set(forceVector:x(), 0, forceVector:y())
            AquaPhysics.push(boat, forceVector, pushPoint)

            local forceVector = boat:getWorldPos(1, 0, 0, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ())
            local pushPoint = boat:getWorldPos(0, 0, -lenHalf, tempVec2):add(-boat:getX(), -boat:getY(), -boat:getZ())
            pushPoint:set(pushPoint:x(), 0, pushPoint:y())

            forceVector:mul(force)
            forceVector:set(forceVector:x(), 0, forceVector:y())
            AquaPhysics.push(boat, forceVector, pushPoint)

        elseif isKeyDown(getCore():getKey("Left")) and
                not isKeyDown(getCore():getKey("Forward")) and
                not isKeyDown(getCore():getKey("Backward")) then
            local forceVector = boat:getWorldPos(1, 0, 0, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ())
            local pushPoint = boat:getWorldPos(0, 0, lenHalf, tempVec2):add(-boat:getX(), -boat:getY(), -boat:getZ())
            pushPoint:set(pushPoint:x(), 0, pushPoint:y())

            forceVector:mul(force)
            forceVector:set(forceVector:x(), 0, forceVector:y())
            AquaPhysics.push(boat, forceVector, pushPoint)

            local forceVector = boat:getWorldPos(-1, 0, 0, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ())
            local pushPoint = boat:getWorldPos(0, 0, -lenHalf, tempVec2):add(-boat:getX(), -boat:getY(), -boat:getZ())
            pushPoint:set(pushPoint:x(), 0, pushPoint:y())

            forceVector:mul(force)
            forceVector:set(forceVector:x(), 0, forceVector:y())
            AquaPhysics.push(boat, forceVector, pushPoint)
        end
    end
end

-------------------------------------
-- Unstick
-------------------------------------
-- For Bullet the water squares are solid blocks. At low speed a wheel row can settle on the seam between
-- two blocks, where its ray finds no support: that end sinks, the hull rubs on the blocks and the engine
-- (driving through the other wheels) no longer moves the boat (bench: debugZ 0.59-0.70 instead of 0.80,
-- pitch or roll 8-12 deg, at most 2-3 km/h under full throttle). While the driver accelerates and the boat
-- stays slow and low, it is pushed along its axis: a few centimetres take the wheel off the seam.
local UNSTICK_FORCE = 15000--per 60 fps frame; bench: frees the 548 kg yacht in under a second
local FLOAT_Z = { BoatSailingYacht = 0.80, BoatMotor = 0.90 }--debugZ afloat (bench)
local unstickFront = Vector3f.new()
local unstickRear = Vector3f.new()
local unstickDir = Vector3f.new()
function AquaPhysics.unstick(boat, playerObj, collisionWithGround)
    if collisionWithGround or not playerObj or boat:getDriver() ~= playerObj or not boat:isEngineRunning() then return end
    local floatZ = FLOAT_Z[boat:getScript():getName()]
    if not floatZ or boat:getDebugZ() > floatZ - 0.07 then return end
    if math.abs(boat:getCurrentSpeedKmHour()) > 3 then return end
    local propeller = boat:getPartById("Propeller")
    if not propeller or not propeller:getInventoryItem() then return end
    local dir = 0
    if isKeyDown(getCore():getKey("Forward")) then
        dir = 1
    elseif isKeyDown(getCore():getKey("Backward")) then
        dir = -1
    end
    if dir == 0 then return end
    boat:getAttachmentWorldPos("trailerfront", unstickFront)
    boat:getAttachmentWorldPos("trailer", unstickRear)
    unstickDir:set(unstickFront:x() - unstickRear:x(), 0, unstickFront:y() - unstickRear:y())
    if unstickDir:length() < 0.01 then return end
    unstickDir:normalize():mul(UNSTICK_FORCE * dir)
    AquaPhysics.push(boat, unstickDir, nil)
end

-------------------------------------
-- Control
-------------------------------------

function AquaPhysics.changeSailAngle(boat, playerObj)
    if not playerObj or not (boat:getDriver() == playerObj) then return end
    local sailAngle = boat:getModData()["sailAngle"]
    if sailAngle == nil then
        sailAngle = 0
        boat:getModData()["sailAngle"] = 0
    end
    if isKeyDown(Keyboard.KEY_LEFT) then
        if sailAngle < 90 then
            sailAngle = math.min(90, sailAngle + 0.5 * frameScale)
        end
        boat:getModData()["sailAngle"] = sailAngle
        playerObj:getStats():remove(CharacterStat.ENDURANCE, 0.0005 * frameScale)--TODO move stats server side
    elseif isKeyDown(Keyboard.KEY_RIGHT) then
        if sailAngle > -90 then
            sailAngle = math.max(-90, sailAngle - 0.5 * frameScale)
        end
        boat:getModData()["sailAngle"] = sailAngle
        playerObj:getStats():remove(CharacterStat.ENDURANCE, 0.0005 * frameScale)--TODO move stats server side
    end
end

function AquaPhysics.stopByAnchor(vehicle, force)   
    local linearVel = vehicle:getLinearVelocity(tempVec1)
    tempVec2:set(linearVel:x(), linearVel:z(), linearVel:y())   

    tempVec1:set(tempVec2:x(), 0, tempVec2:y())
    if tempVec1:length() > 1 then 
        tempVec1:normalize()
    end

    tempVec1:mul(-force)
    AquaPhysics.push(vehicle, tempVec1, nil)
 end

local function dirTest (boat)
    boat:getAttachmentWorldPos("trailerfront", frontVector)
    boat:getAttachmentWorldPos("trailer", rearVector)
    local x = frontVector:x() - rearVector:x()
    local y = frontVector:y() - rearVector:y()
    -- AUD.insp("Boat", "frontVector:", frontVector:x(), frontVector:y())
    -- AUD.insp("Boat", "rearVector:", rearVector:x(), rearVector:y())
    local boatDirection = math.atan2(x,y) * 57.2958 + 180
    -- AUD.insp("Boat", "boatDirection:", boatDirection)
    boatDirVector:set(x, 0, y):normalize()
    -- AUD.insp("Boat", "boatDirVector:", boatDirVector:x(),   boatDirVector:z())
    boatDirVector = boat:getWorldPos(0, 0, 1, tempVec1):add(-boat:getX(), -boat:getY(), -boat:getZ()):normalize()
    -- AUD.insp("Boat", "getWorldPos:", boatDirVector:x(),  boatDirVector:y())
    boatDirVector = boat:getLocalPos(boatDirVector, tempVec2):normalize()
    -- AUD.insp("Boat", "getLocalPos:", boatDirVector:x(), boatDirVector:y(), boatDirVector:z())
    boatDirVector = boat:getLinearVelocity(tempVec2):normalize()
    -- AUD.insp("Boat", "getLinearVelocity:", boatDirVector:x(), boatDirVector:z())
    
end


function AquaPhysics.updateVehicles()
    AquaPhysics.beginFrame()
    local vehicles = getCell():getVehicles()
    if vehicles then
        local iterator = vehicles:iterator()
        if iterator then
            while iterator:hasNext() do
                local boat = iterator:next()
                local boatInfo = boat and AquaConfig.Boat(boat)
                if boatInfo and not boatInfo.onGround then
                    -- dirTest (boat)
                    local collisionWithGround = AquaPhysics.Water.Borders(boat)
                    if AquaPhysics.heightFix(getSpecificPlayer(0), boat) then
                        -- AquaPhysics.inertiaFix(boat)
                        local sails = boat:getPartById("Sails")
                        local anchor = boat:getPartById("BoatAnchor")
                        if sails and sails:getInventoryItem() then--sails part installed
                            local light = sails and sails:getLight()
                            if light and light:getActive() and (not anchor or not anchor:getInventoryItem()) then--sails up and no anchor down
                                AquaPhysics.Wind.windImpulse(boat, collisionWithGround)
                           end
                            AquaPhysics.changeSailAngle(boat, getSpecificPlayer(0))
                        end
                        
                        -- if math.abs(boat:getCurrentSpeedKmHour()) < 4 then
                            AquaPhysics.waterFlowRotation(boat, 2000, getSpecificPlayer(0))
                        -- end
                        AquaPhysics.unstick(boat, getSpecificPlayer(0), collisionWithGround)
                        
                        if anchor and anchor:getInventoryItem() then 
                            AquaPhysics.stopByAnchor(boat, 5000) 
                        end
                        AquaPhysics.boatEngineShutDownOnGround(boat)
                    end
                end
            end
        end
    end
    AquaPhysics.flushPushes()
end

function AquaPhysics.updateBoatMP()
-- print("AquaPhysics.updateBoatMP()")
    local character = getPlayer()
    local boat = character:getVehicle()
    local boatInfo = AquaConfig.Boat(boat)
    if boatInfo and not boatInfo.onGround then
        -- физикой лодки управляет один пассажир. Преимущество отдается водителю.
        local aquaferryman = boat:getPartById("Engine"):getModData()["aquaferryman"]
        if not aquaferryman then
            sendClientCommand(character, 'aquatsar', 'setFerryman', {boat = boat:getId(), })
        elseif aquaferryman == character:getOnlineID() then
            AquaPhysics.beginFrame()
            local collisionWithGround = AquaPhysics.Water.Borders(boat)
            if AquaPhysics.heightFix(character, boat) then
                local sails = boat:getPartById("Sails")
                local anchor = boat:getPartById("BoatAnchor")
                if sails and sails:getInventoryItem() then
                    local light = sails and sails:getLight()
                    if light and light:getActive() and (not anchor or not anchor:getInventoryItem()) then
                        AquaPhysics.Wind.windImpulse(boat, collisionWithGround)
                    end
                    AquaPhysics.changeSailAngle(boat, character)
                end
                AquaPhysics.waterFlowRotation(boat, 2000, character)
                AquaPhysics.unstick(boat, character, collisionWithGround)
                if anchor and anchor:getInventoryItem() then 
                    AquaPhysics.stopByAnchor(boat, 5000) 
                end
                AquaPhysics.boatEngineShutDownOnGround(boat)
            end
            AquaPhysics.flushPushes()
        elseif boat:isDriver(character) then
            sendClientCommand(character, 'aquatsar', 'setFerryman', {boat = boat:getId(), })
        end
    end
end

local function onVehicle(character)
    if instanceof(character, 'IsoPlayer') and character:isLocalPlayer() then
        local vehicle = character:getVehicle()
        if AquaConfig.isBoat(vehicle) then
            Events.OnTick.Add(AquaPhysics.updateBoatMP)
        else
            Events.OnTick.Remove(AquaPhysics.updateBoatMP)
        end
    end
end

local function onCreatePlayer(id)
    if getCore():isDedicated() then return end

    local playerObj = getSpecificPlayer(id)
    if not playerObj or not playerObj:isLocalPlayer() then return end
    if isClient() then
        Events.OnEnterVehicle.Add(onVehicle)
        Events.OnExitVehicle.Add(onVehicle)
    else
        Events.OnTick.Add(AquaPhysics.updateVehicles)
    end
end

local function onPlayerDeath(playerObj)
    if not playerObj:isLocalPlayer() then return end
    if isClient() then
        Events.OnEnterVehicle.Remove(onVehicle)
        Events.OnExitVehicle.Remove(onVehicle)
    else
        Events.OnTick.Remove(AquaPhysics.updateVehicles)
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnPlayerDeath.Add(onPlayerDeath)


MakeshiftRaft = MakeshiftRaft or {}
MakeshiftRaft.SailSpeedCoef = 0.020
MakeshiftRaft.WindSpeedCoef = 0.007
MakeshiftRaft.WindDriftCoef = 0.002
MakeshiftRaft.PaddleSpeed = 0.4 --this does not depend on wind

local keysMemo = {}

local function resetKeys(playerObj)
    keysMemo[playerObj] = {forwardPressed = false, backwardPressed = false }
end

function MakeshiftRaft.OnRaftForward(playerObj)
    if MakeshiftRaft.Verbose then print("forward pressed") end
    local memo = keysMemo[playerObj]
    if not memo then
        resetKeys(playerObj)
        memo = keysMemo[playerObj]
    end
    memo.forwardPressed = true
end

function MakeshiftRaft.OnRaftBackward(playerObj)
    if MakeshiftRaft.Verbose then print("backward pressed") end
    local memo = keysMemo[playerObj]
    if not memo then
        resetKeys(playerObj)
        memo = keysMemo[playerObj]
    end
    memo.backwardPressed = true
end


local function isForwardKeyPressed(playerObj)
    local memo = keysMemo[playerObj]
    return memo and memo.forwardPressed
end

local function isBackwardKeyPressed(playerObj)
    local memo = keysMemo[playerObj]
    return memo and memo.backwardPressed
end


function MakeshiftRaft.initRaftMovement(playerObj)
    resetKeys(playerObj)
end


local function getRelativeAngle(windAngle, playerAngle)
    if windAngle > 180 then windAngle = windAngle - 360 end
    if windAngle < -180 then windAngle = windAngle + 360 end
    if playerAngle > 180 then playerAngle = playerAngle - 360 end
    if playerAngle < -180 then playerAngle = playerAngle + 360 end
    local angle = windAngle - playerAngle
    if angle > 180 then angle = angle - 360 end
    if angle < -180 then angle = angle + 360 end
    return angle
end


function MakeshiftRaft.teleport(isoMovingObject, x, y, z, args)
    isoMovingObject:setX(x)
    isoMovingObject:setY(y)
    isoMovingObject:setZ(z)
    
    if not args or not args.isPseudoMovement then
        isoMovingObject:setLastX(x)
        isoMovingObject:setLastY(y)
        isoMovingObject:setLastZ(z)
    end
end


--no physic here, let's keep it simple and smooth
function MakeshiftRaft.doRaftMovement(playerObj)
    --rotation is handled by right click

    local windSpeed = getClimateManager():getWindspeedKph()
    local windAngleNorthing = getClimateManager():getWindAngleDegrees()--0 means North direction
    local beaufort = MakeshiftRaft.getBeaufort(windSpeed)
    
    local isAnchorDown = MakeshiftRaft.isAnchorDown(playerObj)
    if isAnchorDown and beaufort >= 8 then
        --break anchor link (move it up instantly because I am lazy)
        MakeshiftRaft.setAnchorState(playerObj,false)
        isAnchorDown = false
    end
    
    --override head to body angle handled at animation level.
    local playerAngleRd = MakeshiftRaft.getReferenceAzimuthRd(playerObj)
    local playerAngle = playerAngleRd * 57.2958--rd 2 deg 
    playerObj:setDirectionAngle(playerAngle)
    playerObj:setTargetAndCurrentDirection(playerObj:getForwardDirectionX(),playerObj:getForwardDirectionY())
    
    
    local direction = 0
    if isForwardKeyPressed(playerObj) then
        direction = 1
    elseif isBackwardKeyPressed(playerObj) then
        direction = -1
    end
    resetKeys(playerObj)
    
    local paddleGain = MakeshiftRaft.getPaddleGain(playerObj)
    
    local windAngle = 0
    local deltaAngle = 0
    local deltaAngleRad = 0
    local sailSpeedCoef = 0
    local windSpeedCoef = 0
    local latlSpeedCoef = 0
    local paddleSpeed = isAnchorDown and 0 or paddleGain * direction * MakeshiftRaft.PaddleSpeed
    
    if beaufort < 1 then--no wind no movement
        windSpeed = 0
    elseif isAnchorDown then--anchor, no movement
        windSpeed = 0
    else
        windAngle = MakeshiftRaft.convertWindAngleClimateToEastRef(windAngleNorthing)--I convert wind angle to 0 means east, 90 means south like player angle. this is easier (for me) for X,Y convertion 
        deltaAngle = getRelativeAngle(windAngle, playerAngle)
        deltaAngleRad = deltaAngle / 57.2958
        sailSpeedCoef = MakeshiftRaft.SailSpeedCoef * windSpeed --up to 5, Sail is better than bad wind angle
        windSpeedCoef = MakeshiftRaft.WindSpeedCoef * (beaufort) * windSpeed * math.cos(deltaAngleRad)
        latlSpeedCoef = MakeshiftRaft.WindDriftCoef * (beaufort-1) * windSpeed * math.sin(deltaAngleRad)--drift stays cool
    end
    
    
    
    
    local dt = 0.020 * getGameTime():getMultiplier()--TODO find a real DT but beware pause & out of raft transitions
    local deltaLongi = (sailSpeedCoef + windSpeedCoef + paddleSpeed) * dt--TODO acc but beware pause & out of raft transitions
    local deltaLater = latlSpeedCoef * dt
    local cosPlay = math.cos(playerAngleRd)
    local sinPlay = math.sin(playerAngleRd)
    local deltaX = deltaLongi * cosPlay - deltaLater * sinPlay
    local deltaY = deltaLongi * sinPlay + deltaLater * cosPlay
    
    --TODO add inertia or at least speed filtering. but beware pause & out of raft transitions
    if MakeshiftRaft.Verbose then
        print('Raft wind '..tostring(windSpeed)..' '..tostring(beaufort)..' '..tostring(windAngle)..' '..tostring(windAngleNorthing)..' '..ClimateManager.getWindAngleString(windAngleNorthing))
        print('Raft player '..tostring(playerAngle)..' '..tostring(deltaAngle))
        print('Raft coef '..tostring(sailSpeedCoef)..' '..tostring(windSpeedCoef)..' '..tostring(paddleSpeed)..' '..tostring(latlSpeedCoef))
        print('Raft body delta '..tostring(deltaLongi)..' '..tostring(deltaLater))
        print('Raft abs delta '..tostring(deltaX)..' '..tostring(deltaY))
    end

    MakeshiftRaft.teleport(playerObj,
            playerObj:getX()+deltaX,
            playerObj:getY()+deltaY,
            playerObj:getZ())
            
    if dt > 0 then
        MakeshiftRaft.updatePlayerRaftExtrapolator(playerObj, deltaX/dt, deltaY/dt, 0, dt)
    end
end
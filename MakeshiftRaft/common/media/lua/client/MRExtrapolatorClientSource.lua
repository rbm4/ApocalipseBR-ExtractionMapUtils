
MakeshiftRaft = MakeshiftRaft or {}

--decides when to re-emit the a position of a local controlled raft to the rest of the simulation
--dead-reckoning predicts when an "sufficient error" can exist client side that a precise position is now worth the network update cost

local extrapolators = {}
MakeshiftRaft.minUpdateTime = 80--ms
MakeshiftRaft.minDeltaAng = 0.5--rd
MakeshiftRaft.minDeltaPos = 0.5--square

function MakeshiftRaft.activateMPExtrapolator(playerObj)
    if not playerObj then return end
    extrapolators[playerObj] = { needsUpdate = true, timeRef = getTimestampMs(), refX=playerObj:getX(),refY=playerObj:getY(),refZ=playerObj:getZ(),angle=playerObj:getDirectionAngle()}--maybe try set to 0 for better init, but I fear side effects
end

function MakeshiftRaft.deactivateMPExtrapolator(playerObj)
    if extrapolators[playerObj] then
        extrapolators[playerObj] = nil
    end
end


function MakeshiftRaft.OnTickExtrapolator()
    local currentTime = getTimestampMs()
    for playerObj,extrapolator in pairs(extrapolators) do
        local dt = currentTime-extrapolator.timeRef
        if playerObj and dt > MakeshiftRaft.minUpdateTime then
            local updateServer = extrapolator.needsUpdate
            if not updateServer then
                local dtExtrap = extrapolator.dt or 0.0--same as MRMovement, & both are called OnTick
                local dX = playerObj:getX() - (extrapolator.refX + extrapolator.vX * dtExtrap)--level 0 of extrapolation, sorry
                local dY = playerObj:getY() - (extrapolator.refY + extrapolator.vY * dtExtrap)
                local dZ = playerObj:getZ() - (extrapolator.refZ + extrapolator.vZ * dtExtrap)
                local dA = playerObj:getDirectionAngle() - extrapolator.angle
                if dX > MakeshiftRaft.minDeltaPos or dX < -MakeshiftRaft.minDeltaPos
                or dY > MakeshiftRaft.minDeltaPos or dY < -MakeshiftRaft.minDeltaPos
                or dZ > MakeshiftRaft.minDeltaPos or dZ < -MakeshiftRaft.minDeltaPos
                or dA > MakeshiftRaft.minDeltaAng or dA < -MakeshiftRaft.minDeltaAng then
                    updateServer = true
                end
            end
            
            if updateServer then
                local args = {x=playerObj:getX(),y=playerObj:getY(),z=playerObj:getZ(),vX=extrapolator.vX,vY=extrapolator.vY,vZ=extrapolator.vZ,a=playerObj:getDirectionAngle()}--+state? 1 for sit, 2 for fishing .. whatever
                sendClientCommand(playerObj, 'Raft', 'ExtrapUpd', args)
                extrapolator.timeRef=currentTime
                extrapolator.refX=args.x
                extrapolator.refY=args.y
                extrapolator.refZ=args.z
                extrapolator.angle=args.a
                incrementNbCycle = false
                extrapolator.dt = 0
                extrapolator.needsUpdate = nil
            end
        end
    end
end

--Events.OnTick.Add(MakeshiftRaft.OnTickExtrapolator)--deactivated for now



function MakeshiftRaft.updatePlayerRaftExtrapolator(playerObj, speedX, speedY, speedZ, dt)
    local extrapolator = extrapolators[playerObj]
    if extrapolator then
        extrapolator.vX = speedX
        extrapolator.vY = speedY
        extrapolator.vZ = speedZ
        extrapolator.dt = (extrapolator.dt or 0.0) + dt
    end
end
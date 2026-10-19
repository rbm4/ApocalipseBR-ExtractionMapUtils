
MakeshiftRaft = MakeshiftRaft or {}


function MakeshiftRaft.OnRaftInteraction(playerObj)--when a player controlling a raft pressed interaction key
    
end


function MakeshiftRaft.correctRaftWeightClient(raft)--no need to release weight correct, server does it
    if not raft then return end
    if raft:getWeight() > 0 then
        MakeshiftRaft.setItemWeight(raft, 0)
    end
end

local loggedPlayers = {}

function MakeshiftRaft.OnTick()
    local playersSum = getNumActivePlayers()
    for playerNum = 0, playersSum - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            local boat = playerObj:getVehicle()
            local playerSquare = playerObj:getSquare()

            if boat then
                MakeshiftRaft.setNoClipWater(playerObj, false, playerSquare)
                MakeshiftRaft.deactivateRaftControl(playerObj)
                MakeshiftRaft.deactivateMPExtrapolator(playerObj)
            elseif playerSquare then
                MakeshiftRaft.setNoClipWater(playerObj, MakeshiftRaft.isRaftAvailable(playerObj), playerSquare)
                if MakeshiftRaft.isOnWater(playerObj) then
                    --inhibit bothering controls
                    local enterRaft = MakeshiftRaft.activateRaftControl(playerObj)
                    --start sitting animation
                    if enterRaft then
                        playerObj:reportEvent("EventSitOnGround")
                        MakeshiftRaft.initRaftMovement(playerObj)
                        MakeshiftRaft.activateMPExtrapolator(playerObj)
                        --print ('MakeshiftRaft.OnTick start sit down')
                    elseif not playerObj:isSitOnGround() then--TODO stats machine for possible actions on the raft
                        playerObj:reportEvent("EventSitOnGround")
                        --print ('MakeshiftRaft.OnTick insist sit down')
                    end
                    
                    --correctClientRaftWeight
                    local raft = MakeshiftRaft.getEquippedRaft(playerObj)
                    if raft then
                        MakeshiftRaft.correctRaftWeightClient(raft)
                    end
                    
                    --inhibit contextual menu ?
                    --inhibit ..
                    
                    --do the movement
                    MakeshiftRaft.doRaftMovement(playerObj)
                else
                    --handle transition out of sitting
                    MakeshiftRaft.deactivateRaftControl(playerObj)
                    MakeshiftRaft.deactivateMPExtrapolator(playerObj)
                end
            end
        end
    end
end

Events.OnTick.Add(MakeshiftRaft.OnTick)




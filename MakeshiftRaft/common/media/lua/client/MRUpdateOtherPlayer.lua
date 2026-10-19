

Events.OnLoad.Add()

--local function OnPlayerUpdate(playerObj)
--    if playerObj and not playerObj:isLocalPlayer() then
--        local playerRaft = MakeshiftRaft.getEquippedRaft(playerObj)
--        if playerRaft then
--            print('OnPlayerUpdate with Raft '..playerObj:getName())
--        else
--            print('OnPlayerUpdate without Raft '..playerObj:getName())
--        end
--    elseif playerObj then
--        print('OnPlayerUpdate local '..playerObj:getName())
--    end
--end
--
--Events.OnPlayerUpdate.Add(OnPlayerUpdate)

--[
--OnCharacterCollide
--OnObjectCollide
--OnNPCSurvivorUpdate
--OnPlayerUpdate
--OnCreateLivingCharacter
--OnPostCharactersSquareDraw
--OnPlayerMove
--OnClientCommand
--OnServerCommand
--onLoadModDataFromServer
--OnOtherPlayerDetected
--onToggleSearchMode
--onEnableSearchMode
--onDisableSearchMode
--OnDesignationZoneUpdatedNetwork
--OnExitVehicle
--OnSwitchVehicleSeat
--OnUseVehicle
--OnVehicleHorn

--]

local silenced ={}
silenced['ReuseGridsquare']=true
silenced['OnPlayerUpdate']=true
silenced['OnRenderUpdate']=true
silenced['OnRenderTick']=true
silenced['OnPostRender']=true
silenced['OnTick']=true
silenced['OnTickEvenPaused']=true
silenced['RenderOpaqueObjectsInWorld']=true
silenced['OnMouseMove']=true
silenced['OnPreUIDraw']=true
silenced['OnPostUIDraw']=true
silenced['LoadGridsquare']=true

local function printEvents(playerObj)
    --print('EVENTS')
    for key,value in pairs(Events) do
        --print(key)
        if not silenced[key] then
            Events[key].Add(function() print('Call.'..key) end)
        end
    end
--    print(tab2str(Events))
    --print('EVENTSEND')
    Events.OnPlayerUpdate.Remove(printEvents)
end

--Events.OnPlayerUpdate.Add(printEvents)



local activeEvents ={}
activeEvents['OnAIStateChange']=true
activeEvents['OnKeyKeepPressed']=nil--OnAIStateChange IsoPlayer{  Name:null,  ID:210 }
activeEvents['OnKeyStartPressed']=nil
activeEvents['OnPlayerUpdate']=nil
activeEvents['OnWorldSound']=nil
activeEvents['EveryOneMinute']=true
--10000
--10001
--30
--1
--56
local function printActiveEvents(playerObj)
    --print('EVENTS')
    for key,value in pairs(Events) do
        --print(key)
        if activeEvents[key] then
            Events[key].Add(function(arg1) print('Call.'..key..' '..tostring(arg1)) end)
        end
    end
--    print(tab2str(Events))
    --print('EVENTSEND')
    Events.OnPlayerUpdate.Remove(printActiveEvents)
end
---Events.OnPlayerUpdate.Add(printActiveEvents)


local function OnAIStateChange(playerObj,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10)
    print('OnAIStateChange ['..tostring(playerObj:getX())..','..tostring(playerObj:getY())..','..tostring(playerObj:getZ())..']')
    print('OnAIStateChange arg['..tostring(arg2)..']')
    print('OnAIStateChange arg['..tostring(arg3)..']')
    print('OnAIStateChange arg['..tostring(arg4)..']')
    print('OnAIStateChange arg['..tostring(arg5)..']')
    print('OnAIStateChange arg['..tostring(arg6)..']')
    print('OnAIStateChange arg['..tostring(arg7)..']')
    print('OnAIStateChange arg['..tostring(arg8)..']')
    print('OnAIStateChange arg['..tostring(arg9)..']')
    print('OnAIStateChange arg['..tostring(arg10)..']')
end
--Events.OnAIStateChange.Add(OnAIStateChange)


















require 'AquaConfig'
require 'AquaSwimShared'

TickControl = TickControl or {}
local TickTable = {}
TickTable.Wind = {}

local function isCheatAllowed(playerObj)--see PlayerCheats.isCheatAllowed
    --Core.debug || GameClient.client || GameServer.server; //version B42.13.1
    return isDebugEnabled() or isClient() or isServer()
end


local function isInVicinity(playerSquare,otherSquare)
    if not playerSquare or not otherSquare then return false end
    local dX = playerSquare:getX()-otherSquare:getX()
    if dX > 1 or dX < -1 then return false end
    local dY = playerSquare:getY()-otherSquare:getY()
    if dY > 1 or dY < -1 then return false end
    --local dZ = playerSquare:getZ()-otherSquare:getZ()--TODO think on how to handle Z
    --if dZ > 1 or dZ < -1 then return false end
    return true
end
local function isSwimPassable(playerSquare,otherSquare)
     local swimPassable = not playerSquare:isWallTo(otherSquare) and not playerSquare:isWindowTo(otherSquare)
     --print('isSwimPassable '..sq2str(playerSquare)..'->'..sq2str(otherSquare)..': '..tostring(swimPassable))
     return swimPassable
end

local function applyNormalClip(square)
    local floorTile = square and square:getFloor()
    local sprite = floorTile and floorTile:getSprite()
    local props = sprite and sprite:getProperties()
    if props then 
        props:set(IsoFlagType.solidtrans)
        square:EnsureSurroundNotNull();
        square:RecalcAllWithNeighbours(true);
        --print('set solidtrans to '..sq2str(square))
    end
end
local function applyNoClip(square)
    local floorTile = square and square:getFloor()
    local sprite = floorTile and floorTile:getSprite()
    local props = sprite and sprite:getProperties()
    if props then 
        props:unset(IsoFlagType.solidtrans)
        square:EnsureSurroundNotNull();
        square:RecalcAllWithNeighbours(true);
        --print('unset solidtrans to '..sq2str(square))
    end
end
local function isBlockingSquare(square)
    local floorTile = square and square:getFloor()
    local sprite = floorTile and floorTile:getSprite()
    local props = sprite and sprite:getProperties()
    --print(''..sq2str(square)..' solidtrans='..tostring(props and props:has(IsoFlagType.solidtrans)))
    return props and props:has(IsoFlagType.solidtrans)
end

local walkableWaterTiles = {}
local function setNoClip(playerObj, flag, playerSquare)
    --1--setNoClip. inhibited by Vanilla. locked behing rights check in solo non debug 
    if isCheatAllowed() then
        if playerObj and playerObj:isNoClip() ~= flag then
            playerObj:setNoClip(flag,true)
        end
    --2--cheats:set. inhibited by Vanilla. lock behind unaccessible from lua
    --local cheats = playerObj and playerObj:getCheats()
    --if cheats then
    --    cheats:set(CheatType.NO_CLIP)
    --end

    --3--square prop modifications
    else
        if playerObj and not playerSquare then playerSquare = playerObj:getSquare() end--allow nil in interface for square
        if not playerSquare then return end--TODO LOG
        

        if flag then
            --clear all water tiles far from player back to normal
            for itSq=#walkableWaterTiles, 1, -1 do
                local otherSquare = walkableWaterTiles[itSq]
                if not isInVicinity(playerSquare,otherSquare) or not isSwimPassable(playerSquare,otherSquare) then
                    applyNormalClip(otherSquare)
                    if itSq ~= #walkableWaterTiles then
                        walkableWaterTiles[itSq] = walkableWaterTiles[#walkableWaterTiles]--order does not matter
                    end
                    walkableWaterTiles[#walkableWaterTiles] = nil--release
                end
            end
            
            --add close squares to no clip list
            local refX = playerSquare:getX()
            local refY = playerSquare:getY()
            local refZ = playerSquare:getZ()--TODO?
            for itX = -1, 1 do
                for itY = -1, 1 do
                    local otherSquare = getCell():getGridSquare(refX+itX,refY+itY,refZ)
                    if otherSquare and isBlockingSquare(otherSquare) and isSwimPassable(playerSquare,otherSquare) then
                        applyNoClip(otherSquare)
                        walkableWaterTiles[#walkableWaterTiles+1] = otherSquare
                    end
                end
            end
        else
            --clear all water tiles back to normal
            --clear all water tiles far from player back to normal
            for itSq=#walkableWaterTiles, 1, -1 do
                local otherSquare = walkableWaterTiles[itSq]
                applyNormalClip(otherSquare)
                if itSq ~= #walkableWaterTiles then
                    walkableWaterTiles[itSq] = walkableWaterTiles[#walkableWaterTiles]--order does not matter
                end
                walkableWaterTiles[#walkableWaterTiles] = nil--release
            end
        end
    end
end

-- True Swimming compatibility: it owns the swim, so give back everything Aquatsar could still be
-- holding on the swimmer (water squares left walkable, no-clip, hidden sprite, swim sound loop).
-- Once per player is enough: the swim branch of TickControl.main below never runs again after
-- the hand-over, so nothing can set them a second time.
local swimHandedOver = {}
local function releaseSwimToTrueSwimming(playerObj, playerSquare)
    local playerNum = playerObj:getPlayerNum()
    if swimHandedOver[playerNum] then return end
    swimHandedOver[playerNum] = true
    local emiPl = playerObj:getEmitter()
    if emiPl and emiPl:isPlaying("Swim") then
        emiPl:stopSoundByName("Swim")
    end
    local sprite = playerObj:getSprite()
    local props = sprite and sprite:getProperties()
    if props and props:has(IsoFlagType.invisible) then
        props:unset(IsoFlagType.invisible)
    end
    setNoClip(playerObj, false, playerSquare)
end
Events.OnCreatePlayer.Add(function(playerNum) swimHandedOver[playerNum] = nil end)

function TickControl.switchTheWind(emi, nameOfWind, volume)
    if emi:isPlaying(nameOfWind) then 
        -- AUD.insp("Boat", "TickTable.Wind[nameOfWind]:", TickTable.Wind[nameOfWind])
        emi:setVolume(TickTable.Wind[nameOfWind], volume)
        return 
    end
    for i, j in pairs(TickTable.Wind) do 
        emi:stopSoundByName(i)
    end
    local songId = emi:playAmbientLoopedImpl(nameOfWind)
    TickTable.Wind = {}
    TickTable.Wind[nameOfWind] = songId
    emi:setVolume(TickTable.Wind[nameOfWind], volume)
    emi:set3D(TickTable.Wind[nameOfWind], false)
end

function TickControl.stopWeatherSound(emi)
    emi:stopSoundByName("BoatSailing")
    -- emi:stopSoundByName("BoatSailingByWind")
    for i, j in pairs(TickTable.Wind) do 
        emi:stopSoundByName(i)
    end
    TickTable.Wind = {}
end


function TickControl.main()
    local playersSum = getNumActivePlayers()
    for playerNum = 0, playersSum - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            local boat = playerObj:getVehicle()
            if boat ~= nil and AquaConfig.isBoat(boat) then
                local boatSpeed = boat:getCurrentSpeedKmHour()
                local emi = boat:getEmitter()
                if emi:isPlaying("VehicleSkid") then -- Удаление звука заноса на воде
                    emi:stopSoundByName("VehicleSkid")
                end
                if emi:isPlaying("BoatSailing") then 
                    local windSpeed = getClimateManager():getWindspeedKph()
                    -- AUD.insp("Wind", "windSpeed (MPH):", windSpeed/1.60934)
                    local volume = 0
                    if windSpeed < AquaConfig.windVeryLight then
                        -- AUD.insp("Wind", "windControlSpeed:", "windVeryLight")
                        volume = 1
                        TickControl.switchTheWind(emi, "WindLight", volume)
                    elseif windSpeed < AquaConfig.windLight then
                        -- AUD.insp("Wind", "windControlSpeed:", "windLight")
                        volume = windSpeed/AquaConfig.windLight
                        TickControl.switchTheWind(emi, "WindLight", volume)
                    elseif windSpeed < AquaConfig.windMedium then
                        -- AUD.insp("Wind", "windControlSpeed:", "windMedium")
                        volume = windSpeed/AquaConfig.windMedium
                        TickControl.switchTheWind(emi, "WindMedium", volume)
                    elseif windSpeed < AquaConfig.windStrong then
                        -- AUD.insp("Wind", "windControlSpeed:", "windStrong")
                        volume = (windSpeed - 20 * 1.60934)/(AquaConfig.windStrong - 20 * 1.60934)
                        TickControl.switchTheWind(emi, "WindStrong", volume)
                    elseif windSpeed < AquaConfig.windVeryStrong then
                        -- AUD.insp("Wind", "windControlSpeed:", "windVeryStrong")
                        volume = (windSpeed - 18 * 1.60934)/(AquaConfig.windVeryStrong - 18 * 1.60934)
                        TickControl.switchTheWind(emi, "WindVeryStrong", volume)
                    else
                        -- AUD.insp("Wind", "windControlSpeed:", "windStorm")
                        volume = (windSpeed - 18 * 1.60934)/(AquaConfig.windVeryStrong - 18 * 1.60934)
                        TickControl.switchTheWind(emi, "WindStorm", 1)
                    end
                    -- AUD.insp("Wind", "volume:", volume)
                end

                if boat:getPartById("ManualStarter") then
                    if emi:isPlaying("VehicleStarted") then
                        emi:stopSoundByName("VehicleStarted")
                        emi:playSound("SuccessStartEngineManualy", boat)
                    end
                    if emi:isPlaying("VehicleFailingToStart") then
                        emi:stopSoundByName("VehicleFailingToStart")
                        emi:playSound("FailStartEngineManualy", playerObj)
                    end
                end
            end
        
            local emiPl = playerObj:getEmitter()
            local playerSquare = playerObj:getSquare()
            local trueSwimming = AquatsarYachts.Swim.isHandledByTrueSwimming()
            if trueSwimming then
                releaseSwimToTrueSwimming(playerObj, playerSquare)
            end
            if boat then
                if emiPl:isPlaying("Swim") then
                    emiPl:stopSoundByName("Swim")
                    getSoundManager():PlaySound("LeaveWater", true, 0.0)
                    playerObj:getSprite():getProperties():unset(IsoFlagType.invisible)
                    setNoClip(playerObj, false, playerSquare)
                end
            elseif playerSquare and not trueSwimming then--True Swimming handles the swim: no wetness, no invisible sprite, no square unclipping, no Aquatsar swim sound
                if AquatsarYachts.Swim.isWater(playerSquare) then
                    playerObj:getStats():set(CharacterStat.WETNESS, 100.0)--TODO move stats server side
                    if not playerObj:getSprite():getProperties():has(IsoFlagType.invisible) then
                        emiPl:playSound("Dive")
                        if not isClient() then
                            AquatsarYachts.Swim.wetItems(playerObj)
                        end
                        playerObj:getSprite():getProperties():set(IsoFlagType.invisible)
                        setNoClip(playerObj, true, playerSquare)
                        --print('Player enters water '..tostring(playerObj:isNoClip()))
                    elseif not isCheatAllowed(playerObj) then
                        setNoClip(playerObj, true, playerSquare)--delegate no clip property to squares depending on player position
                    else
                        local moveDir = playerObj:getForwardDirection()--Tch: stated as deprecated in B42.17. and is orientation not movement. but getPlayerMoveDir is missing
                        local x = playerObj:getX() + moveDir:getX()
                        local y = playerObj:getY() + moveDir:getY()
                        local sq = playerSquare
                        local sqDir = getCell():getGridSquare(playerObj:getX() + moveDir:getX(), 
                                                              playerObj:getY() + moveDir:getY(), 
                                                              playerObj:getZ())
                        --print('swim dist '..tostring(sq and sqDir and sq:DistTo(sqDir))..' '..tostring(playerObj:isNoClip()))
                        local dist = sq and sqDir and sq:DistTo(sqDir) or 0
                        if dist >= 1 then
                            if sq:isWallTo(sqDir) or sq:isWindowTo(sqDir) then
                                setNoClip(playerObj, false, playerSquare)
                                --print('swim lock removed '..sq2str(sq)..' '..sq2str(sqDir)..' '..tostring(playerObj:isNoClip()))
                            elseif not playerObj:isNoClip() then
                                -- moveDir:normalize()
                                
                                moveDir:rotate(3.14)
                                local rearSqr = getCell():getGridSquare(playerObj:getX() + moveDir:getX()*2, 
                                                          playerObj:getY() + moveDir:getY()*2, 
                                                          playerObj:getZ())

                                moveDir = playerObj:getForwardDirection()
                                moveDir:rotate(1.57)
                                local sideSqr1 = getCell():getGridSquare(playerObj:getX() + moveDir:getY(), 
                                                              playerObj:getY() + moveDir:getX(), 
                                                              playerObj:getZ())
                                moveDir:rotate(3.14)                              
                                local sideSqr2 = getCell():getGridSquare(playerObj:getX() + moveDir:getX(), 
                                                              playerObj:getY() + moveDir:getY(), 
                                                              playerObj:getZ())
                                
                                if dist==1 and AquatsarYachts.Swim.isWater(sqDir) and 
                                        not sq:isWallTo(sideSqr1) and 
                                        not sq:isWindowTo(sideSqr1) and 
                                        not sq:isWallTo(sideSqr2) and
                                        not sq:isWindowTo(sideSqr2) and
                                        sq:isWallTo(rearSqr) then
                                    setNoClip(playerObj, true, playerSquare)
                                end
                            else
                                --print('swim no square change.'..' '..tostring(playerObj:isNoClip()))
                            end
                        else
                            --print('swim no square change.'..' '..tostring(playerObj:isNoClip()))
                        end
                    end
                    
                    if not emiPl:isPlaying("Swim") and not playerObj:isDead() then
                        playerObj:playSound("Swim")
                    end
                else
                    if playerObj:getSprite():getProperties():has(IsoFlagType.invisible) then
                        emiPl:playSound("LeaveWater")
                        playerObj:getSprite():getProperties():unset(IsoFlagType.invisible)
                        setNoClip(playerObj, false, playerSquare)
                    end
                    if emiPl:isPlaying("Swim") then
                        emiPl:stopSoundByName("Swim")
                    end
                end
            end
        end
    end
end

local function onPlayerDeathStopSwimSound(playerObj)
    playerObj:getEmitter():stopSoundByName("Swim")
end

Events.OnTick.Add(TickControl.main)
Events.OnPlayerDeath.Add(onPlayerDeathStopSwimSound)
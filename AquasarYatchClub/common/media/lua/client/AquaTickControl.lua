require 'AquaConfig'

TickControl = {}
local TickTable = {}
TickTable.Wind = {}

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

function TickControl.wetItems(playerObj)
    local inv = playerObj:getInventory() -- inv = getPlayer():getInventory()    
    local items = {}

    for j=1, inv:getItems():size() do
        local item = inv:getItems():get(j-1);
        table.insert(items, item)
    end

    for i=1, #items do
        if items[i]:IsClothing() then
            items[i]:setWetness(100)
        elseif items[i]:IsLiterature() then
            local item = instanceItem("Aquatsar.TaintedLiterature");
            inv:AddItem(item)
            inv:DoRemoveItem(items[i])
        end
    end
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
        end
    end
end

Events.OnTick.Add(TickControl.main)

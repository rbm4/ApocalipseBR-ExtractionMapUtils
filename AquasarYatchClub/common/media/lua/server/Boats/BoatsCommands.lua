
if isClient() then return end

require 'AquaConfig'

Aquatsar = Aquatsar or {}
Aquatsar.BoatsCommands = Aquatsar.BoatsCommands or {}--with serialized arguments from client
Aquatsar.BoatsActions = Aquatsar.BoatsActions or {}--with direct objects (mostly for B42 MP convertion from client to server / from perform to complete)

local CommonCommands = {}
local Commands = Aquatsar.BoatsCommands
local Actions = Aquatsar.BoatsActions

function Actions.launchBoat(trailer, square)
    if trailer and square then
        local scriptName = AquaConfig.Trailers[trailer:getScript():getName()].boat
        local boat = addVehicleDebug(scriptName, IsoDirections.N, trailer:getSkinIndex(), square)
        boat:setDebugZ(0.75)
        boat:setAngles(trailer:getAngleX(), trailer:getAngleY(), trailer:getAngleZ())
        boat:setRust(trailer:getRust())
        local newTrailerName = AquaConfig.Trailers[trailer:getScript():getName()].emptyTrailer
        AquaConfig.exchangePartsVehicle(trailer, boat)
        trailer = AquaConfig.replaceVehicle(trailer, newTrailerName, 0)
        
        local boatNamePart = boat:getPartById("BoatName")
        if boatNamePart then
            VehicleUtils.callLua(boatNamePart:getLuaFunction("init"), boat, boatNamePart)
        end
        local sails = boat:getPartById("Sails")
        if sails then
            VehicleUtils.callLua(sails:getLuaFunction("init"), boat, sails)
        end
        
        -- Delete key
        local xx = boat:getX()
        local yy = boat:getY()

        for z=0, 3 do
            for i=xx - 15, xx + 15 do
                for j=yy - 15, yy + 15 do
                    local tmpSq = getCell():getGridSquare(i, j, z)
                    if tmpSq ~= nil then
                        for k=0, tmpSq:getObjects():size()-1 do
                            local ttt =    tmpSq:getObjects():get(k)
                            if ttt:getContainer() ~= nil then
                                local items = ttt:getContainer():getItems()
                                for ii=0, items:size()-1 do
                                    if items:get(ii):getKeyId() == boat:getKeyId() then
                                        items:remove(ii)
                                    end
                                end
                            elseif instanceof(ttt, "IsoWorldInventoryObject") then
                                if ttt:getItem() and ttt:getItem():getContainer() then
                                    local items = ttt:getItem():getContainer():getItems()
                                    for ii=0, items:size()-1 do
                                        if items:get(ii):getKeyId() == boat:getKeyId() then
                                            items:remove(ii)
                                        end
                                    end
                                end
                                
                                if ttt:getItem() and ttt:getItem():getKeyId() == boat:getKeyId() then
                                    tmpSq:removeWorldObject(ttt)
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        return false
    end
    return true
end

-- sendClientCommand(self.character, 'aquatsar', 'launchBoat', {trailer = self.trailer:getId(), x = self.square:getX(), y = self.square:getY()})
function Commands.launchBoat(playerObj, args)
    if args.trailer then
        local trailer = getVehicleById(args.trailer)
        local square = getSquare(args.x, args.y, 0)
        Actions.launchBoat(trailer, square)
    end
end

function Actions.loadBoat(trailer, boat)--BaseVehicle, bool, bool
    local newTrailerName = AquaConfig.Trailers[trailer:getScript():getName()].trailerWithBoatTable[boat:getScript():getName()]
    trailer = AquaConfig.replaceVehicle(trailer, newTrailerName, boat:getSkinIndex())
    AquaConfig.exchangePartsVehicle(boat, trailer)
    local boatNamePart = trailer:getPartById("BoatName")
    if boatNamePart then
        VehicleUtils.callLua(boatNamePart:getLuaFunction("init"), trailer, boatNamePart)
    end
    local sails = trailer:getPartById("Sails")
    if sails then
        VehicleUtils.callLua(sails:getLuaFunction("init"), trailer, sails)
    end
    trailer:setRust(boat:getRust())
    boat:permanentlyRemove()
end

-- sendClientCommand(self.character, 'aquatsar', 'loadBoat', {trailer = self.trailer:getId(), boat = self.boat:getId()})
function Commands.loadBoat(playerObj, args)
    if args.trailer and args.boat then
        Actions.loadBoat(getVehicleById(args.trailer), getVehicleById(args.boat))
    end
end

-- sendClientCommand(self.character, 'aquatsar', 'setFerryman', {boat = boat:getId(), })
function Commands.setFerryman(playerObj, args)
    if args.boat then
        local boat = getVehicleById(args.boat)
        local boatEngine = boat:getPartById("Engine")
        if boatEngine then
            boatEngine:getModData()["aquaferryman"] = playerObj:getOnlineID()
            boat:transmitPartModData(boatEngine)
        end
    end
end

-- sendClientCommand(character, 'aquatsar', 'boatOnGround', {boat = boat:getId(), })
function Commands.boatOnGround(playerObj, args)
    if args.boat then
        local boat = getVehicleById(args.boat)
        -- if isServer() then
        boat = AquaConfig.replaceVehicle(boat, "Base.".. boat:getScript():getName() .. "_Ground", boat:getSkinIndex())
        -- else
            -- AquaConfig.replaceVehicleScript(boat, "Base.".. boat:getScript():getName() .. "_Ground")
        -- end
        boat:flipUpright()
        boat:setZ(0)
    end
end


function Actions.setLockState(boat, part, unlock, force)--BaseVehicle, bool, bool
    if not part then
        --print('ERROR Actions.setLockState cannot find part.')
        return
    end
    if part then
        part:getModData()["AquaCabin_isUnlocked"] = unlock
        --print('set AquaCabin_isUnlocked to '..tostring(unlock))
        if force then
            part:getModData()["AquaCabin_isLockRuined"] = true
        end
        --print('set AquaCabin_isUnlocked to '..tostring(unlock)..' ruined='..tostring(part:getModData()["AquaCabin_isLockRuined"]))
        boat:transmitPartModData(part)
    end
end
-- sendClientCommand(arg_pl, 'aquatsar', 'unlockCabin', {boat = boat:getId(), })
function Commands.unlockCabin(playerObj, args)
    if args.boat then
        local boat = getVehicleById(args.boat)
        Actions.setLockState(boat, boat and boat:getPartById("CabinLock"), true, false)
    end
end

-- sendClientCommand(self.character, 'aquatsar', 'forceUnlockCabin', {boat = boat:getId(), })
function Commands.forceUnlockCabin(playerObj, args)
    if args.boat then
        local boat = getVehicleById(args.boat)
        Actions.setLockState(boat, boat and boat:getPartById("CabinLock"), true, true)
    end
end

-- sendClientCommand(arg_pl, 'aquatsar', 'lockCabin', {boat = boat:getId(), })
function Commands.lockCabin(playerObj, args)
    if args.boat then
        local boat = getVehicleById(args.boat)
        Actions.setLockState(boat, boat and boat:getPartById("CabinLock"), false, false)
    end
end

function Actions.setSailCode(boat, sails, sailCode)--BaseVehicle, VehiclePart, int
    if not boat then
        if sails then
            boat = sails:getVehicle()
            if not boat then
                print('ERROR Actions.setSailCode cannot find boat Vehicle.')
            end
        else
            print('ERROR Actions.setSailCode without boat Vehicle nor sails VehiclePart.')
        end
    elseif not sails then
        sails = boat:getPartById("Sails")
        if not sails then
            print('ERROR Actions.setSailCode without boat Vehicle nor sails VehiclePart.')
        end
    end
    
    if boat and sails then
        if sailCode == 0 then sailCode = nil end--backward compatibility
        if sailCode ~= sails:getModData().sailCode then
            sails:getModData().sailCode = sailCode
            boat:transmitPartModData(sails)
        end
        VehicleUtils.callLua(sails:getLuaFunction("init"), boat, sails)
    end
end

-- sendClientCommand(arg_pl, 'aquatsar', 'setSailCode', {boat = boat:getId(), sailCode = 1})
function Commands.setSailCode(playerObj, args)
    if args and args.boat then
        Actions.setSailCode(getVehicleById(args.boat), sails, args.sailCode)
    end
end

-- sendClientCommand(playerObj, 'aquatsar', 'useAnchor', {})
function Commands.useAnchor(playerObj, args)
    local boat = playerObj:getVehicle()
    if boat then
      local part = boat:getPartById("BoatAnchor")
      if part:getInventoryItem() then
        part:setInventoryItem(nil)
      else
        VehicleUtils.createPartInventoryItem(part)
      end
      boat:transmitPartItem(part)
    end
end

CommonCommands.OnClientCommand = function(module, command, playerObj, args)
    if module == 'aquatsar' and Commands[command] then
        args = args or {}
        --local argStr = ''
        --for k,v in pairs(args) do
        --    argStr = argStr..' '..k..'='..tostring(v)
        --end
        Commands[command](playerObj, args)
    end
end

Events.OnClientCommand.Add(CommonCommands.OnClientCommand)
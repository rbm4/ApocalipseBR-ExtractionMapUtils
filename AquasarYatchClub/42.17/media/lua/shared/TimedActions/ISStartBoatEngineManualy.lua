--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISStartBoatEngineManualy = ISBaseTimedAction:derive("ISStartBoatEngineManualy")

function ISStartBoatEngineManualy:isValid()
    return self.boat ~= nil and
--        boat:isEngineWorking() and
        self.boat:isDriver(self.character) and
        not self.boat:isEngineRunning() and 
        not self.boat:isEngineStarted()
end

function ISStartBoatEngineManualy:start()
    self.soundId = self.boat:getEmitter():playSound("TryStartEngineManualy")
end

function ISStartBoatEngineManualy:stop()
    self.boat:getEmitter():stopSound(self.soundId)
    ISBaseTimedAction.stop(self)
end

function ISStartBoatEngineManualy:perform()
    self.boat:getEmitter():stopSound(self.soundId)
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function ISStartBoatEngineManualy:complete()
    if self.boat then
        local haveKey = false;
        -- if self.character:getInventory():haveThisKeyId(boat:getKeyId()) then
            -- haveKey = true;
        -- end
        self.boat:setHotwired(true)
        self.boat:tryStartEngine(haveKey)--TODO FIX ME starting engine seems not be contered somehow, probably because of stuff specific to Sailing boats (conf? code?)
        --print('ISStartBoatEngineManualy engineDoStarting()')
    end
    return self.boat and true
end

function ISStartBoatEngineManualy:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 8 * 50;
end

function ISStartBoatEngineManualy:new(character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.boat = character and character:getVehicle()
    o.maxTime = o:getDuration()
    return o
end




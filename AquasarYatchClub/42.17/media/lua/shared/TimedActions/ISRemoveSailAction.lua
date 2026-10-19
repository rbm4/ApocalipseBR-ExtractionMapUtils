--***********************************************************
--**                      AQUATSAR                          **
--***********************************************************

require "TimedActions/ISBaseTimedAction"
require 'AquaConfig'

ISRemoveSailAction = ISBaseTimedAction:derive("ISRemoveSailAction")

function ISRemoveSailAction:isValid()
    return self.character:getVehicle() ~= nil
end

function ISRemoveSailAction:update()

end

function ISRemoveSailAction:start()
    setGameSpeed(1)
    self.boat:getEmitter():playSound("boat_sails_remove")
end

function ISRemoveSailAction:stop()
    self.boat:getEmitter():stopSoundByName("boat_sails_remove")
    ISBaseTimedAction.stop(self)
end

function ISRemoveSailAction:perform()
    setGameSpeed(1)
    ISBaseTimedAction.perform(self)
end

function ISRemoveSailAction:complete()
    self.character:getStats():remove(CharacterStat.ENDURANCE, 0.23)
    syncPlayerStats(self.character, 0x00000002)
    Aquatsar.BoatsActions.setSailCode(self.boat, self.boat:getPartById("Sails"), nil)
    return true
end

function ISRemoveSailAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 300
end

function ISRemoveSailAction:new(character, boat)
    local o = ISBaseTimedAction.new(self, character)
    o.boat = boat
    o.isFadeOut = false
    o.maxTime = o:getDuration()
    return o
end


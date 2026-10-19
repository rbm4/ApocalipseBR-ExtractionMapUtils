--***********************************************************
--**                      AQUATSAR                          **
--***********************************************************

require "TimedActions/ISBaseTimedAction"
require 'AquaConfig'

ISSetSailAction = ISBaseTimedAction:derive("ISSetSailAction")

function ISSetSailAction:isValid()
    if not self.boat:getPartById("Sails") or not self.boat:getPartById("Sails"):getInventoryItem() then 
        return false
    else
        return self.character:getVehicle() ~= nil
    end
end

function ISSetSailAction:update()
end

function ISSetSailAction:start()
    setGameSpeed(1)
    if not self.boat:getPartById("Sails"):getLight():getActive() then
        self.boat:getEmitter():playSound("boat_sails_set")
        if self.character:getModData()["isFirstSail"] == nil then
            self.character:getModData()["isFirstSail"] = false
            getSoundManager():StopMusic()
            self.sound = getSoundManager():playMusic("aquatsar_main_theme");
            self.isFirstSail = true
        end
    else
        self.maxTime = 200
        self.boat:getEmitter():playSound("boat_sails_change_direction")
    end
end

function ISSetSailAction:stop()
    setGameSpeed(1)
    self.boat:getEmitter():stopSoundByName("boat_sails_set")
    ISBaseTimedAction.stop(self)
end

function ISSetSailAction:perform()
     setGameSpeed(1)
   ISBaseTimedAction.perform(self)
end

function ISSetSailAction:complete()
    self.character:getStats():remove(CharacterStat.ENDURANCE, 0.23)
    syncPlayerStats(self.character, 0x00000002)
    Aquatsar.BoatsActions.setSailCode(self.boat, self.boat:getPartById("Sails"), self.dir == "RIGHT" and 2 or 1)
    return true
end

function ISSetSailAction:getDuration()
    return 400
end

function ISSetSailAction:new(character, boat, dir)
    local o = ISBaseTimedAction.new(self, character)
    o.boat = boat
    o.dir = dir
    o.playerNum = character:getPlayerNum()
    o.isFadeOut = false
    o.maxTime = o:getDuration()
    return o
end


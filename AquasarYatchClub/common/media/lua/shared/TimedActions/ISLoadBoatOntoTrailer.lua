--**************************************************************
--**                    Developer: Aiteron                    **
--**************************************************************
require "AquaConfig"
require "TimedActions/ISBaseTimedAction"

ISLoadBoatOntoTrailer = ISBaseTimedAction:derive("ISLoadBoatOntoTrailer")


function ISLoadBoatOntoTrailer:isValid()
    return self.trailer and not self.trailer:isRemovedFromWorld() and not self.trailer:getCharacter(0);
end

function ISLoadBoatOntoTrailer:update()
    self.character:faceThisObject(self.trailer)
    -- speed 1 = 1, 2 = 5, 3 = 20, 4 = 40
    local uispeed = UIManager.getSpeedControls():getCurrentGameSpeed()
    local speedCoeff = { [1] = 1, [2] = 5, [3] = 20, [4] = 40 }

    local timeLeftNow =  (1 - self:getJobDelta()) * self.maxTime

    if self.isFadeOut == false and timeLeftNow < 250 * speedCoeff[uispeed] then
        self.isFadeOut = true
    end

    self.character:setMetabolicTarget(Metabolics.HeavyWork);
end

function ISLoadBoatOntoTrailer:start()
    setGameSpeed(1)
    self:setActionAnim("Loot")
    self.trailer:getEmitter():playSound("boat_on_trailer")
end

function ISLoadBoatOntoTrailer:stop()
    if self.isFadeOut == true then
        UIManager.FadeIn(self.character:getPlayerNum(), 1)
        UIManager.setFadeBeforeUI(self.character:getPlayerNum(), false)
    end
    setGameSpeed(1)
    self.trailer:getEmitter():stopSoundByName("boat_on_trailer")
    ISBaseTimedAction.stop(self)
end

function ISLoadBoatOntoTrailer:perform()
    local playerNum = self.character:getPlayerNum()
    UIManager.FadeIn(playerNum, 1)
    UIManager.setFadeBeforeUI(playerNum, false)
    setGameSpeed(1)
    self.trailer:getEmitter():stopSoundByName("boat_on_trailer")
    ISBaseTimedAction.perform(self)
end

function ISLoadBoatOntoTrailer:complete()
    if self.boat:getCharacter(0) then return false end
    Aquatsar.BoatsActions.loadBoat(self.trailer, self.boat)
    return true
end

function ISLoadBoatOntoTrailer:getDuration()
    if self.character:isMechanicsCheat() or self.character:isTimedActionInstant() then
        return 1
    end
    return 500;-- TODO исправить на 1000
end

function ISLoadBoatOntoTrailer:new(character, trailer, boat)
    local o = ISBaseTimedAction.new(self, character)
    o.trailer = trailer
    o.boat = boat
    o.isFadeOut = false
    o.maxTime = o:getDuration()
    return o
end


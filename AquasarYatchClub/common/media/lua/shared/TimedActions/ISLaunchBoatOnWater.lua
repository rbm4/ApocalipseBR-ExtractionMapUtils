--**************************************************************
--**                    Developer: Aiteron                    **
--**************************************************************
require "AquaConfig"
require "TimedActions/ISBaseTimedAction"

ISLaunchBoatOnWater = ISBaseTimedAction:derive("ISLaunchBoatOnWater")


function ISLaunchBoatOnWater:isValid()
    return self.trailer and not self.trailer:isRemovedFromWorld();
end

function ISLaunchBoatOnWater:update()
    self.character:faceThisObject(self.trailer)

    -- speed 1 = 1, 2 = 5, 3 = 20, 4 = 40
    local uispeed = UIManager.getSpeedControls():getCurrentGameSpeed()
    local speedCoeff = { [1] = 1, [2] = 5, [3] = 20, [4] = 40 }

    local timeLeftNow =  (1 - self:getJobDelta()) * self.maxTime

    if self.isFadeOut == false and timeLeftNow < 115 * speedCoeff[uispeed] then
        self.isFadeOut = true
    end

    self.character:setMetabolicTarget(Metabolics.HeavyWork);
end

function ISLaunchBoatOnWater:start()
    setGameSpeed(1)
    self:setActionAnim("Loot")
    self.trailer:getEmitter():playSound("boat_launching")
end

function ISLaunchBoatOnWater:stop()
    if self.isFadeOut == true then
        UIManager.setFadeBeforeUI(self.character:getPlayerNum(), false)
    end
    self.trailer:getEmitter():stopSoundByName("boat_launching")
    ISBaseTimedAction.stop(self)
end

function ISLaunchBoatOnWater:perform()
    local playerNum = self.character:getPlayerNum()
    UIManager.FadeIn(playerNum, 1)
    UIManager.setFadeBeforeUI(playerNum, false)
    setGameSpeed(1)
    ISBaseTimedAction.perform(self)
end

function ISLaunchBoatOnWater:complete()
    return Aquatsar.BoatsActions.launchBoat(self.trailer, self.square)
end

function ISLaunchBoatOnWater:getDuration()
    if self.character:isMechanicsCheat() or self.character:isTimedActionInstant() then
        return 1
    end
    return 300;
end

function ISLaunchBoatOnWater:new(character, trailer, square)
    local o = ISBaseTimedAction.new(self, character)
    o.trailer = trailer
    o.square = square
    o.isFadeOut = false
    o.maxTime = o:getDuration()
    return o
end


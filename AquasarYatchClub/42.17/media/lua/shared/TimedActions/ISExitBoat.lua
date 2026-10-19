--***********************************************************
--**                      AQUATSAR                          **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISExitBoat = ISBaseTimedAction:derive("ISExitBoat")

function ISExitBoat:isValid()
    return self.character:getVehicle() ~= nil
end

function ISExitBoat:update()
-- print("ISExitBoat update")
    -- Safety net: this action runs with maxTime = -1 and only ends when the exit animation
    -- fires the "End" event that sets ExitAnimationFinished. On an AMC waverunner the exit
    -- AnimNodes carry conditions, and a node deselected mid-play is destroyed without firing
    -- that event, which would leave the player frozen in the dismount pose, movement blocked,
    -- forever. Force the completion once the animation has had more than enough time to play.
    if self.AquaExitStartMs and self.character:GetVariable("ExitAnimationFinished") ~= "true" then
        local timeoutMs = (AMCTickControl and AMCTickControl.VEHICLE_ANIM_TIMEOUT_MS) or 1500
        if (getTimestampMs() - self.AquaExitStartMs) > timeoutMs then
            self.character:SetVariable("ExitAnimationFinished", "true")
        end
    end
    local vehicle = self.character:getVehicle()
    local seat = vehicle:getSeat(self.character)
    vehicle:playPassengerAnim(seat, "exit")
    if self.character:GetVariable("ExitAnimationFinished") == "true" then
            -- print("ExitAnimationFinished")
        self.character:ClearVariable("ExitAnimationFinished")
        self.character:ClearVariable("bExitingVehicle")
        self:forceComplete()
    end
end

function ISExitBoat:start()
    self.action:setBlockMovementEtc(true) -- ignore 'E' while exiting
    local vehicle = self.character:getVehicle()
    local seat = vehicle:getSeat(self.character)
    -- Set the anim variables BEFORE bExitingVehicle switches the ActionGroup to "exit": the
    -- AnimState re-picks the best matching node every frame, and a node that only becomes
    -- valid a few ticks later is destroyed without firing its "End" event. Guarded, the
    -- Motor Club mod may not be loaded.
    local amcPart = vehicle and vehicle:getPartById("AMCConfig")
    local amcInfo = amcPart and amcPart:getTable("AMCConfig")
    if amcInfo and AMCTickControl and AMCTickControl.primeAnimVariables then
        AMCTickControl.primeAnimVariables(self.character, vehicle, seat, amcInfo)
    end
    if AMCTickControl and AMCTickControl.markAnimStart then
        AMCTickControl.markAnimStart(self.character)
    end
    self.AquaExitStartMs = getTimestampMs()
    self.character:SetVariable("bExitingVehicle", "true")
    vehicle:playPassengerSound(seat, "exit")
end

function ISExitBoat:stop()
    self.character:clearVariable("bExitingVehicle")
    self.character:clearVariable("ExitAnimationFinished")
    local vehicle = self.character:getVehicle()
    local seat = vehicle:getSeat(self.character)
    vehicle:playPassengerAnim(seat, "idle")
    ISBaseTimedAction.stop(self)
end

function ISExitBoat:perform()
    local vehicle = self.character:getVehicle()
    local seat = vehicle:getSeat(self.character)
    local motoInfo = nil
    if vehicle and vehicle:getPartById("AMCConfig") then
        motoInfo = vehicle:getPartById("AMCConfig"):getTable("AMCConfig")
    end
    if motoInfo then
        self.character:clearVariable("ATVehicleType")
        self.character:clearVariable("ATVehicleStatus")
        self.character:clearVariable("ATPassengerStatus")
        if isClient() then
            ModData.getOrCreate("tsaranimations")[self.character:getOnlineID()] = nil
            ModData.transmit("tsaranimations")
        end
        sendClientCommand(self.character, 'autotsaranim', 'updateVariables', {vehicle = self.character:getVehicle():getId(), seatId = self.character:getVehicle():getSeat(self.character), status = "none",})
    end
    vehicle:exit(self.character)
    --vehicle:setCharacterPosition(self.character, seat, "outside")
    self.character:PlayAnim("Idle")
    triggerEvent("OnExitVehicle", self.character)
    vehicle:updateHasExtendOffsetForExitEnd(self.character)
    if self.exitPos then
        self.character:setX(self.exitPos:x())
        self.character:setY(self.exitPos:y())
    else
        vehicle:setCharacterPosition(self.character, seat, "outside")
    end
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function ISExitBoat:new(character, exitPos)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.maxTime = -1
    o.exitPos = exitPos
    return o
end


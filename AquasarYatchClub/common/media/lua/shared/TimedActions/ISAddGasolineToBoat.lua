--***********************************************************
--**           THE INDIE STONE / edited iBrRus             **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISAddGasolineToBoat = ISBaseTimedAction:derive("ISAddGasolineToBoat")

local function predicateEmptyPetrol(item)
    return item:getFluidContainer() and item:getFluidContainer():isEmpty()
end

function ISAddGasolineToBoat:isValid()
    return true
end

function ISAddGasolineToBoat:update()
    local progress
    if isServer() then
        progress = self.netAction:getProgress()
    else
        progress = self:getJobDelta()
    end

    if not isServer() then
        self.character:faceThisObject(self.vehicle)
        self.item:setJobDelta(self:getJobDelta())
        self.item:setJobType(getText("ContextMenu_VehicleAddGas"))
    end

    if not isClient() then
	    local litres = self.tankStart + (self.tankTarget - self.tankStart) * progress
	    litres = math.floor(litres)
	    if litres ~= self.amountSent then
            if self.vehicle then
                if not self.part then
                    print('no such part ', self.part)
                    return
                end
                self.part:setContainerContentAmount(litres)
                self.vehicle:transmitPartModData(self.part)
            else
                print('no such vehicle id=', self.vehicle)
            end
	    	self.amountSent = litres
	    end
	    local litresTaken = litres - self.tankStart
	    if not predicateEmptyPetrol(self.item) then
            self.fluidCont:adjustAmount(self.itemStart - litresTaken)
            self.item:syncItemFields();
        end
    end

    self.character:setMetabolicTarget(Metabolics.HeavyDomestic);
end

function ISAddGasolineToBoat:animEvent(event, parameter)
    if isServer() then
        if event == "update" then
            self:update();
        end
    end
end

function ISAddGasolineToBoat:serverStart()
    local period = 1000; -- basically 50 * 20
    emulateAnimEvent(self.netAction, period, "update", nil)
end

function ISAddGasolineToBoat:start()
    self:setActionAnim("refuelgascan")
    self:setOverrideHandModels(self.item:getStaticModel(), nil)
    self.sound = self.character:playSound("VehicleAddFuelFromCanister")
end

function ISAddGasolineToBoat:stop()
    self.character:stopOrTriggerSound(self.sound)
    self.item:setJobDelta(0)
    ISBaseTimedAction.stop(self)
end

function ISAddGasolineToBoat:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.item:setJobDelta(0)
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function ISAddGasolineToBoat:complete()
    self.fluidCont:adjustAmount(self.itemTarget)
    if self.vehicle then
        if not self.part then
            print('no such part ', self.part)
            return false
        end
        self.part:setContainerContentAmount(self.tankTarget)
        self.vehicle:transmitPartModData(self.part)
    else
        print('ISAddGasolineToBoat no such vehicle id=', self.vehicle)
    end

    self.item:syncItemFields();
    return true
end

function ISAddGasolineToBoat:serverStop()
    self.item:syncItemFields();
    self.vehicle:transmitPartModData(self.part)
end

function ISAddGasolineToBoat:getDuration()
    self.tankStart = self.part:getContainerContentAmount();
    self.itemStart = self.fluidCont:getAmount();
    local add = self.part:getContainerCapacity() - self.tankStart;
    local take = math.min(add, self.itemStart);
    self.tankTarget = self.tankStart + take;
    self.itemTarget = self.itemStart - take;
    self.amountSent = self.tankStart
    return take * 25
end

function ISAddGasolineToBoat:new(character, part, item)
    local o = ISBaseTimedAction.new(self, character)
    o.part = part
    o.item = item
    o.vehicle = part:getVehicle()
    o.fluidCont = o.item:getFluidContainer();
    o.maxTime = o:getDuration();
    return o
end


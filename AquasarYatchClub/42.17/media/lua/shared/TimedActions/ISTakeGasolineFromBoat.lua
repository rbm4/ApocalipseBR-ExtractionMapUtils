--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISTakeGasolineFromBoat = ISBaseTimedAction:derive("ISTakeGasolineFromBoat")

local function predicateEmptyPetrol(item)
	return item:getFluidContainer() and item:getFluidContainer():isEmpty()
end

function ISTakeGasolineFromBoat:isValid()
--	return self.vehicle:isInArea(self.part:getArea(), self.character)
	return true;
end

function ISTakeGasolineFromBoat:update()
	local progress
	if isServer() then
		progress = self.netAction:getProgress()
	else
		progress = self:getJobDelta()
	end

	if not isServer() then
		self.character:faceThisObject(self.vehicle)
		self.item:setJobDelta(progress)
		self.item:setJobType(getText("ContextMenu_VehicleSiphonGas"))
	end

	if not isClient() then
		local litres = self.tankStart + (self.tankTarget - self.tankStart) * progress
		litres = math.ceil(litres)
		if litres ~= self.amountSent then
			self.part:setContainerContentAmount(litres)
			self.amountSent = litres
		end
		local litresTaken = self.tankStart - litres

		if not predicateEmptyPetrol(self.item) then
			self.fluidCont:adjustAmount(self.itemStart + litresTaken);
		else
			self.fluidCont:addFluid(Fluid.Petrol, litresTaken);
		end
		self.item:syncItemFields();
	end

	self.character:setMetabolicTarget(Metabolics.HeavyDomestic);
end

function ISTakeGasolineFromBoat:animEvent(event, parameter)
	if isServer() then
		if event == "update" then
			self:update();
		end
	end
end

function ISTakeGasolineFromBoat:serverStart()
	local period = 1000; -- basically 50 * 20
	emulateAnimEvent(self.netAction, period, "update", nil)
end

function ISTakeGasolineFromBoat:start()
	self:setActionAnim("TakeGasFromVehicle")
	self:setOverrideHandModels(nil, self.item:getStaticModel())

	self.sound = self.character:playSound("CanisterAddFuelSiphon")
end

function ISTakeGasolineFromBoat:stop()
	self.character:stopOrTriggerSound(self.sound)
	self.item:setJobDelta(0)
	ISBaseTimedAction.stop(self)
end

function ISTakeGasolineFromBoat:perform()
	self.character:stopOrTriggerSound(self.sound)
    self.item:setJobDelta(0)
	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ISTakeGasolineFromBoat:complete()
	self.fluidCont:adjustAmount(self.itemTarget)
   	if self.vehicle then
   		if not self.part then
   			print('no such part ',self.part)
   			return false
   		end
		self.part:setContainerContentAmount(self.tankTarget)
   		self.vehicle:transmitPartModData(self.part)
   	else
   		print('no such vehicle id=',self.vehicle)
   	end

	self.item:syncItemFields();
    return true
end

function ISTakeGasolineFromBoat:serverStop()
	self.item:syncItemFields();
    self.vehicle:transmitPartModData(self.part)
end

function ISTakeGasolineFromBoat:getDuration()
    self.itemStart = self.fluidCont:getAmount();
    self.tankStart = self.part:getContainerContentAmount();
    local add = self.fluidCont:getFreeCapacity();
    local take = math.min(add, self.tankStart);
    self.tankTarget = self.tankStart - take;
    self.itemTarget = self.itemStart + take;
    self.amountSent = math.ceil(self.tankStart);
	return take * 50
end

function ISTakeGasolineFromBoat:new(character, part, item)
	local o = ISBaseTimedAction.new(self, character)
	o.vehicle = part:getVehicle()
	o.part = part
	o.item = item
	o.fluidCont = o.item:getFluidContainer();
	o.maxTime = o:getDuration();
	return o
end



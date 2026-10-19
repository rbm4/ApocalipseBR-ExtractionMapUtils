require "TimedActions/ISBaseTimedAction"

ISRepairBoatEngine = ISBaseTimedAction:derive("ISRepairBoatEngine")

function ISRepairBoatEngine:isValid()
    return true;
end


function ISRepairBoatEngine:update()
    self.item:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.MediumWork);
end

function ISRepairBoatEngine:start()
    self.item:setJobType(getText("IGUI_RepairEngine"))
    self:setActionAnim("VehicleWorkOnMid")
end

function ISRepairBoatEngine:stop()
	self.item:setJobDelta(0)
	ISBaseTimedAction.stop(self)
end

function ISRepairBoatEngine:perform()
    self.item:setJobDelta(0)
	ISBaseTimedAction.perform(self)
end

function ISRepairBoatEngine:complete()

	local skill = self.character:getPerkLevel(Perks.Mechanics) - self.vehicle:getScript():getEngineRepairLevel();
	local numberOfParts = self.character:getInventory():getNumberOfItem("EngineParts", false, true);
	local giveXP = self.character:getMechanicsItem(self.part:getVehicle():getMechanicalID() .. "2") == nil
    if self.vehicle then
    	if not self.part then
    		noise('no such part Engine')
    		return false
    	end
    	local condPerPart = 1 + (skill / 2)
    	if condPerPart > 5 then condPerPart = 5 end
    	local done = 0
    	for i=1,numberOfParts do
    		self.part:setCondition(self.part:getCondition() + condPerPart)
    		done = done + 1
    		if self.part:getCondition() >= 100 then
    			self.part:setCondition(100)
    			break
    		end
    	end
    	if done > 0 then
    		if giveXP then
    			addXp(self.character, Perks.Mechanics, done);
    		end
    		local items = self.character:getInventory():RemoveAll('EngineParts', tonumber(done))
    		sendRemoveItemsFromContainer(self.character:getInventory(), items);
    		self.vehicle:transmitPartCondition(self.part)
    	else
    	    addXp(self.character, Perks.Mechanics, 1);
    	end
    	self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE, { success = (done > 0)})
    	if done > 0 then
            self.character:addMechanicsItem(self.item:getID() .. self.vehicle:getMechanicalID() .. "1", self.part, getGameTime():getCalender():getTimeInMillis());
        else
            addXp(self.character, Perks.Mechanics, 1);
        end
    else
    	print('no such vehicle id=',self.vehicle)
    end
	self.character:addMechanicsItem(self.part:getVehicle():getMechanicalID() .. "2", self.part, getGameTime():getCalender():getTimeInMillis());

	return true
end

function ISRepairBoatEngine:getDuration()
	if self.character:isTimedActionInstant() then
		return 1;
	end
	return self.maxTime;
end

function ISRepairBoatEngine:new(character, part, item, maxTime)
	local o = ISBaseTimedAction.new(self, character)
	o.vehicle = part:getVehicle()
	o.part = part
	o.item = item
	o.maxTime = maxTime
	o.jobType = getText("IGUI_RepairEngine")
	return o
end


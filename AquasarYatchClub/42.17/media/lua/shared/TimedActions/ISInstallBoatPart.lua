require "TimedActions/ISBaseTimedAction"

ISInstallBoatPart = ISBaseTimedAction:derive("ISInstallBoatPart")

function ISInstallBoatPart:isValid()
	if self.character:isMechanicsCheat() then return true; end
	if isClient() and self.item then
	    return self.vehicle:canInstallPart(self.character, self.part) and self.character:getInventory():containsID(self.item:getID());
	else
	    return self.vehicle:canInstallPart(self.character, self.part) and self.character:getInventory():contains(self.item);
	end
end

function ISInstallBoatPart:update()
    self.item:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.MediumWork);
end

function ISInstallBoatPart:start()
    if isClient() and self.item then
        self.item = self.character:getInventory():getItemById(self.item:getID())
    end
	self.item:setJobType(getText("IGUI_Install"))

end

function ISInstallBoatPart:stop()
	self.item:setJobDelta(0)
	ISBaseTimedAction.stop(self)
end

function ISInstallBoatPart:perform()
    local pdata = getPlayerData(self.character:getPlayerNum());
    if pdata ~= nil then
       	pdata.playerInventory:refreshBackpacks();
        pdata.lootInventory:refreshBackpacks();
    end

	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function ISInstallBoatPart:complete()
	self.item:setJobDelta(0)

	self.character:removeFromHands(self.item)
	self.character:getInventory():DoRemoveItem(self.item)
	sendRemoveItemFromContainer(self.character:getInventory(),self.item)

	local perksTable = VehicleUtils.getPerksTableForChr(self.part:getTable("install").skills, self.character)
   	if self.vehicle then
    	if not self.part then
    		print('ISInstallBoatPart no such part ',self.part)
    		return
    	end
    		local keyvalues = self.part:getTable("install");
    		local perks = keyvalues.skills;
    		local success, failure = VehicleUtils.calculateInstallationSuccess(perks, self.character, perksTable);
    		if not instanceof(self.item, "InventoryItem") then
    			print('ISInstallBoatPart item is nil')
    			return
    		end
    		if instanceof(self.item, "Radio") and self.item:getDeviceData() ~= nil then
    			local presets = self.item:getDeviceData():getDevicePresets()
    			if self.part:getDeviceData() == nil then
                    self.part:createSignalDevice()
                end
    			self.part:getDeviceData():cloneDevicePresets(presets)
    		end
    		if ZombRand(100) < success then
    			self.part:setInventoryItem(self.item, self.character:getPerkLevel(Perks.Mechanics))
    			local tbl = self.part:getTable("install")
    			if tbl and tbl.complete then
    				VehicleUtils.callLua(tbl.complete, self.vehicle, self.part)
    			end
    			self.vehicle:transmitPartItem(self.part)
    			self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE, { success = true})
    			self.character:addMechanicsItem(self.item:getID() .. self.vehicle:getMechanicalID() .. "1", self.part, getGameTime():getCalender():getTimeInMillis());
    		elseif ZombRand(100) < failure then
    			self.item:setCondition(self.item:getCondition() - ZombRand(5,10));
    			self.character:getInventory():AddItem(self.item);
    			sendAddItemToContainer(self.character:getInventory(), self.item);
    			playServerSound("PZ_MetalSnap", self.character:getCurrentSquare());
    			self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE, { success = false})
    			addXp(self.character, Perks.Mechanics, 1);
    		else
    			self.character:getInventory():AddItem(self.item);
    			sendAddItemToContainer(self.character:getInventory(), self.item);
    			self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE, { success = false})
    			addXp(self.character, Perks.Mechanics, 1);
    		end
    	else
    		print('ISInstallBoatPart no such vehicle id=',self.vehicle)
    	end

	return true
end

function ISInstallBoatPart:getDuration()
    if self.character:isMechanicsCheat() or self.character:isTimedActionInstant() then
        return 1
    end
    return self.maxTime;
end

function ISInstallBoatPart:new(character, part, item, maxTime)
	local o = ISBaseTimedAction.new(self, character)
	o.vehicle = part:getVehicle()
	o.part = part
	o.item = item
	o.maxTime = maxTime;
	o.jobType = getText("Tooltip_Vehicle_Installing", item:getDisplayName());
	return o
end


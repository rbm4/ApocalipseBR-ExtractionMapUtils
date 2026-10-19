--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISUninstallBoatPart = ISBaseTimedAction:derive("ISUninstallBoatPart")

function ISUninstallBoatPart:isValid()
	if self.character:isMechanicsCheat() then return true; end
	return self.part:getInventoryItem() and self.vehicle:canUninstallPart(self.character, self.part)
end

function ISUninstallBoatPart:update()
    self.character:setMetabolicTarget(Metabolics.MediumWork);
end

function ISUninstallBoatPart:start()
end

function ISUninstallBoatPart:stop()
    setGameSpeed(1)
    ISBaseTimedAction.stop(self)
end

function ISUninstallBoatPart:perform()
    setGameSpeed(1)
    ISBaseTimedAction.perform(self)
end

function ISUninstallBoatPart:complete()
	local perksTable = VehicleUtils.getPerksTableForChr(self.part:getTable("install").skills, self.character)
    if self.vehicle then
    	if not self.part then
    		print('no such part '..tostring(self.part))
    		return false
    	end
    	local keyvalues = self.part:getTable("install");
    	local perks = keyvalues.skills;
    	local success, failure = VehicleUtils.calculateInstallationSuccess(perks, self.character, perksTable);
    	local item = self.part:getInventoryItem()
    	if not item then
    		print('ISUninstallBoatPart part already uninstalled ', self.part)
    		return false
    	end
    	if instanceof(item, "Radio") and item:getDeviceData() ~= nil then
            if self.part:getDeviceData() == nil then
                self.part:createSignalDevice()
            end
    		local presets = self.part:getDeviceData():getDevicePresets()
    		item:getDeviceData():cloneDevicePresets(presets)
    	end
    	if ZombRand(100) < success then
			item:setItemCapacity(self.part:getContainerContentAmount());
			self.part:setInventoryItem(nil)
    		local tbl = self.part:getTable("uninstall")
    		if tbl and tbl.complete then
                --print('ISUninstallBoatPart:complete call '..tostring(tbl.complete))
        		VehicleUtils.callLua(tbl.complete, self.vehicle, self.part, item)
    		end
    		self.vehicle:transmitPartItem(self.part)
            --print('ISUninstallBoatPart:complete success has room = '..tostring(self.character:getInventory():hasRoomFor(self.character, item)))
    		-- this is so player don't go over inventory capacity when removing parts
    		if self.character:getInventory():hasRoomFor(self.character, item) then
    			self.character:getInventory():AddItem(item);
    			sendAddItemToContainer(self.character:getInventory(), item);
    		else--put in any container available from current position
                local vehicle = self.vehicle
                local playerObj = self.character
                local container = nil
                for partIndex=1,vehicle:getPartCount() do
                    local vehiclePart = vehicle:getPartByIndex(partIndex-1)
                    local itContainer = vehiclePart:getItemContainer()
                    if itContainer and vehicle:canAccessContainer(partIndex-1, playerObj) and vehiclePart:getId() ~= "TruckBed"
                    and ItemContainer.floatingPointCorrection(itContainer:getCapacityWeight()) + item:getUnequippedWeight() <= itContainer:getEffectiveCapacity(self.character) then
                        container = itContainer
                        break;
                    end
                end
                if container and container:isItemAllowed(item)  then
                    container:AddItem(item);
                    sendAddItemToContainer(container, item);
                else--TODO Tch: let's not drop the part item offboard. trying to force Player inventory but this just cancels the dismount in MP afaik.
                    --local square = self.character:getCurrentSquare()
                    --local dropX,dropY,dropZ = ISTransferAction.GetDropItemOffset(self.character, square, item)
                    --self.character:getCurrentSquare():AddWorldInventoryItem(item, dropX, dropY, dropZ);
                    --if ISInventoryPage then ISInventoryPage.renderDirty = true end--not server side
                    self.character:getInventory():AddItem(item);
                    sendAddItemToContainer(self.character:getInventory(), item);
                end
   			end
   			self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE, { success = true})
   			self.character:addMechanicsItem(item:getID() .. self.vehicle:getMechanicalID() .. "0", self.part, getGameTime():getCalender():getTimeInMillis());
   		elseif ZombRand(failure) < 100 then
   			self.part:setCondition(self.part:getCondition() - ZombRand(5,10));
   			self.vehicle:transmitPartCondition(self.part)
   			playServerSound("PZ_MetalSnap", self.character:getCurrentSquare());
   			self.character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE, { success = false})
   			addXp(self.character, Perks.Mechanics, 1);
   		end
   	else
   		print('ISUninstallBoatPart no such vehicle id=', self.vehicle)
   	end

	return true
end

function ISUninstallBoatPart:getDuration()
    if self.character:isMechanicsCheat() or self.character:isTimedActionInstant() then
        return 1
    end
	return self.workTime - (self.character:getPerkLevel(Perks.Mechanics) * (self.workTime/15));
end

function ISUninstallBoatPart:new(character, part, workTime)
	local o = ISBaseTimedAction.new(self, character)
	o.vehicle = part:getVehicle()
	o.part = part
	o.workTime = workTime
	o.maxTime = o:getDuration();
	o.jobType = getText("Tooltip_Vehicle_Uninstalling", part:getInventoryItem():getDisplayName());
	return o
end


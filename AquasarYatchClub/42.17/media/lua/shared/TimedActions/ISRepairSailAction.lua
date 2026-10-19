--**************************************************************
--**                    Developer: Aiteron                    **
--**************************************************************

require "TimedActions/ISBaseTimedAction"

ISRepairSailAction = ISBaseTimedAction:derive("ISRepairSailAction")

function ISRepairSailAction:isValid()
    return self.character:getInventory():contains(self.sail) and
        self.character:getInventory():contains(self.item) and
        self.character:getInventory():contains(self.needle) and
        self.character:getInventory():contains(self.thread)
end

function ISRepairSailAction:update()
end

function ISRepairSailAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISRepairSailAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISRepairSailAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISRepairSailAction:complete()
    self.character:getInventory():Remove(self.item);
    self.thread:Use();
    self.character:getXp():AddXP(Perks.Tailoring, ZombRand(3, 6))
    self.sail:setCondition(self.sail:getCondition()+self.addCondition)
    --TODO update clients
    return true
end
function ISRepairSailAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1;
	end
	return 600;
end

function ISRepairSailAction:new(character, sail, item, thread, needle, addCondition)
	local o = ISBaseTimedAction.new(self, character)
    o.sail = sail
    o.item = item
    o.thread = thread
    o.needle = needle
    o.addCondition = addCondition
    o.maxTime = o:getDuration()
    return o
end

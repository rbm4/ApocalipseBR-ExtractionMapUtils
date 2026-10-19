require "TimedActions/ISBaseTimedAction"

ISDropItemToWaterAction = ISBaseTimedAction:derive("ISDropItemToWaterAction")

function ISDropItemToWaterAction:isValid()
    return true
end

function ISDropItemToWaterAction:update()
end

function ISDropItemToWaterAction:start()
    self:setActionAnim("Loot")
end

function ISDropItemToWaterAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISDropItemToWaterAction:perform()
    self.character:getEmitter():playSound("ThrowInWater")
    ISBaseTimedAction.perform(self)
end

function ISDropItemToWaterAction:complete()
    local container = self.item:getContainer()
    if container ~= nil then
        if isForceDropHeavyItem(self.item) then
            self.character:setPrimaryHandItem(nil);
            self.character:setSecondaryHandItem(nil);
        end
        self.character:removeFromHands(self.item)
        container:Remove(self.item)
        sendRemoveItemFromContainer(container,self.item)
    end
    return true
end

function ISDropItemToWaterAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = 50
    return o
end





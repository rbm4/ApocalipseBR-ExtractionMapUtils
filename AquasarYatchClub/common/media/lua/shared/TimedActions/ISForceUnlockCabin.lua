--***********************************************************
--**                      AQUATSAR                          **
--***********************************************************

require "TimedActions/ISBaseTimedAction"

ISForceUnlockCabin = ISBaseTimedAction:derive("ISForceUnlockCabin")
local BOREDOMBitMask = SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.BOREDOM)
local UNHAPPINESSBitMask = SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.UNHAPPINESS)


-- Предметы с помощью которых можно вскрыть каюту
ISForceUnlockCabin.openToolsTags = {}
ISForceUnlockCabin.openToolsTags[ItemTag.CROWBAR] = 60 --tag base:crowbar
ISForceUnlockCabin.openToolsTags[ItemTag.SCREWDRIVER] = 40 --base:screwdriver
ISForceUnlockCabin.openToolsTags[ItemTag.SHARP_KNIFE] = 35 --base:sharpknife
ISForceUnlockCabin.openToolsTags[ItemTag.DULL_KNIFE] = 30 --base:dullknife

ISForceUnlockCabin.openToolsItems = {}
ISForceUnlockCabin.openToolsItems["Base.LetterOpener"] = 25
ISForceUnlockCabin.openToolsItems["Base.ButterKnife"] = 25
ISForceUnlockCabin.openToolsItems["Base.IcePick"] = 20
ISForceUnlockCabin.openToolsItems["Base.Scalpel"] = 20

function ISForceUnlockCabin.getOpeningChance(item)
    if not item then return 0 end
    local maxChance = 0
    for tag,chance in pairs(ISForceUnlockCabin.openToolsTags) do
        if item:hasTag(tag) and chance > maxChance then maxChance = chance end
    end
    for itemFullType,chance in pairs(ISForceUnlockCabin.openToolsItems) do
        if item:getFullType()==itemFullType and chance > maxChance then maxChance = chance end
    end
    return maxChance
end

local function fakePredicate(item1)
    return true
end

local function comparatorBestOpeningChance(item1, item2)
    return ISForceUnlockCabin.getOpeningChance(item1) - ISForceUnlockCabin.getOpeningChance(item2)
end

function ISForceUnlockCabin.getBestOpenerRecurse(itemContainer)
     local bestItem = itemContainer:getBestEvalRecurse(fakePredicate,comparatorBestOpeningChance)
     
     return ISForceUnlockCabin.getOpeningChance(bestItem) > 0 and bestItem or nil
end



function ISForceUnlockCabin:isValid()
    if self.character:getInventory():contains(self.opener) and self.boat and self.boat:getPartById("CabinLock") then 
        return true
    else 
        return false
    end
end

function ISForceUnlockCabin:update()
end

function ISForceUnlockCabin:start()
end

function ISForceUnlockCabin:serverStart()
    if not self.success then
        local actionTime = self:getDuration()
        if actionTime < 100 then
            if isServer() then
                self.netAction:forceStop()--stop now
            else
                self:forceStop()--never occures, serverStart is only called on server
            end
        else--let the action occure before stopping no need to wait full timer.
            emulateAnimEvent(self.netAction, actionTime *2/3, "DelayForceStop", nil)--arbotrarily stop at 2/3 of time
        end
    end
end

function ISForceUnlockCabin:animEvent(event, parameter)
    if isServer() and event == "DelayForceStop" then
        self.character:getStats():remove(CharacterStat.ENDURANCE, 0.3)
        syncPlayerStats(self.character, 0x00000002)--SyncPlayerStatsPacket.Stat_Endurance for CharacterStat.ENDURANCE
        self.character:getStats():add(CharacterStat.BOREDOM, 10)
        syncPlayerStats(self.character, BOREDOMBitMask)
        self.character:getStats():add(CharacterStat.UNHAPPINESS, 10)
        syncPlayerStats(self.character, UNHAPPINESSBitMask)
    
        self.netAction:forceStop()--stop now in order to get PZ_MetalSnap
    end
end

function ISForceUnlockCabin:stop()
    getSoundManager():PlayWorldSoundWav("PZ_MetalSnap", self.character:getCurrentSquare(), 1, 10, 2, true)
    ISBaseTimedAction.stop(self)
end

function ISForceUnlockCabin:perform()
    if not isClient() and not self.success then
        getSoundManager():PlayWorldSoundWav("PZ_MetalSnap", self.character:getCurrentSquare(), 1, 10, 2, true)
    else
        self.character:getEmitter():playSound("UnlockDoor")
    end
    ISBaseTimedAction.perform(self)
end

function ISForceUnlockCabin:complete()
    self.character:getStats():remove(CharacterStat.ENDURANCE, 0.7)
    syncPlayerStats(self.character, 0x00000002)--SyncPlayerStatsPacket.Stat_Endurance for CharacterStat.ENDURANCE
    self.character:getStats():add(CharacterStat.BOREDOM, 30)
    syncPlayerStats(self.character, BOREDOMBitMask)
    self.character:getStats():add(CharacterStat.UNHAPPINESS, 30)
    syncPlayerStats(self.character, UNHAPPINESSBitMask)
    if self.success then
        Aquatsar.BoatsActions.setLockState(self.boat, self.boat:getPartById("CabinLock"), true, true)
    end
    return self.success
end

function ISForceUnlockCabin:getDuration()
    if self.character:isTimedActionInstant() then
        if isServer() then
            return 300--give some slack to serverStart ?
         end
         return 1
    end
    return 3000
end

function ISForceUnlockCabin:new(character, boat, opener)
    local o = ISBaseTimedAction.new(self, character)
    o.boat = boat
    o.opener = opener
    o.success = not isClient() and ZombRand(100) < ISForceUnlockCabin.getOpeningChance(opener)--do the roll solo & server
    o.playerNum = character:getPlayerNum()
    o.isFadeOut = false
    o.maxTime = o:getDuration()
    return o
end


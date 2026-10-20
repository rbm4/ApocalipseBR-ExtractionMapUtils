-- Award corpse loot only for kills confirmed by the server.
if not isServer() then return end

require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
if Utils.ZombieMoneyLoaded then return end
Utils.ZombieMoneyLoaded = true

local function onZombieDead(zombie)
    if not Utils.zombieMoneyEnabled() or not isServer() or not zombie then return end

    local player = zombie:getAttackedBy()
    if not player or not instanceof(player, "IsoPlayer") then return end
    local onlineId = player:getOnlineID()
    if onlineId == nil or onlineId < 0 or getPlayerByOnlineID(onlineId) ~= player then return end

    local inventory = zombie:getInventory()
    if not inventory then return end
    local data = zombie:getModData()
    if data.ApocExtractionMoneyDropped then return end

    -- OnZombieDead runs after DoZombieInventory and before corpse creation;
    -- IsoDeadBody takes this inventory, including these additional items.
    inventory:AddItems("Base.Money", ZombRand(1, 11))
    data.ApocExtractionMoneyDropped = true
end

Events.OnZombieDead.Add(onZombieDead)

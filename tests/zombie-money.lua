local file = "ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_ZombieMoney.lua"
local server, hooks, rolls = false, {}, 0
function isServer() return server end
Events = { OnZombieDead = { Add = function(f) hooks[#hooks + 1] = f end } }
package.path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/?.lua;" .. package.path
SandboxVars = { ApocExtractionMapUtils = {} }
dofile(file)
assert(#hooks == 0 and not ApocExtractionMapUtils, "client/SP must not initialize server state")
server = true
dofile(file)
dofile(file)
assert(#hooks == 1, "loading twice must not duplicate rewards")
local onDead = hooks[1]
local connected = {}
function getPlayerByOnlineID(id) return connected[id] end
function instanceof(object, name) return object.class == name end
local amount = 1
function ZombRand(min, max)
    assert(min == 1 and max == 11, "exclusive upper bound must allow 1 through 10")
    rolls = rolls + 1
    return amount
end
local player = { class = "IsoPlayer", getOnlineID = function(self) return self.id end, id = 7 }
connected[7] = player
local function zombie(attacker)
    local data = {}
    local inventory = { existingLoot = "keep", count = 0 }
    function inventory:AddItems(item, count)
        assert(item == "Base.Money", "use the case-sensitive vanilla item ID")
        self.count = self.count + count
    end
    return {
        getAttackedBy = function() return attacker end,
        getInventory = function() return inventory end,
        getModData = function() return data end,
    }, inventory
end
for _, count in ipairs({ 1, 10 }) do
    local disabled, disabledInventory = zombie(player)
    onDead(disabled)
    assert(disabledInventory.count == 0 and not disabled.getModData().ApocExtractionMoneyDropped,
        "missing or false money setting must leave loot unchanged")
    SandboxVars.ApocExtractionMapUtils.ZombieMoneyDrops = true
    amount = count
    local z, inventory = zombie(player)
    onDead(z)
    assert(inventory.count == count and inventory.existingLoot == "keep", "append loot without replacing inventory")
    onDead(z)
    assert(inventory.count == count, "duplicate death notifications must not reward twice")
    SandboxVars.ApocExtractionMapUtils.ZombieMoneyDrops = false
end
SandboxVars.ApocExtractionMapUtils.ZombieMoneyDrops = true
local before = rolls
onDead(nil)
onDead(zombie(nil))
onDead(zombie({ class = "IsoZombie" }))
player.id = nil
onDead(zombie(player))
player.id = -1
onDead(zombie(player))
player.id = 7
connected[7] = nil
onDead(zombie(player))
connected[7] = { class = "IsoPlayer" }
onDead(zombie(player))
connected[7] = player
local noInventory = zombie(player)
noInventory.getInventory = function() return nil end
onDead(noInventory)
server = false
local z, inventory = zombie(player)
onDead(z)
assert(inventory.count == 0 and rolls == before, "invalid attribution, missing inventory and client calls must not roll rewards")
print("PASS: server authority; connected-player attribution; 1/10 endpoints; existing loot; duplicate death/load guards; invalid inputs")

if not isClient() then return end
local Device = require "ApocWallet/RadioDevice"
local Controller = require "ApocWallet/RadioUIController"
require "ApocWallet/UI/RadioWindowModule"
if ApocWallet.radioEntryPointsInstalled then return end
ApocWallet.radioEntryPointsInstalled = true

-- Inventory selection may contain either native items or inventory-stack wrappers.
Events.OnFillInventoryObjectContextMenu.Add(function(index,context,items)
    local player = getSpecificPlayer(index)
    if not player or player:isDead() then return end
    for _,selected in ipairs(items or {}) do
        local item = type(selected) == "table" and selected.items and selected.items[1] or selected
        if Device.isRadio(item) then
            context:addOption(getText("UI_ApocWallet_Open"),player,Controller.open,item)
            return
        end
    end
end)

Events.OnFillWorldObjectContextMenu.Add(function(index,context,objects,test)
    if test then return end
    local player = getSpecificPlayer(index)
    if not player or player:isDead() then return end
    for _,device in ipairs(objects or {}) do
        if Device.isRadio(device) then
            context:addOption(getText("UI_ApocWallet_Open"),player,Controller.open,device)
            return
        end
    end
end)
Events.OnPlayerDeath.Add(Controller.closePlayer)
Events.OnDisconnect.Add(Controller.closeAll)
Events.OnCreatePlayer.Add(function(index,player)
    local pending = Controller.approaches[index]
    if pending and pending.player ~= player then Controller.approaches[index] = nil end
    local old = Controller.windows[index]
    if old and old.player ~= player then Controller.close(old) end
    Controller.reflowAll()
end)
Events.OnResolutionChange.Add(Controller.reflowAll)

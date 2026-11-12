if not isServer() then return end
local Courier=require 'ApocWallet/CourierService'
local Purchase=require 'ApocWallet/PurchaseService'
if ApocWallet.courierControllerInstalled then return end
ApocWallet.courierControllerInstalled=true
local lastSync={}
Events.OnClientCommand.Add(function(module,command,player)
    if module~='ApocWallet' or command~='CourierSync' or not player then return end
    local key=player:getUsername(); local t=getTimestampMs()
    if t-(lastSync[key] or -10000)<5000 then return end
    lastSync[key]=t
    Courier.reconcilePickup(player)
    Courier.sync(player)
end)
Events.OnTick.Add(function() Courier.update(); Purchase.update() end)
-- Empty dedicated servers can pause normal world ticks. Wall-clock fulfillment
-- and loading requests must continue while the simulation is paused.
Events.OnTickEvenPaused.Add(function() Courier.update(); Purchase.update() end)

if not isServer() then return end
local Market=require 'ApocWallet/MarketService'
if ApocWallet.marketControllerInstalled then return end
ApocWallet.marketControllerInstalled=true
Events.OnClientCommand.Add(function(module,command,player,args)
    if module~='ApocWallet' or type(command)~='string' or command:sub(1,6)~='Market' then return end
    Market.run(player,command,args)
end)
Events.OnTick.Add(Market.update)
Events.OnTickEvenPaused.Add(Market.update)

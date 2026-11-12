if not isClient() then return end
local Controller=require 'ApocWallet/RadioUIController'
local Client=require 'ApocWallet/MarketClient'
local Panel=require 'ApocWallet/UI/MarketPanel'
if ApocWallet.radioMarketInstalled then return end
ApocWallet.radioMarketInstalled=true
local open,close=Controller.open,Controller.close
function Controller.open(player,radio)
    local win=open(player,radio)
    if win then Panel.attach(win) end
    return win
end
function Controller.close(win)
    if win and win.marketSession then
        Client.close(win.marketSession)
        if win.marketModal then win.marketModal:setVisible(false); win.marketModal:removeFromUIManager(); win.marketModal=nil end
    end
    return close(win)
end

if isServer() then return end
local Renderer=require 'ApocWallet/DroneRenderer'
local Route=require 'ApocWallet/CourierRoute'
if ApocWallet.CourierClient then return ApocWallet.CourierClient end
local Client={flights={},latestByPlayer={},nextSync=0}
ApocWallet.CourierClient=Client
function Client.latestFor(player)
    return player and Client.latestByPlayer[player:getOnlineID()]
end
function Client.receive(command,args)
    if type(args)~='table' then return end
    if command=='CourierFlight' and type(args.id)=='string' and type(args.path)=='table' then
        args.offset=args.serverNow-getTimestampMs()
        Client.flights[args.id]=args
    elseif command=='CourierETA' and type(args.id)=='string' and type(args.seconds)=='number' and type(args.onlineId)=='number' then
        local key=args.kind=='pickup' and 'UI_ApocWallet_CourierPickupFmt' or 'UI_ApocWallet_CourierDeliveryFmt'
        local message=getText(key,math.ceil(args.seconds))
        Client.latestByPlayer[args.onlineId]=message
        if ApocWallet.MarketClient then ApocWallet.MarketClient.courierETA(args) end
        if ApocWallet.RadioUIController then
            for _,win in pairs(ApocWallet.RadioUIController.windows) do
                if not win.closed and win.player:getOnlineID()==args.onlineId then win:setCourierMessage(message) end
            end
        end
    end
end
Events.OnServerCommand.Add(function(module,command,args)
    if module=='ApocWallet' then Client.receive(command,args) end
end)
Events.OnDisconnect.Add(function()
    Client.flights={}; Client.latestByPlayer={}; Client.nextSync=0
end)
function Client.render()
    local clock=getTimestampMs()
    for id,f in pairs(Client.flights) do
        local t=clock+f.offset
        local start=f.due-f.approach
        local finish=f.due+f.hover+f.depart
        if t>=finish then Client.flights[id]=nil
        elseif t>=start then
            local progress,height
            if t<f.due then
                progress=(t-start)/f.approach
                height=f.vertical and 1.8-1.2*progress or 0.6
            elseif t<f.due+f.hover then progress=1; height=0.6
            else
                progress=1-(t-f.due-f.hover)/f.depart
                height=f.vertical and 0.6+1.2*(1-progress) or 0.6
            end
            local x,y,yaw=Route.sample(f.path,progress)
            if t>=f.due+f.hover then yaw=(yaw+180)%360 end
            if x then Renderer.draw(x,y,f.z,height,yaw,t/1000) end
        end
    end
end
Events.OnPostRender.Add(function()
    local ok,error=pcall(Client.render)
    if not ok and Client.lastError~=tostring(error) then
        Client.lastError=tostring(error); print('[ApocWallet] courier render: '..Client.lastError)
    end
end)
Events.OnTick.Add(function()
    local t=getTimestampMs()
    if t<Client.nextSync then return end
    Client.nextSync=t+15000
    local player=getSpecificPlayer(0)
    if player and player:getOnlineID()>=0 then sendClientCommand(player,'ApocWallet','CourierSync',{}) end
end)
return Client

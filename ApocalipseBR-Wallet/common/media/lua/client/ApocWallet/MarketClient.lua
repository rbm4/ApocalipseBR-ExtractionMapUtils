if isServer() then return end
local P=require 'ApocWallet/MarketProtocol'
local Device=require 'ApocWallet/RadioDevice'
local Dialogue=require 'ApocWallet/RadioDialogue'
if ApocWallet.MarketClient then return ApocWallet.MarketClient end
local C={sessions={},seq=0}
ApocWallet.MarketClient=C
local function token(player)
    C.seq=C.seq+1
    return tostring(getTimestampMs())..':'..player:getOnlineID()..':'..C.seq
end
local function locator(radio)
    if instanceof(radio,'InventoryItem') and radio:getContainer() then return {itemId=radio:getID()} end
    if instanceof(radio,'VehiclePart') then return {vehicleId=radio:getVehicle():getId(),partId=radio:getId()} end
    local sq=Device.square(radio)
    if not sq then return {} end
    return {x=sq:getX(),y=sq:getY(),z=sq:getZ(),objectIndex=instanceof(radio,'IsoWaveSignal') and radio:getObjectIndex() or nil,
        worldItemId=instanceof(radio,'InventoryItem') and radio:getID() or nil}
end
function C.open(win)
    local old=C.sessions[win.playerIndex]
    if old and old.win==win then return old end
    if old then C.close(old) end
    local s={win=win,player=win.player,radio=win.radio,state='offline',mode='market',page=1,pages=1,rows={},
        dialogue=Dialogue.new(win.player,win.radio),nextPoll=0}
    C.sessions[win.playerIndex]=s
    return s
end
local function changed(s) if s.onChange then s.onChange(s) end end
function C.request(s,command,args)
    if s.pending then return false end
    args=args or {}; args.token=token(s.player)
    s.pending={token=args.token,command=command,args=args,sent=getTimestampMs()}
    sendClientCommand(s.player,'ApocWallet',command,args)
    changed(s)
    return true
end
function C.tune(s)
    if s.pending then return end
    s.state='tuning'; s.readyAt=getTimestampMs()+1800
    local sq=s.player:getCurrentSquare()
    s.dialogue:sound('Static')
    s.dialogue:enqueue('player','UI_ApocWallet_MarketTuneTxFmt',{P.sector(sq:getX(),sq:getY(),sq:getZ())})
    C.request(s,'MarketTune',{radio=locator(s.radio)})
end
function C.page(s,mode,page)
    if s.state~='connected' or s.pending or s.transaction then return end
    local t=getTimestampMs()
    if t<(s.nextNavigation or 0) then return end
    s.nextNavigation=t+350
    if C.request(s,'MarketPage',{mode=mode,page=page}) then s.pending.pageChatter=s.dialogue:page(mode,page) end
end
function C.post(s,row,count,price)
    if s.state~='connected' or s.pending or s.transaction then return end
    local ids={}
    for i=1,count do ids[i]=row.ids[i] end
    local sq=s.player:getCurrentSquare()
    s.dialogue:enqueue('player','UI_ApocWallet_MarketPostTxFmt',{row.code,count,P.sector(sq:getX(),sq:getY(),sq:getZ())})
    C.request(s,'MarketPost',{itemIds=ids,price=price})
end
function C.buy(s,row,count)
    if s.state~='connected' or s.pending or s.transaction then return end
    local sq=s.player:getCurrentSquare()
    s.dialogue:enqueue('player','UI_ApocWallet_MarketBuyTxFmt',{row.code,count,P.sector(sq:getX(),sq:getY(),sq:getZ())})
    C.request(s,'MarketBuy',{listingId=row.id,count=count})
end
local function apply(s,args)
    local request=s.pending
    local command=request.command
    if not args.ok and args.error=='STORAGE' then
        -- Preserve the original post/buy token across a temporary recording
        -- failure. A retry must resume the same intent, not create a new one.
        request.sent=getTimestampMs()
        if not request.storageNotice then
            request.storageNotice=true
            s.dialogue:enqueue('operator','UI_ApocWallet_MarketStorageError')
        end
        changed(s)
        return
    end
    s.pending=nil
    if command=='MarketTune' then s.dialogue:stopTuning() end
    if not args.ok then
        if args.error=='RADIO' or args.error=='SIGNAL' then s.state='offline' end
        if args.error~='WAIT' then s.transaction=nil end
        local errors={RADIO='UI_ApocWallet_MarketRadioError',SIGNAL='UI_ApocWallet_MarketSignalError',
            WAIT='UI_ApocWallet_MarketWait',ITEM='UI_ApocWallet_MarketItemError',SOLD='UI_ApocWallet_MarketSold',FUNDS='UI_ApocWallet_MarketFunds',
            UNAVAILABLE='UI_ApocWallet_MarketRefused'}
        s.dialogue:enqueue('operator',errors[args.error] or 'UI_ApocWallet_MarketRefused')
    elseif args.kind=='page' then
        s.mode,s.page,s.pages,s.rows=args.mode,args.page,args.pages,args.rows
        s.state='connected'
        if args.transaction then s.transaction=args.transaction; s.nextPoll=getTimestampMs()+2500 end
        if command=='MarketTune' then s.dialogue:enqueue('operator','UI_ApocWallet_MarketTuneRx') end
        if command=='MarketPage' and request.pageChatter then s.dialogue:enqueue('operator','UI_ApocWallet_MarketPageRxFmt',{args.page}) end
    elseif args.kind=='posted' then
        s.dialogue:enqueue('operator','UI_ApocWallet_MarketPostRxFmt',{args.code,args.count})
        s.needsRefresh=true
    elseif args.kind=='reserved' then
        s.transaction=args.transaction; s.nextPoll=getTimestampMs()+2500
        s.dialogue:enqueue('operator','UI_ApocWallet_MarketBuyWait')
    elseif args.kind=='bought' then
        s.transaction=nil; s.needsRefresh=true
        s.dialogue:enqueue('operator','UI_ApocWallet_MarketBuyRx')
        if s.refreshBalance then s.refreshBalance() end
    end
    changed(s)
end
function C.receive(args)
    if type(args)~='table' then return end
    for _,s in pairs(C.sessions) do
        if s.player:getOnlineID()==args.onlineId and s.pending and s.pending.token==args.token then
            if s.state=='tuning' and getTimestampMs()<s.readyAt then s.deferred=args
            else apply(s,args) end
            return
        end
    end
end
function C.update()
    local t=getTimestampMs()
    for _,s in pairs(C.sessions) do
        if s.win.closed or s.player:isDead() or not Device.canUse(s.player,s.radio) then
            if not s.win.closed and s.win.close then s.win:close() else C.close(s) end
        else
            s.dialogue:update()
            if s.deferred and t>=s.readyAt then local args=s.deferred; s.deferred=nil; apply(s,args) end
            if s.pending and t-s.pending.sent>=10000 then
                -- Retransmit the same token for posts and purchases; never invent
                -- a second transaction after a lost acknowledgment.
                s.pending.sent=t; sendClientCommand(s.player,'ApocWallet',s.pending.command,s.pending.args)
            elseif not s.pending and s.transaction and t>=s.nextPoll then
                s.nextPoll=t+2500; C.request(s,'MarketStatus',{transaction=s.transaction})
            elseif not s.pending and s.needsRefresh then
                s.needsRefresh=nil; C.request(s,'MarketPage',{mode=s.mode,page=s.page})
            end
        end
    end
end
function C.courierETA(args)
    for _,s in pairs(C.sessions) do
        if s.player:getOnlineID()==args.onlineId then
            s.etaSeen=s.etaSeen or {}
            if not s.etaSeen[args.id] then
                s.etaSeen[args.id]=true
                s.dialogue:enqueue('operator',args.kind=='pickup' and 'UI_ApocWallet_CourierPickupFmt' or 'UI_ApocWallet_CourierDeliveryFmt',{args.seconds})
            end
        end
    end
end
function C.close(s)
    if C.sessions[s.win.playerIndex]~=s then return end
    if s.state=='connected' and not s.player:isDead() then s.player:Say(getText('UI_ApocWallet_MarketHangupTx')) end
    s.dialogue:close(); s.dialogue:sound('Hangup')
    sendClientCommand(s.player,'ApocWallet','MarketHangup',{token=token(s.player)})
    C.sessions[s.win.playerIndex]=nil
end
Events.OnServerCommand.Add(function(module,command,args)
    if module=='ApocWallet' and command=='MarketState' then C.receive(args) end
end)
Events.OnTick.Add(C.update)
Events.OnDisconnect.Add(function()
    for _,s in pairs(C.sessions) do s.dialogue:close() end
    C.sessions={}
end)
return C

if isClient() then return end
local Courier=require 'ApocWallet/CourierService'
local Purchase=require 'ApocWallet/PurchaseService'
local P=require 'ApocWallet/MarketProtocol'
local Store=require 'ApocWallet/EntityStore'
if ApocWallet.MarketService then return ApocWallet.MarketService end
local M={sessions={},nextUpdate=0,lastRequest={},lastStatus={}}
ApocWallet.MarketService=M
local function data()
    local d=Courier.data()
    d.market=d.market or {seq=0,listings={},requests={},transactions={},credits={}}
    if not d.market.collecting then
        d.market.collecting={}; d.market.pendingTransactions={}; d.market.pendingCredits={}; d.market.openListings={}
        for id,l in pairs(d.market.listings) do
            if l.state=='collecting' then d.market.collecting[id]=true end
            if l.state=='open' then d.market.openListings[id]=true end
        end
        for id,tx in pairs(d.market.transactions) do if tx.state=='reserved' then d.market.pendingTransactions[id]=true end end
        for id,e in pairs(d.market.credits) do if e.state=='pending' then e.id=id; d.market.pendingCredits[id]=true end end
    end
    if not d.market.expiredListings then
        d.market.expiredListings={}
        for id,l in pairs(d.market.listings) do if l.state=='expired' then d.market.expiredListings[id]=true end end
    end
    d.market.actions=d.market.actions or {}
    if not d.market.pendingActions then
        d.market.pendingActions={}
        for id,a in pairs(d.market.actions) do if not a.done then d.market.pendingActions[id]=true end end
    end
    return d.market
end
M.data=data
local function identity(player)
    local c=ApocBRModEntities and ApocBRModEntities.character(player)
    if not c or c.status~='OK' or type(c.characterId)~='string'
        or not c.characterId:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')
        or type(c.steamId)~='string' or not c.steamId:match('^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$')
        or not P.integer(c.sourceServerId,1,9007199254740991) then return nil end
    return c
end
local function name(item) return (item:getName() or item:getFullType()):gsub('[%c]',''):sub(1,100) end
local function usable(player,item)
    if player:isEquipped(item) then return false end
    if instanceof(item,'InventoryContainer') and not item:getInventory():isEmpty() then return false end
    return true
end
local function carried(player,id) return player:getInventory():getItemById(id) end
local function radio(player,locator)
    local r
    if type(locator)~='table' then return nil end
    if P.integer(locator.itemId,0,2147483647) then r=carried(player,locator.itemId)
    elseif P.integer(locator.vehicleId,0,32767) and type(locator.partId)=='string' and #locator.partId<80 then
        local vehicle=getVehicleById(locator.vehicleId)
        if vehicle and vehicle==player:getVehicle() then r=vehicle:getPartById(locator.partId) end
    elseif P.integer(locator.x,0,1000000) and P.integer(locator.y,0,1000000) and P.integer(locator.z,-32,32) then
        local sq=getCell():getGridSquare(locator.x,locator.y,locator.z)
        local here=player:getCurrentSquare()
        if sq and here and math.abs(player:getX()-locator.x-0.5)<=1.6 and math.abs(player:getY()-locator.y-0.5)<=1.6
            and here:canReachTo(sq) then
            local objects=sq:getObjects()
            for i=0,objects:size()-1 do
                local o=objects:get(i)
                if instanceof(o,'IsoWaveSignal') and o:getObjectIndex()==locator.objectIndex then r=o; break end
            end
            if not r and locator.worldItemId then
                local objects=sq:getWorldObjects()
                for i=0,objects:size()-1 do
                    local item=objects:get(i):getItem()
                    if item and item:getID()==locator.worldItemId then r=item; break end
                end
            end
        end
    end
    if not r then return nil end
    local ok,valid=pcall(function()
        local dd=r:getDeviceData()
        return dd and dd:getIsTwoWay() and dd:getIsTurnedOn()
            and (not dd:getIsBatteryPowered() or dd:getHasBattery() and dd:getPower()>0)
    end)
    return ok and valid and r or nil
end
M.radio=radio
local function reply(player,token,fields)
    fields.token=token; fields.onlineId=player:getOnlineID()
    sendServerCommand(player,'ApocWallet','MarketState',fields)
end
local function available(listing)
    local count=0
    for _,unit in ipairs(listing.units or {}) do if unit.state=='available' then count=count+1 end end
    return count
end
-- Epoch milliseconds: expiry continues across shutdowns (LuaManager.getTimestampMs).
local function expire(listing,t)
    if listing.state~='open' then return end
    if not listing.expiresAt then
        listing.expiresAt=(listing.openedAt or listing.createdAt or t)+P.LISTING_LIFETIME
        Courier.persist('market.listings',listing.id)
    end
    if t>=listing.expiresAt then
        listing.state='expired'; data().openListings[listing.id]=nil; data().expiredListings[listing.id]=true; Courier.persist('market.listings',listing.id)
    end
end
local function recover(action)
    local d=data(); local listing=d.listings[action.listingId]
    local job,error=Courier.delivery(action.owner,action.id,action.destination,action.items)
    if not job then return nil,error=='COURIER_QUEUE_FULL' and 'WAIT' or 'UNAVAILABLE' end
    for _,i in ipairs(action.indices) do listing.units[i].state='returned' end
    d.expiredListings[listing.id]=nil
    action.jobId=job; action.done=true; d.pendingActions[action.id]=nil; Courier.persist('market.actions',action.id,'market.listings',listing.id)
    return action
end
local function manage(player,args,c,command)
    local d=data(); local key=c.characterId..':manage:'..args.token
    local action=d.actions[key]
    if action then
        if action.command~=command or action.listingId~=tostring(args.listingId) then return nil,'INVALID' end
        if action.done then return action end
        return recover(action)
    end
    local listing=d.listings[tostring(args.listingId)]
    if not listing or listing.seller.characterId~=c.characterId then return nil,'ITEM' end
    expire(listing,getTimestampMs())
    if listing.state~='expired' or available(listing)==0 then return nil,'ITEM' end
    -- An unresolved buyer owns its reserved units until settlement. Wait before
    -- letting the seller move any stock, so failed debits cannot strand cargo.
    for _,unit in ipairs(listing.units) do if unit.state=='reserved' then return nil,'WAIT' end end
    action={id=key,command=command,listingId=listing.id}
    if command=='MarketRepost' then
        local active=0
        for _ in pairs(d.openListings) do active=active+1 end
        for _ in pairs(d.collecting) do active=active+1 end
        if active>=2048 then return nil,'WAIT' end
        listing.state='open'; listing.openedAt=getTimestampMs(); listing.expiresAt=listing.openedAt+P.LISTING_LIFETIME
        d.openListings[listing.id]=true; d.expiredListings[listing.id]=nil; action.done=true; d.actions[key]=action; Courier.persist('market.actions',key,'market.listings',listing.id)
        return action
    end
    action.owner=player:getUsername(); action.destination=Courier.capture(player)
    if not action.destination then return nil,'ITEM' end
    action.items={}; action.indices={}
    for i,unit in ipairs(listing.units) do
        if unit.state=='available' then
            action.items[#action.items+1]={type=listing.type,count=1,blob=unit.blob}
            action.indices[#action.indices+1]=i; unit.state='returning'
        end
    end
    d.actions[key]=action; d.pendingActions[key]=true; Courier.persist('market.actions',key,'market.listings',listing.id)
    return recover(action)
end
local function inventory(player,session)
    local groups={}
    local function scan(container,depth)
        if depth>4 then return end
        local items=container:getItems()
        for i=0,items:size()-1 do
            local it=items:get(i)
            if it~=session.radio and usable(player,it) then
                local ft=it:getFullType()
                local g=groups[ft]
                if not g then g={type=ft,name=name(it),code=P.code(ft),ids={},count=0}; groups[ft]=g end
                if g.count<100 then g.count=g.count+1; g.ids[#g.ids+1]=it:getID() end
            end
            if instanceof(it,'InventoryContainer') then scan(it:getInventory(),depth+1) end
        end
    end
    scan(player:getInventory(),0)
    local rows={}
    for _,g in pairs(groups) do rows[#rows+1]=g end
    table.sort(rows,function(a,b) return a.type<b.type end)
    return rows
end
local function page(player,session,mode,n,query)
    query=query or ''
    local all={}
    if mode=='inventory' then all=inventory(player,session)
    else
        local d=data()
        for id in pairs(d.openListings) do expire(d.listings[id],getTimestampMs()) end
        for id in pairs(mode=='expired' and d.expiredListings or d.openListings) do
            local listing=d.listings[id]
            local count=available(listing)
            if count>0 and (mode=='market' and listing.state=='open' or mode=='expired' and listing.state=='expired' and listing.seller.characterId==session.characterId) then
                all[#all+1]={id=listing.id,type=listing.type,name=listing.name,code=P.code(listing.type),count=count,price=listing.price,expiresAt=listing.expiresAt}
            end
        end
        table.sort(all,function(a,b) return tonumber(a.id)<tonumber(b.id) end)
    end
    local filtered={}
    for _,row in ipairs(all) do
        if row.name:lower():find(query:lower(),1,true) then filtered[#filtered+1]=row end
    end
    all=filtered
    local pages=math.max(1,math.ceil(#all/P.PAGE_SIZE))
    n=math.max(1,math.min(pages,n or 1))
    local rows={}
    for i=(n-1)*P.PAGE_SIZE+1,math.min(#all,n*P.PAGE_SIZE) do rows[#rows+1]=all[i] end
    local transaction
    local d=data()
    for id in pairs(d.pendingTransactions) do
        if d.transactions[id].buyer.characterId==session.characterId then transaction=id; break end
    end
    return {ok=true,kind='page',mode=mode,query=query,page=n,pages=pages,rows=rows,transaction=transaction}
end
local function post(player,session,args,c)
    if type(args.itemIds)~='table' or #args.itemIds<1 or #args.itemIds>100 or not P.integer(args.price,1,10000000) then return nil,'INVALID' end
    local request=c.characterId..':'..args.token
    local d=data()
    local existing
    if d.requests[request] then
        existing=d.listings[d.requests[request]]
        if existing.price~=args.price or #existing.itemIds~=#args.itemIds then return nil,'INVALID' end
        for i,id in ipairs(args.itemIds) do if existing.itemIds[i]~=id then return nil,'INVALID' end end
        local escrow=Courier.data().escrow[existing.escrow]
        if escrow then
            if escrow.state=='removing' then Courier.reconcilePickup(player) end
            return existing
        end
        -- A saved intent is not proof that inventory removal happened. Resume
        -- the same intent after a save failure/lost acknowledgment, validating
        -- the original native objects again instead of declaring them missing.
        if existing.state~='collecting' and existing.state~='interrupted'
            and not (existing.state=='rejected' and existing.error==nil) then return nil,'ITEM' end
    end
    local active=0
    for _ in pairs(d.openListings) do active=active+1 end
    for _ in pairs(d.collecting) do active=active+1 end
    if not existing and active>=2048 then return nil,'WAIT' end
    local items,seen,ft={},{},nil
    for _,id in ipairs(args.itemIds) do
        if not P.integer(id,0,2147483647) or seen[id] then return nil,'ITEM' end
        seen[id]=true
        local it=carried(player,id)
        if not it or it==session.radio or not usable(player,it) or ft and ft~=it:getFullType() then return nil,'ITEM' end
        ft=it:getFullType(); items[#items+1]=it
    end
    local listing=existing
    if not listing then
        d.seq=d.seq+1
        listing={id=tostring(d.seq),type=ft,name=name(items[1]),price=args.price,seller={characterId=c.characterId,
            steamId=c.steamId,sourceServerId=c.sourceServerId},owner=player:getUsername(),
            escrow='pickup:'..c.characterId..':'..args.token,units={},itemIds={}}
        for i,id in ipairs(args.itemIds) do listing.itemIds[i]=id end
    end
    local id=listing.id
    listing.state='collecting'; listing.error=nil; listing.createdAt=getTimestampMs()
    d.listings[id]=listing; d.requests[request]=id; d.collecting[id]=true; Courier.persist('market.listings',id,'market.requests',request,'market.$','seq')
    local job,error=Courier.pickup(player,args.token,items)
    if not job then
        listing.state='rejected'; listing.error=error; d.collecting[id]=nil; Courier.persist('market.listings',id)
        print('[ApocWallet] pickup rejected: '..tostring(error))
        local errors={ITEM_UNAVAILABLE='ITEM',COURIER_QUEUE_FULL='WAIT',PERSISTENCE_API_UNAVAILABLE='STORAGE'}
        return nil,errors[error] or 'UNAVAILABLE'
    end
    listing.jobId=job
    return listing
end
local function reconcileListing(listing)
    local escrow=Courier.data().escrow[listing.escrow]
    if listing.state=='collecting' and escrow and escrow.state=='held' then
        for i,spec in ipairs(escrow.items) do listing.units[i]={blob=spec.blob,state='available'} end
        escrow.state='market'; listing.state='open'; listing.jobId=escrow.jobId
        listing.openedAt=getTimestampMs(); listing.expiresAt=listing.openedAt+P.LISTING_LIFETIME
        local d=data(); d.collecting[listing.id]=nil; d.openListings[listing.id]=true; Courier.persist('market.listings',listing.id,'escrow',listing.escrow)
    elseif listing.state=='collecting' and not escrow and getTimestampMs()-(listing.createdAt or 0)>10000 then
        listing.state='interrupted'; data().collecting[listing.id]=nil; Courier.persist('market.listings',listing.id)
    end
end
local function buy(player,session,args,c)
    local d=data(); local txid=c.characterId..':'..args.token
    if d.transactions[txid] then
        local existing=d.transactions[txid]
        if existing.listingId~=tostring(args.listingId) or #existing.indices~=args.count then return nil,'INVALID' end
        return existing
    end
    local listing=d.listings[tostring(args.listingId)]
    if listing then expire(listing,getTimestampMs()) end
    if not listing or listing.state~='open' or not P.integer(args.count,1,100) or available(listing)<args.count then return nil,'SOLD' end
    if listing.price*args.count>1000000000 then return nil,'INVALID' end
    local tx={id=txid,requestKey=args.token,listingId=listing.id,state='reserved',buyer={status='OK',characterId=c.characterId,
        steamId=c.steamId,sourceServerId=c.sourceServerId},owner=player:getUsername(),destination=Courier.capture(player),
        items={},indices={},amount=listing.price*args.count}
    for i,unit in ipairs(listing.units) do
        if unit.state=='available' and #tx.items<args.count then
            unit.state='reserved'; unit.transaction=txid
            tx.items[#tx.items+1]={type=listing.type,count=1,blob=unit.blob}; tx.indices[#tx.indices+1]=i
        end
    end
    d.transactions[txid]=tx; d.pendingTransactions[txid]=true; Courier.persist('market.transactions',txid,'market.listings',listing.id)
    return tx
end
function M.handle(player,command,args)
    if not player or player:isDead() or type(args)~='table' or not P.token(args.token) then return end
    if command=='MarketHangup' then M.sessions[player]=nil; return end
    local t=getTimestampMs()
    if t-(M.lastRequest[player] or -10000)<300 then reply(player,args.token,{ok=false,error='WAIT'}); return end
    M.lastRequest[player]=t
    local c=identity(player)
    if not c then reply(player,args.token,{ok=false,error='SIGNAL'}); return end
    local session=M.sessions[player]
    if command=='MarketTune' then
        if session and t-(session.lastTune or 0)<1500 then reply(player,args.token,{ok=false,error='WAIT'}); return end
        local r=radio(player,args.radio)
        if not r then reply(player,args.token,{ok=false,error='RADIO'}); return end
        session={locator=args.radio,radio=r,lastTune=t,last=0,characterId=c.characterId,expires=t+1800000}
        M.sessions[player]=session
        reply(player,args.token,page(player,session,'market',1)); return
    end
    if not session or session.characterId~=c.characterId or t>session.expires or not radio(player,session.locator) then
        M.sessions[player]=nil; reply(player,args.token,{ok=false,error='RADIO'}); return
    end
    if t-session.last<300 then reply(player,args.token,{ok=false,error='WAIT'}); return end
    session.last=t; session.expires=t+1800000
    if (command=='MarketPost' or command=='MarketBuy' or command=='MarketRecover' or command=='MarketRepost') and not Courier.persistenceReady() then
        reply(player,args.token,{ok=false,error='STORAGE'}); return
    end
    if command=='MarketPage' then
        if not P.integer(args.page,1,100000) or args.mode~='market' and args.mode~='inventory' and args.mode~='expired' then return end
        if args.query~=nil and (type(args.query)~='string' or #args.query>100 or args.query:find('[%c]')) then return end
        reply(player,args.token,page(player,session,args.mode,args.page,args.query))
    elseif command=='MarketRecover' or command=='MarketRepost' then
        local action,error=manage(player,args,c,command)
        if action then reply(player,args.token,{ok=true,kind=command=='MarketRepost' and 'reposted' or 'recovered',jobId=action.jobId})
        else reply(player,args.token,{ok=false,error=error}) end
    elseif command=='MarketPost' then
        local listing,error=post(player,session,args,c)
        if listing then
            reconcileListing(listing)
            if listing.state=='rejected' then reply(player,args.token,{ok=false,error='ITEM'}); return end
            if listing.state~='open' then reply(player,args.token,{ok=false,error='UNAVAILABLE'}); return end
            reply(player,args.token,{ok=true,kind='posted',code=P.code(listing.type),count=#listing.itemIds,jobId=listing.jobId})
        else reply(player,args.token,{ok=false,error=error}) end
    elseif command=='MarketBuy' then
        local tx,error=buy(player,session,args,c)
        if tx then reply(player,args.token,{ok=true,kind='reserved',transaction=tx.id})
        else reply(player,args.token,{ok=false,error=error}) end
    end
end
local function settlement(tx)
    local d=data(); local listing=d.listings[tx.listingId]
    local order=Courier.data().purchases[tx.id]
    if not order then
        local id,error=Purchase.enqueue(tx.buyer,tx.owner,tx.destination,tx.requestKey,
            {amount=tx.amount,reason='market.purchase',items=tx.items})
        if not id then tx.error=error end
        return
    end
    if order.state=='failed' then
        for _,i in ipairs(tx.indices) do
            local unit=listing.units[i]
            if unit.transaction==tx.id then unit.state='available'; unit.transaction=nil end
        end
        tx.state='failed'; tx.error=order.error; d.pendingTransactions[tx.id]=nil
        d.openListings[listing.id]=listing.state=='open' and true or nil
        Courier.persist('market.transactions',tx.id,'market.listings',listing.id)
        expire(listing,getTimestampMs())
    elseif order.state=='fulfilled' then
        for _,i in ipairs(tx.indices) do listing.units[i].state='sold' end
        tx.state='complete'; tx.jobId=order.jobId
        tx.fee=tx.fee or math.floor(tx.amount*P.SALE_TAX_PERCENT/100)
        tx.proceeds=tx.amount-tx.fee
        d.credits[tx.id]=d.credits[tx.id] or {id=tx.id,context=listing.seller,amount=tx.proceeds,state='pending',
            key=listing.seller.characterId..':sale:'..listing.id..':'..tx.requestKey,nextAttempt=0}
        d.pendingCredits[tx.id]=true; d.pendingTransactions[tx.id]=nil
        if available(listing)==0 then d.openListings[listing.id]=nil end
        Courier.persist('market.transactions',tx.id,'market.listings',listing.id,'market.credits',tx.id)
    end
end
local function credit(entry,t)
    if not ApocBrApiBridge or not ApocBrApiBridge.CHARACTER_CREDIT or not ApocBrApiBridge.isEnabled() then return end
    local c=entry.context
    local params=string.format('{"runtimeUuid":"%s","steamId":"%s","sourceServerId":%.0f,"amount":%.0f,"reason":"market.sale","idempotencyKey":"%s"}',
        c.characterId,c.steamId,c.sourceServerId,entry.amount,entry.key)
    -- The seller obligation already committed during settlement. Admission
    -- scheduling must not rewrite it.
    entry.nextAttempt=t+70000
    local requestId
    local ok,id=pcall(ApocBrApiBridge.request,ApocBrApiBridge.CHARACTER_CREDIT,params,function(r)
        Store.run('credit-result:'..tostring(requestId),function()
        entry=data().credits[entry.id]
        if not entry or not requestId or entry.requestId~=requestId or r.requestId~=requestId then return end
        entry.requestId=nil
        if r.ok and r.idempotencyKey==entry.key then
            entry.state='paid'; entry.transactionId=r.transactionId; data().pendingCredits[entry.id]=nil
        else entry.error=r.error; entry.nextAttempt=getTimestampMs()+60000 end
        Courier.persist('market.credits',entry.id)
        end)
    end)
    if ok and id then requestId=id; entry.requestId=id else entry.nextAttempt=t+5000 end
end
function M.update()
    local t=getTimestampMs()
    if t<M.nextUpdate then return end
    M.nextUpdate=t+500
    if not Courier.persistenceReady() then return end
    local d=data()
    for id in pairs(d.openListings) do expire(d.listings[id],t) end
    local recovered=0
    for id in pairs(d.pendingActions) do recover(d.actions[id]); recovered=recovered+1; if recovered>=4 then break end end
    local processed=0
    for id in pairs(d.collecting) do reconcileListing(d.listings[id]); processed=processed+1; if processed>=4 then break end end
    processed=0
    for id in pairs(d.pendingTransactions) do settlement(d.transactions[id]); processed=processed+1; if processed>=4 then break end end
    for id in pairs(d.pendingCredits) do
        local entry=d.credits[id]
        if t>=(entry.nextAttempt or 0) then credit(entry,t); break end
    end
    for player,s in pairs(M.sessions) do
        if t>s.expires or player:isDead() or getPlayerByOnlineID and getPlayerByOnlineID(player:getOnlineID())~=player then
            M.sessions[player]=nil; M.lastRequest[player]=nil; M.lastStatus[player]=nil
        end
    end
end
function M.status(player,token,txid)
    if not player or player:isDead() then return end
    local t=getTimestampMs()
    if t-(M.lastStatus[player] or -10000)<1000 then return end
    M.lastStatus[player]=t
    local tx=data().transactions[txid]
    local c=identity(player)
    if tx and c and tx.buyer.characterId==c.characterId then
        reply(player,token,{ok=tx.state~='failed',kind=tx.state=='complete' and 'bought' or 'pending',
            transaction=txid,error=tx.state=='failed' and 'FUNDS' or nil,jobId=tx.jobId})
    end
end
function M.run(player,command,args)
    if not player or type(args)~='table' or not P.token(args.token) then return end
    Store.run('market:'..player:getOnlineID()..':'..args.token,function()
        if command=='MarketStatus' then
            if type(args.transaction)=='string' and #args.transaction<160 then M.status(player,args.token,args.transaction) end
        else M.handle(player,command,args) end
    end,function(error)
        print('[ApocWallet] market command failed: '..tostring(error))
        reply(player,args.token,{ok=false,error='STORAGE'})
    end)
end
return M

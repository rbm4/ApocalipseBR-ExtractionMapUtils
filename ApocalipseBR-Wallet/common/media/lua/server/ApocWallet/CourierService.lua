-- Server-only durable jobs. Never retain an IsoPlayer as a delivery dependency.
if isClient() then return end
require "ApocWallet/Protocol"
if ApocWallet.CourierService then return ApocWallet.CourierService end
local Route=require "ApocWallet/CourierRoute"
local Service={ nextUpdate=0 }
ApocWallet.CourierService=Service
local TAG='ApocWallet.Couriers.v1'
local APPROACH,HOVER,DEPART=8000,2000,8000
local function now() return getTimestampMs() end
local function data()
    local d=ModData.getOrCreate(TAG)
    d.jobs=d.jobs or {}; d.receipts=d.receipts or {}; d.escrow=d.escrow or {}; d.purchases=d.purchases or {}; d.seq=d.seq or 0
    d.finished=d.finished or {}; d.pendingPurchases=d.pendingPurchases or {}
    return d
end
function Service.persistenceReady()
    return ApocBrApiBridge~=nil and ApocBrApiBridge.saveModData~=nil
        and now()>=(Service.persistenceRetryAt or 0)
end
local function persist()
    if not Service.persistenceReady() then error('PERSISTENCE_API_UNAVAILABLE') end
    local ok,saved=pcall(ApocBrApiBridge.saveModData)
    if not ok or saved~=true then
        Service.persistenceRetryAt=now()+5000
        error('PERSISTENCE_WRITE_FAILED')
    end
end
Service.data=data
Service.persist=persist
local function idOK(id) return type(id)=='string' and #id>0 and #id<=160 and id:match('^[%w_.:%-]+$') end
local function owner(player) return player and player:getUsername() end
local function coords(player)
    local sq=player and not player:isDead() and player:getCurrentSquare()
    if not sq then return nil end
    return {x=sq:getX(),y=sq:getY(),z=sq:getZ()}
end
Service.capture=coords
local function packet(job)
    return {id=job.id,kind=job.kind,x=job.x,y=job.y,z=job.z,due=job.due,
        path=job.path,vertical=job.vertical,serverNow=now(),approach=APPROACH,hover=HOVER,depart=DEPART}
end
function Service.broadcast(job)
    sendServerCommand('ApocWallet','CourierFlight',packet(job))
end
function Service.notify(user, job)
    local list=getOnlinePlayers()
    for i=0,list:size()-1 do
        local player=list:get(i)
        if player:getUsername()==user then
            sendServerCommand(player,'ApocWallet','CourierETA',{id=job.id,kind=job.kind,
                onlineId=player:getOnlineID(),
                seconds=math.max(0,math.ceil((job.due-now())/1000))})
        end
    end
end
local function validItems(items)
    if type(items)~='table' or #items<1 or #items>100 then return false end
    local count=0
    for _,sp in ipairs(items) do
        if type(sp)~='table' or type(sp.type)~='string' or not sp.type:match('^[%w_]+%.[%w_%-]+$')
            or type(sp.count)~='number' or sp.count%1~=0 or sp.count<1 or sp.count>100 then return false end
        if not ScriptManager.instance:getItem(sp.type) then return false end
        if sp.blob~=nil and (type(sp.blob)~='string' or #sp.blob>1398104 or sp.count~=1) then return false end
        count=count+sp.count
    end
    return count<=100
end
Service.validItems=validItems

-- Called only by trusted server fulfillment, after the debit has succeeded.
function Service.delivery(user, receipt, destination, items)
    if not Service.persistenceReady() then return nil,'PERSISTENCE_API_UNAVAILABLE' end
    if not idOK(receipt) or type(user)~='string' or not destination or not validItems(items) then return nil,'INVALID_DELIVERY' end
    for _,axis in ipairs({'x','y','z'}) do
        local v=destination[axis]
        if type(v)~='number' or v~=v or v%1~=0 or math.abs(v)>1000000 then return nil,'INVALID_DESTINATION' end
    end
    local d=data()
    if d.receipts[receipt] then return d.receipts[receipt] end
    local units=0
    for _,sp in ipairs(items) do units=units+sp.count end
    local pending=0
    for _,j in pairs(d.jobs) do
        if j.state~='complete' then pending=pending+1 end
        if j.kind=='delivery' and j.owner==user and j.state=='waiting' and now()<j.due-APPROACH
            and j.x==destination.x and j.y==destination.y and j.z==destination.z
            and (j.units or 100)+units<=100 then
            for _,sp in ipairs(items) do j.items[#j.items+1]={type=sp.type,count=sp.count,blob=sp.blob} end
            j.units=j.units+units
            d.receipts[receipt]=j.id; persist(); Service.notify(user,j)
            return j.id
        end
    end
    if pending>=256 then return nil,'COURIER_QUEUE_FULL' end
    d.seq=d.seq+1
    local job={id=tostring(d.seq),kind='delivery',owner=user,x=destination.x,y=destination.y,z=destination.z,
        due=now()+ZombRand(30000,90001),state='waiting',items={},units=units,placed=0}
    for i,sp in ipairs(items) do job.items[i]={type=sp.type,count=sp.count,blob=sp.blob} end
    d.jobs[job.id]=job; d.receipts[receipt]=job.id
    persist(); Service.notify(user,job)
    return job.id
end

local function pickupJob(player)
    local d=data(); local user=owner(player); local position=coords(player)
    if not user or not position then return nil end
    for _,j in pairs(d.jobs) do
        if j.kind=='pickup' and j.owner==user and j.state=='waiting'
            and now()<j.due-APPROACH then
            j.x,j.y,j.z=position.x,position.y,position.z
            return j
        end
    end
    d.seq=d.seq+1
    local job={id=tostring(d.seq),kind='pickup',owner=user,x=position.x,y=position.y,z=position.z,
        due=now()+ZombRand(30000,90001),state='waiting',items={},placed=0}
    d.jobs[job.id]=job
    return job
end

-- Exact item instances are serialized before removal, in server-owned custody.
-- A later market publisher can consume escrow; drone arrival never removes items.
function Service.pickup(player, requestId, items)
    if not Service.persistenceReady() then return nil,'PERSISTENCE_API_UNAVAILABLE' end
    if not idOK(requestId) or not coords(player) or type(items)~='table' or #items<1 or #items>100 then return nil,'INVALID_PICKUP' end
    if not ApocBrApiBridge or not ApocBrApiBridge.encodeItem then return nil,'ITEM_CODEC_UNAVAILABLE' end
    local context=ApocBRModEntities and ApocBRModEntities.character(player)
    if not context or context.status~='OK' or type(context.characterId)~='string' then return nil,'IDENTITY_UNAVAILABLE' end
    local d=data(); local receipt='pickup:'..context.characterId..':'..requestId
    if d.escrow[receipt] then return d.escrow[receipt].jobId end
    -- Finish any interrupted older removal before accepting another post of
    -- objects whose native IDs might still appear in this inventory.
    if Service.reconcilePickup then Service.reconcilePickup(player) end
    local pending=0
    for _,j in pairs(d.jobs) do if j.state~='complete' then pending=pending+1 end end
    if pending>=256 then return nil,'COURIER_QUEUE_FULL' end
    local seen,encoded,bytes={},{},0
    for i,item in ipairs(items) do
        local container=item and item:getContainer()
        if not container or container:getOutermostContainer()~=player:getInventory() or seen[item:getID()]
            or player:isEquipped(item) then return nil,'ITEM_UNAVAILABLE' end
        seen[item:getID()]=true
        local ok,blob=pcall(ApocBrApiBridge.encodeItem,item)
        if not ok or not blob then return nil,'ITEM_ENCODE_FAILED' end
        bytes=bytes+#blob
        if bytes>4194304 then return nil,'PICKUP_TOO_LARGE' end
        encoded[i]={blob=blob,itemId=item:getID(),type=item:getFullType(),removed=false}
    end
    local job=pickupJob(player)
    if not job then return nil,'INVALID_PICKUP' end
    d.escrow[receipt]={owner=owner(player),characterId=context.characterId,jobId=job.id,items=encoded,state='removing'}
    persist()
    for i,item in ipairs(items) do
        local container=item:getContainer()
        container:DoRemoveItem(item)
        sendRemoveItemFromContainer(container,item)
        encoded[i].removed=true
    end
    d.escrow[receipt].state='held'
    persist(); Service.notify(owner(player),job)
    return job.id
end

local function squareFor(job)
    local cell=getCell()
    local sq=cell and cell:getGridSquare(job.x,job.y,job.z)
    if not sq and ApocBRLobbyStreaming and ApocBRLobbyStreaming.keepCellLoaded then
        ApocBRLobbyStreaming.keepCellLoaded(job.x,job.y)
        sq=cell and cell:getGridSquare(job.x,job.y,job.z)
    end
    return sq
end
local function alreadyPlaced(square,job,index)
    local objects=square:getWorldObjects()
    for i=0,objects:size()-1 do
        local item=objects:get(i):getItem()
        local md=item and item:getModData()
        if md and md.ApocWalletCourier==job.id and md.ApocWalletCargo==index then return true end
    end
    return false
end
local function deliver(job,square)
    local index=0
    local original=job.placed
    local function finish(ok)
        if job.placed~=original then persist() end
        return ok
    end
    for _,spec in ipairs(job.items) do
        for _=1,spec.count do
            index=index+1
            if index>job.placed then
                if not alreadyPlaced(square,job,index) then
                    local item
                    if spec.blob then
                        item=ApocBrApiBridge and ApocBrApiBridge.decodeItem and ApocBrApiBridge.decodeItem(spec.blob)
                        if item and item:getFullType()~=spec.type then return finish(false) end
                    else item=instanceItem(spec.type) end
                    if not item then return finish(false) end
                    local md=item:getModData()
                    md.ApocWalletCourier=job.id; md.ApocWalletCargo=index
                    local ok,result=pcall(function() return square:AddWorldInventoryItem(item,0.5,0.5,0,true) end)
                    -- The native method can place before a transmission failure.
                    if not ok or not result then
                        if not item:getWorldItem() and not alreadyPlaced(square,job,index) then return finish(false) end
                    end
                end
                job.placed=index
            end
        end
    end
    return finish(true)
end
function Service.update()
    local t=now()
    if t<Service.nextUpdate then return end
    Service.nextUpdate=t+250
    if not Service.persistenceReady() then return end
    if not getCell() then return end
    local streamed,routes,handoffs=0,0,0
    for _,job in pairs(data().jobs) do
        if job.state~='complete' and t>=job.due-APPROACH then
            -- Bound simultaneous forced streaming to one destination per update.
            local square=getCell():getGridSquare(job.x,job.y,job.z)
            if not square and streamed<1 then square=squareFor(job); streamed=streamed+1 end
            if square then
                if not job.path and routes<2 then
                    routes=routes+1
                    job.path,job.vertical=Route.plan(getCell(),job.x,job.y,job.z)
                    Service.broadcast(job)
                end
                if t>=job.due and job.state=='waiting' and handoffs<2 then
                    handoffs=handoffs+1
                    if job.kind=='pickup' or deliver(job,square) then
                        job.state='departing'; persist(); Service.broadcast(job)
                    end
                end
                if job.state=='departing' and t>=job.due+HOVER+DEPART then
                    local d=data()
                    d.finished[job.id]={kind=job.kind,x=job.x,y=job.y,z=job.z,completedAt=t}
                    d.jobs[job.id]=nil; persist()
                end
            end
        end
    end
end
function Service.sync(player)
    for _,job in pairs(data().jobs) do
        if job.state~='complete' and job.path then sendServerCommand(player,'ApocWallet','CourierFlight',packet(job)) end
        if job.state~='complete' and job.owner==owner(player) then Service.notify(owner(player),job) end
    end
end
-- Recover the write-ahead custody record if the JVM stopped during removal.
-- Never expose 'removing' escrow to a market publisher as a completed post.
function Service.reconcilePickup(player)
    if not Service.persistenceReady() then return end
    local context=ApocBRModEntities and ApocBRModEntities.character(player)
    if not context or context.status~='OK' then return end
    for _,entry in pairs(data().escrow) do
        if entry.state=='removing' and entry.characterId==context.characterId then
            for _,spec in ipairs(entry.items) do
                local item=player:getInventory():getItemById(spec.itemId)
                if item then
                    local container=item:getContainer()
                    container:DoRemoveItem(item); sendRemoveItemFromContainer(container,item)
                end
                spec.removed=true
            end
            entry.state='held'; persist()
        end
    end
end
return Service

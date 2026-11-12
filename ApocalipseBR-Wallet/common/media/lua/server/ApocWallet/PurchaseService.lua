if isClient() then return end
local Courier=require 'ApocWallet/CourierService'
local Store=require 'ApocWallet/EntityStore'
if ApocWallet.PurchaseService then return ApocWallet.PurchaseService end
local Service={callbacks={},nextUpdate=0}
ApocWallet.PurchaseService=Service
local function keyOK(key) return type(key)=='string' and #key>0 and #key<=80 and key:match('^[%w_.:%-]+$') end
local function notify(order)
    local callback=Service.callbacks[order.id]
    if callback and (order.state=='fulfilled' or order.state=='failed') then
        Service.callbacks[order.id]=nil
        local ok,err=pcall(callback,{ok=order.state=='fulfilled',orderId=order.id,jobId=order.jobId,error=order.error})
        if not ok then print('[ApocWallet] purchase callback failed: '..tostring(err)) end
    end
end
-- Trusted server API: quote must come from the server catalog, never client prices/items.
-- Snapshot coordinates and fulfillment BEFORE calling the asynchronous debit API.
function Service.enqueue(context, user, destination, requestKey, quote, callback)
    if not Courier.persistenceReady() then return nil,'PERSISTENCE_API_UNAVAILABLE' end
    if not destination or not keyOK(requestKey) or type(quote)~='table'
        or not Courier.validItems(quote.items) or type(quote.amount)~='number'
        or quote.amount%1~=0 or quote.amount<1 or quote.amount>1000000000
        or type(quote.reason)~='string' or #quote.reason<1 or #quote.reason>128
        or not quote.reason:match('^[%w _.:%-]+$') then return nil,'INVALID_PURCHASE' end
    if not context or context.status~='OK' or type(context.characterId)~='string'
        or not context.characterId:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')
        or type(context.steamId)~='string' or not context.steamId:match('^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$')
        or type(context.sourceServerId)~='number' or context.sourceServerId%1~=0 or context.sourceServerId<1
        or context.sourceServerId>9007199254740991 then return nil,'IDENTITY_UNAVAILABLE' end
    local d=Courier.data()
    local id=context.characterId..':'..requestKey
    local old=d.purchases[id]
    if old then
        if old.amount~=quote.amount or old.reason~=quote.reason then return nil,'IDEMPOTENCY_CONFLICT' end
        if #old.items~=#quote.items then return nil,'IDEMPOTENCY_CONFLICT' end
        for i,sp in ipairs(quote.items) do
            if old.items[i].type~=sp.type or old.items[i].count~=sp.count or old.items[i].blob~=sp.blob then return nil,'IDEMPOTENCY_CONFLICT' end
        end
        if callback then Service.callbacks[id]=callback; notify(old) end
        return id
    end
    local total=0
    for _ in pairs(d.pendingPurchases) do total=total+1 end
    if total>=256 then return nil,'PURCHASE_QUEUE_FULL' end
    local order={id=id,owner=user,destination={x=destination.x,y=destination.y,z=destination.z},items={},amount=quote.amount,reason=quote.reason,
        characterId=context.characterId,steamId=context.steamId,sourceServerId=context.sourceServerId,
        state='pending',nextAttempt=0,attempts=0}
    for i,sp in ipairs(quote.items) do order.items[i]={type=sp.type,count=sp.count,blob=sp.blob} end
    d.purchases[id]=order; d.pendingPurchases[id]=true; Service.callbacks[id]=callback
    Courier.persist('purchases',id)
    Service.update()
    return id
end
function Service.buy(player, requestKey, quote, callback)
    if not ApocBRModEntities or not ApocBRModEntities.character then return nil,'IDENTITY_API_UNAVAILABLE' end
    return Service.enqueue(ApocBRModEntities.character(player),player:getUsername(),Courier.capture(player),requestKey,quote,callback)
end
local function submit(order,t)
    if not ApocBrApiBridge or not ApocBrApiBridge.CHARACTER_DEBIT or not ApocBrApiBridge.isEnabled() then
        order.error='DEBIT_API_UNAVAILABLE'; order.nextAttempt=t+10000; return
    end
    local parameters=string.format('{"runtimeUuid":"%s","steamId":"%s","sourceServerId":%.0f,"amount":%.0f,"reason":"%s","idempotencyKey":"%s"}',
        order.characterId,order.steamId,order.sourceServerId,order.amount,order.reason,order.id)
    order.attempts=(order.attempts or 0)+1
    -- The business intent was committed by enqueue. Admission timers and HTTP
    -- handles stay in memory; retries replay the same durable idempotency key.
    order.nextAttempt=t+70000
    local requestId
    local ok,id=pcall(ApocBrApiBridge.request,ApocBrApiBridge.CHARACTER_DEBIT,parameters,function(response)
        Store.run('debit-result:'..tostring(requestId),function()
        order=Courier.data().purchases[order.id]
        if not order or not requestId or order.requestId~=requestId or type(response)~='table' or response.requestId~=requestId then return end
        order.requestId=nil
        if response.ok==true and response.idempotencyKey==order.id and type(response.transactionId)=='string'
            and #response.transactionId>0 then
            order.state='paid'; order.transactionId=response.transactionId; order.error=nil
        elseif response.status==400 or response.status==401 or response.status==403 or response.status==404
            or response.status==402 or response.status==409 or response.status==422 then
            order.state='failed'; order.error=response.error or 'DEBIT_REJECTED'
            Courier.data().pendingPurchases[order.id]=nil
        else
            -- Ambiguous response: reconcile by replaying the SAME idempotency key.
            order.error=response.error or 'INVALID_DEBIT_RESPONSE'
            order.nextAttempt=getTimestampMs()+math.min(60000,1500*2^math.min(order.attempts,5))
        end
        Courier.persist('purchases',order.id); notify(order)
        end)
    end)
    if ok and id then requestId=id; order.requestId=id
    else order.error='DEBIT_ADMISSION_WAIT'; order.nextAttempt=t+3000 end
end
function Service.update()
    local t=getTimestampMs()
    if t<Service.nextUpdate then return end
    Service.nextUpdate=t+500
    if not Courier.persistenceReady() then return end
    local d=Courier.data()
    for id in pairs(d.pendingPurchases) do
        local order=d.purchases[id]
        if order.state=='paid' then
            local job,error=Courier.delivery(order.owner,order.id,order.destination,order.items)
            if job then order.jobId=job; order.state='fulfilled'; order.error=nil; d.pendingPurchases[id]=nil; Courier.persist('purchases',order.id); notify(order)
            else order.error=error end
        elseif order.state=='pending' and t>=(order.nextAttempt or 0) then submit(order,t); break end
    end
end
return Service

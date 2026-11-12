local root='ApocalipseBR-Wallet/common/media/lua/'
package.path=root..'shared/?.lua;'..root..'server/?.lua;C:/Users/ricar/Zomboid/Workshop/apocbr/Contents/mods/ApocalisebrPack/42.14/media/lua/server/?.lua;'..package.path
local checks,time,sequence=0,100000,0
local function check(v,m) checks=checks+1; assert(v,m) end
function isServer() return true end
function getTimestampMs() return time end
local callbacks={}
Events={OnTickEvenPaused={Add=function(fn) callbacks[#callbacks+1]=fn end},OnServerStarted={Add=function() end}}
local function tick() for _,fn in ipairs(callbacks) do fn() end end
local function copy(v) if type(v)~='table' then return v end; local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local snapshots={}
local function canonical(v)
    if type(v)~='table' then return type(v)..':'..tostring(v) end
    local keys={};for k in pairs(v)do keys[#keys+1]=k end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={};for _,k in ipairs(keys)do out[#out+1]=canonical(k)..'='..canonical(v[k])end
    return '{'..table.concat(out,';')..'}'
end
local requests,responses,defined={},{},nil
local database,revision,busy=nil,0,false
local lastMutation,lastBody,encodedValues=nil,nil,0
ApocBRModEntities={
    define=function(_,definition) defined=definition; return true end,
    serverScope=function()return {server_id=42,world='engine-world'}end,
    encode=function(v)encodedValues=encodedValues+1;local key=canonical(v);snapshots[key]=copy(v);return key end,
    newMessageId=function()return string.format("00000000-0000-0000-0000-%012d",sequence+1)end,
    documentLoad=function(name)
        sequence=sequence+1;requests[#requests+1]={id=tostring(sequence),action="load",name=name};return {accepted=true,id=tostring(sequence)}
    end,
    documentMutate=function(name,rev,token,ops)
        if busy then return {accepted=false,status="BUSY"} end
        sequence=sequence+1;requests[#requests+1]={id=tostring(sequence),action="mutate",name=name,revision=rev,token=token,operations=copy(ops)}
        return {accepted=true,id=tostring(sequence)}
    end,
    decode=function(key)return copy(assert(snapshots[key]))end,
    submit=function(name,action,keys,values,rev)
        if busy and action=='save' then return {accepted=false,status='BUSY'} end
        sequence=sequence+1;requests[#requests+1]={id=tostring(sequence),action=action,keys=copy(keys),values=copy(values),revision=rev}
        return {accepted=true,id=tostring(sequence)}
    end,
    poll=function()local r=responses;responses={};return r end,
}
local legacyReads=0
ModData={get=function()legacyReads=legacyReads+1;return {legacy='imported'}end}
local function ack(status,commitUnknown)
    local request=table.remove(requests,1);assert(request,'expected asynchronous entity request')
    if request.action=='load' then
        local rows={}
        for _,row in pairs(database or {}) do rows[#rows+1]=copy(row) end
        responses[#responses+1]=database and {id=request.id,status='OK',records=rows,revision=tostring(revision)} or {id=request.id,status='NOT_FOUND'}
    else
        local actual=status or 'OK'
        if status=='OK' or status==nil or commitUnknown then
            local body=canonical(request.operations)
            if tostring(revision)==request.revision then
                database=database or {}
                for _,op in ipairs(request.operations) do
                    local key=op.collection..':'..op.key
                    database[key]=not op.deleted and copy(op) or nil
                end
                revision=revision+1;lastMutation=request.token;lastBody=body
            elseif not (revision==tonumber(request.revision)+1 and request.token==lastMutation and body==lastBody) then actual='CONFLICT' end
        end
        responses[#responses+1]={id=request.id,status=actual,revision=tostring(revision)}
    end
end
local S=require 'ApocWallet/EntityStore'
local startupError
check(not S.run('early-command',function()error('must not run')end,function(reason)startupError=reason end)
    and startupError=='PERSISTENCE_NOT_READY','startup commands get an explicit retryable recording response')
local effects,done=0,0
S.run('post',function()
    S.data().marker='intent';S.persist('$','marker')
    effects=effects+1
    S.data().marker='done';S.persist('$','marker')
    done=done+1
end)
tick();check(not S.ready() and effects==0,'no effect while entity bootstrap is loading')
ack();tick()
check(not S.ready() and effects==0,'legacy import itself waits for the database commit')
ack('OK');tick()
check(S.ready() and S.data().legacy=='imported' and legacyReads==1,'one-time legacy import only on missing SQL row')
check(requests[1].name=='ApocWallet.Couriers.v2','pack contract owns mutation document mapping')
check(effects==0 and #requests==1 and requests[1].revision=='1' and #requests[1].operations==1,'effect waits for SQL acknowledgment with engine-owned scope')
check(not S.run('post',function()error('duplicate')end),'same token cannot create a parallel transaction')
ack('OK');tick()
check(effects==1 and done==0,'native handoff occurs after write-ahead commit, completion still waits')
ack('OK');tick()
check(done==1 and not S.active and tostring(revision)==S.revision,'completion after committed entity checkpoint')
busy=true
S.run('busy',function()S.data().marker='busy';S.persist('$','marker');effects=effects+1 end)
tick();check(effects==1 and #requests==0,'admission rejection cannot authorize effects')
time=time+5001;busy=false;tick();check(#requests==1,'busy persistence retries with same entity')
ack('OUTCOME_UNKNOWN',true);tick()
check(effects==1 and #requests==0,'unknown commit outcome waits before replay')
time=time+5001;tick();check(#requests==1 and requests[1].action=='mutate','unknown commit replays bounded mutation instead of reading wallet')
ack();tick();check(effects==2 and tostring(revision)==S.revision,'identical committed snapshot resumes exactly once')
S.run('metadata',function()S.modData('inventory','17').ApocWalletCourier='courier-1';S.persist()end)
tick();ack('OK');tick()
check(S.data().itemData['inventory:17'].values.ApocWalletCourier=='courier-1','object ModData shares entity checkpoint')
-- Reinitializing the store reads SQL and ignores stale native GlobalModData.
ApocWallet.EntityStore=nil;package.loaded['ApocWallet/EntityStore']=nil
S=require 'ApocWallet/EntityStore';S.update();ack();tick()
check(S.ready() and legacyReads==1 and S.data().marker=='busy','SQL remains authoritative on restart')
-- Run the real pickup service through delayed entity acknowledgments, including
-- a player moving the item while SQL is in flight.
function isClient() return false end
function ZombRand(lo) return lo+1000 end
local removed=0
local inventory={}
function inventory:getOutermostContainer() return self end
function inventory:DoRemoveItem(item) removed=removed+1;item.container=nil end
local square={getX=function()return 1 end,getY=function()return 2 end,getZ=function()return 0 end}
local player={getInventory=function()return inventory end,getCurrentSquare=function()return square end,
    getUsername=function()return 'owner' end,isDead=function()return false end,isEquipped=function()return false end}
local item={container=inventory,getID=function()return 17 end,getFullType=function()return 'Base.Axe' end}
function item:getContainer()return self.container end
ApocBRModEntities.character=function()return {status='OK',characterId='character-a'}end
ApocBrApiBridge={encodeItem=function()return 'native-item-blob' end}
function getOnlinePlayers()return {size=function()return 0 end}end
function sendRemoveItemFromContainer()end
local Courier=require 'ApocWallet/CourierService'
local result,reason
S.run('race-pickup',function()result,reason=Courier.pickup(player,'race',{item})end)
tick();check(removed==0,'pickup does not remove before SQL write-ahead acknowledgment')
item.container=nil;ack('OK');tick()
check(removed==0,'item moved during asynchronous save is never removed from its new owner')
ack('OK');tick()
check(not result and reason=='ITEM_UNAVAILABLE' and S.data().escrow['pickup:character-a:race'].state=='cancelled','raced pickup cancels custody instead of publishing a duplicate')
item.container=inventory
S.run('valid-pickup',function()result,reason=Courier.pickup(player,'valid',{item})end)
tick();check(removed==0,'second pickup also waits for SQL')
ack('OK');tick();check(removed==1 and not result,'removal after intent commit waits for custody confirmation before success')
ack('OK');tick()
check(result and removed==1 and S.data().escrow['pickup:character-a:valid'].state=='held','exactly one removal and a committed held record')
print('Passed '..checks..' asynchronous pack entity-store import, commit barrier, retry, recovery and metadata checks.')

-- A single changed record does not serialize retained history.
S.run('large-history',function()
    for i=1,3000 do S.data().finished[tostring(i)]={blob=string.rep('x',50)} end
    local before=encodedValues
    S.data().purchases.small={id='small',state='pending',amount=1}
    S.persist('purchases','small')
    check(encodedValues-before==1,'one mutation encodes only one record regardless of history')
end)
tick();check(#requests==1 and #requests[1].operations==1 and requests[1].operations[1].collection=='purchases','one changed record yields one mutation')
ack('OK');tick()
local before=sequence
S.run('unchanged',function()S.persist('purchases','small')end);tick()
check(sequence==before,'unchanged touched record causes zero database calls')
S.run('runtime-only',function()
    local order=S.data().purchases.small
    order.nextAttempt=time+5000;order.requestId='runtime';order.attempts=10
    S.persist('purchases','small')
end);tick()
check(sequence==before,'runtime retry bookkeeping causes zero database calls')
S.run('delete',function()S.data().purchases.small=nil;S.persist('purchases','small')end)
tick();check(requests[1].operations[1].deleted==true,'explicit deletion is a targeted mutation')
ack('OK');tick();check(database['purchases:small']==nil,'deletion removes only the target record')
-- Restore canonical fixture after injecting uncommitted history for the cost check.
S.data().finished={}
local beforeIdle=sequence
for i=1,1000 do time=time+250;S.update() end
check(sequence==beforeIdle,'ready idle store never polls SQL')
-- Exercise the actual periodic workers through the real mutation store/facade.
local Market=require 'ApocWallet/MarketService'
local Purchase=require 'ApocWallet/PurchaseService'
local m=Market.data()
local apiAttempts=0
ApocBrApiBridge.CHARACTER_CREDIT='credit';ApocBrApiBridge.CHARACTER_DEBIT='debit'
ApocBrApiBridge.isEnabled=function()return true end
ApocBrApiBridge.request=function()apiAttempts=apiAttempts+1;return nil end
S.run('retry-seed',function()
    m.credits.test={id='test',context={characterId='a',steamId='b',sourceServerId=1},amount=1,key='test',state='pending'}
    m.pendingCredits.test=true
    S.data().purchases.test={id='test',characterId='a',steamId='b',sourceServerId=1,amount=1,reason='test',state='pending'}
    S.data().pendingPurchases.test=true
    S.persist('market.credits','test','purchases','test')
end)
tick();ack('OK');tick()
local retryBaseline=sequence
for i=1,240 do
    time=time+250
    S.run('market-update',Market.update);S.run('purchase-update',Purchase.update);tick()
end
check(apiAttempts>=20 and sequence==retryBaseline,'debit and credit admission retries produce zero SQL mutations for one simulated minute')
-- Cold load must rebuild derived queues from business records.
S.data().pendingPurchases=nil;m.collecting=nil;m.pendingActions=nil
Courier.data();Market.data()
check(S.data().pendingPurchases.test and m.pendingCredits.test,'pending payments are reconstructed without persisted queue snapshots')
S.run('conflict',function()S.data().marker='conflict';S.persist('$','marker')end)
tick();ack('CONFLICT');tick()
check(not S.ready() and S.status=='blocked' and S.data().marker=='busy','conflict restores touched committed record and blocks writes')
before=sequence;time=time+60000;S.update()
check(sequence==before,'conflict does not bootstrap and resume stale queued closures')
-- A fresh scope with no native legacy state still requires an initial commit.
database=nil;revision=0;ModData.get=function()return nil end
ApocWallet.EntityStore=nil;package.loaded['ApocWallet/EntityStore']=nil
S=require 'ApocWallet/EntityStore';S.update();ack();tick()
check(not S.ready() and #requests==1 and #requests[1].operations==0,'empty scope does not activate before its initial head commits')
ack('OK');tick();check(S.ready() and S.revision=='1','empty scope initializes atomically')
print('Passed '..checks..' mutation store, bounded-write and recovery checks.')

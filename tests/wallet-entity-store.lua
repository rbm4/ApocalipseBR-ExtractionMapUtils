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
ApocBRModEntities={
    define=function(_,definition) defined=definition; return true end,
    serverScope=function()return {server_id=42,world='engine-world'}end,
    encode=function(v)local key=canonical(v);snapshots[key]=copy(v);return key end,
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
    if request.action=='find' then
        responses[#responses+1]=database and {id=request.id,status='OK',values=copy(database),revision=tostring(revision)} or {id=request.id,status='NOT_FOUND'}
    else
        if status=='OK' or commitUnknown then database=copy(request.values);revision=revision+1 end
        responses[#responses+1]={id=request.id,status=status or 'OK',revision=tostring(revision)}
    end
end
local S=require 'ApocWallet/EntityStore'
local startupError
check(not S.run('early-command',function()error('must not run')end,function(reason)startupError=reason end)
    and startupError=='PERSISTENCE_NOT_READY','startup commands get an explicit retryable recording response')
local effects,done=0,0
S.run('post',function()
    S.data().marker='intent';S.persist()
    effects=effects+1
    S.data().marker='done';S.persist()
    done=done+1
end)
tick();check(not S.ready() and effects==0,'no effect while entity bootstrap is loading')
ack();tick()
check(not S.ready() and effects==0,'legacy import itself waits for the database commit')
ack('OK');tick()
check(S.ready() and S.data().legacy=='imported' and legacyReads==1,'one-time legacy import only on missing SQL row')
check(defined.table=='wallet_mod_data' and defined.fields.payload.type=='text','pack contract owns scoped entity mapping')
check(effects==0 and #requests==1 and requests[1].keys.server_id==42 and requests[1].keys.world=='engine-world','effect waits for SQL acknowledgment with engine-owned scope')
check(not S.run('post',function()error('duplicate')end),'same token cannot create a parallel transaction')
ack('OK');tick()
check(effects==1 and done==0,'native handoff occurs after write-ahead commit, completion still waits')
ack('OK');tick()
check(done==1 and not S.active and database.payload==S.committed,'completion after committed entity checkpoint')
busy=true
S.run('busy',function()S.data().marker='busy';S.persist();effects=effects+1 end)
tick();check(effects==1 and #requests==0,'admission rejection cannot authorize effects')
time=time+5001;busy=false;tick();check(#requests==1,'busy persistence retries with same entity')
ack('OUTCOME_UNKNOWN',true);tick()
check(effects==1 and #requests==1 and requests[1].action=='find','unknown commit outcome reconciles by reading SQL')
ack();tick();check(effects==2 and database.payload==S.committed,'identical committed snapshot resumes exactly once')
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

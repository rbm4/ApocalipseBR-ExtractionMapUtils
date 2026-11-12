local root='ApocalipseBR-Wallet/common/media/lua/'
package.path=root..'shared/?.lua;'..root..'server/?.lua;'..package.path
local checks,time,saves,packets,world=0,100000,0,{},{}
local function check(v,m) checks=checks+1; assert(v,m) end
function isClient() return false end
function getTimestampMs() return time end
function ZombRand(a,b) return a+1000 end
function instanceof(o,k) return o and o.kind==k end
local function list(t) return {size=function() return #t end,get=function(_,i) return t[i+1] end} end
local persistent={}
ModData={getOrCreate=function() return persistent end}
ScriptManager={instance={getItem=function() return true end}}
local sq={getX=function() return 10 end,getY=function() return 20 end,getZ=function() return 0 end,
    canReachTo=function() return true end,isSolid=function() return false end,isBlockedTo=function() return false end,
    isDoorBlockedTo=function() return false end,isWindowTo=function() return false end}
function sq:getWorldObjects() return list(world) end
function sq:AddWorldInventoryItem(item) local o={getItem=function() return item end}; item.world=o; world[#world+1]=o; return item end
function getCell() return {getGridSquare=function() return sq end} end
function sendServerCommand(...) packets[#packets+1]={...} end
function sendRemoveItemFromContainer() end
local players={}
function getOnlinePlayers() return list(players) end
local function item(id,ft,condition)
    local it={id=id,ft=ft or 'Base.Axe',condition=condition or 42,md={}}
    function it:getID() return self.id end
    function it:getFullType() return self.ft end
    function it:getName() return self.ft end
    function it:getContainer() return self.container end
    function it:getModData() return self.md end
    function it:getWorldItem() return self.world end
    return it
end
local function player(index)
    local p={index=index}
    local inv={items={}}
    function inv:getItems() return list(self.items) end
    function inv:getOutermostContainer() return self end
    function inv:getItemById(id) for _,it in ipairs(self.items) do if it.id==id then return it end end end
    function inv:DoRemoveItem(it)
        for i,v in ipairs(self.items) do if it==v then table.remove(self.items,i); it.container=nil; return end end
    end
    function inv:add(it) self.items[#self.items+1]=it; it.container=self end
    function p:getInventory() return inv end
    function p:getCurrentSquare() return sq end
    function p:getX() return 10.5 end
    function p:getY() return 20.5 end
    function p:isDead() return false end
    function p:isEquipped(it) return it.equipped==true end
    function p:getUsername() return 'player'..index end
    function p:getOnlineID() return index end
    local r=item(100+index,'Base.WalkieTalkie1')
    r.on=true
    function r:getDeviceData() return {getIsTwoWay=function() return true end,getIsTurnedOn=function() return r.on end,
        getIsBatteryPowered=function() return false end} end
    inv:add(r); p.radio=r
    players[#players+1]=p
    return p
end
local seller,buyer,other=player(1),player(2),player(3)
ApocBRModEntities={character=function(p) return {status='OK',characterId=string.format('12345678-1234-4234-8234-%012d',p.index),
    steamId='76561198000000001',sourceServerId=2} end}
local requests,callbacks={},{}
local failSave=false
ApocBrApiBridge={saveModData=function() saves=saves+1; return not failSave end,CHARACTER_DEBIT='DEBIT',CHARACTER_CREDIT='CREDIT',isEnabled=function() return true end,
    encodeItem=function(it) return tostring(it.id)..':'..it.condition end,
    decodeItem=function(blob) local id,c=blob:match('(%d+):(%d+)'); return item(tonumber(id),'Base.Axe',tonumber(c)) end,
    request=function(endpoint,body,callback)
        local id='request'..(#requests+1); requests[#requests+1]={endpoint=endpoint,body=body,id=id}; callbacks[id]=callback; return id
    end}
function instanceItem(ft) return item(999,ft,100) end
local Courier=require 'ApocWallet/CourierService'
local Purchase=require 'ApocWallet/PurchaseService'
local M=require 'ApocWallet/MarketService'
local P=require 'ApocWallet/MarketProtocol'
local function command(p,cmd,args)
    time=time+500
    M.run(p,cmd,args)
    local last=packets[#packets]
    return last and last[3]=='MarketState' and last[4] or nil
end
for _,p in ipairs(players) do
    local result=command(p,'MarketTune',{token='tune'..p.index,radio={itemId=p.radio.id}})
    check(result and result.ok and result.rows and #result.rows==0,'tune authenticates radio and returns player-only empty market')
end
local axe1,axe2=item(1,nil,37),item(2,nil,83)
seller:getInventory():add(axe1); seller:getInventory():add(axe2)
local nativeSave=ApocBrApiBridge.saveModData
ApocBrApiBridge.saveModData=nil
local unavailable=command(seller,'MarketPost',{token='missing-save',itemIds={1,2},price=15})
check(unavailable and unavailable.error=='STORAGE' and M.data().seq==0,'missing save facade fails before creating an intent')
check(axe1.container and axe2.container,'missing save API never removes cargo')
ApocBrApiBridge.saveModData=nativeSave
failSave=true
local interrupted=command(seller,'MarketPost',{token='post1',itemIds={1,2},price=15})
check(interrupted and interrupted.error=='STORAGE','disk save failure gets a recording-error response')
check(axe1.container and axe2.container and not persistent.escrow['pickup:12345678-1234-4234-8234-000000000001:post1'],'failed intent flush never takes inventory')
failSave=false; time=time+10001; M.update()
check(M.data().listings['1'].state=='interrupted','an interrupted intent is not classified as missing cargo')
-- Recover a record already classified as rejected by the previously shipped code.
M.data().listings['1'].state='rejected'; M.data().listings['1'].error=nil
local posted=command(seller,'MarketPost',{token='post1',itemIds={1,2},price=15})
check(M.data().seq==1,'same-token recovery reuses the original listing')
check(posted and posted.kind=='posted','posting response')
check(not axe1.container and not axe2.container,'both exact items removed immediately')
local listing=M.data().listings['1']
check(listing.state=='open' and #listing.units==2,'custody published as listing')
check(listing.units[1].blob=='1:37' and listing.units[2].blob=='2:83','native item condition preserved in custody')
local id=listing.jobId
command(seller,'MarketPost',{token='post1',itemIds={1,2},price=15})
check(M.data().seq==1 and listing.jobId==id,'repeated post token cannot create second listing or pickup')
local page=command(buyer,'MarketPage',{token='page1',mode='market',page=1})
check(#page.rows==1 and page.rows[1].price==15 and page.rows[1].count==2,'public bulletin exposes price and available stock')
check(not page.rows[1].blob and not page.rows[1].seller,'bulletin never exposes custody or identity')
local inv=command(seller,'MarketPage',{token='inventory1',mode='inventory',page=1})
check(#inv.rows==0,'tuned radio excluded from posting inventory')
local bought=command(buyer,'MarketBuy',{token='buy1',listingId='1',count=2,amount=0,items={{type='Base.Gold'}}})
check(bought and bought.kind=='reserved','purchase reserves selected cargo')
local contested=command(other,'MarketBuy',{token='buy2',listingId='1',count=1})
check(contested and not contested.ok and contested.error=='SOLD','second buyer cannot reserve held cargo')
M.update()
check(#requests==1 and requests[1].endpoint=='DEBIT','buy calls real debit boundary once')
check(requests[1].body:find('"amount":30',1,true),'debit uses server listing price, ignores client price')
check(#world==0,'no cargo created before debit confirmation')
local tx=M.data().transactions[bought.transaction]
callbacks.request1({requestId='request1',ok=true,idempotencyKey=tx.id,transactionId='debit1'})
time=time+1000; Purchase.update(); M.update()
check(tx.state=='complete' and tx.jobId,'confirmed debit schedules courier and completes market transfer')
check(listing.units[1].state=='sold','reserved stock consumed only after confirmed purchase')
check(#requests==2 and requests[2].endpoint=='CREDIT','seller settlement uses separate credit')
local credit=M.data().credits[tx.id]
callbacks.request2({requestId='request2',ok=true,idempotencyKey=credit.key,transactionId='credit1'})
check(credit.state=='paid','seller credit receipt persisted')
buyer.getCurrentSquare=function() return nil end
time=persistent.jobs[tx.jobId].due
Courier.update()
check(#world==2 and world[1]:getItem().condition==37 and world[2]:getItem().condition==83,'offline delivery restores exact sold item condition instead of pristine prototypes')
local selfItem=item(3,nil,61); seller:getInventory():add(selfItem)
command(seller,'MarketPost',{token='postself',itemIds={3},price=5})
local selfBuy=command(seller,'MarketBuy',{token='buyself',listingId='2',count=1})
check(selfBuy and selfBuy.kind=='reserved','self-purchase explicitly allowed for testing')
M.update()
local selfTx=M.data().transactions[selfBuy.transaction]
local request=requests[#requests]
callbacks[request.id]({requestId=request.id,ok=false,status=402,error='HTTP_402'})
time=time+1000; M.update()
check(selfTx.state=='failed' and M.data().listings['2'].units[1].state=='available','failed debit releases reservation without consuming cargo')
seller.radio.on=false
local denied=command(seller,'MarketPage',{token='off',mode='market',page=1})
check(denied and not denied.ok and denied.error=='RADIO','radio access is revalidated server-side')
seller.radio.on=true
command(seller,'MarketTune',{token='retune',radio={itemId=seller.radio.id}})
local selfSuccess=command(seller,'MarketBuy',{token='buyself2',listingId='2',count=1})
check(selfSuccess and selfSuccess.kind=='reserved','own listing can be reserved after a failed attempt')
-- Crash boundary: reservation persisted before the debit was queued. Reconcile
-- from the trusted snapshots with no live player or tune session.
package.loaded['ApocWallet/MarketService']=nil; ApocWallet.MarketService=nil
M=require 'ApocWallet/MarketService'
seller.getCurrentSquare=function() return nil end
time=time+1000; M.update()
local selfRetry=M.data().transactions[selfSuccess.transaction]
request=requests[#requests]
check(request.endpoint=='DEBIT','offline reload resumes durable market reservation')
callbacks[request.id]({requestId=request.id,ok=true,idempotencyKey=selfRetry.id,transactionId='self-debit'})
time=time+1000; Purchase.update(); M.update()
check(selfRetry.state=='complete' and M.data().credits[selfRetry.id].state=='pending','self-purchase completes and queues the normal seller credit')
local delivery=persistent.jobs[selfRetry.jobId]
time=delivery.due; Courier.update()
check(#world==3 and world[3]:getItem().condition==61,'self-purchased exact item delivered after player leaves')
check(P.code('Base.Axe')==P.code('Base.Axe') and P.code('Base.Axe')~=P.code('Base.Hammer'),'deterministic item codenames')
check(P.sector(1234,5678,2)=='S012-056-N2','deterministic sector')
print('Passed '..checks..' production market ownership, custody, purchase, settlement and radio checks.')

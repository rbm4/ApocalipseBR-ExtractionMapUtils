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
local failSave,storeAvailable=false,true
package.loaded['ApocWallet/EntityStore']={data=function() return persistent end,ready=function() return storeAvailable end,
 modData=function(kind,id) persistent.itemData=persistent.itemData or {}; persistent.itemData[kind..id]=persistent.itemData[kind..id] or {}; return persistent.itemData[kind..id] end,
 persist=function() if failSave then error('PERSISTENCE_WRITE_FAILED') end; saves=saves+1 end,
 run=function(_,fn,onError) local ok,err=pcall(fn); if not ok then if onError then onError(err) else error(err) end end end}
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
ApocBrApiBridge={CHARACTER_DEBIT='DEBIT',CHARACTER_CREDIT='CREDIT',isEnabled=function() return true end,
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
storeAvailable=false
local unavailable=command(seller,'MarketPost',{token='missing-save',itemIds={1,2},price=15})
check(unavailable and unavailable.error=='STORAGE' and M.data().seq==0,'missing save facade fails before creating an intent')
check(axe1.container and axe2.container,'missing save API never removes cargo')
storeAvailable=true
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
check(tx.fee==3 and credit.amount==27 and requests[2].body:find('"amount":27',1,true),'10 percent deducted from seller after completed sale')
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
-- New listings receive 48 real-world hours starting when custody is published.
seller.getCurrentSquare=function() return sq end
buyer.getCurrentSquare=function() return sq end
command(seller,'MarketTune',{token='expiry-tune',radio={itemId=seller.radio.id}})
local function postItem(id,price)
    seller:getInventory():add(item(id,nil,55))
    local result=command(seller,'MarketPost',{token='expiry-post'..id,itemIds={id},price=price or 19})
    check(result and result.kind=='posted','expiry fixture posted')
    return M.data().listings[tostring(M.data().seq)]
end
local exp=postItem(41)
check(exp.expiresAt-exp.openedAt==48*60*60*1000,'publication receives exactly 48 real hours')
time=exp.expiresAt-1; M.update()
check(exp.state=='open','listing remains open just before deadline')
time=exp.expiresAt; M.nextUpdate=0; M.update()
check(exp.state=='expired' and not M.data().openListings[exp.id],'deadline delists without a player request')
for _,p in ipairs(players) do command(p,'MarketTune',{token='new-tune'..p.index,radio={itemId=p.radio.id}}) end
local expired=command(seller,'MarketPage',{token='expired-page',mode='expired',page=1})
check(#expired.rows==1 and expired.rows[1].id==exp.id,'owner can see expired stock')
local private=command(other,'MarketPage',{token='private-page',mode='expired',page=1})
check(#private.rows==0,'other character cannot browse expired stock')
local late=command(buyer,'MarketBuy',{token='late-buy',listingId=exp.id,count=1})
check(late.error=='SOLD','expired cargo cannot be bought from stale pages')
local stolen=command(other,'MarketRecover',{token='steal',listingId=exp.id})
check(not stolen.ok,'recovery validates server character ownership')
local rep=command(seller,'MarketRepost',{token='repost-expired',listingId=exp.id})
local deadline=exp.expiresAt
check(rep.kind=='reposted' and deadline==time+P.LISTING_LIFETIME,'repost resets full lifetime without a debit')
command(seller,'MarketRepost',{token='repost-expired',listingId=exp.id})
check(exp.expiresAt==deadline,'repost token replay never extends lifetime again')
-- Search all results before pagination, literal matching and case-insensitive ASCII names.
for i=42,48 do postItem(i) end
local last=M.data().listings[tostring(M.data().seq)]; last.name='Unique AXE [rare]'
local found=command(buyer,'MarketPage',{token='search',mode='market',page=1,query='axe [RARE]'})
check(#found.rows==1 and found.rows[1].id==last.id and found.pages==1,'name search finds later pages and treats brackets literally')
local empty=command(buyer,'MarketPage',{token='empty-search',mode='market',page=99,query='nonexistent'})
check(#empty.rows==0 and empty.page==1 and empty.pages==1,'empty filter result clamps pagination')
-- Simulate restart and offline time, then recover through a durable courier receipt.
time=deadline+1
package.loaded['ApocWallet/MarketService']=nil; ApocWallet.MarketService=nil
M=require 'ApocWallet/MarketService'; M.update()
command(seller,'MarketTune',{token='return-tune',radio={itemId=seller.radio.id}})
local recovered=command(seller,'MarketRecover',{token='return-one',listingId=exp.id})
check(recovered.kind=='recovered' and exp.units[1].state=='returned','expired exact cargo handed to courier')
local units=persistent.jobs[recovered.jobId].units
command(seller,'MarketRecover',{token='return-one',listingId=exp.id})
check(persistent.jobs[recovered.jobId].units==units,'same-token recovery cannot duplicate courier cargo')
local twice=command(seller,'MarketRecover',{token='return-twice',listingId=exp.id})
check(not twice.ok,'new token cannot recover already returned units')
time=persistent.jobs[recovered.jobId].due
for _=1,8 do time=time+300; Courier.update() end
check(world[#world]:getItem().condition==55,'returned item retains native condition')
-- Reservation made before expiry settles normally; failure keeps stock expired.
local reserved=postItem(49,9)
command(buyer,'MarketTune',{token='reserve-tune',radio={itemId=buyer.radio.id}})
local pending=command(buyer,'MarketBuy',{token='expire-reserved',listingId=reserved.id,count=1})
time=time+1000; M.update(); local failedRequest=requests[#requests]
time=reserved.expiresAt+1; M.update()
command(seller,'MarketTune',{token='pending-tune',radio={itemId=seller.radio.id}})
local blocked=command(seller,'MarketRepost',{token='pending-repost',listingId=reserved.id})
check(not blocked.ok,'unsettled reservation cannot be reclaimed or reposted')
callbacks[failedRequest.id]({requestId=failedRequest.id,ok=false,status=402,error='HTTP_402'})
time=time+1000; M.update()
check(reserved.state=='expired' and reserved.units[1].state=='available' and not M.data().openListings[reserved.id],'failed purchase after deadline returns stock to expired custody')
local finalReturn=command(seller,'MarketRecover',{token='after-failure',listingId=reserved.id})
check(finalReturn.kind=='recovered','seller can recover failed reservation after settlement')
-- A crash after recording return intent resumes without a connected seller.
local crash=postItem(50)
time=crash.expiresAt+1; M.update()
command(seller,'MarketTune',{token='crash-tune',radio={itemId=seller.radio.id}})
failSave=true
local interruptedReturn=command(seller,'MarketRecover',{token='crash-return',listingId=crash.id})
check(interruptedReturn.error=='STORAGE' and crash.units[1].state=='returning','return intent recorded before courier side effects')
failSave=false
package.loaded['ApocWallet/MarketService']=nil; ApocWallet.MarketService=nil
M=require 'ApocWallet/MarketService'; time=time+1000; M.update()
check(crash.units[1].state=='returned','restart resumes durable return without a live session')
-- A purchase reserved before expiry can still succeed, with the sale fee.
command(seller,'MarketTune',{token='last-tune',radio={itemId=seller.radio.id}})
local success=postItem(51,19)
command(buyer,'MarketTune',{token='last-buyer-tune',radio={itemId=buyer.radio.id}})
local successBuy=command(buyer,'MarketBuy',{token='last-buy',listingId=success.id,count=1})
time=time+1000; M.update(); local successRequest=requests[#requests]
time=success.expiresAt+1; M.update()
callbacks[successRequest.id]({requestId=successRequest.id,ok=true,idempotencyKey=successBuy.transaction,transactionId='late-success'})
time=time+1000; Purchase.update(); M.update()
local successTx=M.data().transactions[successBuy.transaction]
check(successTx.state=='complete' and success.units[1].state=='sold','pre-expiry reservation completes after deadline')
check(successTx.fee==1 and M.data().credits[successTx.id].amount==18,'fractional fee rounds down to whole wallet credits')
print('Passed '..checks..' production market ownership, custody, purchase, settlement and radio checks.')

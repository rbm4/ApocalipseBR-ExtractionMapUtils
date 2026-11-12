local root='ApocalipseBR-Wallet/common/media/lua/'
package.path=root..'shared/?.lua;'..root..'server/?.lua;'..package.path
local checks,time,saves,packets,world,loaded,created=0,100000,0,{}, {},true,0
local function check(v,m) checks=checks+1; assert(v,m) end
function isClient() return false end
function getTimestampMs() return time end
function ZombRand(lo,hi) return lo+10000 end
local persisted={}
ModData={getOrCreate=function() return persisted end}
ApocBrApiBridge={saveModData=function() saves=saves+1; return true end}
function sendServerCommand(...) packets[#packets+1]={...} end
local function list(t) return {size=function() return #t end,get=function(_,i) return t[i+1] end} end
local online={}
function getOnlinePlayers() return list(online) end
local square={getX=function() return 10 end,getY=function() return 20 end,getZ=function() return 0 end}
function square:getWorldObjects() return list(world) end
local failCreate=false
local failAt
function instanceItem(fullType)
    if failCreate or failAt and created>=failAt then return nil end
    created=created+1
    local item={type=fullType,md={}}
    function item:getModData() return self.md end
    function item:getWorldItem() return self.world end
    return item
end
function square:AddWorldInventoryItem(item)
    local object={getItem=function() return item end}
    item.world=object; world[#world+1]=object; return item
end
local cell={}
function cell:getGridSquare(x,y,z)
    if not loaded then return nil end
    if x==10 and y==20 then return square end
    return {isSolid=function() return false end,isBlockedTo=function() return false end,
        isDoorBlockedTo=function() return false end,isWindowTo=function() return false end}
end
function square:isSolid() return false end
function square:isBlockedTo() return false end
function square:isDoorBlockedTo() return false end
function square:isWindowTo() return false end
function getCell() return cell end
local loads=0
ApocBRLobbyStreaming={keepCellLoaded=function() loads=loads+1 end}
ScriptManager={instance={getItem=function(_,id) return id~='Bad.Item' end}}
local C=require 'ApocWallet/CourierService'
local destination={x=10,y=20,z=0}
local goods={{type='Base.Axe',count=2}}
local id=C.delivery('alice','receipt1',destination,goods)
check(id and saves>0,'durable job before dispatch')
check(persisted.jobs[id].due-time>=30000 and persisted.jobs[id].due-time<=90000,'ETA bounds')
destination.x=99; goods[1].count=99
check(persisted.jobs[id].x==10 and persisted.jobs[id].items[1].count==2,'snapshots immutable to caller')
check(C.delivery('alice','receipt1',{x=10,y=20,z=0},{{type='Base.Axe',count=2}})==id,'receipt replay idempotent')
check(C.delivery('alice','receipt2',{x=10,y=20,z=0},{{type='Base.Hammer',count=1}})==id,'multiple purchases one drone')
check(not C.delivery('alice','bad',{x=1.5,y=1,z=0},{{type='Base.Axe',count=1}}),'reject fractional square')
time=persisted.jobs[id].due-8000
loaded=false; C.update()
check(loads==1 and #world==0,'offline unloaded square requested without early cargo')
loaded=true; time=time+250; C.update()
check(#persisted.jobs[id].path>1 and #world==0,'approach starts before cargo')
time=persisted.jobs[id].due; failCreate=true; C.update()
check(#world==0 and persisted.jobs[id].state=='waiting','failed creation retained for retry')
failCreate=false; failAt=1; time=time+250; C.update()
check(#world==1 and persisted.jobs[id].placed==1 and persisted.jobs[id].state=='waiting','partial delivery progress saved')
-- Simulate recovery where a tagged object reached the square before progress saved.
persisted.jobs[id].placed=0
failAt=nil; time=time+250; C.update()
check(#world==3 and persisted.jobs[id].state=='departing','offline ground delivery on saved square')
time=time+250; C.update(); check(#world==3,'no repeat on next tick')
-- Simulated Lua reload keeps durable receipts and progress, no online player.
package.loaded['ApocWallet/CourierService']=nil
ApocWallet.CourierService=nil
C=require 'ApocWallet/CourierService'; C.update()
check(#world==3,'restart retains placement progress')
time=time+10000; C.update(); check(persisted.jobs[id]==nil and persisted.finished[id],'departure completed and active job retired')
local removed=0
local inv={getOutermostContainer=function(self) return self end}
function inv:DoRemoveItem(item) removed=removed+1; item.container=nil end
function sendRemoveItemFromContainer() end
local player={getUsername=function() return 'alice' end,isDead=function() return false end,
    getCurrentSquare=function() return square end,getInventory=function() return inv end,isEquipped=function() return false end}
local function inventoryItem(id)
    local item={container=inv}
    function item:getContainer() return self.container end
    function item:getID() return id end
    function item:getFullType() return 'Base.Axe' end
    return item
end
ApocBrApiBridge={saveModData=function() saves=saves+1; return true end,encodeItem=function(item) return 'native-save-'..item:getID() end}
ApocBRModEntities={character=function() return {status='OK',characterId='12345678-1234-4234-8234-123456789abc',
    steamId='76561198000000001',sourceServerId=2} end}
local pickup=C.pickup(player,'post1',{inventoryItem(1)})
check(pickup and removed==1,'pickup immediately removes inventory item')
check(persisted.escrow['pickup:12345678-1234-4234-8234-123456789abc:post1'].state=='held','pickup exact item blob in persistent custody')
local pickup2=C.pickup(player,'post2',{inventoryItem(2)})
check(pickup2==pickup and removed==2,'pickup batch uses single drone')
check(C.pickup(player,'post1',{inventoryItem(1)})==pickup and removed==2,'pickup replay cannot remove twice')
local before=#world
time=persisted.jobs[pickup].due; C.update()
check(#world==before,'pickup animation never creates cargo')
-- Purchase API succeeds after disconnect and moving the original player.
ApocBRModEntities={character=function() return {status='OK',characterId='12345678-1234-4234-8234-123456789abc',
    steamId='76561198000000001',sourceServerId=2} end}
local callbacks,requests={},{}
ApocBrApiBridge.CHARACTER_DEBIT='DEBIT'
ApocBrApiBridge.isEnabled=function() return true end
ApocBrApiBridge.request=function(endpoint,params,callback)
    local key='request'..tostring(#requests+1); requests[#requests+1]=params; callbacks[key]=callback; return key
end
local P=require 'ApocWallet/PurchaseService'
time=time+1000
local orderId=P.buy(player,'buy1',{amount=10,reason='market.purchase',items={{type='Base.Axe',count=1}}})
check(orderId and #requests==1,'purchase calls API')
check(#world==before,'no delivery before debit success')
player.getCurrentSquare=function() return nil end
callbacks.request1({requestId='request1',ok=true,idempotencyKey=orderId,transactionId='tx1',balance=90})
time=time+1000; P.update()
local order=persisted.purchases[orderId]
check(order.state=='fulfilled' and persisted.jobs[order.jobId].x==10,'callback after disconnect retains purchase square')
local jobCount=0; for _ in pairs(persisted.jobs) do jobCount=jobCount+1 end
callbacks.request1({requestId='request1',ok=true,idempotencyKey=orderId,transactionId='tx1'})
P.update()
local afterCount=0; for _ in pairs(persisted.jobs) do afterCount=afterCount+1 end
check(jobCount==afterCount,'duplicate callback cannot queue second delivery')
player.getCurrentSquare=function() return square end
time=time+1000
local failed=P.buy(player,'buy2',{amount=10,reason='market.purchase',items={{type='Base.Axe',count=1}}})
callbacks.request2({requestId='request2',ok=false,status=402,error='HTTP_402'})
check(persisted.purchases[failed].state=='failed' and not persisted.purchases[failed].jobId,'rejected debit creates no delivery')
-- Lost response and Lua reload replay the exact debit body/key.
time=time+1000
local retry=P.buy(player,'buy3',{amount=10,reason='market.purchase',items={{type='Base.Axe',count=1}}})
local firstBody=requests[3]
check(firstBody:find('idempotencyKey',1,true),'stable key sent to backend')
package.loaded['ApocWallet/PurchaseService']=nil
ApocWallet.PurchaseService=nil
P=require 'ApocWallet/PurchaseService'
time=time+71000; P.update()
check(requests[4]==firstBody,'restart replays identical debit body after uncertain result')
callbacks.request3({requestId='request3',ok=true,idempotencyKey=retry,transactionId='tx3'})
check(persisted.purchases[retry].state=='pending','stale attempt cannot finish a newer attempt')
callbacks.request4({requestId='request4',ok=true,idempotencyKey=retry,transactionId='tx3'})
time=time+1000; P.update()
check(persisted.purchases[retry].state=='fulfilled','matching replay receipt schedules delivery')
print('Passed '..checks..' wallet courier persistence, batching, pickup, offline streaming and purchase checks.')

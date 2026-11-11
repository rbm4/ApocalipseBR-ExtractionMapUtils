local root="ApocalipseBR-Wallet/common/media/lua/"
package.path=root.."shared/?.lua;"..root.."client/?.lua;"..package.path
local checks,requests,walks,blocked,reject,deferred=0,0,{},false,false,false
local players,callbacks={},{}
local function check(ok,message) checks=checks+1; assert(ok,message) end
function isClient() return true end
function getSpecificPlayer(index) return players[index] end
function instanceof(object,kind)
    if not object then return false end
    return object.kind==kind or kind=="InventoryItem" and object.kind=="Radio"
        or kind=="IsoGameCharacter" and object.kind=="IsoPlayer"
end
local function square(x,y,z)
    local s={x=x,y=y,z=z or 0}
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return self.z end
    function s:canReachTo(other)
        return not self.wall and self.z==other.z and math.abs(self.x-other.x)<=1 and math.abs(self.y-other.y)<=1
    end
    return s
end
local function player(index)
    local p={kind="IsoPlayer",index=index,square=square(0,0)}
    p.inventory={}
    function p.inventory:getOutermostContainer() return self end
    function p.inventory:getParent() return p end
    function p:getInventory() return self.inventory end
    function p:getCurrentSquare() return self.square end
    function p:getX() return self.square.x+0.5 end
    function p:getY() return self.square.y+0.5 end
    function p:getPlayerNum() return self.index end
    function p:isDead() return self.dead==true end
    function p:getVehicle() return self.vehicle end
    players[index]=p
    return p
end
local function radio(kind,sq,container)
    local r={kind=kind or "IsoWaveSignal",square=sq,container=container,index=0}
    function r:getDeviceData() return {getIsTwoWay=function() return true end} end
    function r:getFullType() return "Base.WalkieTalkie1" end
    function r:getContainer() return self.container end
    function r:getWorldItem() return self.world end
    function r:getObjectIndex() return self.index end
    function r:getSquare() return self.square end
    function r:getVehicle() return self.vehicle end
    return r
end
require "ApocWallet/Protocol"
ApocWallet.ClientService={refreshBalance=function(_,callback)
    requests=requests+1
    if deferred then callbacks[#callbacks+1]=callback else callback({status="ready",balance=15000}) end
    return function() end
end}
package.loaded["ApocWallet/ClientService"]=true
local View={}
function View:new(p,r,kind,actions)
    return setmetatable({player=p,radio=r,kind=kind,playerIndex=p.index,actions=actions},{__index=self})
end
function View:initialise() end
function View:addToUIManager() self.added=true end
function View:removeFromUIManager() self.added=false end
function View:clampToScreen() end
function View:bringToTop() end
function View:setVisible(v) self.visible=v end
function View:setBalanceState(state) self.status=state.status; self.balance=state.balance end
package.loaded["ApocWallet/UI/RadioWindow"]=View
ISTimedActionQueue={}
function ISTimedActionQueue.hasAction(action) return action.queued==true end
function ISTimedActionQueue.clear(p)
    for _,action in ipairs(walks) do if action.character==p and action.queued then action:stop() end end
end
function ISTimedActionQueue.add(action)
    if reject then return end
    action.queued=true; walks[#walks+1]=action
end
ISWalkToTimedAction={}
function ISWalkToTimedAction:new(p,destination)
    return setmetatable({character=p,location=destination},{__index=self})
end
function ISWalkToTimedAction:setOnComplete(callback) self.callback=callback end
function ISWalkToTimedAction:stop() self.queued=false; self.nativeStopped=true end
function ISWalkToTimedAction:arrive()
    self.queued=false; self.character.square=self.location; self.callback()
end
package.loaded["TimedActions/ISTimedActionQueue"]=true
package.loaded["TimedActions/WalkToTimedAction"]=true
AdjacentFreeTileFinder={Find=function(target)
    return not blocked and square(target.x-1,target.y,target.z) or nil
end}
local Device=require "ApocWallet/RadioDevice"
local Controller=require "ApocWallet/RadioUIController"
local function reset()
    Controller.closeAll(); players={}; walks={}; callbacks={}
    requests,blocked,reject,deferred=0,false,false,false
    return player(0)
end
local p=reset()
local carried=radio("Radio",nil,p.inventory)
check(Controller.open(p,carried)~=nil and #walks==0 and requests==1,"carried radio opens without walking")
p=reset()
local bag={getOutermostContainer=function() return p.inventory end}
check(Controller.open(p,radio("Radio",nil,bag))~=nil and #walks==0,"radio inside carried bag counts as carrying")
p=reset()
local peer=player(1)
check(Controller.open(p,radio("Radio",nil,peer.inventory))==nil and #walks==0,"another player's radio is inaccessible")
p=reset()
check(Controller.open(p,radio(nil,square(1,0)))~=nil and #walks==0,"adjacent reachable radio opens immediately")
p=reset(); local target=radio(nil,square(10,0))
check(Controller.open(p,target)==nil and requests==0 and #walks==1,"far radio queues native walk and defers API/UI")
local action=walks[1]
Controller.open(p,target)
check(#walks==1,"repeated click deduplicates active approach")
action:arrive()
check(Controller.windows[0] and requests==1 and Controller.approaches[0]==nil,"arrival revalidates and opens once")
p=reset(); blocked=true
check(Controller.open(p,radio(nil,square(10,0)))==nil and #walks==0 and requests==0,"no reachable adjacent tile means no window")
p=reset(); Controller.open(p,radio(nil,square(10,0))); action=walks[1]; action:stop(); action.callback()
check(action.nativeStopped and Controller.approaches[0]==nil and requests==0,"cancellation preserves native stop and cannot later open")
p=reset(); target=radio(nil,square(10,0)); Controller.open(p,target); target.index=-1; walks[1]:arrive()
check(requests==0 and not Controller.windows[0],"removed radio cannot open after walking")
p=reset(); target=radio(nil,square(10,0)); Controller.open(p,target); target.square=square(50,0); walks[1]:arrive()
check(requests==0,"radio moved out of reach cannot open")
p=reset(); target=radio(nil,square(1,0)); p.square.wall=true
check(not Device.canUse(p,target),"adjacent through blocked wall is not usable")
Controller.open(p,target); walks[1].queued=false; walks[1].callback()
check(requests==0,"path callback without reachable arrival never opens")
p=reset(); target=radio(nil,square(0,0,1))
check(not Device.canUse(p,target),"same XY on another floor is inaccessible")
Controller.open(p,target); walks[1].queued=false; walks[1].callback()
check(requests==0,"wrong-floor completion cannot open")
p=reset(); Controller.open(p,radio(nil,square(10,0))); action=walks[1]; p.dead=true; action:arrive()
check(requests==0,"dead player cannot receive arrival UI")
p=reset(); Controller.open(p,radio(nil,square(10,0))); action=walks[1]; player(0); action:arrive()
check(requests==0,"replacement player cannot inherit old approach")
p=reset(); reject=true; Controller.open(p,radio(nil,square(10,0)))
check(Controller.approaches[0]==nil and requests==0,"queue rejection releases pending intent")
p=reset(); local r1=radio(nil,square(10,0)); local r2=radio(nil,square(20,0))
Controller.open(p,r1); action=walks[1]; Controller.open(p,r2); action.callback()
check(action.nativeStopped and requests==0 and Controller.approaches[0].radio==r2,"new target invalidates and stops prior approach")
walks[2]:arrive(); check(Controller.windows[0].radio==r2,"only latest target opens")
p=reset(); target=radio(nil,square(1,0)); local win=Controller.open(p,target); p.square=square(10,0)
Controller.refresh(win)
check(win.closed and requests==1,"moving away closes window on Sync without another API read")
p=reset(); deferred=true; target=radio(nil,square(1,0)); win=Controller.open(p,target); p.square=square(10,0)
callbacks[1]({status="ready",balance=1})
check(win.closed and win.balance==nil,"late balance cannot populate out-of-range UI")
p=reset(); target=radio("Radio")
target.world={getWorldObjectIndex=function() return 0 end,getSquare=function() return square(1,0) end}
check(Controller.open(p,target)~=nil,"loose ground radio uses world-object index and proximity")
p=reset(); target=radio("Radio")
target.world={getWorldObjectIndex=function() return -1 end,getSquare=function() return square(1,0) end}
check(Controller.open(p,target)==nil and #walks==0,"removed loose ground radio is not a usable target")
p=reset(); local car={getSquare=function() return square(50,50) end}
p.vehicle=car; target=radio("VehiclePart"); target.vehicle=car
check(Controller.open(p,target)~=nil and #walks==0,"occupant can use the current vehicle's two-way radio")
p=reset(); p.vehicle=car; Controller.open(p,radio(nil,square(10,0)))
check(#walks==0 and requests==0,"external approach does not issue walking action while seated")
p=reset(); Controller.open(p,radio(nil,square(10,0))); action=walks[1]; Controller.closeAll(); action:arrive()
check(requests==0 and Controller.approaches[0]==nil,"disconnect invalidates pending approach without a polling handler")
print("Passed "..checks.." wallet radio access assertions (actual device/controller Lua; native pathfinder/queue mocked).")

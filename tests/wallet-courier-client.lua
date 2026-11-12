local root='ApocalipseBR-Wallet/common/media/lua/'
package.path=root..'shared/?.lua;'..root..'client/?.lua;'..package.path
local checks,time,draws=0,1000,{}
local function check(v,m) checks=checks+1; assert(v,m) end
local function event() return {Add=function() end} end
Events={OnServerCommand=event(),OnPostRender=event(),OnTick=event(),OnDisconnect=event()}
function isServer() return false end
function getTimestampMs() return time end
function getText(key,arg) return key..':'..arg end
require 'ApocWallet/Protocol'
package.loaded['ApocWallet/DroneRenderer']={draw=function(...) draws[#draws+1]={...} end}
local C=require 'ApocWallet/CourierClient'
C.receive('CourierFlight',{id='1',kind='delivery',path={{x=0,y=0},{x=12,y=0}},z=2,
    due=100000,serverNow=92000,approach=8000,hover=2000,depart=8000})
C.render()
check(draws[1][1]==0 and draws[1][3]==2,'client/server clocks aligned at approach start')
time=5000; C.render(); check(draws[2][1]==6,'approaches destination smoothly')
time=9000; C.render(); check(draws[3][1]==12,'arrives at server handoff time')
time=11000; C.render(); check(draws[4][1]==12,'hover then departure')
time=15000; C.render(); check(draws[5][1]==6,'flies away along route')
time=19000; C.render(); check(C.flights['1']==nil and #draws==5,'render removed after departure')
C.receive('CourierETA',{id='1',kind='delivery',seconds=42,onlineId=7})
check(C.latestFor({getOnlineID=function() return 7 end}):find('42',1,true),'radio arrival message')
check(not C.latestFor({getOnlineID=function() return 8 end}),'ETA belongs to the targeted local player')
local Route=require 'ApocWallet/CourierRoute'
local cell={}
function cell:getGridSquare(x,y)
    return {isSolid=function() return false end,isBlockedTo=function(_,next) return false end,
        isDoorBlockedTo=function() return false end,isWindowTo=function() return false end}
end
local path=Route.plan(cell,5,5,0)
check(#path==13 and path[#path].x==5.5,'bounded grid path reaches saved destination')
function cell:getGridSquare(x,y)
    return {isSolid=function() return false end,isBlockedTo=function() return true end,
        isDoorBlockedTo=function() return false end,isWindowTo=function() return false end}
end
local enclosed,vertical=Route.plan(cell,5,5,0)
check(vertical and enclosed[1].x==enclosed[2].x,'enclosed square uses vertical visual instead of crossing walls')
print('Passed '..checks..' courier client timing, approach/departure, ETA and path checks.')

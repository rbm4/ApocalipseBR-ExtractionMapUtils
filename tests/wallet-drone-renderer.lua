package.path = 'ApocalipseBR-Wallet/common/media/lua/shared/?.lua;ApocalipseBR-Wallet/common/media/lua/client/?.lua;' .. package.path
local created,draws = 0,{}
function instanceItem(id) created=created+1; return {id=id} end
local sq={}
local loaded=true
function getCell() return {getGridSquare=function() return loaded and sq or nil end} end
function Render3DItem(item,square,x,y,z,yaw) draws[#draws+1]={item=item,x=x,y=y,z=z,yaw=yaw} end
local R=require 'ApocWallet/DroneRenderer'
assert(R.draw(10.5,20.5,2,0.6,30,1.123))
assert(#draws==5 and created==2, 'body plus four rotors with cached visual items')
assert(draws[1].z>2.6 and draws[1].z<2.63, 'absolute floor plus hover')
assert(draws[2].yaw~=draws[3].yaw,'adjacent rotors counter-rotate')
R.draw(11,21,2,0.6,40,1.01)
assert(created==2 and #draws==10)
loaded=false
assert(not R.draw(0,0,0,0.6,0,1) and #draws==10, 'unloaded square never renders')
print('Passed wallet drone renderer caching, body/rotors, altitude and unloaded-square checks.')

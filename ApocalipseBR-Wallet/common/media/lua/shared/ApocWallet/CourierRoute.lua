-- Bounded grid search for the local approach. Rendering is never authority for cargo.
require "ApocWallet/Protocol"
if ApocWallet.CourierRoute then return ApocWallet.CourierRoute end
local Route = {}
ApocWallet.CourierRoute = Route
local function key(x,y) return x .. ':' .. y end
function Route.plan(cell, x, y, z)
    local goal = cell:getGridSquare(x,y,z)
    if not goal then return nil end
    local queue,seen,head={{x=x,y=y}},{[key(x,y)]=true},1
    -- Search outward from the destination, keeping parent links toward it.
    while head<=#queue and head<=625 do
        local node=queue[head]; head=head+1
        if math.abs(node.x-x)+math.abs(node.y-y)>=12 then
            local path={}
            while node do
                path[#path+1]={x=node.x+0.5,y=node.y+0.5}
                node=node.parent
            end
            return path
        end
        local sq=cell:getGridSquare(node.x,node.y,z)
        for _,d in ipairs({{1,0},{0,1},{-1,0},{0,-1}}) do
            local nx,ny=node.x+d[1],node.y+d[2]
            local k=key(nx,ny)
            if not seen[k] and math.abs(nx-x)<=12 and math.abs(ny-y)<=12 then
                seen[k]=true
                local nextSq=cell:getGridSquare(nx,ny,z)
                if nextSq and not nextSq:isSolid() and not sq:isBlockedTo(nextSq)
                    and not sq:isDoorBlockedTo(nextSq) and not sq:isWindowTo(nextSq) then
                    queue[#queue+1]={x=nx,y=ny,parent=node}
                end
            end
        end
    end
    -- Enclosed targets still receive goods. A vertical approach stays on their
    -- loaded square instead of inventing a route through a wall.
    return {{x=x+0.5,y=y+0.5},{x=x+0.5,y=y+0.5}}, true
end

function Route.sample(path, progress)
    local n=#path
    if n==0 then return nil end
    local p=math.max(0,math.min(1,progress)) * (n-1)
    local i=math.min(n-1,math.floor(p)+1)
    if n==1 then return path[1].x,path[1].y,0 end
    local a,b=path[i],path[i+1]
    local f=p-(i-1)
    local dx,dy=b.x-a.x,b.y-a.y
    local yaw=dx>0 and 90 or dx<0 and 270 or dy<0 and 180 or 0
    return a.x+dx*f,a.y+dy*f,yaw
end
return Route

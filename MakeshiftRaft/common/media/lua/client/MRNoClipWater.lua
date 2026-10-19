MakeshiftRaft = MakeshiftRaft or {}

local function isCheatAllowed(playerObj)--see PlayerCheats.isCheatAllowed
    --Core.debug || GameClient.client || GameServer.server; //version B42.13.1
    return isDebugEnabled() or isClient() or isServer()
end


local function isInVicinity(playerSquare,otherSquare)
    if not playerSquare or not otherSquare then return false end
    local dX = playerSquare:getX()-otherSquare:getX()
    if dX > 1 or dX < -1 then return false end
    local dY = playerSquare:getY()-otherSquare:getY()
    if dY > 1 or dY < -1 then return false end
    --local dZ = playerSquare:getZ()-otherSquare:getZ()--TODO think on how to handle Z
    --if dZ > 1 or dZ < -1 then return false end
    return true
end
local function isRaftPassable(playerSquare,otherSquare)
     local raftPassable = not playerSquare:isWallTo(otherSquare) and not playerSquare:isWindowTo(otherSquare)
     --print('isRaftPassable '..sq2str(playerSquare)..'->'..sq2str(otherSquare)..': '..tostring(raftPassable))
     return raftPassable
end

local function applyNormalClip(square)
    local floorTile = square and square:getFloor()
    local sprite = floorTile and floorTile:getSprite()
    local props = sprite and sprite:getProperties()
    if props then 
        props:set(IsoFlagType.solidtrans)
        square:EnsureSurroundNotNull();
        square:RecalcAllWithNeighbours(true);
        --print('set solidtrans to '..sq2str(square))
    end
end
local function applyNoClip(square)
    local floorTile = square and square:getFloor()
    local sprite = floorTile and floorTile:getSprite()
    local props = sprite and sprite:getProperties()
    if props then 
        props:unset(IsoFlagType.solidtrans)
        square:EnsureSurroundNotNull();
        square:RecalcAllWithNeighbours(true);
        --print('unset solidtrans to '..sq2str(square))
    end
end
local function isBlockingSquare(square)
    local floorTile = square and square:getFloor()
    local sprite = floorTile and floorTile:getSprite()
    local props = sprite and sprite:getProperties()
    --print(''..sq2str(square)..' solidtrans='..tostring(props and props:has(IsoFlagType.solidtrans)))
    return props and props:has(IsoFlagType.solidtrans)
end

local walkableWaterTiles = {}
function MakeshiftRaft.setNoClipWater(playerObj, flag, playerSquare)
    --square prop modifications
    if playerObj and not playerSquare then playerSquare = playerObj:getSquare() end--allow nil in interface for square
    if not playerSquare then return end--TODO LOG

    if flag then
        --clear all water tiles far from player back to normal
        for itSq=#walkableWaterTiles, 1, -1 do
            local otherSquare = walkableWaterTiles[itSq]
            if not isInVicinity(playerSquare,otherSquare) or not isRaftPassable(playerSquare,otherSquare) then
                if MakeshiftRaft.isWaterSquare(otherSquare) then--in case someone built on that square we do not mess with the already modified props
                    applyNormalClip(otherSquare)
                end
                if itSq ~= #walkableWaterTiles then
                    walkableWaterTiles[itSq] = walkableWaterTiles[#walkableWaterTiles]--order does not matter
                end
                walkableWaterTiles[#walkableWaterTiles] = nil--release
            end
        end
        
        --add close squares to no clip list
        local refX = playerSquare:getX()
        local refY = playerSquare:getY()
        local refZ = playerSquare:getZ()
        for itX = -1, 1 do
            for itY = -1, 1 do
                local otherSquare = getCell():getGridSquare(refX+itX,refY+itY,refZ)
                if otherSquare and isBlockingSquare(otherSquare) and isRaftPassable(playerSquare,otherSquare) and MakeshiftRaft.isWaterSquare(otherSquare) then
                    applyNoClip(otherSquare)
                    walkableWaterTiles[#walkableWaterTiles+1] = otherSquare
                end
            end
        end
    else
        --clear all water tiles back to normal
        --clear all water tiles far from player back to normal
        for itSq=#walkableWaterTiles, 1, -1 do
            local otherSquare = walkableWaterTiles[itSq]
            if MakeshiftRaft.isWaterSquare(otherSquare) then--in case someone built on that square we do not mess with the already modified props
                applyNormalClip(otherSquare)
            end
            if itSq ~= #walkableWaterTiles then
                walkableWaterTiles[itSq] = walkableWaterTiles[#walkableWaterTiles]--order does not matter
            end
            walkableWaterTiles[#walkableWaterTiles] = nil--release
        end
    end
end
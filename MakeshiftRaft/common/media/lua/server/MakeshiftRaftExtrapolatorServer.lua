


local function listener(module, command, playerObj, args)
    if module == 'Raft' and command == 'ExtrapUpd' then
        if MakeshiftRaft.Verbose then print('Server Extrap '..tostring(playerObj)..' ['..tostring(playerObj:getX())..','..tostring(playerObj:getY())..','..tostring(playerObj:getZ())..'] '..tab2str(args)) end
        playerObj:setX(args.x)
        playerObj:setY(args.y)
        playerObj:setZ(args.z)
        playerObj:setLastX(args.x)
        playerObj:setLastY(args.y)
        playerObj:setLastZ(args.z)
        playerObj:setDirectionAngle(args.a)--just forcing locally is not gonna do the tric, but it's a start
    end
end
--Events.OnClientCommand.Add(listener)
require 'AquaSwimShared'


local SwimSayWords = {}
SwimSayWords.damage = {}
SwimSayWords.damage["IGUI_SwimWord_Damage1"] = 30
SwimSayWords.damage["IGUI_SwimWord_Damage2"] = 30
SwimSayWords.damage["IGUI_SwimWord_Damage3"] = 30
-- SwimSayWords.damage["IGUI_SwimWord_Damage4"] = 15
-- SwimSayWords.damage["IGUI_SwimWord_Damage5"] = 15
-- SwimSayWords.damage["IGUI_SwimWord_Damage6"] = 15

SwimSayWords.lostItems = {}
SwimSayWords.lostItems["IGUI_SwimWord_LostItems1"] = 33
SwimSayWords.lostItems["IGUI_SwimWord_LostItems2"] = 33
SwimSayWords.lostItems["IGUI_SwimWord_LostItems3"] = 34

SwimSayWords.success = {}
SwimSayWords.success["IGUI_SwimWord_Success1"] = 33
SwimSayWords.success["IGUI_SwimWord_Success2"] = 33
SwimSayWords.success["IGUI_SwimWord_Success3"] = 34

SwimSayWords.fail = {}
SwimSayWords.fail["IGUI_SwimWord_Fail1"] = 33
SwimSayWords.fail["IGUI_SwimWord_Fail2"] = 33
SwimSayWords.fail["IGUI_SwimWord_Fail3"] = 34

SwimSayWords.endurance = {}
SwimSayWords.endurance["IGUI_SwimWord_Endurance1"] = 10
SwimSayWords.endurance["IGUI_SwimWord_Endurance2"] = 10
SwimSayWords.endurance["IGUI_SwimWord_Endurance3"] = 10
SwimSayWords.endurance["IGUI_SwimWord_Endurance4"] = 10

SwimSayWords.LostItems = {"IGUI_SwimWord_LostItems1", "IGUI_SwimWord_LostItems2", "IGUI_SwimWord_LostItems3"}
SwimSayWords.Damage = {"IGUI_SwimWord_Damage1", "IGUI_SwimWord_Damage2", "IGUI_SwimWord_Damage3"}
SwimSayWords.Endurance = {"IGUI_SwimWord_Endurance1", "IGUI_SwimWord_Endurance2", "IGUI_SwimWord_Endurance3", "IGUI_SwimWord_Endurance4"}


------
-- Fast swim

function fastSwim(key, joypadKey)
    if (key == Keyboard.KEY_SPACE and (isShiftKeyDown() or isKeyDown(Keyboard.KEY_LMENU))) then
        local player = getSpecificPlayer(0)
        local dir = player:getForwardDirection()
        local x = player:getX() + dir:getX()
        local y = player:getY() + dir:getY()
        local sq = player:getSquare()
        local sqDir = getCell():getGridSquare(x, y, player:getZ())
        if sq and sqDir and 
                AquatsarYachts.Swim.isWater(sqDir) and 
                not AquatsarYachts.Swim.isWater(sq) and 
                not sq:isWallTo(sqDir) and 
                not sq:isWindowTo(sqDir) then 
            player:setX(x)
            player:setY(y)
        end 
    end
end

function fastSwimJoypad(joypadData, joypadKey)
    -- print(joypadData.player)
    if joypadKey == Keyboard.KEY_SPACE then
        local player = getSpecificPlayer(joypadData.player)
        local dir = player:getForwardDirection()
        local x = player:getX() + dir:getX()
        local y = player:getY() + dir:getY()
        local sq = player:getSquare()
        local sqDir = getCell():getGridSquare(x, y, player:getZ())
        if sq and sqDir and 
                AquatsarYachts.Swim.isWater(sqDir) and 
                not AquatsarYachts.Swim.isWater(sq) and 
                not sq:isWallTo(sqDir) and 
                not sq:isWindowTo(sqDir) then 
            player:setX(x)
            player:setY(y)
        end 
    end
end

function AquatsarYachts.Swim.Say(playerObj, situation, chanceToSay)
    local maxCount = ZombRand(10000)
    local updateChance = maxCount*chanceToSay/1000
    local check = ZombRand(maxCount)
    if check <= updateChance then
        local currentNum = ZombRand(#SwimSayWords[situation])+1
        playerObj:Say(getText(SwimSayWords[situation][currentNum]))
    end
end



function AquatsarYachts.Swim.OnPlayerMoveClient(playerObj)
    if not AquatsarYachts.Swim.isSwimming(playerObj) then return end

    local newEndurance = playerObj:getStats():get(CharacterStat.ENDURANCE)
    if newEndurance < 0.05 then
        if ZombRand(100) < 5 then
            AquatsarYachts.Swim.Say(playerObj, "Damage", 25)
        end
    elseif newEndurance < 0.5 then 
        AquatsarYachts.Swim.Say(playerObj, "Endurance", 1)
    end
end


--sendServerCommand(playerObj, 'Swim', 'LostItems', nil)
function AquatsarYachts.Swim.LostItems(args)
    local playerObj = getPlayer()
    if not playerObj then
        print('AquatsarYachts.Swim.LostItems No valid player at time.')
        return
    end
    local currentNum = ZombRand(#SwimSayWords["LostItems"])+1
    playerObj:Say(getText(SwimSayWords["LostItems"][currentNum]))
end

function AquatsarYachts.Swim.OnServerCommand(mod, command, args)
    --print('AquatsarYachts.Swim.OnServerCommand '..tostring(mod)..' '..tostring(command))
    if 'Swim' == mod then
        local func = AquatsarYachts.Swim[command]
        if func then
            func(args)
        else
            print('Warning: func does not exist in AquatsarYachts.Swim: '..tostring(command))
        end
    end
end


Events.OnPlayerMove.Add(AquatsarYachts.Swim.OnPlayerMoveClient)
Events.OnKeyStartPressed.Add(fastSwim)
Events.OnServerCommand.Add(AquatsarYachts.Swim.OnServerCommand)

-- Events.OnFillWorldObjectContextMenu.Add(swimToPoint)




local function actionAngleLeft(playerObj, boat)
    local sailAngle = boat:getModData()["sailAngle"]
    if sailAngle == nil then
        sailAngle = 0
        boat:getModData()["sailAngle"] = 0
    end
    if sailAngle < 90 then
        sailAngle = sailAngle + 6
        if sailAngle > 90 then sailAngle = 90 end
    end
    boat:getModData()["sailAngle"] = sailAngle
    playerObj:getStats():remove(CharacterStat.ENDURANCE, 0.01)--TODO move stats server side
end

local function actionAngleRight(playerObj, boat)
    local sailAngle = boat:getModData()["sailAngle"]
    if sailAngle == nil then
        sailAngle = 0
        boat:getModData()["sailAngle"] = 0
    end
    if sailAngle > -90 then
        sailAngle = sailAngle - 6
        if sailAngle < -90 then sailAngle = -90 end
    end
    boat:getModData()["sailAngle"] = sailAngle
    playerObj:getStats():remove(CharacterStat.ENDURANCE, 0.01)--TODO move stats server side
end



Aquatsar = Aquatsar or {}

function Aquatsar.loadModConfig()
    local id = "Aquatsar"
    local options = PZAPI.ModOptions:create(id, getText("UI_Aquatsar_ModeOptionTitle"))
    Aquatsar.keyBindSailLeft  = options:addKeyBind("0" , getText("UI_optionscreen_binding_Aquatsar_SailLeft") , Keyboard.KEY_NONE, getText("UI_optionscreen_binding_Aquatsar_SailLeft_tooltip") )
    Aquatsar.keyBindSailRight = options:addKeyBind("1" , getText("UI_optionscreen_binding_Aquatsar_SailRight"), Keyboard.KEY_NONE, getText("UI_optionscreen_binding_Aquatsar_SailRight_tooltip"))
end

Aquatsar.loadModConfig()

function Aquatsar.getKeySailLeft()
    return Aquatsar.keyBindSailLeft:getValue()
end
function Aquatsar.getKeySailRight()
    return Aquatsar.keyBindSailRight:getValue()
end


function Aquatsar.getPlayerAndSailingBoat()
    local playerObj = getSpecificPlayer(0)
    local boat = playerObj and playerObj:getVehicle()
    if boat and AquaConfig.Boat(boat) and  boat:getDriver() == playerObj and boat:getPartById("Sails") then
        return playerObj, boat
    end
    return nil, nil
end

function Aquatsar.ModConfKeyPressed(keynum)
    if keynum == Aquatsar.getKeySailLeft() then
        local playerObj = nil
        local boat = nil
        playerObj, boat = Aquatsar.getPlayerAndSailingBoat()
        if playerObj and boat then 
            actionAngleLeft(playerObj, boat)
        end
    elseif keynum == Aquatsar.getKeySailRight() then
        local playerObj = nil
        local boat = nil
        playerObj, boat = Aquatsar.getPlayerAndSailingBoat()
        if playerObj and boat then 
            actionAngleRight(playerObj, boat)
        end
    end
end

Events.OnKeyPressed.Add(Aquatsar.ModConfKeyPressed);

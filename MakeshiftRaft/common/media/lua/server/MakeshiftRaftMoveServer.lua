
MakeshiftRaft = MakeshiftRaft or {}
--handles the server part of the client movement (not extrapolation for other clients)

local raftEnduranceTraitImpact = {}
raftEnduranceTraitImpact[CharacterTrait.UNFIT] = 1.2
raftEnduranceTraitImpact[CharacterTrait.ATHLETIC] = 0.8
raftEnduranceTraitImpact[CharacterTrait.OVERWEIGHT] = 1.1
raftEnduranceTraitImpact[CharacterTrait.OBESE] = 1.2

MakeshiftRaft.raftEnduranceTraitImpact = raftEnduranceTraitImpact

local raftEnduranceMoodleImpact = {}
raftEnduranceMoodleImpact[MoodleType.PANIC] = 0.2
raftEnduranceMoodleImpact[MoodleType.DRUNK] = 0.2
raftEnduranceMoodleImpact[MoodleType.TIRED] = 0.2
raftEnduranceMoodleImpact[MoodleType.PAIN] = 0.2

MakeshiftRaft.raftEnduranceMoodleImpact = raftEnduranceMoodleImpact

--    for trait,gain in pairs(raftEnduranceTraitImpact) do
--        if playerObj:hasTrait(trait) then coeff = coeff * gain end
--        --print ('MakeshiftRaft.raftDifficultCoeff trait '..tostring(trait:toString())..' gain='..tostring(gain))
--    end

function MakeshiftRaft.forceEquipRaft(playerObj, raft)
    MakeshiftRaft.setItemWeight(raft, 0.0)
    local action = ISWearClothing:new(playerObj, raft)--reuse ISWearClothing high level functions
    local completed = action and action:complete()--returns true, always
    if completed and ISInventoryPage then ISInventoryPage.renderDirty = true end--solo
    return completed
end

function MakeshiftRaft.forceUnequipRaft(playerObj, raft)
    local action = ISUnequipAction:new(playerObj, raft, 1)--reuse ISUnequipAction high level functions
    local completed = action and action:complete()--returns true, always
    if completed and ISInventoryPage then ISInventoryPage.renderDirty = true end--solo
    MakeshiftRaft.resetItemWeight(raft)
    return completed
end

function MakeshiftRaft.forceDropRaft(playerObj, raft)
    MakeshiftRaft.forceUnequipRaft(playerObj, raft)
    local itemSquare = playerObj:getSquare()-- player square
    if not itemSquare then return false end
    local itemOffsetX = playerObj:getX()-itemSquare:getX()-- player offset
    local itemOffsetY = playerObj:getY()-itemSquare:getY()-- player offset
    local itemOffsetZ = playerObj:getZ()-itemSquare:getZ()-- player offset
    local itemRotationZ = MakeshiftRaft.getReferenceAzimuthDeg(playerObj)-- player rotation
    if itemRotationZ < 0 then itemRotationZ = itemRotationZ + 360 end
    itemRotationZ = itemRotationZ - 90
    if itemRotationZ > 360 then itemRotationZ = itemRotationZ - 360 end
    if itemRotationZ < 0 then itemRotationZ = itemRotationZ + 360 end
    local action = ISDropWorldItemAction:new(playerObj, raft, itemSquare, itemOffsetX, itemOffsetY, itemOffsetZ, itemRotationZ, false)
    local completed = action and action:complete()--returns true, always
    if completed and ISInventoryPage then ISInventoryPage.renderDirty = true end--solo
    return completed
end

function MakeshiftRaft.MoveServer(playerObj)
    --TODO whatever to be done server side if on water, without a vehicle
    if MakeshiftRaft.isOnWater(playerObj) then
        --print('MakeshiftRaft.MoveServer on water')
        local raft = MakeshiftRaft.getEquippedRaft(playerObj) == nil and MakeshiftRaft.getAvailableRaft(playerObj)
        if raft then
            --force equip it
            MakeshiftRaft.forceEquipRaft(playerObj,raft)
            
            --print('MakeshiftRaft.MoveServer force equip raft: '..tostring(raft and raft:getFullType()))
            --apply some wetness depending on MakeshiftRaft.getBeaufort(windKph)
            --apply some damage depending on MakeshiftRaft.getBeaufort(windKph)
            --kill (sink and drawn) depending on MakeshiftRaft.getBeaufort(windKph)
        else
            --print('MakeshiftRaft.MoveServer on water no raft: '..tostring(raft and raft:getFullType()))
        end
    elseif playerObj and playerObj:getSquare() then --wait during load
        --not on water: force unequip raft items
        local equippedRaft = MakeshiftRaft.getEquippedRaft(playerObj)
        if equippedRaft then
            MakeshiftRaft.forceDropRaft(playerObj, equippedRaft)
            --print('MakeshiftRaft.MoveServer NOT on water force dropped raft: '..tostring(equippedRaft and equippedRaft:getFullType()))
        else
            --print('MakeshiftRaft.MoveServer NOT on water raft: '..tostring(equippedRaft and equippedRaft:getFullType()))
        end
    end
end

Events.OnPlayerMove.Add(MakeshiftRaft.MoveServer)
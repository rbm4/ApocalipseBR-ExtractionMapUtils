require 'AquaSwimShared'

local function compare(a,b)
    return a:getWeight() > b:getWeight()
end


function AquatsarYachts.Swim.dropItems(playerObj)
    local inv = playerObj:getInventory()    
    local items = {}

    for j=1, inv:getItems():size() do
        local item = inv:getItems():get(j-1);
        table.insert(items, item)
    end

    local dropNum = ZombRand(#items * 0.4)
    table.sort(items, compare)

    for i=1, dropNum do
        if not items[i]:isEquipped() then
            inv:DoRemoveItem(items[i])
        end
        if round(playerObj:getInventory():getCapacityWeight(), 2) < 10 then
            break
        end
    end
    
    if isServer() then
        sendServerCommand(playerObj, 'Swim', 'LostItems', nil)
    else
        if AquatsarYachts.Swim.LostItems then
            AquatsarYachts.Swim.LostItems(nil)
        end
    end
end


local swimEnduranceTraitImpact = {}
swimEnduranceTraitImpact[CharacterTrait.UNFIT] = 1.2
swimEnduranceTraitImpact[CharacterTrait.ATHLETIC] = 0.8
swimEnduranceTraitImpact[CharacterTrait.OVERWEIGHT] = 1.1
swimEnduranceTraitImpact[CharacterTrait.OBESE] = 1.2

AquatsarYachts.Swim.swimEnduranceTraitImpact = swimEnduranceTraitImpact

local swimEnduranceMoodleImpact = {}
swimEnduranceMoodleImpact[MoodleType.PANIC] = 0.2
swimEnduranceMoodleImpact[MoodleType.DRUNK] = 0.2
swimEnduranceMoodleImpact[MoodleType.TIRED] = 0.2
swimEnduranceMoodleImpact[MoodleType.PAIN] = 0.2

AquatsarYachts.Swim.swimEnduranceMoodleImpact = swimEnduranceMoodleImpact

function AquatsarYachts.Swim.swimDifficultCoeff(playerObj, haveLifeboy)
    local canSwim = playerObj:isRecipeKnown("Swimming")
    
    local coeff = 2.5--cannot swim endurance cost
    
    if haveLifeboy then--lifebuoy reduces endurance efficiency of swimmers but increases the one of non swimmers
        coeff = 1.75
    elseif canSwim then
        coeff = 1.0
    end

    local inv = playerObj:getInventory()
    local haveUnderWaterSight = inv and inv:getFirstEval(AquatsarYachts.EvalUnderWaterSight) ~= nil
    if haveUnderWaterSight then
        --print ('AquatsarYachts.Swim.swimDifficultCoeff haveUnderWaterSight '..tostring(haveUnderWaterSight))
        coeff = coeff * 0.9
    end

    local haveSwimGlasses = inv:getItemFromType("Glasses_SwimmingGoggles")--TODO apply UnderWaterSight
    if haveSwimGlasses and haveSwimGlasses:isEquipped() then--TODO remove
        --print ('AquatsarYachts.Swim.swimDifficultCoeff haveUnderWaterSight 2 '..tostring(haveSwimGlasses))
        coeff = coeff * 0.9
    end

    local haveSwimSuit = inv and inv:getFirstEval(AquatsarYachts.EvalSwimSuit) ~= nil
    if haveSwimSuit then
        --print ('AquatsarYachts.Swim.swimDifficultCoeff haveSwimSuit '..tostring(haveSwimSuit))
        coeff = coeff * 0.9
    end

    local equipWeight = round(playerObj:getInventory():getCapacityWeight(), 2)
    if equipWeight > 10 then
        coeff = coeff * (equipWeight/10)
        --print ('AquatsarYachts.Swim.swimDifficultCoeff equipWeight '..tostring(equipWeight)..' gain='..tostring(equipWeight/10))
    end
    
    for trait,gain in pairs(swimEnduranceTraitImpact) do
        if playerObj:hasTrait(trait) then coeff = coeff * gain end
        --print ('AquatsarYachts.Swim.swimDifficultCoeff trait '..tostring(trait:toString())..' gain='..tostring(gain))
    end
    
    local moodles = playerObj:getMoodles()
    for moodle,gain in pairs(swimEnduranceMoodleImpact) do
        coeff = coeff + gain * moodles:getMoodleLevel(moodle)
        --print ('AquatsarYachts.Swim.swimDifficultCoeff moodle '..tostring(moodle:toString())..' offset='..tostring(gain * moodles:getMoodleLevel(moodle)))
    end
    


    local Fitness = playerObj:getPerkLevel(Perks.Fitness)
    coeff = coeff * (1.5 - Fitness/10)
    --print ('AquatsarYachts.Swim.swimDifficultCoeff Fitness gain='..tostring((1.5 - Fitness/10)))
    --print('AquatsarYachts.Swim.swimDifficultCoeff coeff='..tostring(coeff))
    return coeff
end


local damagablePartTab={
BodyPartType.Torso_Upper,
BodyPartType.Torso_Lower,
BodyPartType.UpperLeg_L,
BodyPartType.UpperLeg_R,
BodyPartType.UpperArm_L,
BodyPartType.UpperArm_R
}

function AquatsarYachts.Swim.OnPlayerMove(playerObj)
    if not AquatsarYachts.Swim.isSwimming(playerObj) then return end
    
    --AquatsarYachts.EvalFloater(inventoryItem)
    local inv = playerObj:getInventory()
    local haveLifeboy = inv and inv:getFirstEval(AquatsarYachts.EvalFloater) ~= nil

    local coeff = AquatsarYachts.Swim.swimDifficultCoeff(playerObj, haveLifeboy)
    if playerObj:isAiming() then
        playerObj:getStats():remove(CharacterStat.ENDURANCE, 0.00002*coeff)
    else
        playerObj:getStats():remove(CharacterStat.ENDURANCE, 0.00020*coeff)
        playerObj:getXp():AddXP(Perks.Fitness, 0.05)
    end
    
    if not haveLifeboy then--get survivability with the lifebuoy
        local newEndurance = playerObj:getStats():get(CharacterStat.ENDURANCE)
        local eqWeight = round(inv:getCapacityWeight(), 2)
        local maxWeight = playerObj:getMaxWeight() * 0.9
        if eqWeight > 1.5 * maxWeight and ZombRand(100) < 20 and newEndurance < 0.3 then
            AquatsarYachts.Swim.dropItems(playerObj)
        elseif eqWeight > maxWeight and ZombRand(100) < 5 and newEndurance < 0.3 then
            AquatsarYachts.Swim.dropItems(playerObj)
        end
        if newEndurance < 0.05 then
            if ZombRand(100) < 5 then
                local bpIter = ZombRand(#damagablePartTab)+1
                local bodyPartId = damagablePartTab[bpIter]
                local bodyPart = playerObj:getBodyDamage():getBodyPart(bodyPartId)
                if bodyPart then
                    bodyPart:AddDamage(3)--if too network intensive, go 3% & 5damages or further
                    syncBodyPart(bodyPart, BodyPartSyncPacket.BD_Health);
                else
                    print('Error swimming does not find the body part '..tostring(bpIter)..' to damage '..tostring(bodyPartId))
                end
            end
        end
    end
end

Events.OnPlayerMove.Add(AquatsarYachts.Swim.OnPlayerMove)
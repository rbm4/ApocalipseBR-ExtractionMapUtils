require 'AquaTrueSwimmingCompat'

AquatsarYachts = AquatsarYachts or {}
AquatsarYachts.Swim = AquatsarYachts.Swim or {}

function AquatsarYachts.Swim.isWater(sq)
    local sobjs = sq and sq:getObjects()
    if not sobjs then return false end
    local hasWater = false
    for it=0, sobjs:size()-1 do
        local sobj = sobjs:get(it)
        local props = sobj and sobj:getProperties()
        if props:has(IsoFlagType.water) then
            hasWater = true
        elseif props:has(IsoFlagType.solidfloor) then--solid floor other than water (e.g. B42.13.2 X: 3591, Y: 9891)
            return false
        end
    end
    
    return hasWater
end

function AquatsarYachts.Swim.isSwimming(playerObj)
    if not playerObj or playerObj:getVehicle() then return false end
    return AquatsarYachts.Swim.isWater(playerObj:getSquare())
end

function AquatsarYachts.EvalFloater(inventoryItem)
    --print('AquatsarYachts.EvalFloater '..tostring(inventoryItem)..' '..tostring(inventoryItem and inventoryItem:hasTag(Aquatsar.TAG_Floater))..' '..tostring(inventoryItem and inventoryItem:isEquipped()))
    return inventoryItem and inventoryItem:hasTag(Aquatsar.TAG_Floater) and inventoryItem:isEquipped()
end
function AquatsarYachts.EvalUnderWaterSight(inventoryItem)
    --print('AquatsarYachts.EvalFloater '..tostring(inventoryItem)..' '..tostring(inventoryItem and inventoryItem:hasTag(Aquatsar.TAG_UnderWaterSight))..' '..tostring(inventoryItem and inventoryItem:isEquipped()))
    return inventoryItem and inventoryItem:hasTag(Aquatsar.TAG_UnderWaterSight) and inventoryItem:isEquipped()
end
function AquatsarYachts.EvalSwimSuit(inventoryItem)
    --print('AquatsarYachts.EvalFloater '..tostring(inventoryItem)..' '..tostring(inventoryItem and inventoryItem:hasTag(Aquatsar.TAG_SwimSuit))..' '..tostring(inventoryItem and inventoryItem:isEquipped()))
    return inventoryItem and inventoryItem:hasTag(Aquatsar.TAG_SwimSuit) and inventoryItem:isEquipped()
end


local function addTagToItemList(itemList, tag)
    if not itemList or not tag then return end
    for iterItem=1, #itemList do
        local itemName = itemList[iterItem]
        local item = getScriptManager():getItem(itemName)
        if item then
            if not item:hasTag(tag) then
                local arrTags = item:getTags()
                arrTags:add(tag)
            else
                print("Warning "..itemName.." has already the tag "..tag:toString())
            end
        else
            print("Warning Missing item "..itemName.." cannot add the tag "..tag:toString())
        end
    end
end
AquatsarYachts.Swim.vanillaFloaterItems = {}
AquatsarYachts.Swim.vanillaUnderWaterSightItems = {"Glasses_SwimmingGoggles"}
AquatsarYachts.Swim.vanillaSwimSuitItems = {
"SwimTrunks_Yellow",
"SwimTrunks_Red",
"SwimTrunks_Blue",
"SwimTrunks_Green",
"Swimsuit_TINT"
}

function AquatsarYachts.Swim.addTagToItems()
    addTagToItemList(AquatsarYachts.Swim.vanillaFloaterItems, Aquatsar.TAG_Floater)
    addTagToItemList(AquatsarYachts.Swim.vanillaUnderWaterSightItems, Aquatsar.TAG_UnderWaterSight)
    addTagToItemList(AquatsarYachts.Swim.vanillaSwimSuitItems, Aquatsar.TAG_SwimSuit)
    --print('added tags to vanilla items')
end

Events.OnLoad.Add(AquatsarYachts.Swim.addTagToItems)

function AquatsarYachts.Swim.wetItems(playerObj)--TODO move this server side AquaSwimServer / AquatsarYachts.Swim.OnPlayerMove(
    local inv = playerObj:getInventory() -- inv = getPlayer():getInventory()    
    local items = {}

    for j=1, inv:getItems():size() do
        local item = inv:getItems():get(j-1);
        table.insert(items, item)
    end

    for i=1, #items do
        local soakedItem = items[i]
        if soakedItem:IsClothing() then
            soakedItem:setWetness(100)
            soakedItem:syncItemFields()
        elseif soakedItem:IsLiterature() then
            inv:DoRemoveItem(soakedItem)
            sendRemoveItemFromContainer(inv,soakedItem)
            local item = instanceItem("Aquatsar.TaintedLiterature");
            inv:AddItem(item)
            sendAddItemToContainer(inv, item);
        elseif soakedItem:IsDrainable() then
            local onDeplete = soakedItem:getReplaceOnDeplete()
            if onDeplete then
                local itemType = soakedItem:getFullType()
                --print("AquatsarYachts.Swim.wetItems "..itemType.."Wet =? "..onDeplete)
                if onDeplete == itemType.."Wet" then
                    local soakedType = soakedItem:getReplaceOnDepleteFullType()
                    --print("AquatsarYachts.Swim.wetItems 2 "..soakedType.." =? "..onDeplete)
                    inv:DoRemoveItem(soakedItem)
                    sendRemoveItemFromContainer(inv,soakedItem)
                    local item = instanceItem(onDeplete);
                    inv:AddItem(item)
                    sendAddItemToContainer(inv, item);
                end
            end
        end
    end
end
MakeshiftRaft = MakeshiftRaft or {}
MakeshiftRaft.Verbose = false
MakeshiftRaft.anchorKey = 'MRAnchor'


function MakeshiftRaft.convertWindAngleClimateToEastRef(windAngle)
    if windAngle > 180 then windAngle = windAngle - 360 end
    if windAngle < 180 then windAngle = windAngle + 360 end
    windAngle = windAngle+45--see Climate Change: 0 is center of SE zone, 45 is center of S zone...
    if windAngle > 180 then windAngle = windAngle - 360 end
    return windAngle
end

function MakeshiftRaft.getReferenceAzimuthRd(playerObj)
    --return playerObj:getDirectionAngleRadians()--1
    --return playerObj:getAnimAngleRadians()--2
    return playerObj:getLookAngleRadians()--3
end
function MakeshiftRaft.getReferenceAzimuthDeg(playerObj)
    --return playerObj:getDirectionAngle()--1/ 0 means East, 90 means south. sight azimuth (precise but not ok for body animations)
    --return playerObj:getAnimAngle()--2/ 0 means East, 90 means south. body azimuth (not precise)
    return playerObj:getLookAngleRadians()*57.2958 --3
end

function MakeshiftRaft.isWaterSquare(square)
    return square and square:has(IsoFlagType.water)
end
function MakeshiftRaft.isOnWater(playerObj)
    return playerObj and not playerObj:getVehicle() and MakeshiftRaft.isWaterSquare(playerObj:getSquare())
end

function MakeshiftRaft.EvalRaft(inventoryItem)
    return inventoryItem and inventoryItem:hasTag(MakeshiftRaft.TAG_Raft)
end

function MakeshiftRaft.EvalEquippedRaft(inventoryItem)
    return MakeshiftRaft.EvalRaft(inventoryItem) and inventoryItem:isEquipped()
end

function MakeshiftRaft.EvalUnequippedRaft(inventoryItem)
    return MakeshiftRaft.EvalRaft(inventoryItem) and not inventoryItem:isEquipped()
end

function MakeshiftRaft.getAvailableRaft(playerObj)
    local inv = playerObj and playerObj:getInventory()
    return inv and inv:getFirstEval(MakeshiftRaft.EvalRaft)
end
function MakeshiftRaft.isRaftAvailable(playerObj)
    return MakeshiftRaft.getAvailableRaft(playerObj) ~= nil
end

function MakeshiftRaft.getEquippedRaft(playerObj)
    local inv = playerObj and playerObj:getInventory()
    return inv and inv:getFirstEval(MakeshiftRaft.EvalEquippedRaft)
end

function addTagToItemList(itemList, tag)
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

MakeshiftRaft.vanillaTAG_Raft = {
--"SwimTrunks_Yellow",
}

function MakeshiftRaft.addTagToItems()
    addTagToItemList(MakeshiftRaft.vanillaTAG_Raft, MakeshiftRaft.TAG_Raft)
    --print('added tags to vanilla items')
end

Events.OnLoad.Add(MakeshiftRaft.addTagToItems)


function MakeshiftRaft.getBeaufort(windKph)--Wind.java B42.13.1
    if (windKph < 4.0F) then
        return 0;
    elseif (windKph < 9.0F) then
        return 1;
    elseif (windKph < 16.0F) then
        return 2;
    elseif (windKph < 23.0F) then
        return 3;
    elseif (windKph < 31.0F) then
        return 4;
    elseif (windKph < 40.0F) then
        return 5;
    elseif (windKph < 50.0F) then
        return 6;
    elseif (windKph < 60.0F) then
        return 7;
    elseif (windKph < 72.0F) then
        return 8;
    elseif (windKph < 84.0F) then
        return 9;
    elseif (windKph < 97.0F) then
        return 10;
    end
    return 11;
end

function MakeshiftRaft.setItemWeight(item, weight)
    local md = item:getModData()
    if md then
        md.makeshiftRaftWeight = item:getWeight();
        md.makeshiftRaftActualWeight = item:getActualWeight();
    end
    item:setActualWeight(weight);
    item:setWeight(weight);
    item:setCustomWeight(true);
    item:syncItemFields()
end
function MakeshiftRaft.resetItemWeight(item)
    local md = item:getModData()
    if md and md.makeshiftRaftWeight then
        item:setWeight(md.makeshiftRaftWeight);
        item:setActualWeight(md.makeshiftRaftActualWeight);
        item:setCustomWeight(false);
        --TODO update item to clients
        item:syncItemFields()
    end
end

--anchor
function MakeshiftRaft.isAnchorDown(character)
    local md = character and character:getModData()
    return md and md[MakeshiftRaft.anchorKey] == true
end

function MakeshiftRaft.setAnchorState(character,isDown)
    local md = character and character:getModData()
    if md then md[MakeshiftRaft.anchorKey] = isDown or nil end
end



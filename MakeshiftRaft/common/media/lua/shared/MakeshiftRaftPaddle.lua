MakeshiftRaft = MakeshiftRaft or {}



function MakeshiftRaft.getPaddleGain(playerObj)
    local gain = 0
    if playerObj then
        local item = playerObj:getPrimaryHandItem()
        if item then
            if item:hasTag(MakeshiftRaft.TAG_Paddle) then
                gain = gain + 0.5
            elseif item:hasTag(MakeshiftRaft.TAG_PaddleWeak) then
                gain = gain + 0.25
            end
       end
        item = playerObj:getSecondaryHandItem()
        if item then
            if item:hasTag(MakeshiftRaft.TAG_Paddle) then
                gain = gain + 0.5
            elseif item:hasTag(MakeshiftRaft.TAG_PaddleWeak) then
                gain = gain + 0.25
            end
       end
    end
    return gain
end


---------------------- INIT -----------------
MakeshiftRaft.itemsPaddleTag = {
"CanoePadelX2",
"CanoePadel",
"SpadeForged",
"SpadeWood",
}
MakeshiftRaft.itemsPaddleWeakTag = {
"CanoePadelX2_Broken",
"ScrapWeaponSpade",
"Cudgel_SpadeHead",
"Shovel",
"Shovel2",
"SnowShovel",
}


function MakeshiftRaft.addTagToItemList(itemList, tag)
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

function MakeshiftRaft.addTagToItems()
    MakeshiftRaft.addTagToItemList(MakeshiftRaft.itemsPaddleTag, MakeshiftRaft.TAG_Paddle)
    MakeshiftRaft.addTagToItemList(MakeshiftRaft.itemsPaddleWeakTag, MakeshiftRaft.TAG_PaddleWeak)
    --print('added tags to vanilla items')
end

Events.OnLoad.Add(MakeshiftRaft.addTagToItems)

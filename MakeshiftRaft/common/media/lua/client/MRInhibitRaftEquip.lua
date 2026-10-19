

--make the action not work (especially for double click. ISInventoryPane:onMouseDoubleClick)
local isValidUpperLayer = ISWearClothing and ISWearClothing.isValid
function ISWearClothing:isValid()
    local isValid = isValidUpperLayer(self)
    if isValid and not isServer() and MakeshiftRaft.EvalRaft(self.item) then
        return false
    end
    return isValid
end

--make the option not available in menu
local doWearClothingMenuUpperLayer =  ISInventoryPaneContextMenu.doWearClothingMenu
ISInventoryPaneContextMenu.doWearClothingMenu = function(player, clothing, items, context)
    --remove raft and call upper layer only if items not empty
    local newItems = {}
    local changed = false
    for i,v in ipairs(items) do
        local testItem = v;
        if not instanceof(v, "InventoryItem") then
            testItem = v.items[1];
        end
        if MakeshiftRaft.EvalRaft(testItem) then
            changed = true
        else
            newItems[#newItems+1] = v
        end
    end
    if changed then items = newItems end
    
    if #items > 0 then
        return doWearClothingMenuUpperLayer(player, clothing, items, context)
    else
        return nil
    end
end

local doClothingItemExtraMenuUpperLayer =  ISInventoryPaneContextMenu.doClothingItemExtraMenu
ISInventoryPaneContextMenu.doClothingItemExtraMenu = function(context, clothingItemExtra, playerObj)
    if not MakeshiftRaft.EvalRaft(clothingItemExtra) then
        return doClothingItemExtraMenuUpperLayer(context, clothingItemExtra, playerObj)
    end
    return nil
end

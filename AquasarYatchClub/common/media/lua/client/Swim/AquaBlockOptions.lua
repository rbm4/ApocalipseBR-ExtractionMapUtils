require "CommonTemplates/ISUI/ISContextMenuExtension" 

local function blockOptions(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    if AquatsarYachts.Swim.isSwimming(playerObj) then
        context:removeOptionTsar(context:getOptionFromName(getText("ContextMenu_Fishing")))
        context:removeOptionTsar(context:getOptionFromName(getText("ContextMenu_Build")))
        context:removeOptionTsar(context:getOptionFromName(getText("ContextMenu_SitGround")))
        context:removeOptionTsar(context:getOptionFromName(getText("ContextMenu_Walk_to")))
        context:removeOptionTsar(context:getOptionFromName(getText("ContextMenu_Wash")))
        context:removeOptionTsar(context:getOptionFromName(getText("ContextMenu_SleepOnGround")))
        local heavyItem = playerObj:getPrimaryHandItem()
        if isForceDropHeavyItem(heavyItem) then
            context:removeOptionTsar(context:getOptionFromName(getText("ContextMenu_DropNamedItem", heavyItem:getDisplayName())))
        end
    end
end


Events.OnFillWorldObjectContextMenu.Add(blockOptions)
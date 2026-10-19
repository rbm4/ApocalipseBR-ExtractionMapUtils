require "CustomWater/CustomWater_ConfigAndUtils"
require "TimedActions/ISTakeWaterAction"

-- =========================================================
-- FILL HOOK — inject SeaWater for natural water sources
-- =========================================================

local vanilla_transferFluid = ISTakeWaterAction.transferFluid

function ISTakeWaterAction:transferFluid(_amount)
    if self.waterObject and CustomWater.shouldIntercept(self.waterObject) and self.item then
        if _amount <= 0 then return end

        local fc = self.item:getFluidContainer()
        if not fc then return end

        local added = CustomWater.addCustomWaterToContainer(fc, _amount)

        if added > 0 then
            if self.item.syncItemFields then
                pcall(function() self.item:syncItemFields() end)
            end
            if sendItemStats then
                pcall(function() sendItemStats(self.item) end)
            end
        end

        return
    end

    return vanilla_transferFluid(self, _amount)
end

-- =========================================================
-- START HOOK — show SeaWater name in the job UI
-- =========================================================

local vanilla_start = ISTakeWaterAction.start

function ISTakeWaterAction:start()
    if self.waterObject and CustomWater.shouldIntercept(self.waterObject) and self.item then
        self.item:setBeingFilled(true)
        self.item:setJobType(getText("ContextMenu_Fill") .. " " .. CustomWater.getDisplayName())
        self.item:setJobDelta(0.0)

        self.sound = self.character:playSound(self.item:getFillFromLakeSound() or "GetWaterFromLake")
        self:setAnimVariable("PourType", self.item:getPourType())
        self:setActionAnim("fill_container_tap")

        if self.character:isSecondaryHandItem(nil) then
            self:setOverrideHandModels(nil, self.item:getStaticModel())
        else
            self:setOverrideHandModels(self.item:getStaticModel(), nil)
        end

        self.character:reportEvent("EventTakeWater")
        return
    end

    return vanilla_start(self)
end

-- =========================================================
-- DRINK BLOCK — prevent drinking directly from natural water
-- (would give vanilla Water, not SeaWater)
-- =========================================================

local vanilla_onDrink = ISWorldObjectContextMenu.onDrink

function ISWorldObjectContextMenu.onDrink(worldobjects, waterObject, player)
    if waterObject and CustomWater.shouldIntercept(waterObject) then
        return
    end

    return vanilla_onDrink(worldobjects, waterObject, player)
end

-- =========================================================
-- MENU PATCH — rename natural water source, block drink
-- =========================================================

local function renameContextOption(option, newName)
    if not option then return end
    option.name  = newName
    option.text  = newName
    option.label = newName
    if option.setName then
        pcall(function() option:setName(newName) end)
    end
end

local function optionText(option)
    if not option then return "" end
    return tostring(option.name or option.text or option.label or "")
end

local function addBlockedDrinkTooltip(option)
    if not option then return end
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description  = "<RGB:1,0.2,0.2> " .. CustomWater.getDrinkBlockedTooltip()
    tooltip.maxLineWidth = 512
    option.toolTip       = tooltip
end

local function patchSubMenuOptions(subMenu)
    if not subMenu or not subMenu.options then return end
    for i = 1, #subMenu.options do
        local option = subMenu.options[i]
        local txt    = optionText(option)
        if txt == getText("ContextMenu_Drink") then
            option.notAvailable = true
            addBlockedDrinkTooltip(option)
        elseif txt == getText("ContextMenu_Fill") then
            option.toolTip = nil
        end
    end
end

local function patchContextMenu(player, context, worldobjects, test)
    local waterSource = CustomWater.findInterceptableWaterSource(worldobjects)
    if not waterSource then return end
    if test then return true end

    if not context or not context.options then return end

    for i = 1, #context.options do
        local option = context.options[i]
        local txt    = optionText(option)

        if txt == getText("ContextMenu_NaturalWaterSource") then
            renameContextOption(option, CustomWater.getDisplayName())
            option.toolTip = nil
            if option.subOption then patchSubMenuOptions(option.subOption) end
            if option.subMenu  then patchSubMenuOptions(option.subMenu)  end

        elseif txt == getText("ContextMenu_Drink") then
            renameContextOption(option, CustomWater.getDisplayName() .. " / " .. getText("ContextMenu_Drink"))
            option.notAvailable = true
            addBlockedDrinkTooltip(option)

        elseif txt == getText("ContextMenu_Fill") then
            renameContextOption(option, CustomWater.getDisplayName() .. " / " .. getText("ContextMenu_Fill"))
            option.toolTip = nil
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(patchContextMenu)
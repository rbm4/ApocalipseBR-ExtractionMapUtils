CustomWater = CustomWater or {}

-- =========================================================
-- CONFIGURATION
-- =========================================================

CustomWater.FLUID_FULL_TYPE  = "Base.SeaWater"
CustomWater.FLUID_SHORT_TYPE = "SeaWater"

CustomWater.DISPLAY_NAME_KEY           = "Fluid_Name_SeaWater"
CustomWater.DRINK_BLOCKED_TOOLTIP_KEY  = "Tooltip_SeaWater_DrinkBlocked"

CustomWater.DEBUG = false

-- =========================================================
-- WELL TILE SPRITES — tiles whose water should stay vanilla
-- =========================================================
-- Add more with CustomWater.AddWellSprite("sprite_name")

CustomWater.WELL_SPRITES = CustomWater.WELL_SPRITES or {}

--- Register a well tile sprite name.
--- @param spriteName string  e.g. "camping_01_16"
function CustomWater.AddWellSprite(spriteName)
    if spriteName then
        CustomWater.WELL_SPRITES[spriteName] = true
    end
end

-- Default well tiles
CustomWater.AddWellSprite("camping_01_16")
CustomWater.AddWellSprite("camping_01_64")
CustomWater.AddWellSprite("camping_01_65")
CustomWater.AddWellSprite("camping_01_66")
CustomWater.AddWellSprite("camping_01_67")
CustomWater.AddWellSprite("crafted_01_24")
CustomWater.AddWellSprite("crafted_01_25")
CustomWater.AddWellSprite("crafted_01_28")
CustomWater.AddWellSprite("crafted_01_29")
CustomWater.AddWellSprite("crafted_02_80")
CustomWater.AddWellSprite("crafted_02_81")
CustomWater.AddWellSprite("crafted_02_82")
CustomWater.AddWellSprite("crafted_02_83")
CustomWater.AddWellSprite("crafted_02_84")
CustomWater.AddWellSprite("carpentry_02_52")
CustomWater.AddWellSprite("carpentry_02_53")
CustomWater.AddWellSprite("carpentry_02_54")
CustomWater.AddWellSprite("carpentry_02_55")
CustomWater.AddWellSprite("carpentry_02_120")
CustomWater.AddWellSprite("carpentry_02_121")
CustomWater.AddWellSprite("carpentry_02_122")
CustomWater.AddWellSprite("carpentry_02_123")
CustomWater.AddWellSprite("carpentry_02_124")
CustomWater.AddWellSprite("carpentry_02_125")
CustomWater.AddWellSprite("carpentry_02_126")
CustomWater.AddWellSprite("carpentry_02_127")
CustomWater.AddWellSprite("fixtures_bathroom_01_0")
CustomWater.AddWellSprite("fixtures_bathroom_01_1")
CustomWater.AddWellSprite("fixtures_bathroom_01_2")
CustomWater.AddWellSprite("fixtures_bathroom_01_3")
CustomWater.AddWellSprite("fixtures_bathroom_01_4")
CustomWater.AddWellSprite("fixtures_bathroom_01_5")
CustomWater.AddWellSprite("fixtures_bathroom_01_6")
CustomWater.AddWellSprite("fixtures_bathroom_01_7")
CustomWater.AddWellSprite("fixtures_bathroom_01_8")
CustomWater.AddWellSprite("fixtures_bathroom_01_9")
CustomWater.AddWellSprite("fixtures_bathroom_01_10")
CustomWater.AddWellSprite("fixtures_bathroom_01_11")
CustomWater.AddWellSprite("fixtures_bathroom_01_24")
CustomWater.AddWellSprite("fixtures_bathroom_01_25")
CustomWater.AddWellSprite("fixtures_bathroom_01_26")
CustomWater.AddWellSprite("fixtures_bathroom_01_27")
CustomWater.AddWellSprite("fixtures_bathroom_01_32")
CustomWater.AddWellSprite("fixtures_bathroom_01_33")
CustomWater.AddWellSprite("fixtures_bathroom_01_52")
CustomWater.AddWellSprite("fixtures_bathroom_01_53")
CustomWater.AddWellSprite("fixtures_bathroom_01_54")
CustomWater.AddWellSprite("fixtures_bathroom_01_55")
CustomWater.AddWellSprite("fixtures_sinks_01_0")
CustomWater.AddWellSprite("fixtures_sinks_01_1")
CustomWater.AddWellSprite("fixtures_sinks_01_2")
CustomWater.AddWellSprite("fixtures_sinks_01_3")
CustomWater.AddWellSprite("fixtures_sinks_01_4")
CustomWater.AddWellSprite("fixtures_sinks_01_5")
CustomWater.AddWellSprite("fixtures_sinks_01_6")
CustomWater.AddWellSprite("fixtures_sinks_01_7")
CustomWater.AddWellSprite("fixtures_sinks_01_8")
CustomWater.AddWellSprite("fixtures_sinks_01_9")
CustomWater.AddWellSprite("fixtures_sinks_01_10")
CustomWater.AddWellSprite("fixtures_sinks_01_11")
CustomWater.AddWellSprite("fixtures_sinks_01_12")
CustomWater.AddWellSprite("fixtures_sinks_01_13")
CustomWater.AddWellSprite("fixtures_sinks_01_14")
CustomWater.AddWellSprite("fixtures_sinks_01_15")
CustomWater.AddWellSprite("fixtures_sinks_01_16")
CustomWater.AddWellSprite("fixtures_sinks_01_17")
CustomWater.AddWellSprite("fixtures_sinks_01_18")
CustomWater.AddWellSprite("fixtures_sinks_01_19")
CustomWater.AddWellSprite("fixtures_sinks_01_20")
CustomWater.AddWellSprite("fixtures_sinks_01_21")
CustomWater.AddWellSprite("fixtures_sinks_01_22")
CustomWater.AddWellSprite("fixtures_sinks_01_23")
CustomWater.AddWellSprite("fixtures_sinks_01_24")
CustomWater.AddWellSprite("fixtures_sinks_01_25")
CustomWater.AddWellSprite("fixtures_sinks_01_28")
CustomWater.AddWellSprite("fixtures_sinks_01_29")
CustomWater.AddWellSprite("fixtures_sinks_01_30")
CustomWater.AddWellSprite("fixtures_sinks_01_31")
CustomWater.AddWellSprite("fixtures_sinks_01_32")
CustomWater.AddWellSprite("fixtures_sinks_01_33")
CustomWater.AddWellSprite("fixtures_sinks_01_34")
CustomWater.AddWellSprite("fixtures_sinks_01_35")
CustomWater.AddWellSprite("location_business_office_generic_01_48")
CustomWater.AddWellSprite("location_business_office_generic_01_49")
CustomWater.AddWellSprite("location_business_office_generic_01_56")
CustomWater.AddWellSprite("location_business_office_generic_01_57")
CustomWater.AddWellSprite("location_business_office_generic_01_58")
CustomWater.AddWellSprite("location_business_office_generic_01_59")
CustomWater.AddWellSprite("location_business_office_generic_01_60")
CustomWater.AddWellSprite("location_business_office_generic_01_61")
CustomWater.AddWellSprite("street_decoration_01_12")
CustomWater.AddWellSprite("location_restaurant_bar_0")
CustomWater.AddWellSprite("location_restaurant_bar_0")
CustomWater.AddWellSprite("location_restaurant_bar_0")
CustomWater.AddWellSprite("location_restaurant_bar_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")
CustomWater.AddWellSprite("location_community_park_0")

-- =========================================================
-- EXCLUSION ZONES — MASTER LIST
-- =========================================================
-- Rectangles in world-tile coordinates where natural water
-- reverts to vanilla (fresh water).  Everywhere else,
-- natural water gives SeaWater.
--
-- Populated at load time by zone files calling AddExclusionZone().
-- Zone files just: require the config, then call the function.

CustomWater.EXCLUSION_ZONES = CustomWater.EXCLUSION_ZONES or {}

--- Register one exclusion zone.
--- @param x1 number  world-tile X corner 1
--- @param y1 number  world-tile Y corner 1
--- @param x2 number  world-tile X corner 2
--- @param y2 number  world-tile Y corner 2
--- @param z  number  floor level (default 0)
function CustomWater.AddExclusionZone(x1, y1, x2, y2, z)
    table.insert(CustomWater.EXCLUSION_ZONES, {
        x1 = math.min(x1, x2),
        y1 = math.min(y1, y2),
        x2 = math.max(x1, x2),
        y2 = math.max(y1, y2),
        z  = z or 0,
    })
end

-- =========================================================
-- DEBUG
-- =========================================================

function CustomWater.debug(msg)
    if CustomWater.DEBUG then
        print("[CustomWater] " .. tostring(msg))
    end
end

-- =========================================================
-- DISPLAY
-- =========================================================

function CustomWater.getDisplayName()
    return getText(CustomWater.DISPLAY_NAME_KEY)
end

function CustomWater.getDrinkBlockedTooltip()
    return getText(CustomWater.DRINK_BLOCKED_TOOLTIP_KEY)
end

-- =========================================================
-- WELL TILE DETECTION
-- =========================================================

--- Does this object have a well tile sprite?
--- @param obj IsoObject
--- @return boolean
function CustomWater.isWellTile(obj)
    if not obj then return false end

    local ok, sprite = pcall(function() return obj:getSprite() end)
    if not ok or not sprite then return false end

    local ok2, name = pcall(function() return sprite:getName() end)
    if not ok2 or not name then return false end

    if CustomWater.WELL_SPRITES[name] then
        CustomWater.debug("Well tile detected: " .. tostring(name))
        return true
    end

    return false
end

--- Does this square contain any well tile?
--- @param square IsoGridSquare
--- @return IsoObject or nil  the first well object found
function CustomWater.hasWellTile(square)
    if not square then return nil end

    local ok, objects = pcall(function() return square:getObjects() end)
    if not ok or not objects then return nil end

    local size = objects:size()
    for i = 0, size - 1 do
        local obj = objects:get(i)
        if CustomWater.isWellTile(obj) then
            return obj
        end
    end

    return nil
end

-- =========================================================
-- ZONE CHECK
-- =========================================================

--- Is world position inside any exclusion zone?
--- @param x number  IsoGridSquare:getX()
--- @param y number  IsoGridSquare:getY()
--- @param z number  IsoGridSquare:getZ() (default 0)
--- @return boolean
function CustomWater.isInExclusionZone(x, y, z)
    if not x or not y then return false end
    z = z or 0

    local zones = CustomWater.EXCLUSION_ZONES
    if not zones or #zones == 0 then return false end

    for i = 1, #zones do
        local zone = zones[i]
        if zone
            and x >= zone.x1 and x <= zone.x2
            and y >= zone.y1 and y <= zone.y2
            and z == zone.z then

            CustomWater.debug(string.format(
                "Zone hit: (%d,%d,%d) in [%d-%d,%d-%d,z=%d]",
                x, y, z, zone.x1, zone.x2, zone.y1, zone.y2, zone.z
            ))
            return true
        end
    end

    return false
end

-- =========================================================
-- SOURCE IDENTIFICATION
-- =========================================================

--- Is this water object a natural water tile (not an InventoryItem)?
--- InventoryItems = sinks, rain collectors, water dispensers, wells-as-items.
--- Non-InventoryItem IsoObjects = lakes, rivers, natural water tiles.
--- @param obj IsoObject|InventoryItem
--- @return boolean
function CustomWater.isNaturalWaterSource(obj)
    if not obj then return false end

    -- Primary check: InventoryItem → item-based source → not natural
    local ok, isItem = pcall(function() return instanceof(obj, "InventoryItem") end)
    if ok and isItem then
        return false
    end

    -- Secondary safety: InventoryItems expose getItemType()
    -- If present and callable, treat as item-based
    if obj.getItemType then
        local ok2, result = pcall(function() return obj:getItemType() end)
        if ok2 and result then
            return false
        end
    end

    return true
end

--- Should we intercept this water object and inject SeaWater?
--- True when: natural water source AND not a well tile AND
--- square has no well tile AND not inside an exclusion zone.
--- @param waterObject IsoObject|InventoryItem
--- @return boolean
function CustomWater.shouldIntercept(waterObject)
    if not CustomWater.isNaturalWaterSource(waterObject) then
        return false
    end

    -- Direct check: is the water object itself a well tile?
    if CustomWater.isWellTile(waterObject) then
        CustomWater.debug("Water object is a well tile — vanilla")
        return false
    end

    -- Natural source — check square for wells and exclusion zones
    local square = nil
    if waterObject.getSquare then
        local ok, sq = pcall(function() return waterObject:getSquare() end)
        if ok then square = sq end
    end

    if square then
        -- Check if the square contains a well tile (handles cases where
        -- the water object and well tile are separate objects on the same square)
        if CustomWater.hasWellTile(square) then
            CustomWater.debug("Square contains a well tile — vanilla")
            return false
        end

        -- Check exclusion zones
        local ok2, wx, wy, wz = pcall(function()
            return square:getX(), square:getY(), square:getZ()
        end)
        if ok2 and wx and wy then
            wz = wz or 0
            if CustomWater.isInExclusionZone(wx, wy, wz) then
                CustomWater.debug(string.format(
                    "Natural water at (%d,%d,%d) is in exclusion zone — vanilla",
                    wx, wy, wz
                ))
                return false
            end
        end
    end

    return true
end

--- Find the first interceptable natural water source in a list.
--- @param worldobjects table
--- @return IsoObject or nil
function CustomWater.findInterceptableWaterSource(worldobjects)
    if not worldobjects then return nil end

    for i = 1, #worldobjects do
        if CustomWater.shouldIntercept(worldobjects[i]) then
            return worldobjects[i]
        end
    end

    for _, obj in ipairs(worldobjects) do
        if CustomWater.shouldIntercept(obj) then
            return obj
        end
    end

    return nil
end

-- =========================================================
-- FLUID HELPERS
-- =========================================================

function CustomWater.getCustomFluid()
    if not Fluid or not Fluid.Get then return nil end

    local ok, fluid = pcall(function() return Fluid.Get(CustomWater.FLUID_FULL_TYPE) end)
    if ok and fluid then return fluid end

    ok, fluid = pcall(function() return Fluid.Get(CustomWater.FLUID_SHORT_TYPE) end)
    if ok and fluid then return fluid end

    return nil
end

function CustomWater.getFreeCapacity(fc)
    if not fc then return 0 end

    if fc.getFreeCapacity then
        local ok, value = pcall(function() return fc:getFreeCapacity() end)
        if ok and value then return value end
    end

    if fc.getCapacity and fc.getAmount then
        local ok, value = pcall(function() return fc:getCapacity() - fc:getAmount() end)
        if ok and value then return value end
    end

    return 0
end

function CustomWater.addCustomWaterToContainer(fc, amount)
    if not fc then return 0 end

    local fluid = CustomWater.getCustomFluid()
    if not fluid then
        CustomWater.debug("Could not resolve fluid: " .. tostring(CustomWater.FLUID_FULL_TYPE))
        return 0
    end

    local free   = CustomWater.getFreeCapacity(fc)
    local toAdd  = math.max(0, math.min(amount or free, free))
    if toAdd <= 0 then return 0 end

    if fc.addFluid then
        local ok = pcall(function() fc:addFluid(fluid, toAdd) end)
        if ok then return toAdd end

        ok = pcall(function() fc:addFluid(CustomWater.FLUID_FULL_TYPE, toAdd) end)
        if ok then return toAdd end

        ok = pcall(function() fc:addFluid(CustomWater.FLUID_SHORT_TYPE, toAdd) end)
        if ok then return toAdd end
    end

    return 0
end
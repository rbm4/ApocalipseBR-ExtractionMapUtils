require "Items/Distribution_BagsAndContainers.lua"
require "Items/Distribution_BinJunk.lua"
require "Items/Distribution_ClosetJunk.lua"
require "Items/Distribution_CounterJunk.lua"
require "Items/Distribution_DeskJunk.lua"
require "Items/Distribution_ShelfJunk.lua"
require "Items/Distribution_SideTableJunk.lua"
require "Vehicles/VehicleDistribution_GloveBoxJunk.lua"
require "Vehicles/VehicleDistribution_SeatJunk.lua"
require "VehicleDistribution_TrunkJunk.lua"
require "Vehicles/VehicleDistributions.lua"

local removedItems = {
    ["Base.RiversideMap"]   = true,
    ["Base.RosewoodMap"]    = true,
    ["Base.WestpointMap"]   = true,
    ["Base.MarchRidgeMap"]  = true,
    ["Base.MuldraughMap"]   = true,
    ["Base.LouisvilleMap1"] = true,
    ["Base.LouisvilleMap2"] = true,
    ["Base.LouisvilleMap3"] = true,
    ["Base.LouisvilleMap4"] = true,
    ["Base.LouisvilleMap5"] = true,
    ["Base.LouisvilleMap6"] = true,
    ["Base.LouisvilleMap7"] = true,
    ["Base.LouisvilleMap8"] = true,
    ["Base.LouisvilleMap9"] = true
}

local function removeLoot(zone)
    if not zone or not zone.items then return end
    
    -- Traverse backwards stepping by 2 to align with item ID slots (odd indices)
    for i = #zone.items - 1, 1, -2 do
        local item = zone.items[i]
        if type(item) == "string" and removedItems[item] then
            table.remove(zone.items, i + 1) -- Remove weight
            table.remove(zone.items, i)     -- Remove item string ID
        end
    end
end

local function loopOnTable(tbl)
    if type(tbl) ~= "table" then return end

    if tbl.items then
        removeLoot(tbl)
    end
    if tbl.junk and tbl.junk.items then
        removeLoot(tbl.junk)
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" and k ~= "items" and k ~= "junk" and not v.procedural then
            loopOnTable(v)
        end
    end
end

local function modifyActiveLootTables()
    -- Scrub all active B42 procedural loot pools
    if ProceduralDistributions and ProceduralDistributions.list then
        loopOnTable(ProceduralDistributions.list)
    end

    -- Scrub B42 vehicle storage pools
    if VehicleDistributions then
        loopOnTable(VehicleDistributions)
    end

    -- Scrub stand-alone clutter tables if populated directly
    if ClutterTables then
        loopOnTable(ClutterTables)
    end
end

Events.OnPreDistributionMerge.Add(modifyActiveLootTables)
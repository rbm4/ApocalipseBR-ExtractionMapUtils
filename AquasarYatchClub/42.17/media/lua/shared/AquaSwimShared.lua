-- Water detection for boat physics, launching and menus. Player swimming is handled by external mods.
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

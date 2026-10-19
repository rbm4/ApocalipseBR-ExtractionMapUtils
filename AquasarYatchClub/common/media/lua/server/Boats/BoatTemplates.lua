require 'CommonTemplates/CommonTemplates.lua'

if CommonTemplates and CommonTemplates.Create then

function CommonTemplates.Create.CabinLock(vehicle, part)
    if ZombRand(100) < 35 then--set unlock chances to 35pc 
        part:getModData()["AquaCabin_isUnlocked"] = true
        vehicle:transmitPartModData(part)        
    end
end

end
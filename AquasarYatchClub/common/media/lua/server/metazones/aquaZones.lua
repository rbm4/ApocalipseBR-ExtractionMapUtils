require 'metazones/TSARZones.lua'

Events.OnLoadMapZones.Add(function()
    loadTsarZone('media/mapszones/Muldraugh, KY/aquazones.lua', "aquazones")
end);
if isServer() then return end
require "ApocExtractionMapUtils"
if ApocExtractionMapUtils.ObjectiveClientLoaded then return end
ApocExtractionMapUtils.ObjectiveClientLoaded = true
local Network = require "ApocExtractionMapUtils_Objectives/Network"
local Tracker = require "ApocExtractionMapUtils_Objectives/Tracker"
ApocExtractionMapUtils.ObjectiveClient = { network = Network, tracker = Tracker }
local function create(index, player)
    if player then Tracker.create(index, player, Network.reset(index, player)) end
end
Events.OnCreatePlayer.Add(create)
Events.OnGameStart.Add(function()
    for index = 0, 3 do
        local player = getSpecificPlayer(index)
        if player then create(index, player)
        elseif Tracker.panels[index] then Tracker.panels[index]:removeFromUIManager(); Tracker.panels[index] = nil; Network.slots[index] = nil end
    end
end)
Events.OnServerCommand.Add(Network.onServerCommand)
Events.OnTick.Add(Network.onTick)
Events.OnKeyPressed.Add(function(key)
    local panel = Tracker.panels[0]
    if Keyboard and key == Keyboard.KEY_O and panel and panel.height > 0
        and not getCore():isDoingTextEntry() then panel:setEditing(not panel.editing) end
end)

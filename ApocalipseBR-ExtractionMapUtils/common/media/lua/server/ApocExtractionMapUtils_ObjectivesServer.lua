if not isServer() then return end
require "ApocExtractionMapUtils"
if ApocExtractionMapUtils.ObjectiveServerLoaded then return end
ApocExtractionMapUtils.ObjectiveServerLoaded = true
local Sync = require "ApocExtractionMapUtils_Objectives/Sync"
local Kills = require "ApocExtractionMapUtils_Objectives/Kills"
Events.OnClientCommand.Add(Sync.onClientCommand)
Events.OnTick.Add(Kills.onTick)
Events.OnTick.Add(Sync.onTick)
Events.OnZombieDead.Add(Kills.onDead)
Events.OnZombieCreate.Add(Kills.onCreate)

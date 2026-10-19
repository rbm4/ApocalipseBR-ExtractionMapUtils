require "ApocExtractionMapUtils"
require "ISUI/Maps/ISWorldMap"
require "ISUI/Maps/ISMiniMap"
require "ApocExtractionMapUtils_Reveal"
require "ApocExtractionMapUtils_Cartography"

local Utils = ApocExtractionMapUtils
local Reveal = Utils.Reveal

local originalWorldMapAllowed = ISWorldMap.IsAllowed
function ISWorldMap.IsAllowed(...)
    if Utils.forceMapReveal() then return true end
    return originalWorldMapAllowed(...)
end

local originalMiniMapAllowed = ISMiniMap.IsAllowed
function ISMiniMap.IsAllowed(...)
    if Utils.forceMapReveal() then return true end
    return originalMiniMapAllowed(...)
end

local originalWorldMapNeedsLight = ISWorldMap.NeedsLight
function ISWorldMap.NeedsLight(...)
    if Utils.forceMapReveal() then return false end
    return originalWorldMapNeedsLight(...)
end

local originalMiniMapNeedsLight = ISMiniMap.NeedsLight
function ISMiniMap.NeedsLight(...)
    if Utils.forceMapReveal() then return false end
    return originalMiniMapNeedsLight(...)
end

-- Preserve native minimap initialization, bounds, fog, zoom and saved visibility.
local originalShowWorldMap = ISWorldMap.ShowWorldMap
function ISWorldMap.ShowWorldMap(playerNum, ...)
    local result = originalShowWorldMap(playerNum, ...)
    Reveal.mapOpened(playerNum)
    return result
end

-- A minimap first opened long after login can also request PlayerVisited.
-- Only observe the completed toggle; do not change its UI or rendering state.
local originalToggleMiniMap = ISMiniMap.ToggleMiniMap
function ISMiniMap.ToggleMiniMap(playerNum, ...)
    local result = originalToggleMiniMap(playerNum, ...)
    local miniMap = getPlayerMiniMap(playerNum)
    if miniMap and miniMap:isReallyVisible() then Reveal.mapOpened(playerNum) end
    return result
end

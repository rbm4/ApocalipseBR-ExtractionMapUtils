require "ApocExtractionMapUtils"
require "ISUI/Maps/ISMapDefinitions"

local Utils = ApocExtractionMapUtils
if Utils.Cartography then return Utils.Cartography end

local Cartography = {}
Utils.Cartography = Cartography
local pending = setmetatable({}, { __mode = "k" })
local logged = false

local function isChernarus(mapAPI)
    for i = 0, mapAPI:getDataCount() - 1 do
        local path = mapAPI:getDataFileByIndex(i)
        if path and path:gsub("\\", "/"):lower():find("media/maps/chernarus/", 1, true) then
            return true
        end
    end
    return false
end

function Cartography.apply(mapUI)
    local api = mapUI.javaObject:getAPIv1()
    if not isChernarus(api) then return end
    local style = api:getStyleAPI()
    local waiting = {}
    local count = 0
    for i = 0, style:getLayerCount() - 1 do
        local layer = style:getLayerByIndex(i)
        if layer:getTypeString() == "Polygon" and layer:getFilterKey() == "highway" then
            -- Solid fills generate six extra triangulations for every road. B42
            -- narrows their cell-buffer offsets to signed shorts. Textured fills
            -- triangulate only the original polygon, keeping dense Chernarus cells
            -- below that limit. White preserves the original fill colors/alpha.
            for j = layer:getTextureStops() - 1, 0, -1 do layer:removeTexture(j) end
            for j = layer:getScaleStops() - 1, 0, -1 do layer:removeScale(j) end
            layer:addTexture(0, "media/white.png")
            layer:addTexture(24, "media/white.png")
            layer:addScale(0, 1)
            layer:addScale(24, 1)
            local texture = layer:getTexture(0)
            if not texture or not texture:isReady() then
                -- Native rendering falls back to the solid path for an unready
                -- texture. Do not allow even one frame to cache expanded roads.
                waiting[#waiting + 1] = { layer = layer, zoom = layer:getMinZoom() }
                layer:setMinZoom(1000)
            end
            count = count + 1
        end
    end
    pending[mapUI] = #waiting > 0 and { style = style, layers = waiting } or nil
    if count > 0 and not logged then
        print("[ApocExtractionMapUtils] Chernarus road rendering workaround active (Lua textured polygons).")
        logged = true
    end
end

Events.OnTick.Add(function()
    for mapUI, state in pairs(pending) do
        for i = #state.layers, 1, -1 do
            local entry = state.layers[i]
            if state.style:getLayerByName(entry.layer:getId()) ~= entry.layer then
                table.remove(state.layers, i)
            else
                local texture = entry.layer:getTexture(0)
                if texture and texture:isReady() then
                    entry.layer:setMinZoom(entry.zoom)
                    table.remove(state.layers, i)
                end
            end
        end
        if #state.layers == 0 then pending[mapUI] = nil end
    end
end)

-- Both ISMiniMap.InitPlayer and ISWorldMap:initDataAndStyle (via V3) call
-- this after adding their data. Run before the UI's first render, not on zoom.
local originalStyle = MapUtils.initDefaultStyleV1
function MapUtils.initDefaultStyleV1(mapUI, ...)
    local result = originalStyle(mapUI, ...)
    Cartography.apply(mapUI)
    return result
end

return Cartography

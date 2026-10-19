-- npm exec --yes --package=fengari-node-cli -- fengari tests/cartography.lua
local media = 'ApocalipseBR-ExtractionMapUtils/common/media/lua/'
package.path = media .. 'shared/?.lua;' .. media .. 'client/?.lua;' .. package.path
package.loaded['ISUI/Maps/ISMapDefinitions'] = true
SandboxVars = { ApocExtractionMapUtils = { ForceMapReveal = false } }
local ticks = {}
Events = { OnTick = { Add = function(f) ticks[#ticks + 1] = f end } }
local ready, missing = false, false
local white = { isReady = function() return ready end }
local function layer(id, kind, filter)
    local l = { id = id, kind = kind, filter = filter, minZoom = 11,
        textures = {}, scales = {}, fill = { 134, 125, 113, 255 } }
    function l:getId() return self.id end
    function l:getTypeString() return self.kind end
    function l:getFilterKey() return self.filter end
    function l:getMinZoom() return self.minZoom end
    function l:setMinZoom(z) self.minZoom = z end
    function l:getTextureStops() return #self.textures end
    function l:getScaleStops() return #self.scales end
    function l:removeTexture(i) table.remove(self.textures, i + 1) end
    function l:removeScale(i) table.remove(self.scales, i + 1) end
    function l:addTexture(z, path) self.textures[#self.textures + 1] = { z, path } end
    function l:addScale(z, scale) self.scales[#self.scales + 1] = { z, scale } end
    function l:getTexture(i)
        assert(self.textures[i + 1][2] == 'media/white.png')
        if not missing then return white end
    end
    return l
end
local function makeUI(path)
    local style = { layers = {} }
    function style:getLayerCount() return #self.layers end
    function style:getLayerByIndex(i) return self.layers[i + 1] end
    function style:getLayerByName(id)
        for _, l in ipairs(self.layers) do if l.id == id then return l end end
    end
    local api = { style = style }
    function api:getDataCount() return 1 end
    function api:getDataFileByIndex(i) assert(i == 0); return path end
    function api:getStyleAPI() return self.style end
    local ui = { api = api, javaObject = { getAPIv1 = function() return api end } }
    return ui
end
local initializations = 0
MapUtils = { initDefaultStyleV1 = function(ui, argument)
    initializations = initializations + 1
    ui.api.style.layers = {
        layer('road-primary', 'Polygon', 'highway'),
        layer('custom-road', 'Polygon', 'highway'),
        layer('building', 'Polygon', 'building'),
        layer('water', 'Polygon', 'water'),
        layer('street-labels', 'Text', nil),
    }
    return argument
end }
local nativeInit = MapUtils.initDefaultStyleV1
require 'ApocExtractionMapUtils_Cartography'
local function tick() for _, f in ipairs(ticks) do f() end end
local ordinary = makeUI('media/maps/Muldraugh, KY/worldmap.xml')
MapUtils.initDefaultStyleV1(ordinary)
assert(ordinary.api.style.layers[1].minZoom == 11)
assert(#ordinary.api.style.layers[1].textures == 0, 'other maps retain native styles')
local mini = makeUI('media/maps/Chernarus/worldmap.xml')
assert(MapUtils.initDefaultStyleV1(mini, 'original result') == 'original result')
assert(initializations == 2, 'original style initializer must run exactly once')
local roads = mini.api.style.layers
for i = 1, 2 do
    assert(roads[i].minZoom == 1000, 'unready texture must never use solid fallback')
    assert(#roads[i].textures == 2 and #roads[i].scales == 2)
    assert(roads[i].textures[1][1] == 0 and roads[i].textures[2][1] == 24)
    assert(roads[i].fill[1] == 134 and roads[i].fill[4] == 255, 'preserve fill colors')
end
assert(#roads[3].textures == 0 and #roads[4].textures == 0)
tick()
assert(roads[1].minZoom == 1000, 'wait until texture is actually ready')
ready = true
tick()
assert(roads[1].minZoom == 11 and roads[2].minZoom == 11)
-- Pending records must be removed; later ticks must not undo other style changes.
roads[1].minZoom = 14
tick()
assert(roads[1].minZoom == 14)
local full = makeUI('Z:\\mods\\common\\media\\maps\\Chernarus\\worldmap.xml')
MapUtils.initDefaultStyleV1(full)
assert(#full.api.style.layers[1].textures == 2 and full.api.style.layers[1].minZoom == 11,
    'ready textures apply immediately to full map as well as minimap')
-- Reinitialization replaces layers while an earlier texture load is pending.
ready = false
MapUtils.initDefaultStyleV1(mini)
local discarded = mini.api.style.layers[1]
nativeInit(mini)
ready = true
tick()
assert(discarded.minZoom == 1000 and mini.api.style.layers[1].minZoom == 11,
    'do not reactivate detached layers after a style reset')
-- Missing texture stays suppressed rather than selecting unsafe geometry.
missing = true
MapUtils.initDefaultStyleV1(full)
tick()
assert(full.api.style.layers[1].minZoom == 1000)
missing = false
tick()
assert(full.api.style.layers[1].minZoom == 11)
local count = #ticks
dofile(media .. 'client/ApocExtractionMapUtils_Cartography.lua')
assert(#ticks == count, 'autoload must not duplicate wrapper or scheduler')
print('PASS: Chernarus-only road style; both map UIs; colors preserved; texture readiness gate; reset cleanup; missing texture; single registration; independent of reveal setting')

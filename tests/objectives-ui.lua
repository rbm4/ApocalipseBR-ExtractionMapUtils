local root = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. package.path
local checks, measures, clock, screenWidth, screenHeight, fontHeight = 0, 0, 1000, 900, 700, 14
local function check(ok, message) checks = checks + 1; assert(ok, message) end
local Base = {}
function Base:derive()
    local class = {}; class.__index = class
    return setmetatable(class, { __index = self })
end
function Base:new(x, y, width, height)
    return setmetatable({ x = x, y = y, width = width, height = height, draws = {} }, self)
end
function Base:initialise() self:createChildren() end
function Base:createChildren() end
function Base:setWantMouseEvents(v) self.mouseEvents = v end
function Base:setWantKeyEvents(v) self.keyEvents = v end
function Base:setWidth(v) self.width = v end
function Base:setHeight(v) self.height = v end
function Base:setX(v) self.x = v end
function Base:setY(v) self.y = v end
function Base:setVisible(v) self.visible = v end
function Base:addToUIManager() self.added = true end
function Base:removeFromUIManager() self.added = false end
function Base:onMouseDown() return true end
function Base:onMouseUp() return true end
function Base:drawRect() end
function Base:drawRectBorder() end
function Base:drawText(text) self.draws[#self.draws + 1] = text end
Base.drawTextRight = Base.drawText
ISPanel = Base
package.loaded["ISUI/ISPanel"] = Base
UIFont = { Small = "small" }
function getTimestampMs() return clock end
function getPlayerScreenLeft() return 0 end
function getPlayerScreenTop() return 0 end
function getPlayerScreenWidth() return screenWidth end
function getPlayerScreenHeight() return screenHeight end
function getTextManager() return {
    getFontHeight = function() return fontHeight end,
    MeasureStringX = function(_, _, text) measures = measures + 1; return #text * 7 end
} end
function getText(key) return key end
function getTextOrNull() return nil end
local player = { data = {}, dead = false }
function player:getPlayerNum() return 0 end
function player:getModData() return self.data end
function player:isDead() return self.dead end
local Store = require "ApocExtractionMapUtils_Objectives/Store"
local Tracker = require "ApocExtractionMapUtils_Objectives/Tracker"
local s = Store.new()
s.ready, s.title, s.titleKey, s.visibleRows = true, "Operation", "", 6
for i = 1, 128 do
    local row = { id = "o" .. i, title = "Objective " .. i, titleKey = "", type = "kill_zombies", scope = "player",
        required = true, target = 100, count = 0, status = "active" }
    s.rows[i], s.byId[row.id] = row, row
end
s:cache()
local panel = Tracker.create(0, player, s)
panel:prerender(); panel:render()
check(#panel.labels == 6 and panel.height < screenHeight, "128 objectives render only bounded visible rows")
check(not panel.mouseEvents and not panel:onMouseDown(0, 0) and not panel:onMouseWheel(-1), "ordinary HUD passes mouse input through")
local baseline, generation = measures, s.generation
for _ = 1, 120 do clock = clock + 16; panel:prerender(); panel:render() end
check(measures == baseline and s.generation == generation, "unchanged frames do not remeasure text or rebuild selection/layout")
local first = s.visible[1]
first.count, first.target, first.title = 1000000, 1000000, string.rep("X", 100)
s:cache(); panel:prerender()
check(#panel.labels[1].title * 7 <= panel.width - 59 - #panel.labels[1].counter * 7, "maximum counters reserve measured width without overlapping labels")
panel:setEditing(true); panel:onMouseWheel(-1); panel:prerender()
check(s.offset == 1 and panel.labels[1].row.id == "o2" and panel.mouseEvents, "edit mode enables scrolling and updates cached visible selection")
panel:onMouseUp(0, 0)
check(player.data.ApocObjectiveUI.x == panel.x, "drag position stored without a progress command")
s:scroll(1000); panel:prerender()
check(panel.labels[#panel.labels].row.id == "o128", "final objective remains reachable")
screenWidth, screenHeight, fontHeight = 500, 400, 20
panel:prerender()
check(panel.height <= screenHeight and panel.width <= screenWidth and #panel.labels <= 3, "viewport/scale changes recompute bounded layout")
check(panel.x >= 0 and panel.x + panel.width <= screenWidth and panel.y + panel.height <= screenHeight, "panel clamps inside viewport")
local old = panel
panel = Tracker.create(0, player, s)
check(not old.added and panel.added, "reconnect/UI recreation replaces stale UI manager attachment")
player.dead = true; panel:prerender()
check(panel.height == 0 and not panel.mouseEvents, "dead character cannot leave an invisible mouse blocker")
player.dead = false
s.rows, s.byId = {}, {}; s:cache(); panel:prerender()
check(panel.height == 0 and not panel.mouseEvents, "empty objective store collapses tracker")
function isServer() return false end
function isClient() return true end
function getSpecificPlayer(index) return index == 0 and player or nil end
function player:getOnlineID() return 7 end
local registered = {}
Events = {}
for _, name in ipairs({ "OnCreatePlayer", "OnGameStart", "OnServerCommand", "OnTick", "OnKeyPressed" }) do
    registered[name] = {}
    Events[name] = { Add = function(fn) registered[name][#registered[name] + 1] = fn end }
end
dofile(root .. "client/ApocExtractionMapUtils_ObjectivesClient.lua")
dofile(root .. "client/ApocExtractionMapUtils_ObjectivesClient.lua")
check(#registered.OnGameStart == 1 and #registered.OnTick == 1 and #registered.OnServerCommand == 1, "client loader registers once")
registered.OnGameStart[1]()
local requests = 0
function sendClientCommand() requests = requests + 1 end
registered.OnTick[1]()
check(requests == 1 and Tracker.panels[0].store ~= s, "game start replaces old replica and requests server baseline")
Keyboard = { KEY_O = 24 }
local typing = false
function getCore() return { isDoingTextEntry = function() return typing end } end
Tracker.panels[0]:setHeight(100)
registered.OnKeyPressed[1](24)
check(Tracker.panels[0].editing, "objective edit key controls HUD input mode")
typing = true; registered.OnKeyPressed[1](24)
check(Tracker.panels[0].editing, "typing O in a text entry does not change HUD input mode")
local optional = Store.new()
optional.rows = { { required = true, status = "complete" }, { required = false, status = "unsupported" } }
optional:cache()
check(optional.requiredCount == 1 and optional.completed == 1 and #optional.visible == 2, "optional rows stay visible without blocking required completion summary")
print("PASS: " .. checks .. " objective UI cache/row/input/lifecycle assertions")

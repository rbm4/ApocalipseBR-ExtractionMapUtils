require "ISUI/ISPanel"
local T = require "ApocExtractionMapUtils_Objectives/Theme"
local Tracker = { panels = {} }
local Panel = ISPanel:derive("ApocExtractionObjectiveTracker")
function Panel:new(player, store)
    local slot = player:getPlayerNum()
    local width = math.min(350, getPlayerScreenWidth(slot) - 24)
    local o = ISPanel.new(self, getPlayerScreenLeft(slot) + getPlayerScreenWidth(slot) - width - 18,
        getPlayerScreenTop(slot) + 130, width, 0)
    o.player, o.store, o.slot = player, store, slot
    o.backgroundColor, o.borderColor = { r = 0, g = 0, b = 0, a = 0 }, { r = 0, g = 0, b = 0, a = 0 }
    o.anim, o.editing, o.moveWithMouse, o.layoutGeneration = {}, false, false, -1
    return o
end
function Panel:createChildren()
    ISPanel.createChildren(self)
    self:setWantMouseEvents(false)
    self:setWantKeyEvents(false)
end
function Panel:setEditing(value)
    self.editing, self.moveWithMouse = value == true, value == true
    self:setWantMouseEvents(self.editing and self.height > 0)
end
function Panel:onMouseDown(x, y)
    if self.editing then return ISPanel.onMouseDown(self, x, y) end
    return false
end
function Panel:onMouseUp(x, y)
    if not self.editing then return false end
    ISPanel.onMouseUp(self, x, y)
    self.player:getModData().ApocObjectiveUI = { x = self.x, y = self.y }
    return true
end
function Panel:onMouseWheel(delta)
    if not self.editing then return false end
    self.store:scroll(delta > 0 and -1 or 1)
    return true
end
function Panel:layout()
    local s, h = self.store, getTextManager():getFontHeight(UIFont.Small)
    local width = math.min(350, getPlayerScreenWidth(self.slot) - 24)
    local rows = math.max(1, math.floor((getPlayerScreenHeight(self.slot) - 180) / (h * 2 + 18)))
    if s.windowRows ~= rows then s.windowRows = rows; s:cache() end
    if self.layoutGeneration == s.generation and self.fontHeight == h and self.width == width then return end
    self.fontHeight, self.layoutGeneration = h, s.generation
    self:setWidth(width)
    self.rowHeight, self.labels = h * 2 + 18, {}
    self.heading = T.clip(T.label(s.titleKey, s.title), width - 24)
    self.summary = getText("IGUI_ApocExtractionMapUtils_ObjectivesSummary", s.completed, s.requiredCount)
    self.completedText = getText("IGUI_ApocExtractionMapUtils_ObjectivesCompleted")
    local nextAnim = {}
    for _, row in ipairs(s.visible) do
        nextAnim[row.id] = self.anim[row.id] or row.count / row.target
        local counter = tostring(row.count) .. " / " .. row.target
        local counterWidth = getTextManager():MeasureStringX(UIFont.Small, counter)
        self.labels[#self.labels + 1] = { row = row,
            title = T.clip(T.label(row.titleKey, row.title), width - 59 - counterWidth),
            counter = counter,
            state = T.clip(getText("IGUI_ApocExtractionMapUtils_ObjectivesScope_" .. row.scope) .. " - "
                .. getText("IGUI_ApocExtractionMapUtils_ObjectivesStatus_" .. row.status)
                .. (not row.required and " - " .. getText("IGUI_ApocExtractionMapUtils_ObjectivesOptional") or ""), width - 47) }
    end
    self.anim = nextAnim
    self.footer = getText("IGUI_ApocExtractionMapUtils_ObjectivesPage", s.offset + 1, s.offset + #s.visible, #s.rows)
end
function Panel:prerender()
    local s = self.store
    if self.player:isDead() or not s.ready or #s.rows == 0 then
        self:setHeight(0); self:setWantMouseEvents(false); return
    end
    self:layout()
    self:setHeight(self.fontHeight * 3 + 36 + #s.visible * self.rowHeight)
    self:setX(math.max(getPlayerScreenLeft(self.slot), math.min(self.x,
        getPlayerScreenLeft(self.slot) + getPlayerScreenWidth(self.slot) - self.width)))
    self:setY(math.max(getPlayerScreenTop(self.slot), math.min(self.y,
        getPlayerScreenTop(self.slot) + getPlayerScreenHeight(self.slot) - self.height)))
    self:setWantMouseEvents(self.editing)
end
function Panel:render()
    if self.height <= 0 then return end
    local now = getTimestampMs()
    local dt = math.max(0, math.min(.1, (now - (self.lastRender or now)) / 1000))
    self.lastRender = now
    local h, w, accent = self.fontHeight, self.width, T.accent
    self:drawRect(0, 0, w, self.height, .82, .03, .045, .045)
    self:drawRect(0, 0, 3, self.height, 1, accent[1], accent[2], accent[3])
    self:drawText(self.heading, 12, 8, accent[1], accent[2], accent[3], 1, UIFont.Small)
    self:drawText(self.store.needsSnapshot and getText("IGUI_ApocExtractionMapUtils_ObjectivesSync") or self.summary,
        12, 12 + h, .65, .72, .70, 1, UIFont.Small)
    local y = 20 + h * 2
    for _, item in ipairs(self.labels) do
        local row = item.row
        local col = row.status == "complete" and T.done or row.status == "active" and accent or T.dim
        T.checkbox(self, 12, y + math.max(0, (h - 10) / 2), row.status == "complete", col)
        self:drawText(item.title, 35, y, .92, .94, .93, 1, UIFont.Small)
        self:drawTextRight(item.counter, w - 12, y, col[1], col[2], col[3], 1, UIFont.Small)
        self:drawText(item.state, 35, y + h + 1, .60, .66, .65, .9, UIFont.Small)
        local target = row.count / row.target
        self.anim[row.id] = self.anim[row.id] + (target - self.anim[row.id]) * math.min(1, dt * 8)
        T.bar(self, 35, y + h * 2 + 5, w - 47, self.anim[row.id], col)
        y = y + self.rowHeight
    end
    self:drawText(self.footer, 12, y, .60, .66, .65, 1, UIFont.Small)
    self:drawTextRight(getText(self.editing and "IGUI_ApocExtractionMapUtils_ObjectivesEdit" or "IGUI_ApocExtractionMapUtils_ObjectivesHint"),
        w - 12, y, .60, .66, .65, 1, UIFont.Small)
    -- At most four live completion cards; snapshots never add cards to this queue.
    local toasts, at = self.store.toasts, 1
    while at <= #toasts do
        local toast = toasts[at]
        local age = now - toast.born
        if age > 4500 then table.remove(toasts, at)
        else
            local ty = getPlayerScreenTop(self.slot) + 12 + (at - 1) * 54 - self.y
            local tx = getPlayerScreenLeft(self.slot) + (getPlayerScreenWidth(self.slot) - w) / 2 - self.x
            local alpha = math.min(1, age / 180, (4500 - age) / 400)
            if toast.width ~= w or toast.fontHeight ~= h then
                toast.label, toast.width, toast.fontHeight = T.clip(T.label(toast.titleKey, toast.title), w - 24), w, h
            end
            self:drawRect(tx, ty, w, 48, alpha * .95, .04, .10, .08)
            self:drawText(self.completedText, tx + 12, ty + 4, accent[1], accent[2], accent[3], alpha, UIFont.Small)
            self:drawText(toast.label, tx + 12, ty + h + 6, .95, .95, .95, alpha, UIFont.Small)
            at = at + 1
        end
    end
end
function Tracker.create(index, player, store)
    if Tracker.panels[index] then Tracker.panels[index]:removeFromUIManager() end
    local panel = Panel:new(player, store)
    panel:initialise(); panel:addToUIManager(); panel:setVisible(true)
    local saved = player:getModData().ApocObjectiveUI
    if saved and type(saved.x) == "number" and type(saved.y) == "number" then panel:setX(saved.x); panel:setY(saved.y) end
    Tracker.panels[index] = panel
    return panel
end
return Tracker

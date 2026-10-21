require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISRichTextPanel"
local G = require "ApocExtractionMapUtils_HumanDialogueGraph"

ApocHumanDialogPanel = ISPanel:derive("ApocHumanDialogPanel")
function ApocHumanDialogPanel:new(player, name, options, greetingKey, onSelect, onClose, labels)
    local width, height = 420, 190 + #options * 32
    local x = getPlayerScreenLeft(player:getPlayerNum()) + (getPlayerScreenWidth(player:getPlayerNum()) - width) / 2
    local y = getPlayerScreenTop(player:getPlayerNum()) + 70
    local o = ISPanel.new(self, x, y, width, height)
    o.player, o.npcName, o.options, o.greetingKey = player, name, options, greetingKey
    o.onSelect, o.onClose, o.moveWithMouse = onSelect, onClose, true
    o.labels = labels
    return o
end
function ApocHumanDialogPanel:createChildren()
    ISPanel.createChildren(self)
    self:addChild(ISLabel:new(14, 12, 24, self.npcName, 1, 1, 1, 1, UIFont.Medium, true))
    self.message = ISRichTextPanel:new(14, 42, self.width - 28, 95)
    self.message:initialise()
    self.message.autosetheight = false
    self.message:addScrollBars()
    self:addChild(self.message)
    self:setMessage(self.greetingKey)
    self.buttons = {}
    self:rebuildOptions()
    self.closeButton = ISButton:new(14, self.height - 36, self.width - 28, 26,
        self.labels and self.labels.close or getText("IGUI_ApocExtractionMapUtils_DialogClose"), self, function() self.onClose() end)
    self.closeButton:initialise(); self:addChild(self.closeButton)
end
function ApocHumanDialogPanel:rebuildOptions()
    for _, button in ipairs(self.buttons) do
        if button.tooltipUI then button.tooltipUI:removeFromUIManager() end
        self:removeChild(button)
    end
    self.buttons = {}
    self:setHeight(190 + #self.options * 32)
    for i, option in ipairs(self.options) do
        local button = ISButton:new(14, 142 + (i - 1) * 32, self.width - 28, 26,
            G.label(option, self.fallbackLocale), self, function() self.onSelect(option.id) end)
        local text = option.title and option or G.text(option.texts, G.locale(), self.fallbackLocale)
        if text.description and text.description ~= "" then button.tooltip = text.description end
        button:initialise(); self:addChild(button)
        self.buttons[#self.buttons + 1] = button
    end
    if self.closeButton then self.closeButton:setY(self.height - 36) end
end
function ApocHumanDialogPanel:removeFromUIManager()
    for _, button in ipairs(self.buttons or {}) do
        if button.tooltipUI then button.tooltipUI:removeFromUIManager() end
    end
    ISPanel.removeFromUIManager(self)
end
function ApocHumanDialogPanel:setNode(options, texts, fallback)
    self.options, self.fallbackLocale = options, fallback
    self.nodeText = G.text(texts, G.locale(), fallback)
    self:rebuildOptions()
    self:setResponse("")
end
function ApocHumanDialogPanel:setResolvedNode(options, text)
    self.options, self.nodeText = options, text
    self:rebuildOptions()
    self:setResponse("")
end
function ApocHumanDialogPanel:setResponse(response)
    local text = self.nodeText or {}
    local parts = {}
    for _, value in ipairs({ text.title or "", text.description or "", response or "" }) do
        if value ~= "" then parts[#parts + 1] = value end
    end
    self.message.text = table.concat(parts, " <LINE> ")
    self.message:paginate()
end
function ApocHumanDialogPanel:setMessage(key)
    self.message.text = key and getText(key) or ""
    self.message:paginate()
end
function ApocHumanDialogPanel:setPending(pending)
    for _, button in ipairs(self.buttons) do button:setEnable(not pending) end
end

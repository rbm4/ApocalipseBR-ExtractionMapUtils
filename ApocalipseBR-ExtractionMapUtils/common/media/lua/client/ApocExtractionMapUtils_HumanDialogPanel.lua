require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISRichTextPanel"

ApocHumanDialogPanel = ISPanel:derive("ApocHumanDialogPanel")
function ApocHumanDialogPanel:new(player, name, options, greetingKey, onSelect, onClose)
    local width, height = 420, 190 + #options * 32
    local x = getPlayerScreenLeft(player:getPlayerNum()) + (getPlayerScreenWidth(player:getPlayerNum()) - width) / 2
    local y = getPlayerScreenTop(player:getPlayerNum()) + 70
    local o = ISPanel.new(self, x, y, width, height)
    o.player, o.npcName, o.options, o.greetingKey = player, name, options, greetingKey
    o.onSelect, o.onClose, o.moveWithMouse = onSelect, onClose, true
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
    for i, option in ipairs(self.options) do
        local button = ISButton:new(14, 142 + (i - 1) * 32, self.width - 28, 26,
            getText(option.textKey), self, function() self.onSelect(option.id) end)
        button:initialise(); self:addChild(button)
        self.buttons[#self.buttons + 1] = button
    end
    local close = ISButton:new(14, self.height - 36, self.width - 28, 26,
        getText("IGUI_ApocExtractionMapUtils_DialogClose"), self, function() self.onClose() end)
    close:initialise(); self:addChild(close)
end
function ApocHumanDialogPanel:setMessage(key)
    self.message.text = key and getText(key) or ""
    self.message:paginate()
end
function ApocHumanDialogPanel:setPending(pending)
    for _, button in ipairs(self.buttons) do button:setEnable(not pending) end
end

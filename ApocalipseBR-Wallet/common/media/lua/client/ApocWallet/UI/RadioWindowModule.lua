if not isClient() then return end
require "RadioCom/ISRadioWindow"
require "RadioCom/RadioWindowModules/RWMPanel"
require "ISUI/ISButton"
local Device = require "ApocWallet/RadioDevice"
local Controller = require "ApocWallet/RadioUIController"
if ApocWallet.radioModuleInstalled then return end
ApocWallet.radioModuleInstalled = true

-- Adapted from RadioTraders RT_RadioWindowModule; no trader selection/status polling.
RWMApocWallet = RWMPanel:derive("RWMApocWallet")
function RWMApocWallet:new(x,y,w,h) return RWMPanel.new(self,x,y,w,h) end
function RWMApocWallet:createChildren()
    RWMPanel.createChildren(self)
    local h = math.max(25,getTextManager():getFontHeight(UIFont.Small)+8)
    self.openButton = ISButton:new(6,6,self.width-12,h,getText("UI_ApocWallet_Open"),self,RWMApocWallet.openWallet)
    self.openButton:initialise(); self.openButton:instantiate(); self:addChild(self.openButton)
    self:setHeight(h+12)
end
function RWMApocWallet:readFromObject(player,device,data,kind)
    RWMPanel.readFromObject(self,player,device,data,kind)
    return player ~= nil and Device.isRadio(device,data)
end
function RWMApocWallet:openWallet() Controller.open(self.player,self.device) end
function RWMApocWallet:onJoypadDown(button)
    if button == Joypad.AButton then self:openWallet(); return true end
    return RWMPanel.onJoypadDown(self,button)
end
function RWMApocWallet:getAPrompt() return getText("UI_ApocWallet_Open") end

local original = ISRadioWindow.createChildren
function ISRadioWindow:createChildren()
    original(self)
    if self.apocWalletModule then return end
    self.apocWalletModule = RWMApocWallet:new(0,0,self.width,0)
    self:addModule(self.apocWalletModule,getText("UI_ApocWallet_Title"),true)
end

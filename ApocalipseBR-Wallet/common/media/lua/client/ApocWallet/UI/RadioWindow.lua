require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
local Layout = require "ApocWallet/UI/RadioLayout"

-- Visual shell/layout adapted from RadioTraders RT_SkinWindow/RT_TradeWindow.
-- Direct vanilla inheritance: no trading, audio, signal, inventory or RT globals.
ApocWalletRadioWindow = ISCollapsableWindow:derive("ApocWalletRadioWindow")
local Window = ApocWalletRadioWindow
local textures = {}
local function clamp(n, lo, hi) return math.max(lo,math.min(n,hi)) end

local function viewport(index)
    return getPlayerScreenLeft(index), getPlayerScreenTop(index),
        getPlayerScreenWidth(index), getPlayerScreenHeight(index)
end

local function size(index, kind)
    local _,_,sw,sh = viewport(index)
    local L = Layout[kind]
    local width = kind == "walkie" and sh * 0.90 * L.w / L.h or sw * 0.92
    width = math.max(1,math.floor(math.min(width,sw-16,(sh-16)*L.w/L.h)))
    return width,math.max(1,math.floor(width*L.h/L.w))
end

local function texture(kind, skin, hd)
    local key = kind .. "_" .. skin .. (hd and "_hd" or "_sd")
    if textures[key] == nil then
        textures[key] = getTexture("media/textures/ApocWallet/radio/" .. key .. ".png") or false
    end
    return textures[key] or nil
end

local function fit(text, width)
    local tm = getTextManager()
    if tm:MeasureStringX(UIFont.Small,text) <= width then return text end
    local length = #text
    while length > 0 and tm:MeasureStringX(UIFont.Small,text:sub(1,length) .. "...") > width do length = length - 1 end
    return length > 0 and text:sub(1,length) .. "..." or ""
end

function Window:new(player, radio, kind, actions)
    local index, L = player:getPlayerNum(), Layout[kind]
    local left, top, sw, sh = viewport(index)
    -- Same skin proportions as the source, additionally bounded to this player's viewport.
    local width,height = size(index,kind)
    local o = ISCollapsableWindow.new(self,left+(sw-width)/2,top+(sh-height)/2,width,height)
    o.player, o.radio, o.playerIndex, o.kind, o.L = player, radio, index, kind, L
    o.actions, o.skinIndex, o.status = actions, 1, "loading"
    o.background, o.drawFrame, o.moveWithMouse, o.resizable = false, false, true, false
    o.fontHeight = getTextManager():getFontHeight(UIFont.Small)
    o.title = getText("UI_ApocWallet_Title")
    return o
end

function Window:R(rect)
    local k = self.width/self.L.w
    return math.floor(rect[1]*k),math.floor(rect[2]*k),math.floor(rect[3]*k),math.floor(rect[4]*k)
end

function Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    for _, name in ipairs({"closeButton","collapseButton","pinButton","resizeWidget","resizeWidget2","infoButton"}) do
        if self[name] then self[name]:setVisible(false) end
    end
    self.list = ISScrollingListBox:new(0,0,10,10)
    self.list:initialise(); self.list:instantiate()
    self.list.font, self.list.itemheight = UIFont.Small, self.fontHeight + 6
    self.list.drawBorder = false
    self.list.backgroundColor, self.list.borderColor = {r=0,g=0,b=0,a=0}, {r=0,g=0,b=0,a=0}
    self.list:clear()
    self:addChild(self.list)
    if self.list.vscroll then self.list.vscroll:setVisible(false) end
    local function button(key, fn)
        local b = ISButton:new(0,0,10,10,getText(key),self,fn)
        b.displayBackground = false
        b:initialise(); b:instantiate(); self:addChild(b)
        return b
    end
    self.refreshButton = button("UI_ApocWallet_Sync",function(win) win.actions.refresh(win) end)
    self.refreshButton:setTooltip(getText("UI_ApocWallet_RefreshTooltip"))
    self.skinButton = button("UI_ApocWallet_Skin",function(win) win:nextSkin() end)
    self.skinButton:setTooltip(getText("UI_ApocWallet_SkinTooltip"))
    self.walletCloseButton = button("UI_ApocWallet_Close",function(win) win:close() end)
    self:layout()
    self:setBalanceState({status="loading"})
end

function Window:layout()
    local x,y,w,h = self:R(self.L.list)
    self.list:setX(x+4); self.list:setY(y+self.fontHeight+8)
    self.list:setWidth(math.max(1,w-8)); self.list:setHeight(math.max(1,h-self.fontHeight-12))
    for _, pair in ipairs({{self.refreshButton,1,"UI_ApocWallet_Sync"},{self.skinButton,2,"UI_ApocWallet_Skin"},
        {self.walletCloseButton,6,"UI_ApocWallet_Close"}}) do
        local b, slot = pair[1], pair[2]
        local bx,by,bw,bh = self:R(self.L.keys[slot])
        b:setX(bx); b:setY(by); b:setWidth(bw); b:setHeight(bh)
        b:setTitle(fit(getText(pair[3]),bw-6))
    end
    self.tex = texture(self.kind,self.L.skins[self.skinIndex],self.height > self.L.h*0.55)
    self.heading = fit(getText("UI_ApocWallet_Title"),math.max(0,w-8))
    self.emptyText = fit(getText("UI_ApocWallet_Empty"),math.max(0,w-8))
    self.skinText = fit(getText("UI_ApocWallet_SkinFmt",getText("UI_ApocWallet_Skin_" .. self.L.skins[self.skinIndex])),math.max(0,w-8))
end

function Window:nextSkin()
    self.skinIndex = self.skinIndex % #self.L.skins + 1
    self:layout()
end

function Window:setBalanceState(state)
    self.balanceState = {status=state.status,balance=state.balance,cached=state.cached}
    self.status = state.status
    local _,_,width = self:R(self.L.feed)
    local value
    if state.status == "ready" and type(state.balance) == "number" then
        value = state.balance % 1 == 0 and string.format("%.0f",state.balance) or tostring(state.balance)
    end
    local text = value and getText("UI_ApocWallet_BalanceFmt",value)
        or getText(state.status == "loading" and "UI_ApocWallet_Loading" or "UI_ApocWallet_Unavailable")
    if value and getTextManager():MeasureStringX(UIFont.Small,text) > width-16 then text = value end
    self.balanceText = fit(text,width-16)
    self.statusText = state.status == "ready" and getText(state.cached and "UI_ApocWallet_Cached" or "UI_ApocWallet_Updated")
        or getText(state.status == "loading" and "UI_ApocWallet_Waiting" or "UI_ApocWallet_TryRefresh")
    if state.status == "error" and type(state.error) == "string" and #state.error<=80
        and state.error:match("^[A-Z0-9_]+$") then
        self.statusText = getText("UI_ApocWallet_FailureFmt",state.error)
    end
    self.statusText = fit(self.statusText,width-16)
    self.refreshButton:setEnable(true)
end

function Window:reflow()
    local w,h = size(self.playerIndex,self.kind)
    self:setWidth(w); self:setHeight(h)
    self.fontHeight = getTextManager():getFontHeight(UIFont.Small)
    self.list.itemheight = self.fontHeight + 6
    self:layout()
    self:setBalanceState(self.balanceState or {status="loading"})
    self:clampToScreen()
end

function Window:clampToScreen()
    local left,top,sw,sh = viewport(self.playerIndex)
    self:setX(clamp(self.x,left,left+math.max(0,sw-self.width)))
    self:setY(clamp(self.y,top,top+math.max(0,sh-self.height)))
end

function Window:close()
    if self.actions then self.actions.close(self) end
end

function Window:onMouseUp(x,y)
    ISCollapsableWindow.onMouseUp(self,x,y)
    self:clampToScreen()
end

function Window:onMouseUpOutside(x,y)
    ISCollapsableWindow.onMouseUpOutside(self,x,y)
    self:clampToScreen()
end

function Window:prerender()
    if self.tex then self:drawTextureScaled(self.tex,0,0,self.width,self.height,1,1,1,1)
    else self:drawRect(0,0,self.width,self.height,0.98,0.08,0.10,0.08) end
end

function Window:render()
    local x,y,w,h = self:R(self.L.feed)
    self:drawText(self.balanceText or "",x+8,y+8,0.43,1,0.55,1,UIFont.Small)
    self:drawText(self.statusText or "",x+8,y+12+self.fontHeight,0.6,0.8,0.65,1,UIFont.Small)
    local lx,ly,lw,lh = self:R(self.L.list)
    self:drawText(self.heading,lx+4,ly+4,0.43,1,0.55,1,UIFont.Small)
    self:drawTextCentre(self.emptyText,lx+lw/2,ly+lh/2,0.6,0.8,0.65,1,UIFont.Small)
    local gx,gy,gw,gh = self:R(self.L.log)
    self:drawText(self.skinText,gx+4,gy+math.max(0,(gh-self.fontHeight)/2),0.6,0.8,0.65,1,UIFont.Small)
end

return Window

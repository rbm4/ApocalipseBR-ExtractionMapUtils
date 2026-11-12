require 'ISUI/ISButton'
require 'ISUI/ISTextBox'
local Client=require 'ApocWallet/MarketClient'
local Portrait=require 'ApocWallet/OperatorPortrait'
local P=require 'ApocWallet/MarketProtocol'
local Panel={}
local function fit(text,width)
    local tm=getTextManager()
    while #text>0 and tm:MeasureStringX(UIFont.Small,text)>width do
        local start=#text
        while start>1 and text:byte(start)>=128 and text:byte(start)<192 do start=start-1 end
        text=text:sub(1,start-1)
    end
    return text
end
local function selected(win)
    local row=win.list.items[win.list.selected]
    return row and row.item or nil
end
local function prompt(win,key,max,callback)
    if win.marketModal then return end
    local box
    box=ISTextBox:new(win:getX(),win:getY(),340,180,getText(key,max),'1',win,function(target,button)
        target.marketModal=nil
        if button.internal~='OK' or target.closed then return end
        local value=tonumber(button.parent.entry:getText())
        if not P.integer(value,1,max) then
            target.marketSession.dialogue:enqueue('operator','UI_ApocWallet_MarketInvalidAmount'); return
        end
        callback(value)
    end,win.playerIndex)
    win.marketModal=box
    box:initialise(); box:addToUIManager()
    box.entry:setOnlyNumbers(true)
    box.maxChars=10
end
function Panel.action(win)
    local s=win.marketSession
    if s.pending or s.transaction then return end
    if s.state~='connected' then Client.tune(s); return end
    local row=selected(win)
    if not row then return end
    prompt(win,'UI_ApocWallet_MarketQuantityFmt',row.count,function(count)
        if s.mode=='inventory' then
            prompt(win,'UI_ApocWallet_MarketPriceFmt',10000000,function(price) Client.post(s,row,count,price) end)
        else Client.buy(s,row,count) end
    end)
end
function Panel.layout(win)
    local s=win.marketSession
    if not s then return end
    local keys={
        {win.refreshButton,1,s.state=='connected' and (s.mode=='inventory' and 'UI_ApocWallet_MarketPost' or 'UI_ApocWallet_MarketBuy') or 'UI_ApocWallet_MarketTune'},
        {win.skinButton,2,s.state=='connected' and (s.mode=='inventory' and 'UI_ApocWallet_MarketBrowse' or 'UI_ApocWallet_MarketInventory') or 'UI_ApocWallet_Skin'},
        {win.marketPrev,3,'UI_ApocWallet_MarketPrevious'}, {win.marketNext,4,'UI_ApocWallet_MarketNext'},
        {win.marketRefresh,5,'UI_ApocWallet_MarketBulletin'}, {win.walletCloseButton,6,'UI_ApocWallet_MarketHangup'},
    }
    for _,pair in ipairs(keys) do
        local b,slot=pair[1],pair[2]
        local x,y,w,h=win:R(win.L.keys[slot])
        b:setX(x); b:setY(y); b:setWidth(w); b:setHeight(h); b:setTitle(fit(getText(pair[3]),w-6))
    end
    local connected=s.state=='connected'
    local busy=s.pending~=nil or s.transaction~=nil
    win.refreshButton:setEnable(not busy)
    win.skinButton:setEnable(not busy)
    win.marketPrev:setEnable(connected and not busy and s.page>1)
    win.marketNext:setEnable(connected and not busy and s.page<s.pages)
    win.marketRefresh:setEnable(connected and not busy)
    local _,_,w=win:R(win.L.list)
    win.marketHeading=fit(getText(s.mode=='inventory' and 'UI_ApocWallet_MarketInventory' or 'UI_ApocWallet_MarketBrowse')..'  '..s.page..'/'..s.pages,w-8)
    win.marketStatus=getText(s.state=='connected' and 'UI_ApocWallet_MarketConnected' or s.state=='tuning' and 'UI_ApocWallet_MarketTuning' or 'UI_ApocWallet_MarketOffline')
    local _,_,fw,fh=win:R(win.L.feed)
    local ph=math.max(16,math.min(fh-win.fontHeight*2-14,fw*0.43))
    local pw=ph*17/21
    win.marketStatusDisplay=fit(win.marketStatus,fw-pw-18)
    win.marketBalanceDisplay=fit(win.balanceText or '',fw-12)
    win.marketOperatorDisplay=fit(getText('UI_ApocWallet_MarketOperator'),fw-pw-18)
end
function Panel.populate(win)
    local s=win.marketSession
    win.list:clear()
    local _,_,width=win:R(win.L.list)
    for _,row in ipairs(s.rows) do
        row.label=fit(row.name,width-16)
        row.detail=fit(row.code..'  x'..row.count..(row.price and '  $'..row.price or ''),width-16)
        win.list:addItem(row.name,row)
    end
    win.list.selected=#s.rows>0 and 1 or -1
    Panel.layout(win)
end
function Panel.render(win)
    local s=win.marketSession
    local x,y,w,h=win:R(win.L.feed)
    local fh=win.fontHeight
    local ph=math.max(16,math.min(h-fh*2-14,w*0.43))
    local pw=ph*17/21
    Portrait.draw(win,x+5,y+5,pw,ph,s.state,s.dialogue.talkingUntil)
    local tx=x+pw+12
    win:drawText(win.marketOperatorDisplay,tx,y+8,0.5,1,0.65,1,UIFont.Small)
    win:drawText(win.marketStatusDisplay,tx,y+12+fh,0.6,0.8,0.65,1,UIFont.Small)
    win:drawText(win.marketBalanceDisplay,x+6,y+h-fh-6,0.5,1,0.65,1,UIFont.Small)
    local lx,ly,lw,lh=win:R(win.L.list)
    win:drawText(win.marketHeading or '',lx+4,ly+4,0.5,1,0.65,1,UIFont.Small)
    if #s.rows==0 then
        win:drawTextCentre(getText(s.state=='connected' and 'UI_ApocWallet_MarketEmpty' or 'UI_ApocWallet_MarketTuneHint'),lx+lw/2,ly+lh/2,0.6,0.8,0.65,1,UIFont.Small)
    end
    local gx,gy,gw,gh=win:R(win.L.log)
    win:drawText(win.marketLog1 or win.courierDisplay or '',gx+4,gy+2,0.6,0.9,0.65,1,UIFont.Small)
    if gh>=fh*2 then win:drawText(win.marketLog2 or '',gx+4,gy+fh+2,0.6,0.9,0.65,1,UIFont.Small) end
end
function Panel.attach(win)
    if win.marketSession then return win end
    local s=Client.open(win); win.marketSession=s
    local function button(fn)
        local b=ISButton:new(0,0,10,10,'',win,fn)
        b.displayBackground=false; b:initialise(); b:instantiate(); win:addChild(b); return b
    end
    win.marketPrev=button(function() Client.page(s,s.mode,s.page-1) end)
    win.marketNext=button(function() Client.page(s,s.mode,s.page+1) end)
    win.marketRefresh=button(function() Client.page(s,s.mode,s.page); s.refreshBalance() end)
    win.refreshButton.onclick=Panel.action
    win.skinButton.onclick=function()
        if s.state=='connected' then Client.page(s,s.mode=='market' and 'inventory' or 'market',1)
        else win:nextSkin() end
    end
    win.refreshButton:setTooltip(getText('UI_ApocWallet_MarketTuneHint'))
    win.skinButton:setTooltip(getText('UI_ApocWallet_MarketInventoryHint'))
    win.list.itemheight=win.fontHeight*2+6
    win.list.doDrawItem=function(list,y,item)
        local row=item.item
        if item.index==list.selected then list:drawRect(0,y,list.width,list.itemheight,0.3,0.2,0.5,0.25) end
        list:drawText(row.label,4,y+2,0.85,0.95,0.85,1,UIFont.Small)
        list:drawText(row.detail,4,y+win.fontHeight+3,0.55,0.8,0.6,1,UIFont.Small)
        return y+list.itemheight
    end
    s.refreshBalance=function() if not win.closed then win.actions.refresh(win) end end
    s.onChange=function() Panel.populate(win) end
    s.dialogue.onLine=function(history)
        local line=history[#history]
        local _,_,width=win:R(win.L.log)
        local text=(line.speaker=='operator' and getText('UI_ApocWallet_MarketOperator') or getText('UI_ApocWallet_MarketYou'))..': '..line.text
        win.marketLog1=fit(text,width-8)
        win.marketLog2=fit(text:sub(#win.marketLog1+1),width-8)
    end
    win.marketLayout=Panel.layout; win.marketRender=Panel.render
    local oldLayout=win.layout
    win.layout=function(self) oldLayout(self); self.list.itemheight=self.fontHeight*2+6; Panel.populate(self) end
    local oldBalance=win.setBalanceState
    win.setBalanceState=function(self,state) oldBalance(self,state); Panel.layout(self) end
    Panel.populate(win)
    return win
end
return Panel

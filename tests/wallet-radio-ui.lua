local root = "ApocalipseBR-Wallet/common/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. package.path
local checks, now, clockReads, measures = 0, 1000, 0, 0
local width,height,fontHeight = 1920,1080,14
local players, packets, textures = {}, {}, {}
local function check(ok,message) checks = checks + 1; assert(ok,message) end
function isClient() return true end
function getTimestampMs() clockReads = clockReads + 1; return now end
function getSpecificPlayer(index) return players[index] end
function getNumActivePlayers() return 2 end
function getPlayerScreenLeft(index) return index == 1 and width or 0 end
function getPlayerScreenTop() return 0 end
function getPlayerScreenWidth() return width end
function getPlayerScreenHeight() return height end
function getTextManager() return {
    getFontHeight = function() return fontHeight end,
    MeasureStringX = function(_,_,text) measures = measures + 1; return #text*7 end,
} end
UIFont = { Small = "Small" }; Joypad = { AButton = 1 }
local translations = {
    UI_ApocWallet_Title="Wallet", UI_ApocWallet_Open="Open wallet", UI_ApocWallet_BalanceFmt="Balance: %1",
    UI_ApocWallet_Loading="Loading balance...", UI_ApocWallet_Unavailable="Balance unavailable",
    UI_ApocWallet_Waiting="Waiting for the server", UI_ApocWallet_TryRefresh="Use Sync to try again",
    UI_ApocWallet_Cached="Cached balance", UI_ApocWallet_Updated="Balance received",
    UI_ApocWallet_Empty="No listings yet", UI_ApocWallet_Sync="Sync", UI_ApocWallet_Skin="Skin",
    UI_ApocWallet_Close="Close", UI_ApocWallet_SkinFmt="Skin: %1",
}
function getText(key,arg) return (translations[key] or key):gsub("%%1",function() return tostring(arg) end) end
function getTexture(path) textures[path] = true; return {path=path} end
function instanceof(object,kind)
    return object ~= nil and (object.kind == kind or kind == "InventoryItem" and object.inventory == true)
end
local square = {getX=function() return 0 end,getY=function() return 0 end,canReachTo=function() return true end}
local function device(kind,twoWay,fullType)
    local d = {kind=kind,inventory=kind=="Radio"}
    d.container = d.inventory and players[0] and players[0].inventoryContainer or nil
    function d:getContainer() return self.container end
    function d:getWorldItem() return nil end
    function d:getSquare() return square end
    function d:getObjectIndex() return 0 end
    function d:getDeviceData() return {getIsTwoWay=function() return twoWay ~= false end} end
    function d:getFullType() return fullType or "Base.WalkieTalkie1" end
    return d
end
local function player(index,id)
    local p = {index=index,id=id}
    p.inventoryContainer={getOutermostContainer=function(self) return self end}
    function p:getInventory() return self.inventoryContainer end
    function p:getCurrentSquare() return square end
    function p:getX() return 0.5 end
    function p:getY() return 0.5 end
    function p:getVehicle() return nil end
    function p:getPlayerNum() return self.index end
    function p:getOnlineID() return self.id end
    function p:isDead() return self.dead == true end
    players[index] = p
    return p
end
local function event()
    local handlers = {}
    return {
        Add=function(f) handlers[#handlers+1]=f end,
        Remove=function(f) for i,h in ipairs(handlers) do if h==f then table.remove(handlers,i); return end end end,
        count=function() return #handlers end,
        fire=function(...)
            local snapshot={}; for i,h in ipairs(handlers) do snapshot[i]=h end
            for _,h in ipairs(snapshot) do h(...) end
        end,
    }
end
Events = {}
for _,name in ipairs({"OnCreatePlayer","OnGameStart","OnTick","OnServerCommand","OnPlayerDeath","OnDisconnect",
    "OnFillInventoryObjectContextMenu","OnFillWorldObjectContextMenu","OnResolutionChange"}) do Events[name]=event() end

-- Widget doubles follow the native initialise -> instantiate/createChildren lifecycle.
local Base = {}
Base.__index = Base
function Base:derive()
    local class={}; class.__index=class
    return setmetatable(class,{__index=self})
end
function Base:new(x,y,w,h)
    return setmetatable({x=x,y=y,width=w,height=h,children={},visible=true,draws={}},self)
end
function Base:initialise() self.initialised=true end
function Base:instantiate() if not self.instantiated then self.instantiated=true; self:createChildren() end end
function Base:createChildren() end
function Base:addChild(child) self.children[#self.children+1]=child end
function Base:setVisible(v) self.visible=v end
function Base:getIsVisible() return self.visible end
function Base:addToUIManager() self:instantiate(); self.added=true end
function Base:removeFromUIManager() self.added=false end
function Base:bringToTop() self.fronted=(self.fronted or 0)+1 end
function Base:setX(v) self.x=v end
function Base:setY(v) self.y=v end
function Base:setWidth(v) self.width=v end
function Base:setHeight(v) self.height=v end
function Base:getWidth() return self.width end
function Base:getHeight() return self.height end
function Base:setEnable(v) self.enable=v end
function Base:setTitle(v) self.title=v end
function Base:setTooltip(v) self.tooltip=v end
function Base:drawRect() end
function Base:drawTextureScaled(tex) self.drawnTexture=tex end
function Base:drawText(text) self.draws[#self.draws+1]=text end
Base.drawTextCentre=Base.drawText
function Base:update() end
function Base:onMouseUp() self.moving=false end
Base.onMouseUpOutside=Base.onMouseUp
ISCollapsableWindow=Base:derive()
function ISCollapsableWindow:createChildren()
    for _,name in ipairs({"closeButton","collapseButton","pinButton","resizeWidget","resizeWidget2","infoButton"}) do
        self[name]=Base:new(0,0,10,10)
    end
end
ISButton=Base:derive()
function ISButton:new(x,y,w,h,title,target,callback)
    local b=Base.new(self,x,y,w,h); b.title,b.target,b.callback=title,target,callback; return b
end
ISScrollingListBox=Base:derive()
function ISScrollingListBox:new(x,y,w,h)
    local l=Base.new(self,x,y,w,h); l.items={}; l.vscroll=Base:new(0,0,1,1); return l
end
function ISScrollingListBox:clear() self.items={} end
RWMPanel=Base:derive()
function RWMPanel:readFromObject(p,d,data,kind) self.player,self.device,self.deviceData,self.deviceType=p,d,data,kind end
function RWMPanel:onJoypadDown() return false end
ISRadioWindow=Base:derive()
local originals=0
function ISRadioWindow:createChildren() originals=originals+1; self.modules=self.modules or {} end
function ISRadioWindow:addModule(module,title)
    self.modules[#self.modules+1]={module=module,title=title}; module:initialise(); module:instantiate()
end
for _,name in ipairs({"ISUI/ISCollapsableWindow","ISUI/ISScrollingListBox","ISUI/ISButton",
    "TimedActions/ISTimedActionQueue","TimedActions/WalkToTimedAction",
    "RadioCom/ISRadioWindow","RadioCom/RadioWindowModules/RWMPanel"}) do package.loaded[name]=true end
function sendClientCommand(p,module,command,args) packets[#packets+1]={player=p,module=module,command=command,args=args} end
local function reply(packet,balance,error)
    Events.OnServerCommand.fire("ApocWallet","BalanceState",{token=packet.args.token,onlineId=packet.player:getOnlineID(),
        status=error and "error" or "ready",balance=balance,error=error,updatedAt=now})
end

require("ApocWallet/Diagnostics").enabled = false
require "ApocWallet/ClientController"
require "ApocWallet/RadioEntryPoints"
local Controller=ApocWallet.RadioUIController
local Device=require "ApocWallet/RadioDevice"
local p=player(0,7)
local walkie=device("Radio")
local radioPanel=ISRadioWindow:new(0,0,300,400)
radioPanel:initialise(); radioPanel:instantiate()
check(originals==1 and #radioPanel.modules==1,"vanilla createChildren preserved and wallet module added")
radioPanel:createChildren()
check(#radioPanel.modules==1,"same window cannot gain a duplicate wallet module")
dofile(root .. "client/ApocWallet/UI/RadioWindowModule.lua")
dofile(root .. "client/ApocWallet/RadioEntryPoints.lua")
check(Events.OnFillInventoryObjectContextMenu.count()==1 and Events.OnResolutionChange.count()==1,"reload does not duplicate entry points")
local module=radioPanel.apocWalletModule
check(module:readFromObject(p,walkie,walkie:getDeviceData(),"InventoryItem"),"module captures native two-way radio")
check(not module:readFromObject(p,device("Radio",false),nil,"InventoryItem"),"one-way radio rejected")
check(Device.isRadio(device("VehiclePart")) and Device.kind(device("VehiclePart"))=="ham","native two-way vehicle device supported")
check(Device.kind(device("Radio",true,"Base.HamRadio1"))=="ham","inventory ham radio uses desktop shell")
module:readFromObject(p,walkie,walkie:getDeviceData(),"InventoryItem")
module:openWallet()
local win=Controller.windows[0]
check(win and win.added and win.kind=="walkie" and #win.list.items==0,"radio button opens independent skinned window with empty list")
check(win.status=="loading" and win.refreshButton.enable,"window shows pending operation with explicit retry available")
check(win.tex.path:find("ApocWallet/radio/walkie_standard_hd.png",1,true),"handheld HD texture selected")
check(win.closeButton.visible==false and win.walletCloseButton.visible,"source frame replaced with working wallet controls")
local same=Controller.open(p,walkie)
check(same==win and win.fronted==1,"opening again fronts the same per-player window")
Events.OnTick.fire()
check(#packets==1 and packets[1].command=="RefreshBalance","UI requests balance through actual wallet service")
reply(packets[1],15000)
check(win.status=="ready" and win.balanceText:find("15000",1,true),"server push updates visible balance")
check(win.refreshButton.enable and Events.OnTick.count()==0,"callback enables refresh and leaves no wallet tick handler")
win:setBalanceState({status="ready",balance=9007199254740991})
check(win.balanceText:find("9007199254740991",1,true),"integer credits retain full precision instead of scientific notation")
win:setBalanceState({status="ready",balance=15000})
local beforeClock,beforeMeasures,beforePackets=clockReads,measures,#packets
for _=1,100 do win:update(); win:prerender(); win:render() end
check(clockReads==beforeClock and measures==beforeMeasures and #packets==beforePackets,"render/update does not poll, read clocks or remeasure text")
check(win.drawnTexture==win.tex,"render uses copied skin")
for _=1,8 do win:nextSkin() end
check(win.L.skins[win.skinIndex]=="blackmarket","all nine ordinary handheld skins are selectable")
win:nextSkin(); check(win.skinIndex==1,"skin cycle wraps")
local cancelCount=0
local oldUnsubscribe=win.unsubscribe
win.unsubscribe=function() cancelCount=cancelCount+1; oldUnsubscribe() end
win:close(); win:close()
check(not win.added and win.closed and Controller.windows[0]==nil and cancelCount==1,"close removes UI and unsubscribes exactly once")
local cached=Controller.open(p,walkie)
check(cached.status=="ready" and cached.balanceText:find("15000",1,true),"synchronous cache callback works during open")
check(#packets==1 and not cached.refreshing,"cache hit starts no extra command and clears refreshing flag")
cached:close()
now=7000
local closed=Controller.open(p,walkie); Events.OnTick.fire(); local pendingPacket=packets[#packets]
closed:close()
local reopened=Controller.open(p,walkie)
reply(pendingPacket,9000)
check(reopened.status=="ready" and reopened.balanceText:find("9000",1,true),"reopened window joins shared pending request")
check(closed.status=="loading" and not closed.added,"old window never receives late balance callback")
now=13000
reopened.refreshButton.callback(reopened.refreshButton.target); Events.OnTick.fire()
reply(packets[#packets],nil,"HTTP_503")
check(reopened.status=="error" and reopened.balanceText=="Balance unavailable","backend failure is not displayed as zero")
now=19000; Controller.refresh(reopened); Events.OnTick.fire(); reply(packets[#packets],0)
check(reopened.balanceText:find("0",1,true) and reopened.status=="ready","actual zero balance is displayed")
local second=player(1,8)
local ham=Controller.open(second,device("IsoWaveSignal"))
check(ham and ham.kind=="ham" and ham.x>=width and ham.x+ham.width<=width*2,"desktop skin stays in second player's viewport")
Events.OnTick.fire(); reply(packets[#packets],42)
check(ham.balanceText:find("42",1,true) and reopened.balanceText:find("0",1,true),"split-screen balance updates remain isolated")
for _=1,7 do ham:nextSkin() end
check(ham.L.skins[ham.skinIndex]=="flag","eight desktop skin variants selectable")
width,height=640,480
Events.OnResolutionChange.fire()
check(reopened.width<=width and reopened.height<=height and reopened.x>=0 and reopened.x+reopened.width<=width,"resolution event reflows handheld skin")
check(ham.width<=width and ham.height<=height and ham.x>=width and ham.x+ham.width<=width*2,"resolution event reflows second-player desktop")
check(reopened.tex.path:find("_sd.png",1,true) and ham.tex.path:find("_sd.png",1,true),"small viewports switch both shells to SD artwork")
fontHeight=26; Events.OnResolutionChange.fire()
check(reopened.list.height>0 and ham.list.height>0 and reopened.fontHeight==26,"larger fonts retain positive empty-list geometry")
for _,button in ipairs({reopened.refreshButton,reopened.skinButton,reopened.walletCloseButton}) do
    check(button.x>=0 and button.x+button.width<=reopened.width and button.y+button.height<=reopened.height,
        "skinned button remains inside handheld bounds")
end
ham:setX(-500); ham:setY(9999); ham:onMouseUp(0,0)
check(ham.x>=width and ham.y+ham.height<=height,"drag release clamps inside owning viewport")
local options={}
local context={addOption=function(_,title,target,callback,arg) options[#options+1]={title=title,target=target,callback=callback,arg=arg} end}
Events.OnFillInventoryObjectContextMenu.fire(0,context,{{items={walkie}}})
check(#options==1 and options[1].arg==walkie,"inventory stack wrapper adds one wallet action")
options[1].callback(options[1].target,options[1].arg)
check(Controller.windows[0]==reopened,"context action reuses existing wallet window")
options={}; Events.OnFillWorldObjectContextMenu.fire(0,context,{device("IsoWaveSignal")},true)
check(#options==0,"world-menu test pass has no side effects")
Events.OnFillWorldObjectContextMenu.fire(0,context,{device("IsoWaveSignal")},false)
check(#options==1,"world radio also offers wallet action")
check(Controller.open(p,device("Radio",false))==nil and Controller.open(p,{kind="Food"})==nil,"nonradio/one-way objects cannot open wallet")
local replacement=player(0,7)
Events.OnCreatePlayer.fire(0,replacement)
check(reopened.closed and Controller.windows[0]==nil,"replacement character closes previous-life UI")
second.dead=true; Events.OnPlayerDeath.fire(second)
check(ham.closed and Controller.windows[1]==nil,"death closes only the matching player's wallet")
walkie.container=replacement.inventoryContainer
local final=Controller.open(replacement,walkie)
Events.OnDisconnect.fire()
check(final.closed and next(Controller.windows)==nil,"disconnect removes all wallet windows")
check(RadioTraders==nil and RTTradeWindow==nil and RTSkinWindow==nil,"no RadioTraders runtime dependency loaded")
print("Passed " .. checks .. " wallet radio UI assertions (actual wallet Lua; mocked native widgets/network).")

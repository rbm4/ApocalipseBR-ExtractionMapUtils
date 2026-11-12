require 'ApocWallet/Protocol'
if ApocWallet.RadioDialogue then return ApocWallet.RadioDialogue end
local D={}; D.__index=D
ApocWallet.RadioDialogue=D
function D.new(player,radio)
    return setmetatable({player=player,radio=radio,queue={},history={},nextLine=0,lastPage=-10000,talkingUntil=0,sounds={}},D)
end
function D:sound(name)
    local ok,id=pcall(function() return self.player:getEmitter():playSound('ApocWallet_'..name) end)
    if ok and id then
        self.sounds[#self.sounds+1]=id
        if name=='Static' then self.static=id end
        if #self.sounds>32 then table.remove(self.sounds,1) end
    end
end
function D:stopTuning()
    if self.static then pcall(function() self.player:getEmitter():stopSound(self.static) end); self.static=nil end
end
function D:enqueue(speaker,key,args)
    if #self.queue>=24 then return end
    self.queue[#self.queue+1]={speaker=speaker,key=key,args=args or {}}
end
function D:page(mode,page)
    local t=getTimestampMs()
    if t-self.lastPage<5000 then return end
    self.lastPage=t
    self:enqueue('player','UI_ApocWallet_MarketPageTxFmt',{page})
    return true
end
function D:update()
    local t=getTimestampMs()
    if t<self.nextLine or #self.queue==0 then return end
    self.nextLine=t+1400
    local line=table.remove(self.queue,1)
    local a=line.args
    local text=getText(line.key,a[1],a[2],a[3],a[4])
    self.history[#self.history+1]={speaker=line.speaker,text=text}
    if #self.history>12 then table.remove(self.history,1) end
    if line.speaker=='player' then self.player:Say(text)
    else
        self.talkingUntil=t+1600
        self:sound('Squelch')
        -- Native device speech; text remains in the radio log if the device
        -- cannot currently emit (for example, after the player moves away).
        pcall(function() self.radio:AddDeviceText(text,0.45,1,0.65,nil,nil,0) end)
    end
    if self.onLine then self.onLine(self.history) end
end
function D:close()
    self.queue={}
    pcall(function()
        local emitter=self.player:getEmitter()
        for _,id in ipairs(self.sounds) do emitter:stopSound(id) end
    end)
    self.sounds={}
end
return D

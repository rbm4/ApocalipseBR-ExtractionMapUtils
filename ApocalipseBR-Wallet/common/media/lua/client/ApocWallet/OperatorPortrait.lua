require 'ApocWallet/Protocol'
if ApocWallet.OperatorPortrait then return ApocWallet.OperatorPortrait end
local Portrait={frames={}}
ApocWallet.OperatorPortrait=Portrait
function Portrait.load()
    if Portrait.loaded then return end
    Portrait.loaded=true
    for i=0,15 do Portrait.frames[i+1]=getTexture(string.format('media/textures/ApocWallet/operator/control_%02d.png',i)) end
end
function Portrait.draw(ui,x,y,w,h,state,talkingUntil)
    Portrait.load()
    local t=getTimestampMs()
    ui:drawRect(x,y,w,h,1,0.02,0.04,0.03)
    if state=='connected' then
        local index=t<(talkingUntil or 0) and math.floor(t*8/1000)%16+1 or 1
        local tex=Portrait.frames[index] or Portrait.frames[1]
        if tex then ui:drawTextureScaled(tex,x,y,w,h,1,0.85,1,0.85) end
    end
    -- RadioTraders' scan-line treatment, bounded and deterministic.
    local scan=math.floor(t/35)%math.max(1,math.floor(h))
    ui:drawRect(x,y+scan,w,1,0.16,0.65,1,0.7)
    if state~='connected' then
        for i=1,8 do
            local row=(math.floor(t/60)+i*17)%math.max(1,math.floor(h))
            ui:drawRect(x,y+row,w,1,0.18,0.6,0.8,0.6)
        end
    end
end
return Portrait

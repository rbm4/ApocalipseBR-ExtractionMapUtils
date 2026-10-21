package.path="ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/?.lua;"..package.path
local checks=0
local function check(v,message) checks=checks+1;assert(v,message) end
local function derive(base)
    local result={};result.__index=result;setmetatable(result,{__index=base})
    function result:derive() return derive(self) end
    return result
end
ISPanel=derive({})
function ISPanel.new(class,x,y,w,h) return setmetatable({width=w,height=h,children={}},class) end
function ISPanel:createChildren() end
function ISPanel:addChild(child) self.children[child]=true end
function ISPanel:removeChild(child) self.children[child]=nil end
function ISPanel:setHeight(height) self.height=height end
function ISPanel:removeFromUIManager() self.removed=true end
ISButton={new=function(_,x,y,w,h,title,target,callback)
    return {title=title,y=y,initialise=function() end,setY=function(self,y) self.y=y end,
        setEnable=function(self,v) self.enabled=v end,click=function() callback(target) end}
end}
ISLabel={new=function() return {} end}
ISRichTextPanel={new=function() return {initialise=function() end,addScrollBars=function() end,paginate=function() end} end}
for _,name in ipairs({"ISUI/ISPanel","ISUI/ISButton","ISUI/ISLabel","ISUI/ISRichTextPanel"}) do package.loaded[name]=true end
UIFont={Medium=1}
function getPlayerScreenLeft() return 0 end
function getPlayerScreenWidth() return 1280 end
function getPlayerScreenTop() return 0 end
function getText(key) return key end
local locale="EN"
Translator={getLanguage=function() return {name=function() return locale end} end}
dofile("ApocalipseBR-ExtractionMapUtils/common/media/lua/client/ApocExtractionMapUtils_HumanDialogPanel.lua")
local options={{id="ask",texts={EN={title="Ask",description="Ask about the docks."},PTBR={title="Perguntar",description="Pergunte sobre as docas."}}}}
local chosen
local panel=ApocHumanDialogPanel:new({getPlayerNum=function() return 0 end},"Guide",options,nil,function(id) chosen=id end,function() end)
panel:createChildren()
check(panel.buttons[1].title=="Ask" and panel.buttons[1].tooltip=="Ask about the docks.","database title and description render independently")
panel.buttons[1].click();check(chosen=="ask","dynamic button submits stable option ID")
locale="PTBR"
panel:setNode(options,{EN={title="Welcome",description="English"},PTBR={title="Bem-vindo",description="Descrição do diálogo"}},"EN")
panel:setResponse("Resposta do NPC")
check(panel.buttons[1].title=="Perguntar" and panel.buttons[1].tooltip=="Pergunte sobre as docas.","Portuguese option labels use cached locale text")
check(panel.message.text:find("Bem-vindo",1,true) and panel.message.text:find("Descrição do diálogo",1,true)
    and panel.message.text:find("Resposta do NPC",1,true),"node title, description and NPC response are visible")
panel:setPending(true);check(panel.buttons[1].enabled==false,"pending choices disabled")
local tipRemoved=false
panel.buttons[1].tooltipUI={removeFromUIManager=function() tipRemoved=true end}
panel:setNode({}, {EN={title="Done",description="Finished"}},"EN")
check(tipRemoved and #panel.buttons==0 and panel.height==190,"terminal nodes resize and release stale tooltip UI")
check(panel.message.text:find("Done",1,true),"missing locale uses configured fallback")
locale="EN"
panel:setResolvedNode({{id="pt",title="Perguntar",description="Texto do servidor"}}, {title="Servidor",description="Idioma PTBR"})
panel:setResponse("Resposta do servidor")
check(panel.buttons[1].title=="Perguntar" and panel.buttons[1].tooltip=="Texto do servidor","English client renders resolved server labels unchanged")
check(panel.message.text:find("Resposta do servidor",1,true),"server response is displayed without client translation")
local serverPanel=ApocHumanDialogPanel:new({getPlayerNum=function() return 0 end},"NPC",{},nil,function() end,function() end,{close="Encerrar conversa"})
serverPanel:createChildren()
check(serverPanel.closeButton.title=="Encerrar conversa","server controls dialogue interface labels on an English client")
panel:removeFromUIManager();check(panel.removed,"panel closes through native UI base")
print("Passed "..checks.." dialogue panel localization, descriptions, advancement and cleanup assertions.")

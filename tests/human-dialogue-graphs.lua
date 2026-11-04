package.path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/server/?.lua;" .. package.path
package.path = "ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/?.lua;" .. package.path
local count, now, sent = 0, 1000, {}
local function check(v, message) count=count+1; assert(v,message) end
local function event()
    local e={callbacks={}}
    function e.Add(fn) e.callbacks[#e.callbacks+1]=fn end
    function e.fire(...) for _,fn in ipairs(e.callbacks) do fn(...) end end
    return e
end
Events={OnClientCommand=event(),OnTick=event(),OnApocBRHumanDialogueClosed=event(),OnApocBRHumanRosterChanged=event()}
function isServer() return true end
function getTimestampMs() return now end
local player={getOnlineID=function() return 1 end}
function getPlayerByOnlineID() return player end
function sendServerCommand(p,module,command,args) sent[#sent+1]={command=command,args=args} end
local G=require "ApocExtractionMapUtils_HumanDialogueGraph"
local W=require "ApocExtractionMapUtils_HumanDialogueWire"
local function texts(title,response)
    return {EN={title=title,description="Details",response=response or "Answer",speech="Spoken answer"},
        PTBR={title="Título",description="Descrição",response="Resposta",speech="Fala"}}
end
local graph={id="quest",revision=1,entryNode="root",fallbackLocale="EN",nodes={
    root={id="root",texts=texts("Welcome"),options={
        {id="ask",nextNode="more",setFlag="trusted",texts=texts("Ask")},
        {id="secret",nextNode="secret",requiredFlag="trusted",texts=texts("Hidden title","Hidden answer")}}},
    more={id="more",texts=texts("More"),options={{id="back",nextNode="root",texts=texts("Back")}}},
    secret={id="secret",texts=texts("Secret room"),options={{id="end",nextNode="root",close=true,texts=texts("Goodbye")}}}
}}
local public=G.public(G.prepare(graph),"root",{})
check(#public.nodes.root.options==1 and public.nodes.secret==nil,"secret content absent from public graph")
check(public.nodes.root.options[1].setFlag==nil,"condition/effect details stay server-only")
check(public.nodes.more~=nil,"public future nodes included for graph navigation")
check(G.text(texts("English"),"missing","EN").title=="English","unsupported locale falls back")

local database={database=true,ready=false,generation=1}
local actor={id=1024,key="guide",name="Guide",profileId="lobby-guide"}
local resolved={schema=2,id="quest",revision=1,entryNode="root",rootNode="root",locale="PTBR",nodes={
    root={id="root",text={title="Servidor",description="Texto"},options={{id="ask",title="Perguntar",description="Detalhes"}}}}}
local begins, selections, lastSelection=0,0,nil
ApocBRHumanAPI={version=4,dialogues=function() return database end,roster=function() return {actor} end,
    text=function(key) return key end,
    dialogueRoster=function(p) return {{id=1024,key="guide",name="Guide",dialogue=resolved,options=resolved.nodes.root.options}} end,
    dialogueBegin=function(p,id,revision,node,option)
        if revision~=1 or node~="root" or option~="ask" then return {error="unavailable"} end
        begins=begins+1;return {id=id,key="guide",name="Guide",token=8}
    end,
    arrive=function() return true end,
    dialogueView=function() return resolved end,
    dialogueSelect=function(...)
        local a={...};selections=selections+1;lastSelection=a
        return {sequence=a[7],option=a[6],response="Resposta do servidor",dialogue=resolved,close=false}
    end,
    finish=function() Events.OnApocBRHumanDialogueClosed.fire(player,{id=1024,token=8});return true end}
dofile("ApocalipseBR-ExtractionMapUtils/common/media/lua/server/ApocExtractionMapUtils_HumanDialogsServer.lua")
local D=ApocExtractionMapUtils.HumanDialogs
local function command(command,args)
    now=now+600;Events.OnClientCommand.fire(D.MODULE,"Human"..command,player,args)
end
command("List",{})
check(#sent==0,"startup waits for engine content")
database.ready=true;Events.OnTick.fire()
local roster=sent[#sent].args.actors
check(#roster==1 and roster[1].options[1].title=="Perguntar","roster forwards server-resolved labels")
check(roster[1].options[1].texts==nil,"no multilingual dictionary is sent to clients")
command("Begin",{id=1024,request=1,option="secret",node="root",dialogueRevision=1})
check(begins==0,"engine rejection cannot reserve a session")
command("Begin",{id=1024,request=2,option="ask",node="root",dialogueRevision=99})
check(begins==0,"stale revision is rejected through engine API")
command("Begin",{id=1024,request=3,option="ask",node="root",dialogueRevision=1,locale="EN",speech="Injected"})
check(begins==1 and selections==0,"reservation has no speech side effects")
command("Arrive",{id=1024,token=8})
check(selections==1 and sent[#sent].command=="HumanSelected","arrival routes initial option through engine")
check(#lastSelection==7 and lastSelection[1]==player and lastSelection[6]=="ask","API receives authenticated actor and option identifiers, no locale or speech")
local selected=sent[#sent].args
local _,contents=W.receive(nil,selected.contentFrame)
check(contents[1].dialogue.nodes.root.text.title=="Servidor" and selected.response=="Resposta do servidor","node and response arrive already resolved")
command("Select",{id=1024,token=9,sequence=2,option="ask",node="root",dialogueRevision=1})
check(selections==1,"foreign token never reaches engine")
command("Select",{id=1024,token=8,sequence=2,option="ask",node="root",dialogueRevision=1,locale="EN",nextNode="forged"})
check(selections==2 and #lastSelection==7 and lastSelection[4]=="root","Lua forwards only identifiers; progression is engine-owned")
command("Close",{id=1024,token=8})
check(sent[#sent].command=="HumanClosed","engine close event releases Lua session")

local D = ApocExtractionMapUtils.HumanDialogs
local commits, cancels, completions = 0, 0, 0
D.registerAction("test.action", function(ctx)
    check(ctx.player==player and ctx.npcKey=="guide", "handler receives authenticated server context")
    return {success=true,responsePool="test.result.success",close=true,
        afterResponse=function() commits=commits+1 end, cancel=function() cancels=cancels+1 end}
end)
ApocBRHumanAPI.dialogueSelect=function()
    return {action={id="test.action",responsePrefix="test.result"},option="ask",sequence=1}
end
ApocBRHumanAPI.dialogueComplete=function(p,id,token,result)
    check(commits==0 and result.responsePool=="test.result.success", "effect waits for pooled NPC response")
    completions=completions+1
    return {dialogue=resolved,option="ask",sequence=1,response="Pooled speech",close=true}
end
command("Begin",{id=1024,request=3,dialogueRevision=1,node="root",option="ask"})
command("Arrive",{id=1024,token=8})
check(completions==1 and commits==1 and cancels==0, "accepted callback completes response then executes once")
command("Select",{id=1024,token=8,sequence=1,option="ask",node="root",dialogueRevision=1})
check(commits==1, "closed lease cannot execute action again")
now=now+1000
ApocBRHumanAPI.dialogueComplete=function() return {error="unavailable"} end
command("Begin",{id=1024,request=4,dialogueRevision=1,node="root",option="ask"})
command("Arrive",{id=1024,token=8})
check(commits==1 and cancels==1, "failed completion cancels prepared effect")
now=now+1000
local failureLog
local operationLog=ApocExtractionMapUtils.logOperation
ApocExtractionMapUtils.logOperation=function(message) failureLog=message end
D.registerAction("test.after_error",function()
    return {success=true,responsePool="test.result.success",close=true,
        afterResponse=function() error("after response test failure") end,
        cancel=function() cancels=cancels+1 end}
end)
ApocBRHumanAPI.dialogueSelect=function() return {action={id="test.after_error",responsePrefix="test.result"},option="ask",sequence=1} end
ApocBRHumanAPI.dialogueComplete=function() return {dialogue=resolved,option="ask",sequence=1,response="Ready",close=true} end
command("Begin",{id=1024,request=5,dialogueRevision=1,node="root",option="ask"})
command("Arrive",{id=1024,token=8})
check(cancels==2 and failureLog:find("AFTER_RESPONSE_FAILED",1,true) and failureLog:find("after response test failure",1,true), "post-response exceptions are logged and cancel reservations")
ApocExtractionMapUtils.logOperation=operationLog

-- Large UTF-8 content splits into bounded frames and installs atomically.
local actors={}
for i=1,18 do
    local copy=G.public(G.prepare(graph),"root",{})
    copy.nodes.root.texts={EN={title="Title",description=string.rep("á",600)}}
    actors[i]={id=i,key="npc"..i,name="NPC",dialogue=copy,options=copy.nodes.root.options}
end
local frames=W.pack(actors,50)
check(#frames>1,"large roster uses multipart HumanList")
local pending,result
for i=#frames,1,-1 do
    check(W.size(frames[i])<W.MAX_FRAME,"frame remains within byte budget")
    pending,result=W.receive(pending,frames[i])
    if i>1 then check(result==nil,"partial payload never replaces live roster") end
end
check(result and #result==18 and result[1].dialogue.nodes.more~=nil,"out-of-order frames reconstruct complete graph")
local resolvedActors={}
for i=1,30 do
    resolvedActors[i]={id=i,key="npc"..i,name="NPC",dialogue={schema=2,id="guide",revision=1,entryNode="root",rootNode="root",locale="PTBR",
        labels={talk="Conversar com %1",close="Encerrar conversa"},
        nodes={root={id="root",text={title="Servidor",description=string.rep("a",1500)},options={{id="ask",title="Perguntar",description="Detalhes"}}}}}}
end
local resolvedFrames=W.pack(resolvedActors,60)
check(#resolvedFrames>1,"resolved single-language views also use bounded multipart transport")
local resolvedPending,resolvedResult
for i=#resolvedFrames,1,-1 do resolvedPending,resolvedResult=W.receive(resolvedPending,resolvedFrames[i]) end
check(resolvedResult[1].dialogue.nodes.root.text.title=="Servidor" and resolvedResult[1].dialogue.labels.close=="Encerrar conversa",
    "multipart reconstruction preserves resolved text and server interface labels")
pending=W.receive(nil,frames[1]);local before=pending.count
pending=W.receive(pending,frames[1]);check(pending.count==before,"duplicate part ignored")
local invalid={part=1,parts=999,revision=51,records={}}
check(W.receive(nil,invalid)==nil,"excessive part count rejected")
print("Passed "..count.." database dialogue graph, secret filtering, branching, sessions and framing assertions.")

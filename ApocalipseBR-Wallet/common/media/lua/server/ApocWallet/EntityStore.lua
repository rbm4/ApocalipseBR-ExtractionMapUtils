if not isServer() then return end
require 'ApocWallet/Protocol'
local Entities=require 'ApocBR/Entities'
if ApocWallet.EntityStore then return ApocWallet.EntityStore end
local S={queue={},keys={},nextAttempt=0,status='loading'}
ApocWallet.EntityStore=S
local function log(status) if S.lastLog~=status then S.lastLog=status; print('[ApocWallet/Entities] '..status) end end
function S.data()
    if not S.root then error('PERSISTENCE_NOT_READY') end
    return S.root
end
function S.ready() return S.status=='ready' end
-- Wallet-owned per-object metadata shares the same scoped database checkpoint.
-- The native item table is only the replicated marker used by world retries.
function S.modData(kind,id)
    local root=S.data(); root.itemData=root.itemData or {}
    local key=kind..':'..id
    root.itemData[key]=root.itemData[key] or {kind=kind,objectId=id,values={}}
    return root.itemData[key].values
end
local function encode() return Entities.encode(S.root) end
local function complete(task,ok,reason)
    S.keys[task.key]=nil; S.active=nil
    if not ok then
        if S.committed then S.root=Entities.decode(S.committed) end
        if task.onError then task.onError(reason) else log('OPERATION_FAILED '..tostring(reason)) end
    end
end
local function resume(task)
    local ok,reason=coroutine.resume(task.thread)
    if not ok then complete(task,false,reason)
    elseif coroutine.status(task.thread)=='dead' then complete(task,true) end
end
function S.run(key,operation,onError)
    if S.keys[key] then return false end
    if not S.ready() and onError then onError('PERSISTENCE_NOT_READY'); return false end
    if #S.queue>=128 then if onError then onError('PERSISTENCE_BUSY') end; return false end
    local task={key=key,thread=coroutine.create(operation),onError=onError}
    S.keys[key]=task; S.queue[#S.queue+1]=task
    return true
end
local function save(task)
    task.retryAt=getTimestampMs()+5000; task.inflight=true
    local ok,error=pcall(function()
        S.entity:set('payload',task.payload)
        S.entity:save(function(result)
            task.inflight=false
            if result.status=='OK' then task.ack=true
            elseif result.status=='CONFLICT' or result.status=='OUTCOME_UNKNOWN' then
                -- Lost commit acknowledgment: accept only the identical snapshot.
                S.repository:find(S.scope,function(found)
                    if found.status=='OK' and found.entity:get('payload')==task.payload then S.entity=found.entity; task.ack=true
                    else task.failure='PERSISTENCE_CONFLICT' end
                end)
                task.inflight=true
            elseif result.status~='BUSY' and result.status~='UNAVAILABLE' then task.failure='PERSISTENCE_'..tostring(result.status) end
        end)
    end)
    if not ok then task.inflight=false; task.failure='PERSISTENCE_'..tostring(error) end
end
function S.persist()
    local task=S.active
    if not task or coroutine.running()~=task.thread then error('PERSISTENCE_TRANSACTION_REQUIRED') end
    local payload=encode()
    if payload==S.committed then return end
    task.payload=payload; save(task)
    coroutine.yield()
end
local function bootstrap()
    if S.loading or getTimestampMs()<S.nextAttempt then return end
    S.nextAttempt=getTimestampMs()+5000; S.loading=true
    local function fail(result) S.loading=false; log('LOAD_'..tostring(result.status)) end
    local ok,error=pcall(function()
        if not S.repository then
            S.repository=Entities.define('ApocWallet.State', {table='wallet_mod_data',fields={
                server_id={type='integer',id=true},world={type='string',id=true},record_id={type='string',id=true},payload={type='text'},
            }})
        end
        local scope=Entities.serverScope()
        S.scope={server_id=scope.server_id,world=scope.world,record_id='global:ApocWallet.Couriers.v1'}
        S.repository:find(S.scope,function(result)
            if result.status=='OK' then
                local decoded,root=pcall(Entities.decode,result.entity:get('payload'))
                if not decoded then fail({status='INVALID_PAYLOAD'}); return end
                S.root=root; S.entity=result.entity; S.committed=result.entity:get('payload')
            elseif result.status=='NOT_FOUND' then
                -- Read-only one-time legacy import, only when no scoped SQL row exists.
                local legacy=ModData and ModData.get and ModData.get('ApocWallet.Couriers.v1')
                S.root=legacy and Entities.decode(Entities.encode(legacy)) or {}
                S.committed=nil
                local values={server_id=S.scope.server_id,world=S.scope.world,record_id=S.scope.record_id,payload=Entities.encode(S.root)}
                S.entity=S.repository:new(values)
                S.entity:save(function(written)
                    if written.status~='OK' then fail(written); return end
                    S.committed=values.payload
                    S.loading=false; S.status='ready'; log('READY')
                end)
                return
            else fail(result); return end
            S.loading=false; S.status='ready'; log('READY')
        end)
    end)
    if not ok then fail({status=error}) end
end
function S.update()
    if not S.ready() then bootstrap(); return end
    for _=1,4 do
        local task=S.active
        if not task then
            task=table.remove(S.queue,1)
            if not task then return end
            S.active=task; resume(task)
        elseif task.failure then
            S.status='blocked'; log(task.failure); complete(task,false,task.failure); return
        elseif task.ack then
            S.committed=task.payload; task.payload=nil; task.ack=nil; task.inflight=false; resume(task)
        elseif task.payload then
            if not task.inflight and getTimestampMs()>=(task.retryAt or 0) then save(task) end
            return
        else return end
    end
end
Events.OnServerStarted.Add(bootstrap)
Events.OnTickEvenPaused.Add(S.update)
return S

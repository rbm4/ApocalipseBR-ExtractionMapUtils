MakeshiftRaft = MakeshiftRaft or {}
MakeshiftRaft.prefix = "MRK"
local getCore = getCore

MakeshiftRaft.keyControlClient = {}
local function getPlayerKeyStore(playerObj)
    local pk = playerObj and playerObj:getUsername()
    if not pk then return nil end
    local ks = MakeshiftRaft.keyControlClient[pk]
    if not ks then
        MakeshiftRaft.keyControlClient[pk] = {}
        ks = MakeshiftRaft.keyControlClient[pk]
    end
    return ks
end

local function getKeyBinding2POD(core, keyCore)
    return {k = core:getKey(keyCore), j = core:getAltKey(keyCore)}--we got no way to get shift ctrl alt from core (but we could parse lua keyBinding struct)
end

local function serializeKeyBinding2POD(playerObj, core, keyCore, clearCore)
    local keyPlayer = MakeshiftRaft.prefix..keyCore
    local ks = getPlayerKeyStore(playerObj)
    if not ks then return end
    ks[keyPlayer] = getKeyBinding2POD(core,keyCore)
    if clearCore then
        core:addKeyBinding(keyCore, Keyboard.KEY_NONE, Keyboard.KEY_NONE, false, false, false)
    end
end

local function deserializePOD2KeyBinding(core, keyCore, playerObj, consumeMD)
    local key = Keyboard.KEY_NONE
    local altKey = Keyboard.KEY_NONE
    local shiftB = false
    local ctrl = false
    local alt = false
    local keyPlayer = MakeshiftRaft.prefix..keyCore
    local ks = getPlayerKeyStore(playerObj)
    if not ks then return end
    local md = ks[keyPlayer]
    if md then
        key = md.k or key
        altKey = md.j or altKey
        shiftB = md.s or shiftB
        ctrl = md.c or ctrl
        alt = md.a or alt
        if consumeMD then ks[keyPlayer] = nil end
    end
    local keyBefore = core:getKey(keyCore)
    --print('Reload key binding '..tostring(keyCore)..' '..tostring(key))
    core:addKeyBinding(keyCore, key, altKey, shiftB, ctrl, alt)
end

function MakeshiftRaft.getRaftInteractionControl(playerObj)
    local ks = getPlayerKeyStore(playerObj)
    return ks and ks[MakeshiftRaft.prefix.."Interact"]
end

function MakeshiftRaft.isRaftKeyInteraction(playerObj, key)
    return MakeshiftRaft.isRaftKey(playerObj, "Interact", key)
end

function MakeshiftRaft.isRaftKeyForward(playerObj, key)
    return MakeshiftRaft.isRaftKey(playerObj, "Forward", key)
end

function MakeshiftRaft.isRaftKeyBackward(playerObj, key)
    return MakeshiftRaft.isRaftKey(playerObj, "Backward", key)
end
function MakeshiftRaft.isRaftKey(playerObj, keyStr, key)
    local ks = getPlayerKeyStore(playerObj)
    if not ks then return end
    local keyBinding = keyStr and ks[MakeshiftRaft.prefix..keyStr]
    return keyBinding and (keyBinding.k == key or keyBinding.j == key)
end

function MakeshiftRaft.hasRaftControl(playerObj)
    local core = getCore()
    local keyCore = "Interact"
    local result = core:getKey(keyCore)== Keyboard.KEY_NONE and core:getAltKey(keyCore)==Keyboard.KEY_NONE
    --print ('MakeshiftRaft.hasRaftControl Interact: '..tostring(core:getKey(keyCore))..' '..tostring(core:getAltKey(keyCore))..' '..tostring(result))
    return result--this would break with players having no key there
end

MakeshiftRaft.inhibitedControlKeys = {
"Forward" ,
"Backward",
"Left"    ,
"Right"   ,
"Run"     ,
"Interact",
"Sprint"
}

function MakeshiftRaft.activateRaftControl(playerObj)
    if MakeshiftRaft.hasRaftControl(playerObj) then
        return false
    end
    local core = getCore()
    for itKeys = 1, #MakeshiftRaft.inhibitedControlKeys do
        serializeKeyBinding2POD(playerObj, core, MakeshiftRaft.inhibitedControlKeys[itKeys], true)
    end
    --print ('MakeshiftRaft.activateRaftControl '..'lose Core keybinds')
    return true
end

function MakeshiftRaft.deactivateRaftControl(playerObj)
    if not MakeshiftRaft.hasRaftControl(playerObj) then return false end
    local core = getCore()
    for itKeys = 1, #MakeshiftRaft.inhibitedControlKeys do
        deserializePOD2KeyBinding(core, MakeshiftRaft.inhibitedControlKeys[itKeys], playerObj, true)
    end
    --print ('MakeshiftRaft.activateRaftControl '..'retrieve Core keybinds')
    return true
end


function MakeshiftRaft.OnKeyStartPressed(key)
    local playersNb = getNumActivePlayers()
    for playerNum = 0, playersNb - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            if MakeshiftRaft.isRaftKeyInteraction(playerObj, key) then
                MakeshiftRaft.OnRaftInteraction(playerObj)
            end
        end
    end
end

function MakeshiftRaft.OnKeyKeepPressed(key)
    local playersNb = getNumActivePlayers()
    for playerNum = 0, playersNb - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            if MakeshiftRaft.isRaftKeyForward(playerObj, key) then
                MakeshiftRaft.OnRaftForward(playerObj)
            elseif MakeshiftRaft.isRaftKeyBackward(playerObj, key) then
                MakeshiftRaft.OnRaftBackward(playerObj)
            end
        end
    end
end

Events.OnKeyStartPressed.Add(MakeshiftRaft.OnKeyStartPressed)--todo activate once we got some action to do on the raft (fishing ?)
Events.OnKeyKeepPressed.Add(MakeshiftRaft.OnKeyKeepPressed)--todo activate once we got some action to do on the raft (fishing ?)

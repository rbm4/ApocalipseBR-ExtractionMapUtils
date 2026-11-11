require "ApocWallet/ClientService"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/WalkToTimedAction"
local Device = require "ApocWallet/RadioDevice"
local Window = require "ApocWallet/UI/RadioWindow"
if ApocWallet.RadioUIController then return ApocWallet.RadioUIController end
local Controller = { windows = {}, approaches = {} }
ApocWallet.RadioUIController = Controller

local function current(win)
    return Controller.windows[win.playerIndex] == win and getSpecificPlayer(win.playerIndex) == win.player
        and not win.player:isDead() and not win.closed
end

function Controller.close(win)
    if not win or win.closed then return end
    win.closed = true
    if win.unsubscribe then win.unsubscribe(); win.unsubscribe = nil end
    if Controller.windows[win.playerIndex] == win then Controller.windows[win.playerIndex] = nil end
    win:setVisible(false); win:removeFromUIManager()
end

function Controller.refresh(win)
    if not current(win) then return end
    if not Device.isRadio(win.radio) or not Device.canUse(win.player,win.radio) then Controller.close(win); return end
    if win.unsubscribe then win.unsubscribe(); win.unsubscribe = nil end
    win.generation = (win.generation or 0) + 1
    local generation = win.generation
    win.refreshing = true
    win:setBalanceState({status="loading"})
    local unsubscribe = ApocWallet.ClientService.refreshBalance(win.playerIndex,function(result)
        if not current(win) or win.generation ~= generation then return end
        if not Device.isRadio(win.radio) or not Device.canUse(win.player,win.radio) then Controller.close(win); return end
        win.refreshing = false
        if result.error == "CANCELLED" then Controller.close(win); return end
        win:setBalanceState(result)
    end)
    -- A cache hit can invoke the callback before refreshBalance returns.
    if current(win) and win.generation == generation then win.unsubscribe = unsubscribe else unsubscribe() end
end

local function approach(player,radio)
    local index = player:getPlayerNum()
    local old = Controller.approaches[index]
    if old and old.player == player and old.radio == radio and ISTimedActionQueue.hasAction(old.action) then return end
    local square = Device.square(radio)
    if not square or player:getVehicle() then return end
    local adjacent = AdjacentFreeTileFinder.Find(square,player)
    if not adjacent then return end
    -- Native interaction semantics: selecting this walk replaces current queued actions.
    ISTimedActionQueue.clear(player)
    local action = ISWalkToTimedAction:new(player,adjacent)
    local token = {player=player,radio=radio,action=action}
    Controller.approaches[index] = token
    local originalStop = action.stop
    function action:stop()
        if Controller.approaches[index] == token then Controller.approaches[index] = nil end
        originalStop(self)
    end
    action:setOnComplete(function()
        if Controller.approaches[index] ~= token then return end
        Controller.approaches[index] = nil
        if getSpecificPlayer(index) == player and not player:isDead()
            and Device.isRadio(radio) and Device.canUse(player,radio) then Controller.open(player,radio) end
    end)
    ISTimedActionQueue.add(action)
    if not ISTimedActionQueue.hasAction(action) and Controller.approaches[index] == token then
        Controller.approaches[index] = nil
    end
end

function Controller.open(player, radio)
    if not isClient() or not player or player:isDead() or getSpecificPlayer(player:getPlayerNum()) ~= player
        or not Device.isRadio(radio) then return nil end
    if not Device.canUse(player,radio) then approach(player,radio); return nil end
    local index = player:getPlayerNum()
    local existing = Controller.windows[index]
    Controller.approaches[index] = nil
    if existing and current(existing) and Device.canUse(player,existing.radio) then
        existing:setVisible(true); existing:clampToScreen(); existing:bringToTop()
        return existing
    end
    if existing then Controller.close(existing) end
    local win = Window:new(player,radio,Device.kind(radio),{refresh=Controller.refresh,close=Controller.close})
    Controller.windows[index] = win
    win:initialise(); win:addToUIManager(); win:clampToScreen()
    Controller.refresh(win)
    return win
end

function Controller.closePlayer(player)
    local pending = player and Controller.approaches[player:getPlayerNum()]
    if pending and pending.player == player then Controller.approaches[player:getPlayerNum()] = nil end
    local win = player and Controller.windows[player:getPlayerNum()]
    if win and win.player == player then Controller.close(win) end
end

function Controller.closeAll()
    Controller.approaches = {}
    for _,win in pairs(Controller.windows) do Controller.close(win) end
end

function Controller.reflowAll()
    for _,win in pairs(Controller.windows) do
        if current(win) then win:reflow() else Controller.close(win) end
    end
end

return Controller

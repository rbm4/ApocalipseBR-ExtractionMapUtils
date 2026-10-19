--require 'ISUI/ISEmoteRadialMenu'
local ISEmoteRadialMenu_fillMenu_old = ISEmoteRadialMenu.fillMenu
local memoEmoteMRAnchorUpIcon = nil
local memoEmoteMRAnchorDnIcon = nil

local function initEmoteMRAnchor()
    memoEmoteMRAnchorUpIcon = getTexture('media/ui/boats/RadialMenu_AnchorUp.png');
    memoEmoteMRAnchorDnIcon = getTexture('media/ui/boats/RadialMenu_AnchorDown.png');
end


function ISEmoteRadialMenu:fillMenu(submenu)
    self:handleMRRadialOptions(submenu)

    ISEmoteRadialMenu_fillMenu_old(self, submenu)
end

function ISEmoteRadialMenu:handleMRRadialOptions(submenu)
    if not MakeshiftRaft.isOnWater(self.character) then return end
    local raft = MakeshiftRaft.getEquippedRaft(self.character)
    if not raft then return end
    
    if MakeshiftRaft.isAnchorDown(self.character) then
        if not memoEmoteMRAnchorDnIcon then initEmoteMRAnchor() end
        ISEmoteRadialMenu.menu[MakeshiftRaft.anchorKey] = {name=getText('IGUI_Emote_MRAnchorDn')}
        ISEmoteRadialMenu.icons[MakeshiftRaft.anchorKey] = memoEmoteMRAnchorDnIcon
    else
        --todo show anchor cannot be dropped with too much wind
        if not memoEmoteMRAnchorUpIcon then initEmoteMRAnchor() end
        ISEmoteRadialMenu.menu[MakeshiftRaft.anchorKey] = {name=getText('IGUI_Emote_MRAnchorUp')}
        ISEmoteRadialMenu.icons[MakeshiftRaft.anchorKey] = memoEmoteMRAnchorUpIcon
    end
end

local upperLayerEmote = ISEmoteRadialMenu.emote
function ISEmoteRadialMenu:emote(emote)
    --print("emote = ".. (emote or ""))
    if emote == MakeshiftRaft.anchorKey then
        local isDown = MakeshiftRaft.isAnchorDown(self.character)
        MakeshiftRaft.setAnchorState(self.character, not isDown)--toggle
        --upperLayerEmote(self, emote)
    else
        upperLayerEmote(self, emote)
    end
end
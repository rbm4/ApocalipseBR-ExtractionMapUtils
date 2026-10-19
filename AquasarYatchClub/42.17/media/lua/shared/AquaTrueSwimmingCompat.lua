--***********************************************************
--**                      AQUATSAR                          **
--**            True Swimming compatibility                 **
--***********************************************************
-- True Swimming (mod id "TrueSwimming") is a full swimming mod: real breaststroke animations,
-- its own water-square unblocking, its own endurance/drowning/item-loss model, its own sounds.
-- Aquatsar ships a swimming layer too, and the two collide head-on:
--   * both unset IsoFlagType.solidtrans on the SHARED water sprite properties and both put it
--     back, so each one closes the squares the other just opened (swimmer stuck on the shore);
--   * both drain ENDURANCE and roll for item loss / body damage on OnPlayerMove (double cost);
--   * Aquatsar hides the swimmer (IsoFlagType.invisible on the player sprite), which would hide
--     True Swimming's animation;
--   * both play their own enter/swim/leave sounds.
-- So when True Swimming is actually running, Aquatsar steps out of the swim entirely.
--
-- What is NOT delegated, on purpose: AquatsarYachts.Swim.isWater(). Despite living in the Swim
-- namespace it is the water DETECTOR used all over the boat code (WaterNWindPhysics, the boat
-- seat enter/exit search in ISBoatMenu, the trailer launch check, the gamepad prompts, the debug
-- spawner). Unloading the "Swim" files instead of gating the four gameplay entry points would
-- take the boats down with them. The handover is therefore surgical: boarding, driving, sailing,
-- mechanics and exiting a boat are untouched and keep working while True Swimming swims.

AquatsarYachts = AquatsarYachts or {}
AquatsarYachts.Swim = AquatsarYachts.Swim or {}

AquatsarYachts.Swim.TRUE_SWIMMING_MOD_ID = "TrueSwimming"

local handedOver = nil

local function resolve()
    local mods = getActivatedMods()
    if not (mods and mods:contains(AquatsarYachts.Swim.TRUE_SWIMMING_MOD_ID)) then
        return false
    end
    -- True Swimming is singleplayer only: its single script starts with "if isClient() then return end"
    -- and, being a client/ file, it is never loaded by a dedicated server. On a multiplayer client or
    -- on a server Aquatsar has to keep swimming itself even though the mod is in the list.
    if isClient() or isServer() then
        return false
    end
    -- and it only swims when its own sandbox switch is on
    local sandbox = SandboxVars and SandboxVars.TrueSwimming
    if sandbox and sandbox.Enabled == false then
        return false
    end
    return true
end

-- true = True Swimming is in charge of the swim, Aquatsar must not touch the swimmer
function AquatsarYachts.Swim.isHandledByTrueSwimming()
    if handedOver == nil then
        handedOver = resolve()
    end
    return handedOver
end

-- the mod list cannot change in-session, but SandboxVars may not be filled in yet when this file
-- is loaded: settle the answer for good once the game is up
Events.OnGameStart.Add(function()
    handedOver = resolve()
    if handedOver then
        print("Aquatsar Yacht Club: True Swimming is active, swimming delegated to it (boats unchanged).")
    end
end)

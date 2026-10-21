-- npm exec --yes --package=fengari-node-cli -- fengari tests/boat-cheats.lua
ISCollapsableWindow = { derive = function() return {} end }
UIFont = { Small = 1, Medium = 2 }
getTextManager = function() return { getFontHeight = function() return 12 end } end
getText = function(text) return text end
getTextOrNull = function() return nil end
getDebug = function() return true end
UIManager = { getSpeedControls = function()
    return { getCurrentGameSpeed = function() return 1 end }
end }
JoypadState = { players = {} }
package.loaded['CommonTemplates/CommonTemplates.lua'] = true
CommonTemplates = {
    InstallTest = { PartNotInCabin = function() return true end },
    UninstallTest = { PartNotInCabin = function() return true end },
}
local player = { getAccessLevel = function() return 'Admin' end }
getSpecificPlayer = function() return player end
local commands = 0
sendClientCommand = function() commands = commands + 1 end
local function loadBoatFile(path)
    return assert(loadfile(path))
end

for _, version in ipairs({ 'common', '42.17' }) do
    local lua = 'AquasarYatchClub/' .. version .. '/media/lua/'
    -- Compile all changed runtime files, including code outside the mocked paths.
    for _, file in ipairs({
        'client/Boats/ISUI/ISBoatMechanics.lua',
        'client/Boats/ISUI/ISBoatPartMenu.lua',
        'client/Boats/ISUI/ISBoatMenu.lua', 'server/Boats/Boats.lua',
    }) do loadBoatFile(lua .. file) end
    ISVehicleMechanics = { cheat = true }
    loadBoatFile(lua .. 'client/Boats/ISUI/ISBoatMechanics.lua')()
    loadBoatFile(lua .. 'client/Boats/ISUI/ISBoatPartMenu.lua')()
    loadBoatFile(lua .. 'server/Boats/Boats.lua')()
    assert(ISVehicleMechanics.cheat, 'boat code must not change vanilla mechanics state')
    for name in pairs(ISBoatMechanics) do
        assert(not name:find('onCheat'), 'cheat callback remains: ' .. name)
    end
    assert(ISBoatPartMenu.onDebugFill == nil)

    local options = {}
    ISContextMenu = { get = function()
        return {
            numOptions = 1, setVisible = function() end,
            addOption = function(_, label)
                options[#options + 1] = label
                return {}
            end,
        }
    end }
    local part = {
        getItemType = function() return nil end,
        getWindow = function() return nil end,
        isContainer = function() return false end,
        getId = function() return 'Propeller' end,
    }
    local selected
    local ui = setmetatable({
        playerNum = 0, getAbsoluteX = function() return 0 end,
        getAbsoluteY = function() return 0 end,
        getMouseOverPart = function() return selected end,
        selectPart = function() end,
    }, { __index = ISBoatMechanics })
    -- Admin + debug + global cheat enabled must still produce no cheat options.
    ui:doPartContextMenu(part, 0, 0)
    assert(#options == 0)
    ui:onRightMouseUp(0, 0)
    assert(ui.context == nil and #options == 0)
    selected = part
    ui:onRightMouseUp(0, 0)
    assert(ui.context and #options == 0)

    -- Normal actions still prepare required items and queue their timed action.
    local transfers, equips, queued = 0, 0, 0
    ISBoatPartMenu.toPlayerInventory = function() end
    ISBoatPartMenu.transferRequiredItems = function() transfers = transfers + 1 end
    ISBoatPartMenu.equipRequiredItems = function() equips = equips + 1 end
    ISTimedActionQueue = { add = function() queued = queued + 1 end }
    local action = { new = function() return {} end }
    ISInstallBoatPart, ISUninstallBoatPart, ISRenameBoat = action, action, action
    part.getTable = function() return { time = 50 } end
    part.getArea = function() return 'Engine' end
    ISBoatPartMenu.onInstallPart(player, part, {})
    ISBoatPartMenu.onUninstallPart(player, part)
    ISBoatPartMenu.onRenameBoat(player, part, {})
    assert(transfers == 3 and equips == 3 and queued == 3)

    for _, running in ipairs({ true, false }) do
        local boat = { isEngineRunning = function() return running end }
        assert(Boats.InstallTest.Propeller(boat, part, player) == not running)
        assert(Boats.UninstallTest.Propeller(boat, part, player) == not running)
    end
    assert(commands == 0, 'mechanics menus sent a cheat command')
    print('PASS boat cheat removal: ' .. version)
end

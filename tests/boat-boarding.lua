-- npm exec --yes --package=fengari-node-cli -- fengari tests/boat-boarding.lua
package.loaded['ISUI/ISPanelJoypad'] = true
package.loaded['CommonTemplates/CommonTemplates.lua'] = true
package.loaded['AquaConfig'] = true
ISPanelJoypad = { derive = function() return {} end }
ISVehicleSeatUI = {}
UIFont = { Medium = 1, Large = 2 }
getTextManager = function() return { getFontHeight = function() return 12 end } end
getText = function(key) return key end
ItemTag = { HEAVY_ITEM = 'heavy' }

for _, version in ipairs({ 'common', '42.17' }) do
    assert(loadfile('AquasarYatchClub/' .. version .. '/media/lua/client/Boats/ISUI/ISBoatSeatUI.lua'))()
    local state, log, boat, player, ui
    local function record(value) log[#log + 1] = value end
    local function reset()
        state = { nearby = true, installed = true, unlocked = true, client = true }
        log = {}
        player = {
            getVehicle = function() return state.vehicle end,
            getPlayerNum = function() return 1 end,
            getOnlineID = function() return 42 end,
            getPrimaryHandItem = function() return state.heavy end,
            getSecondaryHandItem = function() return nil end,
            isAiming = function() return true end,
            nullifyAiming = function() record('aim') end,
            triggerMusicIntensityEvent = function(_, event) assert(event == 'VehicleEnter') end,
            Say = function(_, text) state.message = text end,
            -- The selected seat may be far from shore. No seat-distance check is allowed.
            DistToSquared = function() error('must not check distance to selected seat') end,
        }
        boat = {
            getMaxPassengers = function() return 3 end,
            getScript = function() return { getPassenger = function(_, seat)
                return { getId = function() return seat == 1 and 'Cabin' or 'Deck' end }
            end } end,
            getPartById = function(_, id)
                if id == 'CabinLock' then return { getModData = function()
                    return { AquaCabin_isUnlocked = state.unlocked }
                end } end
                if id == 'InCabinCabin' then return {} end
            end,
            getPassengerPosition = function(_, seat, position)
                if seat ~= 2 and not (state.noInside and position == 'inside') then return {} end
            end,
            isSeatInstalled = function() return state.installed end,
            isSeatOccupied = function() return state.occupied end,
            getCharacter = function() return state.person end,
            enter = function(_, seat, character)
                assert(character == player)
                record('enter')
                if state.failed then return false end
                state.vehicle, state.seat = boat, seat
                return true
            end,
            setCharacterPosition = function(_, character, seat, position)
                assert(character == player and seat == state.seat and position == 'inside')
                record('inside')
            end,
            transmitCharacterPosition = function(_, seat, position)
                assert(seat == state.seat and position == 'inside')
                record('sync')
            end,
            playPassengerAnim = function(_, _, anim) assert(anim == 'idle'); record('idle') end,
            playPassengerSound = function() record('sound') end,
            getSeat = function() return state.seat or -1 end,
            getPartForSeatContainer = function() return { getId = function() return 'SeatDeck' end } end,
            canSwitchSeat = function() return state.canSwitch ~= false end,
        }
        AquaConfig = { isBoat = function(target) return target == boat and not state.notBoat end }
        ISBoatMenu = { getBoatToInteractWith = function(character)
            assert(character == player)
            return state.nearby and boat or nil
        end }
        ISTimedActionQueue = {
            clear = function(character) assert(character == player); record('clear') end,
            add = function() error('outside boarding must be immediate') end,
        }
        getCell = function() return { setDrag = function(_, _, playerNum) assert(playerNum == 1) end } end
        getPlayerContextMenu = function() return nil end
        isClient = function() return state.client end
        sendClientCommand = function(character, module, command, args)
            assert(character == player and module == 'player' and command == 'onDropHeavyItem' and args.id == 42)
            state.dropCommand = true
        end
        forceDropHeavyItems = function(character) assert(character == player); state.dropped = true end
        triggerEvent = function(event, character)
            assert(event == 'OnEnterVehicle' and character == player)
            record('event')
        end
        ISVehicleMenu = {
            moveItemsFromSeat = function() state.movedItems = true; return true end,
            onSwitchSeat = function(_, seat) state.switched = seat end,
        }
        ui = setmetatable({ vehicle = boat, character = player,
            closeSelf = function() state.closed = true end,
        }, { __index = ISBoatSeatUI })
    end

    reset()
    ui:useSeat(0)
    assert(state.vehicle == boat and state.seat == 0 and state.closed)
    assert(table.concat(log, ',') == 'clear,enter,aim,sound,inside,sync,idle,event')

    for _, unlocked in ipairs({ false, true }) do
        reset(); state.unlocked = unlocked
        ui:useSeat(1)
        assert(state.vehicle == nil and #log == 0, 'cannot board directly into a cabin')
    end
    for _, flag in ipairs({ 'occupied', 'person', 'noInside', 'notBoat', 'failed' }) do
        reset(); state[flag] = true
        ui:useSeat(0)
        assert(state.vehicle == nil)
        for _, event in ipairs(log) do assert(event ~= 'sync' and event ~= 'event') end
    end
    reset(); state.installed = false; ui:useSeat(0); assert(#log == 0)
    reset(); state.nearby = false; ui:useSeat(0); assert(#log == 0)
    reset(); ui:useSeat(2); assert(#log == 0, 'seat without outside position is not an entry')
    for _, seat in ipairs({ -1, 3, 0.5, '0' }) do
        reset(); assert(not ui:enterFromOutside(seat)); assert(#log == 0)
    end
    reset(); state.vehicle = {}; assert(not ui:enterFromOutside(0)); assert(#log == 0)

    -- Aboard players retain the existing seat-switch and cabin-lock behavior.
    for _, unlocked in ipairs({ false, true }) do
        reset(); state.vehicle, state.seat, state.unlocked = boat, 0, unlocked
        ui.characterSeat = 0
        ui:useSeat(1)
        assert((state.switched == 1) == unlocked)
        assert(#log == 0)
    end
    reset(); state.vehicle, state.seat, state.canSwitch = boat, 0, false
    ui.characterSeat = 0; ui:useSeat(1); assert(state.switched == nil)

    for _, client in ipairs({ false, true }) do
        reset(); state.client = client
        state.heavy = { hasTag = function(_, tag) return tag == ItemTag.HEAVY_ITEM end }
        ui:useSeat(0)
        assert(state.vehicle == boat)
        assert(client and state.dropCommand or not client and state.dropped)
    end
    print('PASS immediate exterior boat boarding: ' .. version)
end

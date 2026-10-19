SingingInsectSystem = SingingInsectSystem or {}
local SingingInsectVolume = require("Insects/SingingInsectsVolume")
local DEBUG = false

-- 1. SYSTEM CONFIGURATION
SingingInsectSystem.poolSize = 25
SingingInsectSystem.emitterPool = {}
SingingInsectSystem.activeSequences = {}
SingingInsectSystem.isInitialized = false
-- Independent trigger times for each direction - each has its own timing
SingingInsectSystem.nextTriggerTime = { front = nil, rear = nil, side = nil }
SingingInsectSystem.playerBubbleRadius = 15  -- Tunable: minimum distance from player in units

-- Monthly cache for pre-filtering insects by month
SingingInsectSystem.MonthlyCache = {}
SingingInsectSystem.lastCachedMonth = -1

-- Zone caching
local BIOME_CHECK_DIST = 10
local BiomeManager = { currentZone = "Unknown", lastValidZone = "TownZone", lastX = 0, lastY = 0 }

-- Timing & Multipliers
SingingInsectSystem.globalTickCounter = 0
SingingInsectSystem.realTimeCounter = 0
SingingInsectSystem.lastCheckMinutesStamp = -1
SingingInsectSystem.suppressionTimer = 0
SingingInsectSystem.isPanicked = false
SingingInsectSystem.startlePosition = {x = nil, y = nil}  -- Track where startle occurred for distance-based reset
SingingInsectSystem.startleRadius = 35  -- Tunable: distance in units - insects within this radius will stop calling
SingingInsectSystem.TICKS_PER_SECOND = 60
SingingInsectSystem.startupGracePeriod = 5.0  -- 5 real seconds of silence at start
SingingInsectSystem.startupTimer = 0
SingingInsectSystem.startPauseDuration = 60.0  -- 60 real seconds - side and rear emitters paused
SingingInsectSystem.startPauseTimer = 0
SingingInsectSystem.globalSpawnCooldown = 1.5  -- 1.5 game minutes between any insect spawn
SingingInsectSystem.lastSpawnTime = -1  -- Track last spawn time in game minutes
local RESET_DISTANCE = 20  -- Distance in tiles to reset startle state

-- Performance Localizations
local ZRand = ZombRand
local ZRandFloat = ZombRandFloat
local floor = math.floor
local abs = math.abs
local math_sin = math.sin

-- Rarity weighting power (higher = steeper curve, common insects dominate)
-- Power = 1: Linear (even distribution)
-- Power = 2: Moderate curve
-- Power = 3: Steep curve (common insects dominate, rare insects are special)
local RARITY_POWER = 3
local MAX_RARITY = 10

-- 2. DYNAMIC SCALING & PLACEMENT CONSTANTS
local BASE_RADIUS_MIN = 16
local BASE_RADIUS_MAX = 25

-- Rear emitter distances (inside audible range, fading out behind player)
local REAR_RADIUS_MIN = 15
local REAR_RADIUS_MAX = 20

-- Side emitter distances (lateral placement for surround feel)
local SIDE_RADIUS_MIN = 15
local SIDE_RADIUS_MAX = 20

local DIRECTIONS = {
    {x = 0, y = -1}, {x = 1, y = -1}, {x = 1, y = 0}, {x = 1, y = 1},
    {x = 0, y = 1}, {x = -1, y = 1}, {x = -1, y = 0}, {x = -1, y = -1}
}

local DIRECTION_WEIGHTS = {
    forward = 10, forwardDiag = 6, side = 2, backward = 0, backDiag = 0
}

-- Rear direction weights (opposite of front - favor behind placement)
local REAR_DIRECTION_WEIGHTS = {
    forward = 0, forwardDiag = 0, side = 2, backward = 10, backDiag = 6
}

-- Side direction weights (favor left/right placement for lateral movement)
local SIDE_DIRECTION_WEIGHTS = {
    forward = 0, forwardDiag = 8, side = 10, backward = 0, backDiag = 8
}

local BIOME_DENSITY = {
    DeepForest = 3.5, OrganicForest = 3.0, PRForest = 2.8, Forest = 2.2,
    FarmLand = 2.5, Farm = 2.3, Vegitation = 2.4, TownZone = 0.5, WaterZone = 1.5,
    PHForest = 2.6, clay_lake = 1.8, clay_shore = 1.6, TrailerPark = 0.8,
    Unknown = 0.7, ForagingNav = 0.7
}

-- 2. SPECIES DATA (converted to bird format)
SingingInsectSystem.Insects = {
    spring_field_cricket = {
        name = "Spring Field Cricket",
        biomes = { "FarmLand", "Vegitation", "PHForest", "TownZone", "DeepForest" },
        months = {5, 6, 7},
        hours = { start = 20, stop = 6 },
        rarity = 1,
        soundBase = "SpringFieldCricket",
        callVariants = 9,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    fall_field_cricket = {
        name = "Fall Field Cricket",
        biomes = { "FarmLand", "Vegitation", "PHForest", "clay_shore", "Shoreline", "DeepForest" },
        months = {8, 9, 10},
        hours = { start = 19, stop = 5 },
        rarity = 1,
        soundBase = "FallFieldCricket",
        callVariants = 8,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    snowy_tree_cricket = {
        name = "Snowy Tree Cricket",
        biomes = { "PHForest", "Forest", "PRForest", "Shoreline", "clay_shore", "DeepForest" },
        months = {7, 8, 9},
        hours = { start = 20, stop = 4 },
        rarity = 1,
        soundBase = "SnowyTreeCricket",
        callVariants = 2,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    forbes_tree_cricket = {
        name = "Forbes's Tree Cricket",
        biomes = { "PHForest", "FarmLand", "Vegitation", "DeepForest" },
        months = {7, 8},
        hours = { start = 20, stop = 3 },
        rarity = 1,
        soundBase = "ForbesTreeCricket",
        callVariants = 6,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    northern_mole_cricket = {
        name = "Northern Mole Cricket",
        biomes = { "clay_lake", "clay_shore", "WaterZone" },
        months = {6, 7, 8},
        hours = { start = 19, stop = 22 },
        rarity = 3,
        soundBase = "NorthernMoleCricket",
        callVariants = 9,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    common_meadow_katydid = {
        name = "Common Meadow Katydid",
        biomes = { "FarmLand", "Vegitation", "DeepForest" },
        months = {7, 8, 9},
        hours = { start = 18, stop = 2 },
        rarity = 1,
        soundBase = "CommonMeadowKatydid",
        callVariants = 6,
        Repeat = {min = 5, max = 20},
        callDelay = {min = 0.8, max = 0.8}
    },
    gladiator_meadow_katydid = {
        name = "Gladiator Meadow Katydid",
        biomes = { "clay_lake", "clay_shore", "WaterZone", "Shoreline" },
        months = {6, 7, 8},
        hours = { start = 9, stop = 21 },
        rarity = 1,
        soundBase = "GladiatorMeadowKatydid",
        callVariants = 11,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    black_legged_meadow_katydid = {
        name = "Black-legged Meadow Katydid",
        biomes = { "FarmLand", "Vegitation", "DeepForest" },
        months = {7, 8},
        hours = { start = 10, stop = 20 },
        rarity = 2,
        soundBase = "BlackLeggedMeadowKatydid",
        callVariants = 7,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    straight_lanced_meadow_katydid = {
        name = "Straight-lanced Meadow Katydid",
        biomes = { "FarmLand", "Vegitation", "DeepForest" },
        months = {8, 9},
        hours = { start = 12, stop = 22 },
        rarity = 3,
        soundBase = "StraightLancedMeadowKatydid",
        callVariants = 3,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    },
    short_winged_meadow_katydid = {
        name = "Short-winged Meadow Katydid",
        biomes = { "FarmLand", "Vegitation", "TownZone", "DeepForest" },
        months = {7, 8},
        hours = { start = 8, stop = 18 },
        rarity = 3,
        soundBase = "ShortWingedMeadowKatydid",
        callVariants = 1,
        Repeat = {min = 5, max = 20},
        callDelay = {min = 0.8, max = 0.8}
    },
    common_true_katydid = {
        name = "Common True Katydid",
        biomes = { "PHForest", "DeepForest", "OrganicForest" },
        months = {8, 9},
        hours = { start = 20, stop = 2 },
        rarity = 3,
        soundBase = "CommonTrueKatydid",
        callVariants = 10,
        Repeat = {min = 10, max = 30},
        callDelay = {min = 0.8, max = 0.8}
    }
}

-- 4. DETERMINISTIC PLACEMENT ENGINE
local function getSeedRoll(seed, max)
    local val = (abs(floor(seed)) * 1103515245 + 12345) % 2147483648
    if max then return val % max end
    return val
end

function SingingInsectSystem.getWeightedDirection(player, seed)
    local playerDir = player:getDir()
    local dirIndex = 1
    local dirMap = { N=1, NE=2, E=3, SE=4, S=5, SW=6, W=7, NW=8 }
    dirIndex = dirMap[playerDir:toString()] or 1

    local weights = {}
    for i = 1, 8 do
        local angleDiff = abs(i - dirIndex)
        if angleDiff > 4 then angleDiff = 8 - angleDiff end
        if angleDiff == 0 then weights[i] = DIRECTION_WEIGHTS.forward
        elseif angleDiff == 1 then weights[i] = DIRECTION_WEIGHTS.forwardDiag
        elseif angleDiff == 2 then weights[i] = DIRECTION_WEIGHTS.side
        elseif angleDiff == 3 then weights[i] = DIRECTION_WEIGHTS.backDiag
        else weights[i] = DIRECTION_WEIGHTS.backward end
    end

    local totalWeight = 0
    for i = 1, 8 do totalWeight = totalWeight + weights[i] end
    local roll = getSeedRoll(seed, totalWeight)
    local currentWeight = 0
    for i = 1, 8 do
        currentWeight = currentWeight + weights[i]
        if roll < currentWeight then return DIRECTIONS[i] end
    end
    return DIRECTIONS[1]
end

function SingingInsectSystem.getRearDirection(player, seed)
    local playerDir = player:getDir()
    local dirIndex = 1
    local dirMap = { N=1, NE=2, E=3, SE=4, S=5, SW=6, W=7, NW=8 }
    dirIndex = dirMap[playerDir:toString()] or 1

    local weights = {}
    for i = 1, 8 do
        local angleDiff = abs(i - dirIndex)
        if angleDiff > 4 then angleDiff = 8 - angleDiff end
        if angleDiff == 0 then weights[i] = REAR_DIRECTION_WEIGHTS.backward
        elseif angleDiff == 1 then weights[i] = REAR_DIRECTION_WEIGHTS.backDiag
        elseif angleDiff == 2 then weights[i] = REAR_DIRECTION_WEIGHTS.side
        elseif angleDiff == 3 then weights[i] = REAR_DIRECTION_WEIGHTS.forwardDiag
        else weights[i] = REAR_DIRECTION_WEIGHTS.forward end
    end

    local totalWeight = 0
    for i = 1, 8 do totalWeight = totalWeight + weights[i] end
    local roll = getSeedRoll(seed, totalWeight)
    local currentWeight = 0
    for i = 1, 8 do
        currentWeight = currentWeight + weights[i]
        if roll < currentWeight then return DIRECTIONS[i] end
    end
    return DIRECTIONS[5]
end

function SingingInsectSystem.getSideDirection(player, seed)
    local playerDir = player:getDir()
    local dirIndex = 1
    local dirMap = { N=1, NE=2, E=3, SE=4, S=5, SW=6, W=7, NW=8 }
    dirIndex = dirMap[playerDir:toString()] or 1

    local weights = {}
    for i = 1, 8 do
        local angleDiff = abs(i - dirIndex)
        if angleDiff > 4 then angleDiff = 8 - angleDiff end
        if angleDiff == 0 then weights[i] = SIDE_DIRECTION_WEIGHTS.forward
        elseif angleDiff == 1 then weights[i] = SIDE_DIRECTION_WEIGHTS.forwardDiag
        elseif angleDiff == 2 then weights[i] = SIDE_DIRECTION_WEIGHTS.side
        elseif angleDiff == 3 then weights[i] = SIDE_DIRECTION_WEIGHTS.backDiag
        else weights[i] = SIDE_DIRECTION_WEIGHTS.backward end
    end

    local totalWeight = 0
    for i = 1, 8 do totalWeight = totalWeight + weights[i] end
    local roll = getSeedRoll(seed, totalWeight)
    local currentWeight = 0
    for i = 1, 8 do
        currentWeight = currentWeight + weights[i]
        if roll < currentWeight then return DIRECTIONS[i] end
    end
    return DIRECTIONS[2]
end

-- Bubble Repulsion System: Pushes emitters away from player if they enter the bubble
function SingingInsectSystem.applyBubbleRepulsion(playerX, playerY, posX, posY)
    local dx = posX - playerX
    local dy = posY - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- If inside or at bubble boundary, push out to boundary
    if distance < SingingInsectSystem.playerBubbleRadius then
        if distance == 0 then
            -- Edge case: emitter exactly on player, push in random direction
            local angle = ZRandFloat(0, math.pi * 2)
            posX = playerX + math.cos(angle) * SingingInsectSystem.playerBubbleRadius
            posY = playerY + math.sin(angle) * SingingInsectSystem.playerBubbleRadius
        else
            -- Push to bubble boundary along same direction
            local scale = SingingInsectSystem.playerBubbleRadius / distance
            posX = playerX + dx * scale
            posY = playerY + dy * scale
        end
    end
    
    return posX, posY
end

-- 5. POOL MANAGEMENT
function SingingInsectSystem.allocateEmitterPool()
    local world = getWorld()
    if not world then
        if DEBUG then print("[SingingInsectSystem] ERROR: getWorld() returned nil") end
        return false
    end
    for i = 1, SingingInsectSystem.poolSize do
        local emitter = world:getFreeEmitter()
        if emitter then
            table.insert(SingingInsectSystem.emitterPool, { emitter = emitter, inUse = false, lastUsed = 0 })
        end
    end
    if DEBUG then print("[SingingInsectSystem] Allocated " .. #SingingInsectSystem.emitterPool .. " emitters") end
    return #SingingInsectSystem.emitterPool > 0
end

function SingingInsectSystem.getFreeEmitterFromPool()
    local time = SingingInsectSystem.globalTickCounter
    for _, poolEntry in ipairs(SingingInsectSystem.emitterPool) do
        if not poolEntry.inUse or poolEntry.emitter:isEmpty() then
            poolEntry.inUse = true
            poolEntry.lastUsed = time
            return poolEntry
        end
    end
    local oldest = SingingInsectSystem.emitterPool[1]
    for i = 2, #SingingInsectSystem.emitterPool do
        if SingingInsectSystem.emitterPool[i].lastUsed < oldest.lastUsed then oldest = SingingInsectSystem.emitterPool[i] end
    end
    oldest.emitter:stopAll()
    oldest.inUse = true
    oldest.lastUsed = time
    return oldest
end

-- 6. SEQUENCER & PLAYBACK
function SingingInsectSystem.updateSequences()
    if #SingingInsectSystem.activeSequences == 0 then return end
    local currentRealTime = SingingInsectSystem.realTimeCounter
    local player = getPlayer()
    if not player then return end
    
    for i = #SingingInsectSystem.activeSequences, 1, -1 do
        local seq = SingingInsectSystem.activeSequences[i]
        
        if currentRealTime >= seq.nextNoteTime then
            local variantCount = seq.insectData.callVariants
            local variant = ZRand(variantCount) + 1
            local soundName = seq.insectData.soundBase .. "Call" .. tostring(variant)
            
            local poolEntry = SingingInsectSystem.getFreeEmitterFromPool()
            if poolEntry then
                -- Apply bubble repulsion to push emitter away from player
                local px, py = player:getX(), player:getY()
                seq.pos.x, seq.pos.y = SingingInsectSystem.applyBubbleRepulsion(px, py, seq.pos.x, seq.pos.y)
                poolEntry.emitter:setPos(seq.pos.x, seq.pos.y, player:getZ())
                local handle = poolEntry.emitter:playSound(soundName)
                SingingInsectVolume.applyToHandle(poolEntry.emitter, handle)
                poolEntry.emitter:tick()
                poolEntry.lastUsed = SingingInsectSystem.globalTickCounter
                
                seq.remaining = seq.remaining - 1
                if seq.remaining > 0 then
                    local nextDelay = seq.delayRange.min + (ZRandFloat(0.0, 1.0) * (seq.delayRange.max - seq.delayRange.min))
                    seq.nextNoteTime = currentRealTime + nextDelay
                else
                    table.remove(SingingInsectSystem.activeSequences, i)
                end
            else
                table.remove(SingingInsectSystem.activeSequences, i)
            end
        end
    end
end

-- Layer 2: Continuously update all active sequence positions based on player movement
-- This ensures emitters stay outside the bubble even when player moves between notes
function SingingInsectSystem.updateSequencePositions(player)
    if #SingingInsectSystem.activeSequences == 0 then return end
    
    local px, py = player:getX(), player:getY()
    
    for _, seq in ipairs(SingingInsectSystem.activeSequences) do
        seq.pos.x, seq.pos.y = SingingInsectSystem.applyBubbleRepulsion(px, py, seq.pos.x, seq.pos.y)
    end
end

function SingingInsectSystem.playInsectSound(player, insectData, seed, env, isRear, isSide)
    local px, py = player:getX(), player:getY()
    local soundType = "Call"
    
    local direction
    local dist
    local location
    
    if isSide then
        direction = SingingInsectSystem.getSideDirection(player, seed)
        dist = (SIDE_RADIUS_MIN + env.radiusOffset) + getSeedRoll(seed + 44, (SIDE_RADIUS_MAX - SIDE_RADIUS_MIN))
        location = "SIDE"
    elseif isRear then
        direction = SingingInsectSystem.getRearDirection(player, seed)
        dist = (REAR_RADIUS_MIN + env.radiusOffset) + getSeedRoll(seed + 44, (REAR_RADIUS_MAX - REAR_RADIUS_MIN))
        location = "REAR"
    else
        direction = SingingInsectSystem.getWeightedDirection(player, seed)
        dist = (BASE_RADIUS_MIN + env.radiusOffset) + getSeedRoll(seed + 22, (BASE_RADIUS_MAX - BASE_RADIUS_MIN))
        location = "FRONT"
    end
    
    local countR = insectData.Repeat or {min = 1, max = 1}
    local repeatCount = getSeedRoll(seed, (countR.max - countR.min) + 1) + countR.min

    local delayRange = insectData.callDelay or {min = 0.5, max = 0.8}

    if DEBUG then print("[SingingInsectSystem] Queuing " .. location .. " " .. insectData.name .. " (" .. soundType .. ")") end
    
    -- Layer 1: Apply bubble repulsion at sequence creation to prevent initial placement inside bubble
    local rawX = px + (direction.x * dist)
    local rawY = py + (direction.y * dist)
    local finalX, finalY = SingingInsectSystem.applyBubbleRepulsion(px, py, rawX, rawY)
    
    table.insert(SingingInsectSystem.activeSequences, {
        insectData = insectData, soundType = soundType, remaining = repeatCount,
        delayRange = delayRange, nextNoteTime = SingingInsectSystem.realTimeCounter,
        pos = {x = finalX, y = finalY}
    })
end

-- 7. TICK & LOGIC
function SingingInsectSystem.getCurrentBiome(player)
    local x, y = floor(player:getX()), floor(player:getY())
    if abs(x - BiomeManager.lastX) > BIOME_CHECK_DIST or abs(y - BiomeManager.lastY) > BIOME_CHECK_DIST then
        BiomeManager.lastX, BiomeManager.lastY = x, y
        local mapZones = getWorld():getMetaGrid():getZonesAt(x, y, 0)
        local foundZone = "Unknown"
        if mapZones then
            for i = 0, mapZones:size() - 1 do
                local zType = mapZones:get(i):getType()
                if zType == "TownZone" or zType == "DeepForest" then
                    foundZone = zType
                    break
                end
                if BIOME_DENSITY[zType] and foundZone == "Unknown" then
                    foundZone = zType
                end
            end
        end

        -- If we found "Unknown" or "ForagingNav" (Road), use last valid biome instead
        if foundZone == "Unknown" or foundZone == "ForagingNav" then
            foundZone = BiomeManager.lastValidZone
        else
            -- Only update lastValidZone if we found a real biome
            BiomeManager.lastValidZone = foundZone
        end

        BiomeManager.currentZone = foundZone
    end
    return BiomeManager.currentZone
end

-- Distance-based reset: Reset startle state if player travels far from startle location
function SingingInsectSystem.checkDistanceReset(player)
    if not SingingInsectSystem.isPanicked then return end
    
    local sx, sy = SingingInsectSystem.startlePosition.x, SingingInsectSystem.startlePosition.y
    if not sx or not sy then return end
    
    local px, py = player:getX(), player:getY()
    local dx = px - sx
    local dy = py - sy
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance >= RESET_DISTANCE then
        SingingInsectSystem.suppressionTimer = 0
        SingingInsectSystem.isPanicked = false
        SingingInsectSystem.startlePosition = {x = nil, y = nil}
        if DEBUG then print("[SingingInsectSystem] Reset startle state after traveling " .. distance .. " tiles") end
    end
end

function SingingInsectSystem.onTick()
    if not SingingInsectSystem.isInitialized then return end
    
    local player = getPlayer()
    -- B42 SAFETY: Check for player existence and square loading
    if not player or player:isDead() or not player:getCurrentSquare() then return end
    
    -- Check if player has traveled far enough to reset startle state
    SingingInsectSystem.checkDistanceReset(player)
    
    SingingInsectSystem.globalTickCounter = SingingInsectSystem.globalTickCounter + 1
    SingingInsectSystem.realTimeCounter = SingingInsectSystem.realTimeCounter + (1.0 / SingingInsectSystem.TICKS_PER_SECOND)
    SingingInsectSystem.updateSequences()
    SingingInsectSystem.updateSequencePositions(player)  -- Layer 2: Update positions every tick

    -- STARTUP GRACE PERIOD - NO SOUNDS FOR FIRST 5 SECONDS
    if SingingInsectSystem.startupTimer < SingingInsectSystem.startupGracePeriod then
        SingingInsectSystem.startupTimer = SingingInsectSystem.startupTimer + (1.0 / SingingInsectSystem.TICKS_PER_SECOND)
        return  -- Exit early, no zone processing during grace period
    end

    -- START PAUSE PERIOD - SIDE AND REAR EMITTERS PAUSED FOR FIRST 60 SECONDS
    if SingingInsectSystem.startPauseTimer < SingingInsectSystem.startPauseDuration then
        SingingInsectSystem.startPauseTimer = SingingInsectSystem.startPauseTimer + (1.0 / SingingInsectSystem.TICKS_PER_SECOND)
    end

    -- OPTIMIZATION: Cache getGameTime() once per tick and extract all needed values
    local gt = getGameTime()
    local month = gt:getMonth() + 1
    local hour = gt:getHour()
    local currentMinutesStamp = gt:getMinutesStamp()
    local worldAgeMinutes = gt:getWorldAgeHours() * 60
    
    if currentMinutesStamp == SingingInsectSystem.lastCheckMinutesStamp then return end
    SingingInsectSystem.lastCheckMinutesStamp = currentMinutesStamp

    if SingingInsectSystem.suppressionTimer > 0 then
        SingingInsectSystem.suppressionTimer = SingingInsectSystem.suppressionTimer - 1
        return
    end

    local sq = player:getSquare()
    if not sq or not sq:isOutside() then return end
    if player:getVehicle() and player:getVehicle():isEngineRunning() then return end
    if getClimateManager():getPrecipitationIntensity() > 0.4 then return end

    -- OPTIMIZATION: Pass cached time values to avoid redundant getGameTime() calls
    SingingInsectSystem.updateZoneState(player, gt, month, hour, worldAgeMinutes)
end

function SingingInsectSystem.updateZoneState(player, gt, month, hour, worldAgeMinutes)
    local biome = SingingInsectSystem.getCurrentBiome(player)
    local gameTimeMinutes = worldAgeMinutes
    local px, py = floor(player:getX()), floor(player:getY())

    local seed = (px * 31 + py) + floor(gameTimeMinutes / 10)
    local seasonalIntensity = (math_sin((month - 3) * (3.14159 / 6)) + 1) / 2
    local seasonalDensity = 0.2 + (seasonalIntensity * 0.8)

    local env = {
        radiusOffset = (1 - seasonalIntensity) * 15,
        tempoMulti = 2.0 - (seasonalIntensity * 0.5),
        biomeDensity = BIOME_DENSITY[biome] or 1.5,
        biome = biome,
        seasonalDensity = seasonalDensity
    }

    local timeMultiplier = 1.0
    if hour >= 20 and hour < 21 then timeMultiplier = 0.4      -- 8pm-9pm: Activity just starting
    elseif hour >= 21 and hour < 23 then timeMultiplier = 0.8  -- 9pm-11pm: Rising activity
    elseif hour >= 23 or hour < 2 then timeMultiplier = 1.2       -- 11pm-2am: Peak activity
    elseif hour >= 2 and hour < 5 then timeMultiplier = 0.6        -- 2am-5am: Dropping activity
    else timeMultiplier = 0.05                                          -- 5am-8pm: Daytime silence
    end

    -- Process each direction independently with its own timing
    SingingInsectSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, "front", timeMultiplier, 0)
    
    -- Skip rear and side emitters during start pause period (first 60 real seconds)
    if SingingInsectSystem.startPauseTimer >= SingingInsectSystem.startPauseDuration then
        SingingInsectSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, "rear", timeMultiplier, 1000)
        SingingInsectSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, "side", timeMultiplier, 2000)
    end
end

-- Helper function to process each direction independently
function SingingInsectSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, direction, timeMultiplier, seedOffset)
    local dirSeed = seed + seedOffset
    local zoneTempo = (0.5 + (getSeedRoll(dirSeed, 100) / 100) * 2.5) * timeMultiplier * env.tempoMulti * (1.0 / env.biomeDensity) * env.seasonalDensity
    
    -- Initialize trigger time if not set
    if not SingingInsectSystem.nextTriggerTime[direction] then
        SingingInsectSystem.nextTriggerTime[direction] = gameTimeMinutes + zoneTempo
    end

    -- Check if this direction should trigger
    if gameTimeMinutes >= SingingInsectSystem.nextTriggerTime[direction] then
        -- Check global cooldown - ensure minimum time between any bird spawn
        if SingingInsectSystem.lastSpawnTime >= 0 and gameTimeMinutes - SingingInsectSystem.lastSpawnTime < SingingInsectSystem.globalSpawnCooldown then
            -- Not enough time has passed since last spawn, skip this trigger
            return
        end
        
        SingingInsectSystem.tryPlayZoneInsect(player, dirSeed, env, hour, month, direction)
        -- Update last spawn time
        SingingInsectSystem.lastSpawnTime = gameTimeMinutes
        -- Add jitter (±20% random variation) to break up rhythmic spawning
        local jitter = (getSeedRoll(dirSeed + 999, 40) - 20) / 100  -- -0.2 to +0.2
        local nextDelay = zoneTempo * (1.0 + jitter)
        SingingInsectSystem.nextTriggerTime[direction] = gameTimeMinutes + nextDelay
    end
end

-- Rebuild monthly cache - filters all insects by month to reduce per-call comparisons
function SingingInsectSystem.rebuildMonthlyCache(month)
    SingingInsectSystem.MonthlyCache = {}
    SingingInsectSystem.lastCachedMonth = month
    for key, insect in pairs(SingingInsectSystem.Insects) do
        for _, m in ipairs(insect.months) do
            if m == month then
                table.insert(SingingInsectSystem.MonthlyCache, insect)
                break
            end
        end
    end
end

function SingingInsectSystem.tryPlayZoneInsect(player, seed, env, hour, month, direction)
    -- Rebuild cache if month changed (happens once per month in game time)
    if SingingInsectSystem.lastCachedMonth ~= month then
        SingingInsectSystem.rebuildMonthlyCache(month)
    end
    
    -- Cap active sequences to prevent FPS drops during peak calling period
    if #SingingInsectSystem.activeSequences > 12 then return end
    local validInsects = {}
    -- Iterate only cached insects (already filtered by month) - reduces comparisons by ~94%
    for _, v in ipairs(SingingInsectSystem.MonthlyCache) do
        local bMatch = false
        for _, b in ipairs(v.biomes) do if b == env.biome then bMatch = true break end end
        if bMatch then
            local startH, stopH = v.hours.start, v.hours.stop
            local hMatch = (startH < stopH) and (hour >= startH and hour < stopH) or (hour >= startH or hour < stopH)
            if hMatch then table.insert(validInsects, v) end
        end
    end

    if #validInsects == 0 then return end
    
    local totalWeight = 0
    for _, v in ipairs(validInsects) do
        v._calcWeight = math.pow(MAX_RARITY + 1 - v.rarity, RARITY_POWER)
        totalWeight = totalWeight + v._calcWeight
    end
    
    -- Each direction is now independent - spawn only for the requested direction
    local isRear = (direction == "rear")
    local isSide = (direction == "side")
    
    local roll = getSeedRoll(seed, totalWeight)
    local currentWeight = 0
    for _, v in ipairs(validInsects) do
        currentWeight = currentWeight + v._calcWeight
        if roll < currentWeight then
            SingingInsectSystem.playInsectSound(player, v, seed, env, isRear, isSide)
            break
        end
    end
end

function SingingInsectSystem.OnWeaponSwing(character, weapon)
    if not weapon or weapon:getSoundRadius() <= 20 then return end

    local player = getPlayer()
    if not player then return end

    -- Store the player's position when startle occurred for distance-based reset
    SingingInsectSystem.startlePosition.x = player:getX()
    SingingInsectSystem.startlePosition.y = player:getY()

    -- Check if gunshot is within audible range of player
    local dx = character:getX() - player:getX()
    local dy = character:getY() - player:getY()
    local distanceToGunshot = math.sqrt(dx * dx + dy * dy)

    -- Only react if gunshot is within weapon's sound radius of player
    if distanceToGunshot > weapon:getSoundRadius() then return end

    local px, py = player:getX(), player:getY()
    local removedCount = 0

    -- Remove nearby insect sequences (within startle radius)
    -- Distant insects continue calling, so area doesn't go completely silent
    for i = #SingingInsectSystem.activeSequences, 1, -1 do
        local seq = SingingInsectSystem.activeSequences[i]
        local dx = seq.pos.x - px
        local dy = seq.pos.y - py
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < SingingInsectSystem.startleRadius then
            table.remove(SingingInsectSystem.activeSequences, i)
            removedCount = removedCount + 1
        end
    end

    if DEBUG then print("[SingingInsectSystem] Removed " .. removedCount .. " nearby insect sequences") end

    SingingInsectSystem.suppressionTimer = 1200
    SingingInsectSystem.isPanicked = true
    -- Reset all independent trigger times
    SingingInsectSystem.nextTriggerTime = { front = nil, rear = nil, side = nil }
    -- Reset last spawn time to allow insects to respawn after suppression
    SingingInsectSystem.lastSpawnTime = -1
end

-- 8. INITIALIZATION
function SingingInsectSystem.init()
    -- B42 SAFETY: isServer() is strictly enforced; getWorld() must exist
    if isServer() or SingingInsectSystem.isInitialized then return end
    
    -- Ensure player exists before grabbing emitters
    if not getPlayer() then return end

    if SingingInsectSystem.allocateEmitterPool() then
        local gt = getGameTime()
        SingingInsectSystem.lastCheckMinutesStamp = gt:getMinutesStamp()
        SingingInsectSystem.realTimeCounter = 0
        SingingInsectSystem.startupTimer = 0  -- Initialize startup timer
        SingingInsectSystem.startPauseTimer = 0  -- Initialize start pause timer
        SingingInsectSystem.lastSpawnTime = -1  -- Initialize last spawn time
        
        -- Set initial trigger times to prevent burst at startup
        local initialDelay = 10.0  -- 10 game minutes after startup
        for _, dir in ipairs({"front", "rear", "side"}) do
            SingingInsectSystem.nextTriggerTime[dir] = gt:getWorldAgeHours() * 60 + initialDelay
        end
        
        Events.OnTick.Add(SingingInsectSystem.onTick)
        Events.OnWeaponSwing.Add(SingingInsectSystem.OnWeaponSwing)
        SingingInsectSystem.isInitialized = true
        if DEBUG then print("[SingingInsectSystem] B42 Unified Module Active with 5s startup grace period") end
    end
end

-- Changed from OnGameStart to OnCreatePlayer for stability
Events.OnCreatePlayer.Add(SingingInsectSystem.init)
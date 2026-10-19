BirdSoundSystem = BirdSoundSystem or {}

-- VOLUME MODULE (safe require with fallback)
local BirdSoundVolume = require("Birds/BirdSoundVolume")
if not BirdSoundVolume then
    print("[BirdSoundSystem] WARNING: BirdSoundVolume.lua failed to load; volume control disabled. " ..
          "Check that the file exists at Client/BirdSoundVolume.lua.")
    -- No-op fallback so the tick loop never crashes on a missing module.
    BirdSoundVolume = {
        getLive = function() return 1.0 end,
        applyToHandle = function() end,
    }
end

local DEBUG = false

-- 1. SYSTEM CONFIGURATION
BirdSoundSystem.poolSize = 25
BirdSoundSystem.emitterPool = {}
BirdSoundSystem.activeSequences = {}
BirdSoundSystem.isInitialized = false
-- Independent trigger times for each direction - each has its own timing
BirdSoundSystem.nextTriggerTime = { front = nil, rear = nil, side = nil }
BirdSoundSystem.playerBubbleRadius = 15  -- Tunable: minimum distance from player in units

-- Monthly cache for pre-filtering birds by month
BirdSoundSystem.MonthlyCache = {}
BirdSoundSystem.lastCachedMonth = -1

-- Zone caching
local BIOME_CHECK_DIST = 10
local BiomeManager = { currentZone = "Unknown", lastValidZone = "TownZone", lastX = 0, lastY = 0 }

-- Timing & Multipliers
BirdSoundSystem.globalTickCounter = 0
BirdSoundSystem.realTimeCounter = 0
BirdSoundSystem.lastCheckMinutesStamp = -1
BirdSoundSystem.suppressionTimer = 0
BirdSoundSystem.isPanicked = false
BirdSoundSystem.startlePosition = {x = nil, y = nil}  -- Track where startle occurred for distance-based reset
BirdSoundSystem.startleRadius = 35  -- Tunable: distance in units - birds within this radius will fly away
BirdSoundSystem.TICKS_PER_SECOND = 60
BirdSoundSystem.startupGracePeriod = 5.0  -- 5 real seconds of silence at start
BirdSoundSystem.startupTimer = 0
BirdSoundSystem.startPauseDuration = 60.0  -- 60 real seconds - side and rear emitters paused
BirdSoundSystem.startPauseTimer = 0
BirdSoundSystem.globalSpawnCooldown = 1.5  -- 1.5 game minutes between any bird spawn
BirdSoundSystem.lastSpawnTime = -1  -- Track last spawn time in game minutes
local RESET_DISTANCE = 20  -- Distance in tiles to reset startle state

-- Performance Localizations
local ZRand = ZombRand
local ZRandFloat = ZombRandFloat
local floor = math.floor
local abs = math.abs
local math_sin = math.sin

-- Rarity weighting power (higher = steeper curve, common birds dominate)
-- Power = 1: Linear (even distribution)
-- Power = 2: Moderate curve
-- Power = 3: Steep curve (common birds dominate, rare birds are special)
local RARITY_POWER = 3
local MAX_RARITY = 10

-- 2. DYNAMIC SCALING & PLACEMENT CONSTANTS
local BASE_RADIUS_MIN = 26
local BASE_RADIUS_MAX = 35

-- Rear emitter distances (inside audible range, fading out behind player)
local REAR_RADIUS_MIN = 25
local REAR_RADIUS_MAX = 30

-- Side emitter distances (lateral placement for surround feel)
local SIDE_RADIUS_MIN = 25
local SIDE_RADIUS_MAX = 30

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
    DeepForest = 1.8, OrganicForest = 1.6, PRForest = 1.4, Forest = 1.2,
    FarmLand = 0.8, Farm = 0.6, Vegitation = 0.8, TownZone = 0.1, WaterZone = 0.3,
    PHForest = 1.4, clay_lake = 1.2, clay_shore = 1.0, TrailerPark = 0.8,
    Unknown = 0.7, ForagingNav = 0.7
}

-- 3. BIRD DATA TABLE
BirdSoundSystem.Birds = {
    american_robin = {
        name = "American Robin",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation" },
        months = {3,4,5,6,7,8,9,10},
        hours = { start = 5, stop = 20 },
        rarity = 1,
        soundBase = "AmericanRobin",
        callVariants = 6,
        songVariants = 9,
        songWeight = 0.8,
        Repeat = {min = 14, max = 22},
        callDelay = {min = 2.4, max = 3},
        songInterval = {min = 2.4, max = 2.9}
    },
    american_goldfinch = {
        name = "American Goldfinch",
        biomes = { "TownZone", "FarmLand", "Forest", "OrganicForest", "PRForest", "Vegitation" },
        months = {5,6,7,8,9,10},
        hours = { start = 6, stop = 20 },
        rarity = 5,
        soundBase = "AmericanGoldfinch",
        callVariants = 12,
        songVariants = 5,
        songWeight = 0.5,
        Repeat = {min = 14, max = 22},
        callDelay = {min = 0.8, max = 1},
        songInterval = {min = 3.9, max = 5.2}
    },
    black_capped_chickadee = {
        name = "Black-capped Chickadee",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation" },
        months = {1,2,3,4,5,6,7,8,9,10,11,12},
        hours = { start = 6, stop = 19 },
        rarity = 5,
        soundBase = "BlackCappedChickadee",
        callVariants = 6,
        songVariants = 8,
        songWeight = 0.5,
        Repeat = {min = 8, max = 15},
        callDelay = {min = 1.2, max = 2.3},
        songInterval = {min = 2.3, max = 2.7}
    },
    blue_jay = {
        name = "Blue Jay",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation" },
        months = {1,2,3,4,5,6,7,8,9,10,11,12},
        hours = { start = 6, stop = 20 },
        rarity = 7,
        soundBase = "BlueJay",
        callVariants = 6,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 14, max = 22},
        callDelay = {min = 2.4, max = 3.6}
    },
    american_crow = {
        name = "American Crow",
        biomes = { "TownZone", "FarmLand", "Forest" },
        months = {1,2,3,4,5,6,7,8,9,10,11,12},
        hours = { start = 6, stop = 21 },
        rarity = 1,
        soundBase = "AmericanCrow",
        callVariants = 4,
        songVariants = 1,
        songWeight = 0.0,
        Repeat = {min = 8, max = 15},
        callDelay = {min = 5.4, max = 7.2}
    },
    barred_owl = {
        name = "Barred Owl",
        biomes = { "DeepForest", "OrganicForest", "Forest" },
        months = {1,2,3,4,10,11,12},
        hours = { start = 20, stop = 5 },
        rarity = 10,
        soundBase = "BarredOwl",
        callVariants = 9,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 7, max = 12},
        callDelay = {min = 0.6, max = 3.8}
    },
    common_loon = {
        name = "Common Loon",
        biomes = { "WaterZone", "clay_lake", "Shoreline" },
        months = {4,5,6,7,8,9,10},
        hours = { start = 5, stop = 22 },
        rarity = 7,
        soundBase = "CommonLoon",
        callVariants = 10,
        songVariants = 3,
        songWeight = 0.8,
        Repeat = {min = 6, max = 14},
        callDelay = {min = 1.2, max = 1.9},
        songInterval = {min = 7.3, max = 8.1}
    },
    belted_kingfisher = {
        name = "Belted Kingfisher",
        biomes = { "WaterZone", "clay_lake", "Shoreline", "Forest", "DeepForest", "OrganicForest" },
        months = {4,5,6,7,8,9,10},
        hours = { start = 6, stop = 21 },
        rarity = 7,
        soundBase = "BeltedKingfisher",
        callVariants = 5,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 14, max = 22},
        callDelay = {min = 1.7, max = 2.9}
    },
    bohemian_waxwing = {
        name = "Bohemian Waxwing",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation" },
        months = {11,12,1,2,3,4},
        hours = { start = 7, stop = 18 },
        rarity = 8,
        soundBase = "BohemianWaxwing",
        callVariants = 10,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 14, max = 22},
        callDelay = {min = 0.8, max = 4.2}
    },
    canada_goose = {
        name = "Canada Goose",
        biomes = { "WaterZone", "clay_lake", "Shoreline", "FarmLand", "Vegitation" },
        months = {3,4,5,6,7,8,9,10,11},
        hours = { start = 5, stop = 21 },
        rarity = 3,
        soundBase = "CanadaGoose",
        callVariants = 8,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 14, max = 22},
        callDelay = {min = 1.5, max = 1.6}
    },
    common_grackle = {
        name = "Common Grackle",
        biomes = { "TownZone", "FarmLand", "Forest", "Vegitation" },
        months = {3,4,5,6,7,8,9,10},
        hours = { start = 6, stop = 20 },
        rarity = 3,
        soundBase = "CommonGrackle",
        callVariants = 5,
        songVariants = 7,
        songWeight = 0.6,
        Repeat = {min = 8, max = 22},
        callDelay = {min = 1.9, max = 2.3},
        songInterval = {min = 2.9, max = 3.8}
    },
    dark_eyed_junco = {
        name = "Dark-eyed Junco",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation" },
        months = {10,11,12,1,2,3,4,5},
        hours = { start = 6, stop = 19 },
        rarity = 3,
        soundBase = "DarkEyedJunco",
        callVariants = 9,
        songVariants = 5,
        songWeight = 0.7,
        Repeat = {min = 8, max = 22},
        callDelay = {min = 0.7, max = 1.3},
        songInterval = {min = 4.2, max = 4.4}
    },
    herring_gull = {
        name = "Herring Gull",
        biomes = { "WaterZone", "clay_lake", "Shoreline", "TownZone", "FarmLand" },
        months = {1,2,3,4,5,6,7,8,9,10,11,12},
        hours = { start = 5, stop = 21 },
        rarity = 3,
        soundBase = "HerringGull",
        callVariants = 9,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 4, max = 15},
        callDelay = {min = 0.8, max = 1.6}
    },
    mallard_male = {
        name = "Mallard Male",
        biomes = { "WaterZone", "clay_lake", "Shoreline", "FarmLand", "Vegitation" },
        months = {3,4,5,6,7,8,9,10,11},
        hours = { start = 5, stop = 21 },
        rarity = 4,
        soundBase = "MallardMale",
        callVariants = 10,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 9, max = 22},
        callDelay = {min = 0.5, max = 0.6}
    },
    mallard_female = {
        name = "Mallard Female",
        biomes = { "WaterZone", "clay_lake", "Shoreline", "FarmLand", "Vegitation" },
        months = {3,4,5,6,7,8,9,10,11},
        hours = { start = 5, stop = 21 },
        rarity = 4,
        soundBase = "MallardFemale",
        callVariants = 16,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 7, max = 22},
        callDelay = {min = 0.24, max = 0.3}
    },
    northern_flicker = {
        name = "Northern Flicker",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation" },
        months = {1,2,3,4,5,6,7,8,9,10,11,12},
        hours = { start = 6, stop = 20 },
        rarity = 6,
        soundBase = "NorthernFlicker",
        callVariants = 3,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 8, max = 22},
        callDelay = {min = 6, max = 6.5}
    },
    pileated_woodpecker = {
        name = "Pileated Woodpecker",
        biomes = { "DeepForest", "OrganicForest", "Forest" },
        months = {1,2,3,4,5,6,7,8,9,10,11,12},
        hours = { start = 6, stop = 19 },
        rarity = 9,
        soundBase = "PileatedWoodpecker",
        callVariants = 4,
        songVariants = 0,
        songWeight = 0.0,
        Repeat = {min = 9, max = 22},
        callDelay = {min = 7.5, max = 8.3}
    },
    red_winged_blackbird = {
        name = "Red-winged Blackbird",
        biomes = { "FarmLand", "Vegitation", "WaterZone", "Shoreline" },
        months = {3,4,5,6,7,8,9},
        hours = { start = 5, stop = 21 },
        rarity = 2,
        soundBase = "RedWingedBlackbird",
        callVariants = 6,
        songVariants = 4,
        songWeight = 0.8,
        Repeat = {min = 13, max = 22},
        callDelay = {min = 1.5, max = 3.0},
        songInterval = {min = 0.9, max = 1.5}
    },
    song_sparrow = {
        name = "Song Sparrow",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation", "Shoreline", "clay_lake" },
        months = {3,4,5,6,7,8,9,10,11},
        hours = { start = 5, stop = 20 },
        rarity = 2,
        soundBase = "SongSparrow",
        callVariants = 15,
        songVariants = 5,
        songWeight = 0.8,
        Repeat = {min = 12, max = 22},
        callDelay = {min = 0.75, max = 1.2},
        songInterval = {min = 6.2, max = 6.6}
    },
    white_throated_sparrow = {
        name = "White-throated Sparrow",
        biomes = { "TownZone", "FarmLand", "Forest", "DeepForest", "OrganicForest", "PRForest", "Vegitation" },
        months = {10,11,12,1,2,3,4,5},
        hours = { start = 6, stop = 19 },
        rarity = 3,
        soundBase = "WhiteThroatedSparrow",
        callVariants = 11,
        songVariants = 5,
        songWeight = 0.7,
        Repeat = {min = 11, max = 22},
        callDelay = {min = 0.9, max = 1.7},
        songInterval = {min = 6, max = 6.2}
    },
    yellow_rumped_warbler = {
        name = "Yellow-rumped Warbler",
        biomes = { "TownZone", "FarmLand", "Forest", "OrganicForest", "PRForest", "Vegitation" },
        months = {4,5,6,7,8,9,10},
        hours = { start = 6, stop = 20 },
        rarity = 5,
        soundBase = "YellowRumpedWarbler",
        callVariants = 11,
        songVariants = 4,
        songWeight = 0.7,
        Repeat = {min = 11, max = 22},
        callDelay = {min = 0.6, max = 1.3},
        songInterval = {min = 7.4, max = 8.2}
    }
}

-- 4. DETERMINISTIC PLACEMENT ENGINE
local function getSeedRoll(seed, max)
    local val = (abs(floor(seed)) * 1103515245 + 12345) % 2147483648
    if max then return val % max end
    return val
end

function BirdSoundSystem.getWeightedDirection(player, seed)
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

function BirdSoundSystem.getRearDirection(player, seed)
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

function BirdSoundSystem.getSideDirection(player, seed)
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
function BirdSoundSystem.applyBubbleRepulsion(playerX, playerY, posX, posY)
    local dx = posX - playerX
    local dy = posY - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- If inside or at bubble boundary, push out to boundary
    if distance < BirdSoundSystem.playerBubbleRadius then
        if distance == 0 then
            -- Edge case: emitter exactly on player, push in random direction
            local angle = ZRandFloat(0, math.pi * 2)
            posX = playerX + math.cos(angle) * BirdSoundSystem.playerBubbleRadius
            posY = playerY + math.sin(angle) * BirdSoundSystem.playerBubbleRadius
        else
            -- Push to bubble boundary along same direction
            local scale = BirdSoundSystem.playerBubbleRadius / distance
            posX = playerX + dx * scale
            posY = playerY + dy * scale
        end
    end
    
    return posX, posY
end

-- 5. POOL MANAGEMENT
function BirdSoundSystem.allocateEmitterPool()
    local world = getWorld()
    if not world then
        if DEBUG then print("[BirdSoundSystem] ERROR: getWorld() returned nil") end
        return false
    end
    for i = 1, BirdSoundSystem.poolSize do
        local emitter = world:getFreeEmitter()
        if emitter then
            table.insert(BirdSoundSystem.emitterPool, { emitter = emitter, inUse = false, lastUsed = 0 })
        end
    end
    if DEBUG then print("[BirdSoundSystem] Allocated " .. #BirdSoundSystem.emitterPool .. " emitters") end
    return #BirdSoundSystem.emitterPool > 0
end

function BirdSoundSystem.getFreeEmitterFromPool()
    local time = BirdSoundSystem.globalTickCounter
    for _, poolEntry in ipairs(BirdSoundSystem.emitterPool) do
        if not poolEntry.inUse or poolEntry.emitter:isEmpty() then
            poolEntry.inUse = true
            poolEntry.lastUsed = time
            return poolEntry
        end
    end
    local oldest = BirdSoundSystem.emitterPool[1]
    for i = 2, #BirdSoundSystem.emitterPool do
        if BirdSoundSystem.emitterPool[i].lastUsed < oldest.lastUsed then oldest = BirdSoundSystem.emitterPool[i] end
    end
    oldest.emitter:stopAll()
    oldest.inUse = true
    oldest.lastUsed = time
    return oldest
end

-- 6. SEQUENCER & PLAYBACK
function BirdSoundSystem.updateSequences()
    if #BirdSoundSystem.activeSequences == 0 then return end
    local currentRealTime = BirdSoundSystem.realTimeCounter
    local player = getPlayer()
    if not player then return end
    
    for i = #BirdSoundSystem.activeSequences, 1, -1 do
        local seq = BirdSoundSystem.activeSequences[i]
        
        if currentRealTime >= seq.nextNoteTime then
            local variantCount = (seq.soundType == "Song") and seq.birdData.songVariants or seq.birdData.callVariants
            local variant = ZRand(variantCount) + 1
            local soundName = seq.birdData.soundBase .. seq.soundType .. tostring(variant)
            
            local poolEntry = BirdSoundSystem.getFreeEmitterFromPool()
            if poolEntry then
                -- Apply bubble repulsion to push emitter away from player
                local px, py = player:getX(), player:getY()
                seq.pos.x, seq.pos.y = BirdSoundSystem.applyBubbleRepulsion(px, py, seq.pos.x, seq.pos.y)
                poolEntry.emitter:setPos(seq.pos.x, seq.pos.y, player:getZ())
                -- Play first, then set volume on the returned handle
                local handle = poolEntry.emitter:playSound(soundName)
                BirdSoundVolume.applyToHandle(poolEntry.emitter, handle)
                poolEntry.emitter:tick()
                poolEntry.lastUsed = BirdSoundSystem.globalTickCounter
                
                seq.remaining = seq.remaining - 1
                if seq.remaining > 0 then
                    local nextDelay = seq.delayRange.min + (ZRandFloat(0.0, 1.0) * (seq.delayRange.max - seq.delayRange.min))
                    seq.nextNoteTime = currentRealTime + nextDelay
                else
                    table.remove(BirdSoundSystem.activeSequences, i)
                end
            else
                table.remove(BirdSoundSystem.activeSequences, i)
            end
        end
    end
end

-- Layer 2: Continuously update all active sequence positions based on player movement
-- This ensures emitters stay outside the bubble even when player moves between notes
function BirdSoundSystem.updateSequencePositions(player)
    if #BirdSoundSystem.activeSequences == 0 then return end
    
    local px, py = player:getX(), player:getY()
    
    for _, seq in ipairs(BirdSoundSystem.activeSequences) do
        seq.pos.x, seq.pos.y = BirdSoundSystem.applyBubbleRepulsion(px, py, seq.pos.x, seq.pos.y)
    end
end

function BirdSoundSystem.playBirdSound(player, birdData, seed, env, isRear, isSide)
    local px, py = player:getX(), player:getY()
    local songWeight = birdData.songWeight * (env.songProbFactor + 0.1)
    local soundType = (birdData.songVariants > 0 and (getSeedRoll(seed + 55, 100) / 100 < songWeight)) and "Song" or "Call"
    
    local direction
    local dist
    local location
    
    if isSide then
        direction = BirdSoundSystem.getSideDirection(player, seed)
        dist = (SIDE_RADIUS_MIN + env.radiusOffset) + getSeedRoll(seed + 44, (SIDE_RADIUS_MAX - SIDE_RADIUS_MIN))
        location = "SIDE"
    elseif isRear then
        direction = BirdSoundSystem.getRearDirection(player, seed)
        dist = (REAR_RADIUS_MIN + env.radiusOffset) + getSeedRoll(seed + 44, (REAR_RADIUS_MAX - REAR_RADIUS_MIN))
        location = "REAR"
    else
        direction = BirdSoundSystem.getWeightedDirection(player, seed)
        dist = (BASE_RADIUS_MIN + env.radiusOffset) + getSeedRoll(seed + 22, (BASE_RADIUS_MAX - BASE_RADIUS_MIN))
        location = "FRONT"
    end
    
    local countR = birdData.Repeat or {min = 1, max = 1}
    local repeatCount = getSeedRoll(seed, (countR.max - countR.min) + 1) + countR.min

    local delayRange = (soundType == "Call") and (birdData.callDelay or {min = 0.5, max = 0.8}) or (birdData.songInterval or {min = 4.0, max = 8.0})

    if DEBUG then print("[BirdSoundSystem] Queuing " .. location .. " " .. birdData.name .. " (" .. soundType .. ")") end
    
    -- Layer 1: Apply bubble repulsion at sequence creation to prevent initial placement inside bubble
    local rawX = px + (direction.x * dist)
    local rawY = py + (direction.y * dist)
    local finalX, finalY = BirdSoundSystem.applyBubbleRepulsion(px, py, rawX, rawY)
    
    table.insert(BirdSoundSystem.activeSequences, {
        birdData = birdData, soundType = soundType, remaining = repeatCount,
        delayRange = delayRange, nextNoteTime = BirdSoundSystem.realTimeCounter,
        pos = {x = finalX, y = finalY}
    })
end

-- 7. TICK & LOGIC
function BirdSoundSystem.getCurrentBiome(player)
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
function BirdSoundSystem.checkDistanceReset(player)
    if not BirdSoundSystem.isPanicked then return end
    
    local sx, sy = BirdSoundSystem.startlePosition.x, BirdSoundSystem.startlePosition.y
    if not sx or not sy then return end
    
    local px, py = player:getX(), player:getY()
    local dx = px - sx
    local dy = py - sy
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance >= RESET_DISTANCE then
        BirdSoundSystem.suppressionTimer = 0
        BirdSoundSystem.isPanicked = false
        BirdSoundSystem.startlePosition = {x = nil, y = nil}
        if DEBUG then print("[BirdSoundSystem] Reset startle state after traveling " .. distance .. " tiles") end
    end
end

function BirdSoundSystem.onTick()
    if not BirdSoundSystem.isInitialized then return end
    
    local player = getPlayer()
    -- B42 SAFETY: Check for player existence and square loading
    if not player or player:isDead() or not player:getCurrentSquare() then return end
    
    -- Check if player has traveled far enough to reset startle state
    BirdSoundSystem.checkDistanceReset(player)
    
    BirdSoundSystem.globalTickCounter = BirdSoundSystem.globalTickCounter + 1
    BirdSoundSystem.realTimeCounter = BirdSoundSystem.realTimeCounter + (1.0 / BirdSoundSystem.TICKS_PER_SECOND)
    BirdSoundSystem.updateSequences()
    BirdSoundSystem.updateSequencePositions(player)  -- Layer 2: Update positions every tick

    -- STARTUP GRACE PERIOD - NO SOUNDS FOR FIRST 5 SECONDS
    if BirdSoundSystem.startupTimer < BirdSoundSystem.startupGracePeriod then
        BirdSoundSystem.startupTimer = BirdSoundSystem.startupTimer + (1.0 / BirdSoundSystem.TICKS_PER_SECOND)
        return  -- Exit early, no zone processing during grace period
    end

    -- START PAUSE PERIOD - SIDE AND REAR EMITTERS PAUSED FOR FIRST 60 SECONDS
    if BirdSoundSystem.startPauseTimer < BirdSoundSystem.startPauseDuration then
        BirdSoundSystem.startPauseTimer = BirdSoundSystem.startPauseTimer + (1.0 / BirdSoundSystem.TICKS_PER_SECOND)
    end

    -- OPTIMIZATION: Cache getGameTime() once per tick and extract all needed values
    local gt = getGameTime()
    local month = gt:getMonth() + 1
    local hour = gt:getHour()
    local currentMinutesStamp = gt:getMinutesStamp()
    local worldAgeMinutes = gt:getWorldAgeHours() * 60
    
    if currentMinutesStamp == BirdSoundSystem.lastCheckMinutesStamp then return end
    BirdSoundSystem.lastCheckMinutesStamp = currentMinutesStamp

    if BirdSoundSystem.suppressionTimer > 0 then
        BirdSoundSystem.suppressionTimer = BirdSoundSystem.suppressionTimer - 1
        return
    end

    local sq = player:getSquare()
    if not sq or not sq:isOutside() then return end
    if player:getVehicle() and player:getVehicle():isEngineRunning() then return end
    if getClimateManager():getPrecipitationIntensity() > 0.4 then return end

    -- OPTIMIZATION: Pass cached time values to avoid redundant getGameTime() calls
    BirdSoundSystem.updateZoneState(player, gt, month, hour, worldAgeMinutes)
end

function BirdSoundSystem.updateZoneState(player, gt, month, hour, worldAgeMinutes)
    local biome = BirdSoundSystem.getCurrentBiome(player)
    local gameTimeMinutes = worldAgeMinutes
    local px, py = floor(player:getX()), floor(player:getY())

    local seed = (px * 31 + py) + floor(gameTimeMinutes / 10)
    local seasonalIntensity = (math_sin((month - 3) * (3.14159 / 6)) + 1) / 2
    local seasonalDensity = 0.2 + (seasonalIntensity * 0.8)
    
    local timeIntensity = 0.05
    if hour >= 5 and hour < 6 then timeIntensity = 1.2
    elseif hour >= 6 and hour < 7 then timeIntensity = 1.0
    elseif hour >= 7 and hour < 9 then timeIntensity = 0.8
    elseif hour >= 9 and hour < 12 then timeIntensity = 0.5
    elseif hour >= 12 and hour < 16 then timeIntensity = 0.3
    elseif hour >= 16 and hour < 18 then timeIntensity = 0.5
    elseif hour >= 18 and hour < 20 then timeIntensity = 0.7
    end

    local env = {
        songProbFactor = seasonalIntensity * timeIntensity,
        radiusOffset = (1 - seasonalIntensity) * 15,
        tempoMulti = 2.0 - (seasonalIntensity * 0.5),
        biomeDensity = BIOME_DENSITY[biome] or 1.5,
        biome = biome,
        seasonalDensity = seasonalDensity
    }

    local timeMultiplier = 1.0
    if hour >= 5 and hour < 7 then timeMultiplier = 0.3
    elseif hour >= 7 and hour < 9 then timeMultiplier = 0.5
    elseif hour >= 9 and hour < 12 then timeMultiplier = 1.0
    elseif hour >= 12 and hour < 17 then timeMultiplier = 1.5
    elseif hour >= 17 and hour < 20 then timeMultiplier = 1.2
    else timeMultiplier = 0.05  -- Nighttime: 20:00-5:00 - very rare
    end

    -- Process each direction independently with its own timing
    BirdSoundSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, "front", timeMultiplier, 0)
    
    -- Skip rear and side emitters during start pause period (first 60 real seconds)
    if BirdSoundSystem.startPauseTimer >= BirdSoundSystem.startPauseDuration then
        BirdSoundSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, "rear", timeMultiplier, 1000)
        BirdSoundSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, "side", timeMultiplier, 2000)
    end
end

-- Helper function to process each direction independently
function BirdSoundSystem.processDirectionTrigger(player, seed, env, hour, month, gameTimeMinutes, direction, timeMultiplier, seedOffset)
    local dirSeed = seed + seedOffset
    local zoneTempo = (0.5 + (getSeedRoll(dirSeed, 100) / 100) * 2.5) * timeMultiplier * env.tempoMulti * (1.0 / env.biomeDensity) * env.seasonalDensity
    
    -- Initialize trigger time if not set
    if not BirdSoundSystem.nextTriggerTime[direction] then
        BirdSoundSystem.nextTriggerTime[direction] = gameTimeMinutes + zoneTempo
    end

    -- Check if this direction should trigger
    if gameTimeMinutes >= BirdSoundSystem.nextTriggerTime[direction] then
        -- Check global cooldown - ensure minimum time between any bird spawn
        if BirdSoundSystem.lastSpawnTime >= 0 and gameTimeMinutes - BirdSoundSystem.lastSpawnTime < BirdSoundSystem.globalSpawnCooldown then
            -- Not enough time has passed since last spawn, skip this trigger
            return
        end
        
        BirdSoundSystem.tryPlayZoneBird(player, dirSeed, env, hour, month, direction)
        -- Update last spawn time
        BirdSoundSystem.lastSpawnTime = gameTimeMinutes
        -- Add jitter (±20% random variation) to break up rhythmic spawning
        local jitter = (getSeedRoll(dirSeed + 999, 40) - 20) / 100  -- -0.2 to +0.2
        local nextDelay = zoneTempo * (1.0 + jitter)
        BirdSoundSystem.nextTriggerTime[direction] = gameTimeMinutes + nextDelay
    end
end

-- Rebuild monthly cache - filters all birds by month to reduce per-call comparisons
function BirdSoundSystem.rebuildMonthlyCache(month)
    BirdSoundSystem.MonthlyCache = {}
    BirdSoundSystem.lastCachedMonth = month
    for key, bird in pairs(BirdSoundSystem.Birds) do
        for _, m in ipairs(bird.months) do
            if m == month then
                table.insert(BirdSoundSystem.MonthlyCache, bird)
                break
            end
        end
    end
end

function BirdSoundSystem.tryPlayZoneBird(player, seed, env, hour, month, direction)
    -- Rebuild cache if month changed (happens once per month in game time)
    if BirdSoundSystem.lastCachedMonth ~= month then
        BirdSoundSystem.rebuildMonthlyCache(month)
    end
    
    -- Cap active sequences to prevent FPS drops during Dawn Chorus
    if #BirdSoundSystem.activeSequences > 12 then return end
    local validBirds = {}
    -- Iterate only cached birds (already filtered by month) - reduces comparisons by ~94%
    for _, v in ipairs(BirdSoundSystem.MonthlyCache) do
        local bMatch = false
        for _, b in ipairs(v.biomes) do if b == env.biome then bMatch = true break end end
        if bMatch then
            local startH, stopH = v.hours.start, v.hours.stop
            local hMatch = (startH < stopH) and (hour >= startH and hour < stopH) or (hour >= startH or hour < stopH)
            if hMatch then table.insert(validBirds, v) end
        end
    end

    if #validBirds == 0 then return end
    
    local totalWeight = 0
    for _, v in ipairs(validBirds) do
        v._calcWeight = math.pow(MAX_RARITY + 1 - v.rarity, RARITY_POWER)
        totalWeight = totalWeight + v._calcWeight
    end
    
    -- Each direction is now independent - spawn only for the requested direction
    local isRear = (direction == "rear")
    local isSide = (direction == "side")
    
    local roll = getSeedRoll(seed, totalWeight)
    local currentWeight = 0
    for _, v in ipairs(validBirds) do
        currentWeight = currentWeight + v._calcWeight
        if roll < currentWeight then
            BirdSoundSystem.playBirdSound(player, v, seed, env, isRear, isSide)
            break
        end
    end
end

function BirdSoundSystem.OnWeaponSwing(character, weapon)
    if not weapon or weapon:getSoundRadius() <= 20 then return end

    local player = getPlayer()
    if not player then return end

    -- Store the player's position when startle occurred for distance-based reset
    BirdSoundSystem.startlePosition.x = player:getX()
    BirdSoundSystem.startlePosition.y = player:getY()

    -- Check if gunshot is within audible range of player
    local dx = character:getX() - player:getX()
    local dy = character:getY() - player:getY()
    local distanceToGunshot = math.sqrt(dx * dx + dy * dy)

    -- Only react if gunshot is within weapon's sound radius of player
    if distanceToGunshot > weapon:getSoundRadius() then return end

    local px, py = player:getX(), player:getY()
    local removedCount = 0

    -- Remove nearby bird sequences (within startle radius)
    -- Distant birds continue singing, so forest doesn't go completely silent
    for i = #BirdSoundSystem.activeSequences, 1, -1 do
        local seq = BirdSoundSystem.activeSequences[i]
        local dx = seq.pos.x - px
        local dy = seq.pos.y - py
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < BirdSoundSystem.startleRadius then
            -- Play flyaway sound for this bird before removing
            local flyAwayCount = 13  -- FlyAway1 through FlyAway13
            local flyAwayIndex = ZRand(flyAwayCount) + 1
            local soundName = "FlyAway" .. tostring(flyAwayIndex)
            
            -- Get a free emitter to play flyaway sound
            local poolEntry = BirdSoundSystem.getFreeEmitterFromPool()
            if poolEntry then
                -- Apply bubble repulsion to push emitter away from player
                local fx, fy = BirdSoundSystem.applyBubbleRepulsion(px, py, seq.pos.x, seq.pos.y)
                poolEntry.emitter:setPos(fx, fy, player:getZ())
                
                -- Add subtle stagger: random delay between 0 and 0.15 seconds
                local staggerDelay = ZRandFloat(0.0, 0.15)
                
                -- Play first, then set volume on the returned handle
                local handle = poolEntry.emitter:playSound(soundName)
                BirdSoundVolume.applyToHandle(poolEntry.emitter, handle)
                poolEntry.emitter:tick()
                poolEntry.lastUsed = BirdSoundSystem.globalTickCounter
            end
            
            table.remove(BirdSoundSystem.activeSequences, i)
            removedCount = removedCount + 1
        end
    end

    if DEBUG then print("[BirdSoundSystem] Removed " .. removedCount .. " nearby bird sequences") end

    BirdSoundSystem.suppressionTimer = 1200
    BirdSoundSystem.isPanicked = true
    -- Reset all independent trigger times
    BirdSoundSystem.nextTriggerTime = { front = nil, rear = nil, side = nil }
    -- Reset last spawn time to allow birds to respawn after suppression
    BirdSoundSystem.lastSpawnTime = -1
end

-- 8. INITIALIZATION
function BirdSoundSystem.init()
    -- B42 SAFETY: isServer() is strictly enforced; getWorld() must exist
    if isServer() or BirdSoundSystem.isInitialized then return end
    
    -- Ensure player exists before grabbing emitters
    if not getPlayer() then return end

    if BirdSoundSystem.allocateEmitterPool() then
        local gt = getGameTime()
        BirdSoundSystem.lastCheckMinutesStamp = gt:getMinutesStamp()
        BirdSoundSystem.realTimeCounter = 0
        BirdSoundSystem.startupTimer = 0  -- Initialize startup timer
        BirdSoundSystem.startPauseTimer = 0  -- Initialize start pause timer
        BirdSoundSystem.lastSpawnTime = -1  -- Initialize last spawn time
        
        -- Set initial trigger times to prevent burst at startup
        local initialDelay = 10.0  -- 10 game minutes after startup
        for _, dir in ipairs({"front", "rear", "side"}) do
            BirdSoundSystem.nextTriggerTime[dir] = gt:getWorldAgeHours() * 60 + initialDelay
        end
        
        Events.OnTick.Add(BirdSoundSystem.onTick)
        Events.OnWeaponSwing.Add(BirdSoundSystem.OnWeaponSwing)
        BirdSoundSystem.isInitialized = true
        if DEBUG then print("[BirdSoundSystem] B42 Unified Module Active with 5s startup grace period") end
    end
end

-- Changed from OnGameStart to OnCreatePlayer for stability
Events.OnCreatePlayer.Add(BirdSoundSystem.init)
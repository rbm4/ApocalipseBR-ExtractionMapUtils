BitingInsectSystem = BitingInsectSystem or {}
local DEBUG = false

-- 1. SYSTEM CONFIGURATION
BitingInsectSystem.poolSize = 15
BitingInsectSystem.emitterPool = {}
BitingInsectSystem.isInitialized = false

-- Timing & Multipliers
BitingInsectSystem.lastCheckMinutesStamp = 0
BitingInsectSystem.globalTickCounter = 0
BitingInsectSystem.globalIntensityMultiplier = 1.0 -- Scaling hook for sandbox

-- Damage Configuration
BitingInsectSystem.bodyDamageAmount = 0.8 -- Actual HP damage for bites that causeBodyDamage

-- Rarity System Configuration (matching SingingInsectsSystem pattern)
local MAX_RARITY = 10
local RARITY_POWER = 1

-- Localize functions for performance
local ZRand = ZombRand
local ZRandFloat = ZombRandFloat
local floor = math.floor
local abs = math.abs
local BIOME_CHECK_DIST = 10 

-- 2. DATA TABLES (Unchanged Protection/Damage)
BitingInsectSystem.DamageTypes = {
    itchy_welt     = { stress = 0.05, unhappiness = 0.05, pain = 2, causesBodyDamage = true },
    bloody_welt    = { stress = 0.05, unhappiness = 0.05, pain = 8, causesBodyDamage = true },
    hard_welt      = { stress = 0.05, unhappiness = 0.05, pain = 15, causesBodyDamage = true },
    hot_prick      = { stress = 0.05, unhappiness = 0.05, pain = 12, causesBodyDamage = true },
    bullseye_welt  = { stress = 0.05, unhappiness = 0.05, pain = 25, causesBodyDamage = true },
    sting          = { stress = 0.05, unhappiness = 0.05, pain = 50, causesBodyDamage = true },
    cluster_rash   = { stress = 0.05, unhappiness = 0.05, pain = 5, causesBodyDamage = true }
}

local PROTECTION_MAP = {
    head = { ["FullHat"] = 0.9, ["Hat"] = 0.4, ["Mask"] = 0.6, ["MaskEyes"] = 0.5, ["MaskFull"] = 0.9, ["FullSuitHead"] = 1.0, ["Scarf"] = 0.5, ["Neck"] = 0.3, ["Gorget"] = 0.8, ["Scba"] = 0.9, ["JacketHat"] = 0.8, ["SweaterHat"] = 0.6 },
    upper = { ["Jacket"] = 0.8, ["JacketBulky"] = 0.9, ["Shirt"] = 0.6, ["ShortSleeveShirt"] = 0.4, ["Tshirt"] = 0.3, ["TankTop"] = 0.1, ["Sweater"] = 0.7, ["Boilersuit"] = 0.9, ["FullSuit"] = 1.0, ["Hands"] = 0.7, ["LeftArm"] = 0.5, ["RightArm"] = 0.5, ["TorsoExtraVest"] = 0.4, ["Bandage"] = 0.2 },
    legs = { ["Pants"] = 0.7, ["ShortPants"] = 0.3, ["Skirt"] = 0.2, ["LongSkirt"] = 0.6, ["Socks"] = 0.2, ["Shoes"] = 0.8, ["GaiterLeft"] = 0.5, ["GaiterRight"] = 0.5, ["ThighLeft"] = 0.3, ["ThighRight"] = 0.3, ["KneeLeft"] = 0.2, ["KneeRight"] = 0.2, ["Underwear"] = 0.1 }
}

-- Zone to BodyPart mapping with weights for selective body damage
local ZONE_BODY_PARTS = {
    head = {
        { part = "Head", partIndex = 0, weight = 70 },
        { part = "Neck", partIndex = 1, weight = 30 }
    },
    upper = {
        { part = "Torso_Upper", partIndex = 2, weight = 50 },
        { part = "LeftArm", partIndex = 4, weight = 20 },
        { part = "RightArm", partIndex = 5, weight = 20 },
        { part = "Torso_Lower", partIndex = 3, weight = 10 }
    },
    legs = {
        { part = "LeftLeg", partIndex = 6, weight = 35 },
        { part = "RightLeg", partIndex = 7, weight = 35 },
        { part = "LeftFoot", partIndex = 8, weight = 15 },
        { part = "RightFoot", partIndex = 9, weight = 15 }
    }
}

BitingInsectSystem.Insects = {
    mosquito     = { name = "Mosquito", damageType = "itchy_welt", months = {3,4,5,6,7,8}, activePeriods = {{start = 7, stop = 11}, {start = 15, stop = 3}}, biteChanceMod = 1.0, zone = "upper", soundBase = "Mosquito", soundVariants = 5, movementMods = { sprinting = 0.01, running = 0.1, walking = 0.5, idle = 1.0 }, fireRepelled = true, rarity = 1.0 },
    black_fly    = { name = "Black Fly", damageType = "bloody_welt", months = {4,5}, peakHours = {start = 7, stop = 19}, biteChanceMod = 1.4, zone = "head", soundBase = "Flybuzz", soundVariants = 9, movementMods = { sprinting = 0.2, running = 0.4, walking = 0.7, idle = 1.0 }, fireRepelled = true, rarity = 3.0 },
    deer_fly     = { name = "Deer Fly", damageType = "hard_welt", months = {5,6,7}, peakHours = {start = 10, stop = 17}, biteChanceMod = 0.9, zone = "upper", soundBase = "Flybuzz", soundVariants = 9, movementMods = { sprinting = 1.5, running = 1.2, walking = 0.8, idle = 0.5 }, fireRepelled = false, rarity = 5.0 },
    horse_fly    = { name = "Horse Fly", damageType = "bullseye_welt", months = {6,7}, peakHours = {start = 9, stop = 18}, biteChanceMod = 0.6, zone = "upper", soundBase = "Flybuzz", soundVariants = 9, movementMods = { sprinting = 2.0, running = 1.5, walking = 0.8, idle = 0.5 }, fireRepelled = false, rarity = 6.0 },
    stable_fly   = { name = "Stable Fly", damageType = "hot_prick", months = {4,5,6,7,8}, peakHours = {start = 6, stop = 21}, biteChanceMod = 1.8, zone = "legs", soundBase = "Flybuzz", soundVariants = 9, targetRooms = {"barn", "shed", "fishingstorage"}, movementMods = { sprinting = 0.3, running = 0.5, walking = 0.8, idle = 1.0 }, fireRepelled = true, rarity = 4.0 },
    midges       = { name = "Midge", damageType = "cluster_rash", months = {4,5,6,7,8}, peakHours = {start = 6, stop = 21}, biteChanceMod = 0.6, zone = "head", soundBase = "Swarm", soundVariants = 4, movementMods = { sprinting = 0.4, running = 0.6, walking = 0.8, idle = 1.0 }, fireRepelled = true, rarity = 2.0 },
    yellowjacket = { name = "Yellowjacket", damageType = "sting", months = {6,7,8,9,10}, peakHours = {start = 8, stop = 20}, biteChanceMod = 0.1, zone = "upper", soundBase = "Flybuzz", soundVariants = 9, movementMods = { sprinting = 2.0, running = 1.5, walking = 0.8, idle = 0.5 }, fireRepelled = false, rarity = 10.0 }
}

local BIOME_WEIGHTS = {
    ["DeepForest"] = 95, ["OrganicForest"] = 85, ["Forest"] = 75, ["PRForest"] = 65,
    ["PHForest"] = 70, ["FarmLand"] = 30, ["Farm"] = 25, ["Vegitation"] = 35,
    ["TownZone"] = 5, ["TrailerPark"] = 8, ["Shoreline"] = 90,
    ["clay_lake"] = 95, ["clay_shore"] = 90, ["Unknown"] = 10, ["ForagingNav"] = 10
}
InsectManager = { currentZone = "Unknown", lastValidZone = "TownZone", intensity = 10, lastX = 0, lastY = 0 }

-- 3. POOL MANAGEMENT (Recycling Implementation)
function BitingInsectSystem.allocateEmitterPool()
    local world = getWorld()
    if not world then return false end
    for i = 1, BitingInsectSystem.poolSize do
        local emitter = world:getFreeEmitter()
        if emitter then
            table.insert(BitingInsectSystem.emitterPool, { emitter = emitter, inUse = false, emitterIndex = nil, lastUsed = 0 })
        end
    end
    return #BitingInsectSystem.emitterPool > 0
end

function BitingInsectSystem.getFreeEmitterFromPool()
    local time = BitingInsectSystem.globalTickCounter
    
    -- 1. Try to find a truly idle emitter using isEmpty()
    -- This is the safe B42-friendly way to check if an emitter is busy.
    for _, poolEntry in ipairs(BitingInsectSystem.emitterPool) do
        if not poolEntry.inUse or poolEntry.emitter:isEmpty() then
            poolEntry.inUse = true
            poolEntry.lastUsed = time
            return poolEntry
        end
    end
    
    -- 2. If all are busy, recycle the one that hasn't been used for the longest time
    local oldest = BitingInsectSystem.emitterPool[1]
    for i = 2, #BitingInsectSystem.emitterPool do
        if BitingInsectSystem.emitterPool[i].lastUsed < oldest.lastUsed then 
            oldest = BitingInsectSystem.emitterPool[i] 
        end
    end
    
    -- Force stop whatever was playing to make room for the new sound
    oldest.emitter:stopAll()
    oldest.inUse = true
    oldest.lastUsed = time
    return oldest
end

-- 4. LOGIC ENGINE
function BitingInsectSystem.calculateDefense(player, zoneName)
    local wornItems = player:getWornItems()
    if not wornItems or wornItems:isEmpty() then return 0.0 end
    local probOfBite = 1.0
    local zoneTable = PROTECTION_MAP[zoneName] or PROTECTION_MAP["upper"]
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:get(i)
        if wornItem then
            local locationId = wornItem:getLocation()
            if zoneTable[locationId] then probOfBite = probOfBite * (1.0 - zoneTable[locationId]) end
        end
    end
    return 1.0 - probOfBite
end

function BitingInsectSystem.getRandomBodyPartForZone(zone)
    local candidates = ZONE_BODY_PARTS[zone] or ZONE_BODY_PARTS["upper"]
    local totalWeight = 0
    for _, candidate in ipairs(candidates) do
        totalWeight = totalWeight + candidate.weight
    end
    local roll = ZRandFloat(0, totalWeight)
    local currentWeight = 0
    for _, candidate in ipairs(candidates) do
        currentWeight = currentWeight + candidate.weight
        if roll < currentWeight then
            return candidate.part, candidate.partIndex
        end
    end
    return candidates[1].part, candidates[1].partIndex
end

function BitingInsectSystem.applyBite(player, insect)
    if not player or not player:isAlive() then return end

    local defense = BitingInsectSystem.calculateDefense(player, insect.zone)
    local biteBlocked = ZRandFloat(0.0, 1.0) < defense

    -- Audio: Spatialized with Immediate Tick
    if insect.soundBase and (not biteBlocked or ZRand(4) == 0) then
        local poolEntry = BitingInsectSystem.getFreeEmitterFromPool()
        if poolEntry then
            local variant = ZRand(insect.soundVariants) + 1
            local soundName = insect.soundBase .. tostring(variant)
            poolEntry.emitter:setPos(player:getX() + ZRandFloat(-0.5, 0.5), player:getY() + ZRandFloat(-0.5, 0.5), player:getZ())
            poolEntry.emitter:playSound(soundName)
            poolEntry.emitter:tick()
        end
    end

    if biteBlocked then return end

    -- Get damage profile
    local profile = BitingInsectSystem.DamageTypes[insect.damageType]
    if not profile then return end

    -- Apply stats (STRESS and UNHAPPINESS work with stats:add)
    local stats = player:getStats()
    if stats then
        stats:add(CharacterStat.STRESS, profile.stress or 0)
        stats:add(CharacterStat.UNHAPPINESS, profile.unhappiness or 0)
    end

    -- Only apply body damage for painful bites (to trigger pain moodle)
    if profile.causesBodyDamage then
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            local bodyPartName, partIndex = BitingInsectSystem.getRandomBodyPartForZone(insect.zone)
            
            -- Use minimal damage but apply full pain value directly
            -- This creates a "low damage, high pain" injury type
            local minimalDamage = BitingInsectSystem.bodyDamageAmount
            local painAmount = profile.pain or 0
            
            -- Use applyDamageFromWeapon to specify pain directly
            -- damageType 0 = generic/none, pain is passed as float
            bodyDamage:applyDamageFromWeapon(partIndex, minimalDamage, 0, painAmount)
            
            if DEBUG then 
                print("[Insects] Painful Bite: " .. insect.name .. " -> " .. bodyPartName .. " (damage: " .. minimalDamage .. ", pain: " .. painAmount .. ")")
            end
        end
    else
        if DEBUG then 
            print("[Insects] Mild Bite: " .. insect.name .. " (stress only)")
        end
    end

    -- Send stat updates for multiplayer
    if instanceof(player, "IsoPlayer") then
        sendPlayerStat(player, CharacterStat.STRESS)
        sendPlayerStat(player, CharacterStat.UNHAPPINESS)
    end
end

-- 5. ENGINE & HEARTBEAT
function BitingInsectSystem.onTick()
    if not BitingInsectSystem.isInitialized then return end
    BitingInsectSystem.globalTickCounter = BitingInsectSystem.globalTickCounter + 1

    -- OPTIMIZATION: Cache getGameTime() once per tick and extract all needed values
    local gt = getGameTime()
    local month = gt:getMonth()
    local hour = gt:getHour()
    local currentMinutesStamp = gt:getMinutesStamp()
    local worldAgeHours = gt:getWorldAgeHours()

    -- Ensure logic runs exactly once per in-game minute
    if currentMinutesStamp - BitingInsectSystem.lastCheckMinutesStamp < 1 then return end
    BitingInsectSystem.lastCheckMinutesStamp = currentMinutesStamp

    local player = getPlayer()
    if not player or player:isDead() or player:getVehicle() then return end
    if getClimateManager():getTemperature() < 10 then return end

    -- OPTIMIZATION: Pass cached time values to avoid redundant getGameTime() calls
    local activeCandidates = BitingInsectSystem.getEligibleInsects(month, hour)
    if #activeCandidates == 0 then return end

    -- Biome Intensity Check
    local x, y = floor(player:getX()), floor(player:getY())
    if abs(x - InsectManager.lastX) > BIOME_CHECK_DIST or abs(y - InsectManager.lastY) > BIOME_CHECK_DIST then
        InsectManager.lastX, InsectManager.lastY = x, y
        local mapZones = getWorld():getMetaGrid():getZonesAt(x, y, 0)
        local foundZone = "Unknown"
        if mapZones then
            for i = 0, mapZones:size() - 1 do
                local zType = mapZones:get(i):getType()
                if BIOME_WEIGHTS[zType] then
                    foundZone = zType
                    InsectManager.intensity = BIOME_WEIGHTS[foundZone]
                    break
                end
            end
        end

        -- If we found "Unknown" or "ForagingNav" (Road), use last valid biome instead
        if foundZone == "Unknown" or foundZone == "ForagingNav" then
            foundZone = InsectManager.lastValidZone
            InsectManager.intensity = BIOME_WEIGHTS[foundZone] or 10
        else
            -- Only update lastValidZone if we found a real biome
            InsectManager.lastValidZone = foundZone
        end

        InsectManager.currentZone = foundZone
    end

    local sq = player:getSquare()
    local isOutside = player:isOutside()
    local hasRepellent = BitingInsectSystem.hasRepellent(player, worldAgeHours)
    local envProtected = BitingInsectSystem.checkEnvironmentalProtection(player)

    -- Filter eligible insects that can bite based on conditions
    local canBiteInsects = {}
    for _, insect in ipairs(activeCandidates) do
        local canBite = false

        if insect.name == "Stable Fly" then
            local room = sq:getRoom()
            local roomName = room and room:getName() or "none"
            if insect.targetRooms then
                for _, target in ipairs(insect.targetRooms) do
                    if roomName == target then canBite = true; break end
                end
            end
        else
            if isOutside and not hasRepellent then
                if not (insect.fireRepelled and envProtected) then canBite = true end
            end
        end

        if canBite then
            table.insert(canBiteInsects, insect)
        end
    end

    -- Use weighted selection to pick ONE insect (mosquitos most common, stings rarest)
    local selectedInsect = BitingInsectSystem.getWeightedInsect(canBiteInsects)
    
    if selectedInsect then
        local moveMulti = 1.0
        if player:isSprinting() then moveMulti = selectedInsect.movementMods.sprinting
        elseif player:isRunning() then moveMulti = selectedInsect.movementMods.running
        elseif player:isPlayerMoving() then moveMulti = selectedInsect.movementMods.walking
        else moveMulti = selectedInsect.movementMods.idle end

        -- Adjusted probability: intensity * mod * move / 5 matches the frequency system
        -- Logic: (Intensity * Mod * Multi) / 5 is the % chance per in-game minute.
        local biteChance = (InsectManager.intensity * BitingInsectSystem.globalIntensityMultiplier * selectedInsect.biteChanceMod * moveMulti) / 5
        
        if ZRandFloat(0, 100) < biteChance then
            BitingInsectSystem.applyBite(player, selectedInsect)
        end
    end
end

-- 6. HELPERS
function BitingInsectSystem.isHourInPeriod(hour, period)
    local hS, hE = period.start, period.stop
    return (hS > hE) and (hour >= hS or hour < hE) or (hour >= hS and hour < hE)
end

function BitingInsectSystem.getEligibleInsects(month, hour)
    local list = {}
    for _, data in pairs(BitingInsectSystem.Insects) do
        local monthMatch = false
        for _, m in ipairs(data.months) do if month == (m - 1) then monthMatch = true break end end
        if monthMatch then
            local periods = data.activePeriods or {data.peakHours}
            local hourMatch = false
            for _, period in ipairs(periods) do
                if BitingInsectSystem.isHourInPeriod(hour, period) then hourMatch = true break end
            end
            if hourMatch then table.insert(list, data) end
        end
    end
    return list
end

-- Weighted selection based on rarity (matching SingingInsectsSystem pattern)
function BitingInsectSystem.getWeightedInsect(eligibleInsects)
    if #eligibleInsects == 0 then return nil end
    if #eligibleInsects == 1 then return eligibleInsects[1] end

    -- Calculate weights using rarity power curve
    local weightedList = {}
    local totalWeight = 0

    for _, insect in ipairs(eligibleInsects) do
        -- Lower rarity = higher weight (more common)
        local weight = math.pow(MAX_RARITY + 0.5 - insect.rarity, RARITY_POWER)
        totalWeight = totalWeight + weight
        table.insert(weightedList, { insect = insect, weight = weight })
    end

    -- Select based on cumulative weight
    local roll = ZRandFloat(0, totalWeight)
    local currentWeight = 0

    for _, entry in ipairs(weightedList) do
        currentWeight = currentWeight + entry.weight
        if roll < currentWeight then
            return entry.insect
        end
    end

    return weightedList[1].insect
end

function BitingInsectSystem.checkEnvironmentalProtection(player)
    local sq = player:getCurrentSquare()
    if not sq then return false end
    local heat = sq:getCell():getHeatSourceTemperature(floor(player:getX()), floor(player:getY()), floor(player:getZ()))
    return heat > 5 or sq:getRoom() ~= nil
end

function BitingInsectSystem.hasRepellent(player, worldAgeHours)
    local data = player:getModData()
    return data.insectRepellentTime and data.insectRepellentTime > worldAgeHours
end

-- 7. INITIALIZATION
function BitingInsectSystem.init()
    if BitingInsectSystem.isInitialized then return end
    if BitingInsectSystem.allocateEmitterPool() then
        BitingInsectSystem.lastCheckMinutesStamp = getGameTime():getMinutesStamp()
        Events.OnTick.Add(BitingInsectSystem.onTick)
        BitingInsectSystem.isInitialized = true
        if DEBUG then print("[BitingInsectSystem] Swarms are active") end
    end
end

Events.OnGameStart.Add(BitingInsectSystem.init)
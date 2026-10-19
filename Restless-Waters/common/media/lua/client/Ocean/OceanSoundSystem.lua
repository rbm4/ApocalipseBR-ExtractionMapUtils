-- Ocean Sound Emitter System 
-- Client-side system that manages FMOD emitters for ocean sounds.

-- VOLUME MODULE (HorseMod-style live reader)
local OceanVolume = require("Ocean/OceanVolume")

-- GLOBAL TABLE INITIALIZATION
OceanSoundEmitters = OceanSoundEmitters or {}

-- GLOBAL SETTINGS
OceanSoundSettings = {
    minInterval = 3.5,
    maxInterval = 6.4,
}

-- SYSTEM CONFIGURATION

OceanSoundSystem = {
    poolSize = 100,
    emitterPool = {},
    activeEmitters = {},

    activationRange = 50,
    bufferRange = 10,

    updateInterval = 5,
    updateCounter = 0,
    emittersPerUpdate = 10,

    balancerUpdateInterval = 90,
    balancerUpdateCounter = 0,

    circularBuffer = {},
    bufferIndex = 1,

    playerPosition = {
        x = 0,
        y = 0,
        z = 0,
        lastUpdate = 0
    },
    positionCacheInterval = 10,
    positionCacheCounter = 0,

    globalTickCounter = 0,

    debugEnabled = false,

    useBalancerPositioning = true,

    isInitialized = false,
    isEnabled = true,

    soundAliases = {},
}

-- INITIALIZATION

function OceanSoundSystem.initSoundAliases()
    OceanSoundSystem.soundAliases = {}
    for i = 1, 30 do
        table.insert(OceanSoundSystem.soundAliases, "oceanwaves_" .. string.format("%02d", i))
    end
end

function OceanSoundSystem.allocateEmitterPool()
    local world = getWorld()
    if not world then
        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem] Error: World not available for emitter allocation")
        end
        return false
    end
    
    local successCount = 0
    for i = 1, OceanSoundSystem.poolSize do
        local emitter = world:getFreeEmitter()
        if emitter then
            table.insert(OceanSoundSystem.emitterPool, {
                emitter = emitter,
                inUse = false,
                emitterIndex = nil,
                lastUsed = 0
            })
            successCount = successCount + 1
        end
    end
    
    return successCount > 0
end

function OceanSoundSystem.initializeAllEmitters()
    local minTicks = OceanSoundSettings.minInterval * 60
    local maxTicks = OceanSoundSettings.maxInterval * 60

    if OceanSoundSystem.debugEnabled then
        print("[OceanSoundSystem] Initializing " .. #OceanSoundEmitters .. " emitters...")
    end

    for index, emitter in ipairs(OceanSoundEmitters) do
        emitter.index = index
        emitter.nextPlayTick = ZombRand(minTicks, maxTicks)
        emitter.active = false
        emitter.poolEntry = nil
    end
    
    if OceanSoundSystem.debugEnabled then
        print("[OceanSoundSystem] Emitter initialization complete.")
    end
end

function OceanSoundSystem.initializeCircularBuffer()
    OceanSoundSystem.circularBuffer = {}
    
    for i = 1, #OceanSoundEmitters do
        table.insert(OceanSoundSystem.circularBuffer, i)
    end
    
    for i = #OceanSoundSystem.circularBuffer, 2, -1 do
        local j = ZombRand(1, i)
        OceanSoundSystem.circularBuffer[i], OceanSoundSystem.circularBuffer[j] =
            OceanSoundSystem.circularBuffer[j], OceanSoundSystem.circularBuffer[i]
    end
end

function OceanSoundSystem.init()
    if OceanSoundSystem.isInitialized then
        return
    end
    
    if isServer() then
        return
    end
    
    OceanSoundSystem.initializeAllEmitters()
    OceanSoundSystem.initSoundAliases()
    
    if not OceanSoundSystem.allocateEmitterPool() then
        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem] Error: Failed to allocate emitter pool")
        end
        return
    end
    
    OceanSoundSystem.initializeCircularBuffer()
    
    Events.OnTick.Add(OceanSoundSystem.onTick)
    
    OceanSoundSystem.isInitialized = true
    
    if OceanSoundSystem.debugEnabled then
        print("[OceanSoundSystem] Ocean sound system initialized")
    end
end

-- PLAYER POSITION TRACKING

function OceanSoundSystem.updatePlayerPosition()
    local player = getPlayer()
    if not player then
        return false
    end
    
    OceanSoundSystem.playerPosition.x = player:getX()
    OceanSoundSystem.playerPosition.y = player:getY()
    OceanSoundSystem.playerPosition.z = player:getZ()
    OceanSoundSystem.playerPosition.lastUpdate = OceanSoundSystem.globalTickCounter
    
    return true
end

function OceanSoundSystem.getPlayerPosition()
    return OceanSoundSystem.playerPosition.x, 
           OceanSoundSystem.playerPosition.y, 
           OceanSoundSystem.playerPosition.z
end

-- EMITTER POOL MANAGEMENT

function OceanSoundSystem.getFreeEmitterFromPool()
    for i, poolEntry in ipairs(OceanSoundSystem.emitterPool) do
        if not poolEntry.inUse then
            poolEntry.inUse = true
            poolEntry.lastUsed = OceanSoundSystem.globalTickCounter
            return poolEntry, i
        end
    end
    
    local oldestIndex = 1
    local oldestTime = math.huge
    
    for i, poolEntry in ipairs(OceanSoundSystem.emitterPool) do
        if poolEntry.lastUsed < oldestTime then
            oldestTime = poolEntry.lastUsed
            oldestIndex = i
        end
    end
    
    local poolEntry = OceanSoundSystem.emitterPool[oldestIndex]
    if poolEntry.emitterIndex then
        OceanSoundSystem.deactivateEmitter(poolEntry.emitterIndex)
    end
    
    poolEntry.inUse = true
    poolEntry.lastUsed = OceanSoundSystem.globalTickCounter
    return poolEntry, oldestIndex
end

function OceanSoundSystem.activateEmitter(emitterDef)
    local mainPoolEntry, mainPoolIndex = OceanSoundSystem.getFreeEmitterFromPool()
    
    if not mainPoolEntry then
        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem DEBUG] activateEmitter: No available main emitter in pool for index " .. emitterDef.index)
        end
        return nil
    end
    
    mainPoolEntry.emitter:setPos(emitterDef.posX, emitterDef.posY, emitterDef.posZ)
    mainPoolEntry.emitterIndex = emitterDef.index
    
    local activeData = {
        main = {
            poolEntry = mainPoolEntry,
            poolIndex = mainPoolIndex
        },
        balancer = nil,
        emitterDef = emitterDef
    }
    
    if OceanSoundSystem.useBalancerPositioning then
        local balancerPoolEntry, balancerPoolIndex = OceanSoundSystem.getFreeEmitterFromPool()
        
        if balancerPoolEntry then
            local playerX, playerY, playerZ = OceanSoundSystem.getPlayerPosition()
            
            local balancerX, balancerY, balancerZ = OceanSoundSystem.calculateBalancerPosition(
                playerX, playerY, playerZ, emitterDef
            )
            
            local actualDistance = OceanSoundSystem.getDistance(
                playerX, playerY, playerZ,
                emitterDef.posX, emitterDef.posY, emitterDef.posZ
            )
            
            balancerPoolEntry.emitter:setPos(balancerX, balancerY, balancerZ)
            balancerPoolEntry.emitterIndex = emitterDef.index
            
            activeData.balancer = {
                poolEntry = balancerPoolEntry,
                poolIndex = balancerPoolIndex,
                posX = balancerX,
                posY = balancerY,
                posZ = balancerZ
            }
            
            if OceanSoundSystem.debugEnabled then
                print("[OceanSoundSystem DEBUG] Emitter " .. emitterDef.index ..
                      " - Main: (" .. emitterDef.posX .. ", " .. emitterDef.posY .. ")" ..
                      " Balancer: (" .. balancerX .. ", " .. balancerY .. ")" ..
                      " distance=" .. actualDistance)
            end
        else
            if OceanSoundSystem.debugEnabled then
                print("[OceanSoundSystem DEBUG] activateEmitter: No available balancer emitter for index " .. emitterDef.index)
            end
        end
    else
        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem DEBUG] Emitter " .. emitterDef.index ..
                  " - Main only: (" .. emitterDef.posX .. ", " .. emitterDef.posY .. ")")
        end
    end
    
    OceanSoundSystem.activeEmitters[emitterDef.index] = activeData
    emitterDef.active = true
    
    if OceanSoundSystem.debugEnabled then
        print("[OceanSoundSystem DEBUG] activateEmitter: Emitter " .. emitterDef.index .. " activated")
    end
    
    return activeData
end

function OceanSoundSystem.deactivateEmitter(emitterIndex)
    local activeData = OceanSoundSystem.activeEmitters[emitterIndex]

    if not activeData then
        return
    end

    if OceanSoundSystem.debugEnabled then
        print("[OceanSoundSystem DEBUG] deactivateEmitter: Emitter " .. emitterIndex .. " deactivated (nextPlayTick=" .. (OceanSoundEmitters[emitterIndex].nextPlayTick or "nil") .. ")")
    end

    if activeData.main and activeData.main.poolEntry then
        activeData.main.poolEntry.emitter:stopAll()
        activeData.main.poolEntry.emitter:tick()
        activeData.main.poolEntry.inUse = false
        activeData.main.poolEntry.emitterIndex = nil
    end

    if activeData.balancer and activeData.balancer.poolEntry then
        activeData.balancer.poolEntry.emitter:stopAll()
        activeData.balancer.poolEntry.emitter:tick()
        activeData.balancer.poolEntry.inUse = false
        activeData.balancer.poolEntry.emitterIndex = nil
    end

    OceanSoundSystem.activeEmitters[emitterIndex] = nil

    local emitterDef = OceanSoundEmitters[emitterIndex]
    if emitterDef then
        emitterDef.active = false
    end
end

-- BALANCER POSITION UPDATES

function OceanSoundSystem.calculateBalancerPosition(playerX, playerY, playerZ, emitterDef)
    local actualDistance = OceanSoundSystem.getDistance(
        playerX, playerY, playerZ,
        emitterDef.posX, emitterDef.posY, emitterDef.posZ
    )
    
    local dirX = emitterDef.posX - playerX
    local dirY = emitterDef.posY - playerY
    
    local vectorLength = math.sqrt(dirX * dirX + dirY * dirY)
    if vectorLength > 0 then
        dirX = dirX / vectorLength
        dirY = dirY / vectorLength
    end
    
    local balancerX = playerX - (dirX * actualDistance)
    local balancerY = playerY - (dirY * actualDistance)
    local balancerZ = playerZ
    
    return balancerX, balancerY, balancerZ
end

function OceanSoundSystem.updateBalancerPosition(activeData, emitterDef)
    if not activeData or not activeData.balancer or not activeData.balancer.poolEntry then
        return
    end

    local playerX, playerY, playerZ = OceanSoundSystem.getPlayerPosition()

    local balancerX, balancerY, balancerZ = OceanSoundSystem.calculateBalancerPosition(
        playerX, playerY, playerZ, emitterDef
    )

    activeData.balancer.poolEntry.emitter:setPos(balancerX, balancerY, balancerZ)

    activeData.balancer.posX = balancerX
    activeData.balancer.posY = balancerY
    activeData.balancer.posZ = balancerZ

    if OceanSoundSystem.debugEnabled then
        print("[OceanSoundSystem DEBUG] updateBalancerPosition: Emitter " .. emitterDef.index ..
              " - Balancer updated to (" .. balancerX .. ", " .. balancerY .. ")")
    end
end

-- SOUND PLAYBACK

function OceanSoundSystem.getRandomSoundAlias()
    if #OceanSoundSystem.soundAliases == 0 then
        OceanSoundSystem.initSoundAliases()
    end
    return OceanSoundSystem.soundAliases[ZombRand(1, #OceanSoundSystem.soundAliases)]
end

function OceanSoundSystem.playEmitterSound(emitterDef, activeData)
    if not activeData or not activeData.main then
        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem DEBUG] playEmitterSound: No activeData or main emitter for emitter " .. (emitterDef.index or "unknown"))
        end
        return
    end

    local soundAlias = OceanSoundSystem.getRandomSoundAlias()
    local mainSq = getSquare(emitterDef.posX, emitterDef.posY, emitterDef.posZ)

    if mainSq then
        -- Main emitter: play first, then set volume on the returned handle
        local mainHandle = activeData.main.poolEntry.emitter:playSoundImpl(soundAlias, mainSq)
        OceanVolume.applyToHandle(activeData.main.poolEntry.emitter, mainHandle)
        activeData.main.poolEntry.emitter:tick()

        -- Balancer emitter: same pattern
        if activeData.balancer and activeData.balancer.poolEntry then
            local balancerSq = getSquare(activeData.balancer.posX, activeData.balancer.posY, activeData.balancer.posZ)
            if balancerSq then
                local balancerHandle = activeData.balancer.poolEntry.emitter:playSoundImpl(soundAlias, balancerSq)
                OceanVolume.applyToHandle(activeData.balancer.poolEntry.emitter, balancerHandle)
                activeData.balancer.poolEntry.emitter:tick()
            end
        end

        local minTicks = OceanSoundSettings.minInterval * 60
        local maxTicks = OceanSoundSettings.maxInterval * 60
        local intervalTicks = ZombRand(minTicks, maxTicks)

        emitterDef.nextPlayTick = OceanSoundSystem.globalTickCounter + intervalTicks

        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem DEBUG] playEmitterSound: Emitter " .. emitterDef.index .. " playing '" .. soundAlias .. "', interval=" .. intervalTicks .. " ticks, currentTick=" .. OceanSoundSystem.globalTickCounter .. ", nextPlayTick=" .. emitterDef.nextPlayTick)
        end
    else
        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem DEBUG] playEmitterSound: Emitter " .. emitterDef.index .. " - No square at position")
        end
    end
end

-- UPDATE SYSTEM

function OceanSoundSystem.getDistance(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

function OceanSoundSystem.isEmitterInRange(emitterDef, playerX, playerY, playerZ)
    local distance = OceanSoundSystem.getDistance(
        playerX, playerY, playerZ,
        emitterDef.posX, emitterDef.posY, emitterDef.posZ
    )
    
    return distance <= (OceanSoundSystem.activationRange + OceanSoundSystem.bufferRange)
end

function OceanSoundSystem.updateEmitters()
    local playerX, playerY, playerZ = OceanSoundSystem.getPlayerPosition()
    local totalEmitters = #OceanSoundSystem.circularBuffer
    local activeInRangeCount = 0

    OceanSoundSystem.balancerUpdateCounter = OceanSoundSystem.balancerUpdateCounter + 1
    local shouldUpdateBalancers = OceanSoundSystem.balancerUpdateCounter >= OceanSoundSystem.balancerUpdateInterval

    if shouldUpdateBalancers then
        OceanSoundSystem.balancerUpdateCounter = 0
        if OceanSoundSystem.debugEnabled then
            print("[OceanSoundSystem DEBUG] updateEmitters: Updating all balancer positions")
        end
    end

    local processedCount = 0

    while processedCount < OceanSoundSystem.emittersPerUpdate do
        local emitterIndex = OceanSoundSystem.circularBuffer[OceanSoundSystem.bufferIndex]
        local emitterDef = OceanSoundEmitters[emitterIndex]

        if emitterDef then
            if OceanSoundSystem.isEmitterInRange(emitterDef, playerX, playerY, playerZ) then
                activeInRangeCount = activeInRangeCount + 1

                local activeData = OceanSoundSystem.activeEmitters[emitterIndex]

                if not activeData then
                    activeData = OceanSoundSystem.activateEmitter(emitterDef)
                end

                if activeData and shouldUpdateBalancers then
                    OceanSoundSystem.updateBalancerPosition(activeData, emitterDef)
                end

                if activeData and OceanSoundSystem.globalTickCounter >= emitterDef.nextPlayTick then
                    OceanSoundSystem.playEmitterSound(emitterDef, activeData)
                end
            else
                if emitterDef.active then
                    OceanSoundSystem.deactivateEmitter(emitterIndex)
                end
            end
        end

        OceanSoundSystem.bufferIndex = (OceanSoundSystem.bufferIndex % totalEmitters) + 1
        processedCount = processedCount + 1
    end

    if activeInRangeCount > 0 and OceanSoundSystem.debugEnabled then
        print("[OceanSoundSystem DEBUG] updateEmitters: " .. activeInRangeCount .. " emitters in range, processed " .. processedCount .. " this cycle, tick=" .. OceanSoundSystem.globalTickCounter)
    end
end

function OceanSoundSystem.onTick()
    if not OceanSoundSystem.isEnabled then
        return
    end

    if not OceanSoundSystem.isInitialized then
        return
    end

    OceanSoundSystem.globalTickCounter = OceanSoundSystem.globalTickCounter + 1

    OceanSoundSystem.positionCacheCounter = OceanSoundSystem.positionCacheCounter + 1
    if OceanSoundSystem.positionCacheCounter >= OceanSoundSystem.positionCacheInterval then
        OceanSoundSystem.positionCacheCounter = 0
        OceanSoundSystem.updatePlayerPosition()
    end

    OceanSoundSystem.updateCounter = OceanSoundSystem.updateCounter + 1

    if OceanSoundSystem.updateCounter >= OceanSoundSystem.updateInterval then
        OceanSoundSystem.updateCounter = 0
        OceanSoundSystem.updateEmitters()
    end
end

Events.OnGameStart.Add(OceanSoundSystem.init)
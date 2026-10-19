-- PEI Fish Configuration Module
-- Clears all vanilla fish and replaces with PEI-specific fish species
-- Based on realistic Atlantic Canadian marine biology

local function InitPEIFish()
    -- table.wipe is safer than {} as it maintains the reference the game expects
    if Fishing and Fishing.fishes then
        table.wipe(Fishing.fishes)
    else
        print("[PEI Fish] ERROR: Fishing table not found!")
        return
    end

    ---------------------------------------
    -- SMALL FISH (20-40cm, 0.5-2kg)
    ---------------------------------------

    -- Atlantic Tomcod
    local AtlanticTomcod = Fishing.FishConfig:new("Base.AtlanticTomcod")
    AtlanticTomcod:setLocation(true, true)
    AtlanticTomcod:setMaxLength(35)
    AtlanticTomcod:setTrophyLength(40)
    AtlanticTomcod:setMaxWeight(0.5)
    AtlanticTomcod:setTrophyWeight(0.7)
    AtlanticTomcod:setWeightFactor(2)
    AtlanticTomcod:initFishSizeData()
    AtlanticTomcod:addLures(Fishing.lure.Insect, 0.3)
    AtlanticTomcod:addLures(Fishing.lure.Minnows, 0.5)
    AtlanticTomcod:addLures(Fishing.lure.Worms, 0.7)
    AtlanticTomcod:addLures(Fishing.lure.Leeches, 0.3)
    AtlanticTomcod.lure["Base.JigLure"] = 0.5
    AtlanticTomcod.lure["Base.MinnowLure"] = 0.5
    AtlanticTomcod.lure["Base.Worm"] = 0.9
    table.insert(Fishing.fishes, AtlanticTomcod)

    -- Atlantic Herring
    local AtlanticHerring = Fishing.FishConfig:new("Base.AtlanticHerring")
    AtlanticHerring:setLocation(true, true)
    AtlanticHerring:setMaxLength(40)
    AtlanticHerring:setTrophyLength(45)
    AtlanticHerring:setMaxWeight(1.0)
    AtlanticHerring:setTrophyWeight(1.5)
    AtlanticHerring:setWeightFactor(2)
    AtlanticHerring:initFishSizeData()
    AtlanticHerring:addLures(Fishing.lure.Insect, 0.5)
    AtlanticHerring:addLures(Fishing.lure.Minnows, 0.3)
    AtlanticHerring:addLures(Fishing.lure.Worms, 0.5)
    AtlanticHerring:addLures(Fishing.lure.Plant, 0.3)
    AtlanticHerring.lure["Base.JigLure"] = 0.3
    AtlanticHerring.lure["Base.MinnowLure"] = 0.3
    table.insert(Fishing.fishes, AtlanticHerring)

    -- Rainbow Smelt
    local RainbowSmelt = Fishing.FishConfig:new("Base.RainbowSmelt")
    RainbowSmelt:setLocation(true, true)
    RainbowSmelt:setMaxLength(20)
    RainbowSmelt:setTrophyLength(25)
    RainbowSmelt:setMaxWeight(0.3)
    RainbowSmelt:setTrophyWeight(0.4)
    RainbowSmelt:setWeightFactor(2)
    RainbowSmelt:initFishSizeData()
    RainbowSmelt:addLures(Fishing.lure.Insect, 0.7)
    RainbowSmelt:addLures(Fishing.lure.Minnows, 0.1)
    RainbowSmelt:addLures(Fishing.lure.Worms, 0.7)
    RainbowSmelt:addLures(Fishing.lure.Plant, 0.3)
    RainbowSmelt.lure["Base.JigLure"] = 0.3
    RainbowSmelt.lure["Base.MinnowLure"] = 0.1
    RainbowSmelt.lure["Base.Worm"] = 0.9
    table.insert(Fishing.fishes, RainbowSmelt)

    ---------------------------------------
    -- MEDIUM FISH (40-70cm, 2-8kg)
    ---------------------------------------

    -- Atlantic Cod
    local AtlanticCod = Fishing.FishConfig:new("Base.AtlanticCod")
    AtlanticCod:setLocation(true, true)
    AtlanticCod:setMaxLength(90)
    AtlanticCod:setTrophyLength(110)
    AtlanticCod:setMaxWeight(10)
    AtlanticCod:setTrophyWeight(20)
    AtlanticCod:setWeightFactor(3)
    AtlanticCod:initFishSizeData()
    AtlanticCod:addLures(Fishing.lure.Insect, 0.1)
    AtlanticCod:addLures(Fishing.lure.Minnows, 0.7)
    AtlanticCod:addLures(Fishing.lure.Worms, 0.5)
    AtlanticCod:addLures(Fishing.lure.Flesh, 0.5)
    AtlanticCod.lure["Base.JigLure"] = 0.5
    AtlanticCod.lure["Base.MinnowLure"] = 0.7
    AtlanticCod.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, AtlanticCod)

    -- Atlantic Mackerel
    local AtlanticMackerel = Fishing.FishConfig:new("Base.AtlanticMackerel")
    AtlanticMackerel:setLocation(true, true)
    AtlanticMackerel:setMaxLength(50)
    AtlanticMackerel:setTrophyLength(60)
    AtlanticMackerel:setMaxWeight(3.5)
    AtlanticMackerel:setTrophyWeight(5)
    AtlanticMackerel:setWeightFactor(2)
    AtlanticMackerel:initFishSizeData()
    AtlanticMackerel:addLures(Fishing.lure.Insect, 0.3)
    AtlanticMackerel:addLures(Fishing.lure.Minnows, 0.7)
    AtlanticMackerel:addLures(Fishing.lure.Worms, 0.3)
    AtlanticMackerel:addLures(Fishing.lure.Flesh, 0.5)
    AtlanticMackerel.lure["Base.JigLure"] = 0.7
    AtlanticMackerel.lure["Base.MinnowLure"] = 0.7
    AtlanticMackerel.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, AtlanticMackerel)

    -- Summer Flounder
    local SummerFlounder = Fishing.FishConfig:new("Base.SummerFlounder")
    SummerFlounder:setLocation(true, true)
    SummerFlounder:setMaxLength(70)
    SummerFlounder:setTrophyLength(85)
    SummerFlounder:setMaxWeight(6)
    SummerFlounder:setTrophyWeight(10)
    SummerFlounder:setWeightFactor(3)
    SummerFlounder:initFishSizeData()
    SummerFlounder:addLures(Fishing.lure.Insect, 0.1)
    SummerFlounder:addLures(Fishing.lure.Minnows, 0.7)
    SummerFlounder:addLures(Fishing.lure.Worms, 0.5)
    SummerFlounder:addLures(Fishing.lure.Flesh, 0.7)
    SummerFlounder.lure["Base.JigLure"] = 0.5
    SummerFlounder.lure["Base.MinnowLure"] = 0.5
    SummerFlounder.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, SummerFlounder)

    -- Haddock
    local Haddock = Fishing.FishConfig:new("Base.Haddock")
    Haddock:setLocation(true, true)
    Haddock:setMaxLength(80)
    Haddock:setTrophyLength(95)
    Haddock:setMaxWeight(8)
    Haddock:setTrophyWeight(12)
    Haddock:setWeightFactor(3)
    Haddock:initFishSizeData()
    Haddock:addLures(Fishing.lure.Insect, 0.1)
    Haddock:addLures(Fishing.lure.Minnows, 0.7)
    Haddock:addLures(Fishing.lure.Worms, 0.5)
    Haddock:addLures(Fishing.lure.Flesh, 0.5)
    Haddock.lure["Base.JigLure"] = 0.5
    Haddock.lure["Base.MinnowLure"] = 0.7
    Haddock.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, Haddock)

    -- Lumpfish
    local Lumpfish = Fishing.FishConfig:new("Base.Lumpfish")
    Lumpfish:setLocation(true, true)
    Lumpfish:setMaxLength(50)
    Lumpfish:setTrophyLength(60)
    Lumpfish:setMaxWeight(5)
    Lumpfish:setTrophyWeight(8)
    Lumpfish:setWeightFactor(3)
    Lumpfish:initFishSizeData()
    Lumpfish:addLures(Fishing.lure.Insect, 0.3)
    Lumpfish:addLures(Fishing.lure.Minnows, 0.5)
    Lumpfish:addLures(Fishing.lure.Worms, 0.5)
    Lumpfish:addLures(Fishing.lure.Plant, 0.5)
    Lumpfish.lure["Base.JigLure"] = 0.3
    Lumpfish.lure["Base.MinnowLure"] = 0.5
    table.insert(Fishing.fishes, Lumpfish)

    -- Pollack
    local Pollack = Fishing.FishConfig:new("Base.Pollack")
    Pollack:setLocation(true, true)
    Pollack:setMaxLength(100)
    Pollack:setTrophyLength(120)
    Pollack:setMaxWeight(15)
    Pollack:setTrophyWeight(25)
    Pollack:setWeightFactor(4)
    Pollack:initFishSizeData()
    Pollack:addLures(Fishing.lure.Insect, 0.1)
    Pollack:addLures(Fishing.lure.Minnows, 0.7)
    Pollack:addLures(Fishing.lure.Worms, 0.5)
    Pollack:addLures(Fishing.lure.Flesh, 0.5)
    Pollack.lure["Base.JigLure"] = 0.5
    Pollack.lure["Base.MinnowLure"] = 0.7
    Pollack.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, Pollack)

    -- White Perch
    local WhitePerch = Fishing.FishConfig:new("Base.WhitePerch")
    WhitePerch:setLocation(true, true)
    WhitePerch:setMaxLength(40)
    WhitePerch:setTrophyLength(45)
    WhitePerch:setMaxWeight(2)
    WhitePerch:setTrophyWeight(3)
    WhitePerch:setWeightFactor(2)
    WhitePerch:initFishSizeData()
    WhitePerch:addLures(Fishing.lure.Insect, 0.7)
    WhitePerch:addLures(Fishing.lure.Minnows, 0.1)
    WhitePerch:addLures(Fishing.lure.Worms, 0.7)
    WhitePerch:addLures(Fishing.lure.Leeches, 0.5)
    WhitePerch.lure["Base.JigLure"] = 0.5
    WhitePerch.lure["Base.MinnowLure"] = 0.3
    WhitePerch.lure["Base.Worm"] = 0.9
    table.insert(Fishing.fishes, WhitePerch)

    -- Winter Flounder
    local WinterFlounder = Fishing.FishConfig:new("Base.WinterFlounder")
    WinterFlounder:setLocation(true, true)
    WinterFlounder:setMaxLength(60)
    WinterFlounder:setTrophyLength(70)
    WinterFlounder:setMaxWeight(3)
    WinterFlounder:setTrophyWeight(5)
    WinterFlounder:setWeightFactor(2)
    WinterFlounder:initFishSizeData()
    WinterFlounder:addLures(Fishing.lure.Insect, 0.3)
    WinterFlounder:addLures(Fishing.lure.Minnows, 0.7)
    WinterFlounder:addLures(Fishing.lure.Worms, 0.7)
    WinterFlounder:addLures(Fishing.lure.Flesh, 0.3)
    WinterFlounder.lure["Base.JigLure"] = 0.5
    WinterFlounder.lure["Base.MinnowLure"] = 0.5
    WinterFlounder.lure["Base.BaitFish"] = 0.7
    table.insert(Fishing.fishes, WinterFlounder)

    ---------------------------------------
    -- LARGE FISH (70-100cm, 8-20kg)
    ---------------------------------------

    -- Atlantic Salmon
    local AtlanticSalmon = Fishing.FishConfig:new("Base.AtlanticSalmon")
    AtlanticSalmon:setLocation(true, true)
    AtlanticSalmon:setMaxLength(90)
    AtlanticSalmon:setTrophyLength(110)
    AtlanticSalmon:setMaxWeight(15)
    AtlanticSalmon:setTrophyWeight(25)
    AtlanticSalmon:setWeightFactor(4)
    AtlanticSalmon:initFishSizeData()
    AtlanticSalmon:addLures(Fishing.lure.Insect, 0.3)
    AtlanticSalmon:addLures(Fishing.lure.Minnows, 0.7)
    AtlanticSalmon:addLures(Fishing.lure.Worms, 0.3)
    AtlanticSalmon:addLures(Fishing.lure.Flesh, 0.5)
    AtlanticSalmon.lure["Base.JigLure"] = 0.5
    AtlanticSalmon.lure["Base.MinnowLure"] = 0.7
    AtlanticSalmon.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, AtlanticSalmon)

    -- Brook Trout
    local BrookTrout = Fishing.FishConfig:new("Base.BrookTrout")
    BrookTrout:setLocation(true, true)
    BrookTrout:setMaxLength(60)
    BrookTrout:setTrophyLength(75)
    BrookTrout:setMaxWeight(5)
    BrookTrout:setTrophyWeight(8)
    BrookTrout:setWeightFactor(2)
    BrookTrout:initFishSizeData()
    BrookTrout:addLures(Fishing.lure.Insect, 0.7)
    BrookTrout:addLures(Fishing.lure.Minnows, 0.3)
    BrookTrout:addLures(Fishing.lure.Worms, 0.7)
    BrookTrout:addLures(Fishing.lure.Leeches, 0.5)
    BrookTrout.lure["Base.JigLure"] = 0.5
    BrookTrout.lure["Base.MinnowLure"] = 0.3
    BrookTrout.lure["Base.Worm"] = 0.9
    table.insert(Fishing.fishes, BrookTrout)

    -- Brown Trout
    local BrownTrout = Fishing.FishConfig:new("Base.BrownTrout")
    BrownTrout:setLocation(true, true)
    BrownTrout:setMaxLength(70)
    BrownTrout:setTrophyLength(85)
    BrownTrout:setMaxWeight(8)
    BrownTrout:setTrophyWeight(12)
    BrownTrout:setWeightFactor(3)
    BrownTrout:initFishSizeData()
    BrownTrout:addLures(Fishing.lure.Insect, 0.5)
    BrownTrout:addLures(Fishing.lure.Minnows, 0.7)
    BrownTrout:addLures(Fishing.lure.Worms, 0.5)
    BrownTrout:addLures(Fishing.lure.Leeches, 0.5)
    BrownTrout.lure["Base.JigLure"] = 0.5
    BrownTrout.lure["Base.MinnowLure"] = 0.7
    BrownTrout.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, BrownTrout)

    -- Gaspereau
    local Gaspereau = Fishing.FishConfig:new("Base.Gaspereau")
    Gaspereau:setLocation(true, true)
    Gaspereau:setMaxLength(40)
    Gaspereau:setTrophyLength(45)
    Gaspereau:setMaxWeight(1.5)
    Gaspereau:setTrophyWeight(2)
    Gaspereau:setWeightFactor(2)
    Gaspereau:initFishSizeData()
    Gaspereau:addLures(Fishing.lure.Insect, 0.5)
    Gaspereau:addLures(Fishing.lure.Minnows, 0.3)
    Gaspereau:addLures(Fishing.lure.Worms, 0.5)
    Gaspereau:addLures(Fishing.lure.Plant, 0.3)
    Gaspereau.lure["Base.JigLure"] = 0.3
    Gaspereau.lure["Base.MinnowLure"] = 0.3
    table.insert(Fishing.fishes, Gaspereau)

    -- Striped Bass
    local StripedBass = Fishing.FishConfig:new("Base.StripedBass2")
    StripedBass:setLocation(true, true)
    StripedBass:setMaxLength(120)
    StripedBass:setTrophyLength(150)
    StripedBass:setMaxWeight(25)
    StripedBass:setTrophyWeight(40)
    StripedBass:setWeightFactor(5)
    StripedBass:initFishSizeData()
    StripedBass:setPredator(true)
    StripedBass:addLures(Fishing.lure.Insect, 0.1)
    StripedBass:addLures(Fishing.lure.Minnows, 0.7)
    StripedBass:addLures(Fishing.lure.Worms, 0.3)
    StripedBass:addLures(Fishing.lure.Flesh, 0.7)
    StripedBass.lure["Base.JigLure"] = 0.5
    StripedBass.lure["Base.MinnowLure"] = 0.7
    StripedBass.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, StripedBass)

    ---------------------------------------
    -- VERY LARGE FISH (100cm+, 20kg+)
    ---------------------------------------

    -- Atlantic Halibut
    local AtlanticHalibut = Fishing.FishConfig:new("Base.AtlanticHalibut")
    AtlanticHalibut:setLocation(true, true)
    AtlanticHalibut:setMaxLength(200)
    AtlanticHalibut:setTrophyLength(250)
    AtlanticHalibut:setMaxWeight(80)
    AtlanticHalibut:setTrophyWeight(150)
    AtlanticHalibut:setWeightFactor(6)
    AtlanticHalibut:initFishSizeData()
    AtlanticHalibut:setPredator(true)
    AtlanticHalibut:addLures(Fishing.lure.Insect, 0.0)
    AtlanticHalibut:addLures(Fishing.lure.Minnows, 0.5)
    AtlanticHalibut:addLures(Fishing.lure.Worms, 0.1)
    AtlanticHalibut:addLures(Fishing.lure.Flesh, 0.9)
    AtlanticHalibut.lure["Base.JigLure"] = 0.5
    AtlanticHalibut.lure["Base.MinnowLure"] = 0.5
    AtlanticHalibut.lure["Base.BaitFish"] = 0.9
    AtlanticHalibut.lure["Base.FishFillet"] = 0.9
    table.insert(Fishing.fishes, AtlanticHalibut)

    -- Spiny Dogfish
    local SpinyDogfish = Fishing.FishConfig:new("Base.SpinyDogfish")
    SpinyDogfish:setLocation(true, true)
    SpinyDogfish:setMaxLength(120)
    SpinyDogfish:setTrophyLength(140)
    SpinyDogfish:setMaxWeight(10)
    SpinyDogfish:setTrophyWeight(15)
    SpinyDogfish:setWeightFactor(4)
    SpinyDogfish:initFishSizeData()
    SpinyDogfish:setPredator(true)
    SpinyDogfish:addLures(Fishing.lure.Insect, 0.0)
    SpinyDogfish:addLures(Fishing.lure.Minnows, 0.5)
    SpinyDogfish:addLures(Fishing.lure.Worms, 0.1)
    SpinyDogfish:addLures(Fishing.lure.Flesh, 0.7)
    SpinyDogfish.lure["Base.JigLure"] = 0.3
    SpinyDogfish.lure["Base.MinnowLure"] = 0.5
    SpinyDogfish.lure["Base.BaitFish"] = 0.9
    table.insert(Fishing.fishes, SpinyDogfish)

    -- Brown Bullhead Catfish
    local BrownBullheadCatfish = Fishing.FishConfig:new("Base.BrownBullheadCatfish")
    BrownBullheadCatfish:setLocation(true, true)
    BrownBullheadCatfish:setMaxLength(50)
    BrownBullheadCatfish:setTrophyLength(60)
    BrownBullheadCatfish:setMaxWeight(3)
    BrownBullheadCatfish:setTrophyWeight(5)
    BrownBullheadCatfish:setWeightFactor(2)
    BrownBullheadCatfish:initFishSizeData()
    BrownBullheadCatfish:addLures(Fishing.lure.Insect, 0.1)
    BrownBullheadCatfish:addLures(Fishing.lure.Minnows, 0.0)
    BrownBullheadCatfish:addLures(Fishing.lure.Worms, 0.7)
    BrownBullheadCatfish:addLures(Fishing.lure.Flesh, 0.5)
    BrownBullheadCatfish:addLures(Fishing.lure.Plant, 0.5)
    BrownBullheadCatfish.lure["Base.JigLure"] = 0.3
    BrownBullheadCatfish.lure["Base.MinnowLure"] = 0.3
    BrownBullheadCatfish.lure["Base.Worm"] = 0.9
    table.insert(Fishing.fishes, BrownBullheadCatfish)

    --print("[PEI Fish] Loaded " .. #Fishing.fishes .. " PEI fish species")
end

-- Fire this event during game initialization
Events.OnGameStart.Add(InitPEIFish)
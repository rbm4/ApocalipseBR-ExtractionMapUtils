---@namespace BirdSound
require("AcadiaModOptions")

local birdSoundVolumeOption =
    PZAPI.ModOptions:getOptions("Acadia"):getOption("BirdSoundVolume")
---@cast birdSoundVolumeOption umbrella.ModOptions.Slider

local BirdSoundVolume = {}

---Read the live UI value if the widget exists, otherwise the cached value.
---@return number
---@nodiscard
local function getSliderValue()
    local element = birdSoundVolumeOption.element
    if element then
        return element:getCurrentValue()
    end
    return birdSoundVolumeOption.value
end

---Final 0..1 volume multiplier, scaled by the game's master sound volume.
---@return number
---@nodiscard
function BirdSoundVolume.getLive()
    return getCore():getOptionSoundVolume() * 0.1 * getSliderValue()
end

---Set the volume on a specific playing sound handle.
---Must be called AFTER playSoundImpl returns the handle.
---@param emitter BaseSoundEmitter
---@param handle integer
---@return integer handle (for convenience)
function BirdSoundVolume.applyToHandle(emitter, handle)
    if emitter and handle and handle ~= 0 then
        emitter:setVolume(handle, BirdSoundVolume.getLive())
    end
    return handle
end

return BirdSoundVolume
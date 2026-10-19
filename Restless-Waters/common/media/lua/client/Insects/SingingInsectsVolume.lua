---@namespace SingingInsect
require("AcadiaModOptions")

local singingInsectVolumeOption =
    PZAPI.ModOptions:getOptions("Acadia"):getOption("SingingInsectVolume")
---@cast singingInsectVolumeOption umbrella.ModOptions.Slider

local SingingInsectVolume = {}

---Read the live UI value if the widget exists, otherwise the cached value.
---@return number
---@nodiscard
local function getSliderValue()
    local element = singingInsectVolumeOption.element
    if element then
        return element:getCurrentValue()
    end
    return singingInsectVolumeOption.value
end

---Final 0..1 volume multiplier, scaled by the game's master sound volume.
---@return number
---@nodiscard
function SingingInsectVolume.getLive()
    return getCore():getOptionSoundVolume() * 0.1 * getSliderValue()
end

---Set the volume on a specific playing sound handle.
---Must be called AFTER playSound returns the handle.
---@param emitter BaseSoundEmitter
---@param handle integer
---@return integer handle (for convenience)
function SingingInsectVolume.applyToHandle(emitter, handle)
    if emitter and handle and handle ~= 0 then
        emitter:setVolume(handle, SingingInsectVolume.getLive())
    end
    return handle
end

return SingingInsectVolume
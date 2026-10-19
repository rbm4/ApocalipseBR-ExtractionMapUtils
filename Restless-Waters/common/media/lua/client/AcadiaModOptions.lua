---Holds the mod option values for the Acadia mod.
---@type table<string, any>
local ModOptions = {
    ---Ocean sound volume multiplier (relative to master sound volume).
    ---@type number
    OceanSoundVolume = 1.0,

    ---Bird sound volume multiplier (relative to master sound volume).
    ---@type number
    BirdSoundVolume = 1.0,

    ---Singing insect volume multiplier (relative to master sound volume).
    ---@type number
    SingingInsectVolume = 1.0,

    -- Add future options here, e.g.:
    -- SomeOtherSlider = 0.5,
    -- SomeKeybind    = Keyboard.KEY_F,
}

-- Single namespace for all Acadia mod options.
-- OceanVolume.lua must look this up as PZAPI.ModOptions:getOptions("Acadia").
local MOD_ID = "Acadia"
local options = PZAPI.ModOptions:create(MOD_ID, getText("IGUI_ModOptions_AcadiaName"))

-- =====================================================================
-- OCEAN SOUND
-- =====================================================================

options:addDescription(getText("IGUI_ModOptions_OceanSoundVolume_Desc"))
options:addSlider(
    "OceanSoundVolume",
    getText("IGUI_ModOptions_OceanSoundVolume_Name"),
    0.01, 1, 0.01,
    ModOptions.OceanSoundVolume
)

-- =====================================================================
-- BIRD SOUND
-- =====================================================================

options:addDescription(getText("IGUI_ModOptions_BirdSoundVolume_Desc"))
options:addSlider(
    "BirdSoundVolume",
    getText("IGUI_ModOptions_BirdSoundVolume_Name"),
    0.01, 1, 0.01,
    ModOptions.BirdSoundVolume
)

-- =====================================================================
-- SINGING INSECT SOUND
-- =====================================================================

options:addDescription(getText("IGUI_ModOptions_SingingInsectVolume_Desc"))
options:addSlider(
    "SingingInsectVolume",
    getText("IGUI_ModOptions_SingingInsectVolume_Name"),
    0.01, 1, 0.01,
    ModOptions.SingingInsectVolume
)

-- =====================================================================
-- Future options go here, following the same pattern:
--   options:addDescription(...)
--   options:addSlider(...) / addKeyBind(...) / addTickBox(...)
-- =====================================================================

---Helper: copies UI state into ModOptions.
---Runs on every main-menu enter so ModOptions reflects the user's saved choices.
function options:apply()
    for k, v in pairs(self.dict) do
        if v.type == "multipletickbox" then
            for i = 1, #v.values do
                ModOptions[(k .. "_" .. tostring(i))] = v:getValue(i)
            end
        elseif v.type ~= "button" then
            ModOptions[k] = v:getValue()
        end
    end
end

---Init values on menu enter (matches HorseMod pattern).
Events.OnMainMenuEnter.Add(function()
    options:apply()
end)

return ModOptions
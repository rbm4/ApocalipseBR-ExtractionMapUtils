-- =========================================================
-- Mod Compatibility Tile List
-- These tiles are added to the white list so the seawater system does not block them
-- =========================================================

require "CustomWater/CustomWater_ConfigAndUtils"

CustomWater = CustomWater or {}
CustomWater.WELL_SPRITES = CustomWater.WELL_SPRITES or {}

-- Lifestyles Hobbies
local LS_MISC_WELLS = {
    "LS_Misc_2_3",
    "LS_Misc_2_4",
    "LS_Misc_2_5",
    "LS_Misc_2_6",
    "LS_Misc_2_7",
    "LS_Misc_2_8",
    "LS_Misc_2_9",
    "LS_Misc_2_10",
    "LS_Misc_2_11",
    "LS_Misc_2_12",
    "LS_Misc_2_13",
    "LS_Misc_2_14",
    "LS_Misc_2_15",
    "LS_Misc_2_16",
    "LS_Misc_2_17",
    "LS_Misc_2_18",
    "LS_Misc_2_19",
    "LS_Misc_2_20",
    "LS_Misc_2_21",
    "LS_Misc_2_22",
    "LS_Misc_2_23",
    "LS_Misc_3",
    "LS_Misc_4",
    "LS_Misc_5",
    "LS_Misc_6",
    "LS_Misc_7",
    "LS_Misc_8",
    "LS_Misc_9",
    "LS_Misc_10",
    "LS_Misc_11",
    "LS_Misc_12",
    "LS_Misc_13",
    "LS_Misc_14",
    "LS_Misc_15",
    "LS_Misc_16",
    "LS_Misc_17",
    "LS_Misc_18",
    "LS_Misc_19",
    "LS_Misc_20",
    "LS_Misc_21",
    "LS_Misc_22",
    "LS_Misc_23",
    "LS_Misc_24",
    "LS_Misc_25",
    "LS_Misc_26",
    "LS_Misc_27",
    "LS_Misc_28",
    "LS_Misc_29",
    "LS_Misc_30",
    "LS_Misc_31",
    "LS_Misc_32",
    "LS_Misc_33",
    "LS_Misc_34",
    "LS_Misc_35",
    "LS_Misc_36",
    "LS_Misc_37",
    "LS_Misc_38",
    "LS_Misc_39",
    "LS_Misc_40",
    "LS_Misc_41",
    "LS_Misc_42",
    "LS_Misc_43",
    "LS_Misc_44",
    "LS_Misc_45",
    "LS_Misc_46",
    "LS_Misc_47",
}

for _, sprite in ipairs(LS_MISC_WELLS) do
    CustomWater.AddWellSprite(sprite)
end
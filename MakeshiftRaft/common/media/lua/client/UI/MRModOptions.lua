
MakeshitRaft = MakeshitRaft or {}

function MakeshitRaft.loadModConfig()
    local id = "MakeshitRaft"
    local options = PZAPI.ModOptions:create(id, getText("UI_MakeshitRaft_ModeOptionTitle"))
    MakeshitRaft.ShowWindRose = options:addTickBox("0", getText("UI_optionscreen_MakeshitRaft_Show"), true, getText("UI_optionscreen_MakeshitRaft_Show_tooltip"))
    MakeshitRaft.WindRoseColor = options:addColorPicker("1", getText("UI_optionscreen_MakeshitRaft_WindRoseColor"), 1, 1, 1, 1, getText("UI_optionscreen_MakeshitRaft_WindRoseColor_tooltip"))
    MakeshitRaft.ArrowColor = options:addColorPicker("2", getText("UI_optionscreen_MakeshitRaft_ArrowColor"), 0.0, 0.0, 0.0, 1, getText("UI_optionscreen_MakeshitRaft_ArrowColor_tooltip"))
end

MakeshitRaft.loadModConfig()

function MakeshitRaft.getShowWindRose()
    return MakeshitRaft.ShowWindRose:getValue()
end
function MakeshitRaft.getWindRoseColor()
    return MakeshitRaft.WindRoseColor:getValue()
end
function MakeshitRaft.getArrowColor()
    return MakeshitRaft.ArrowColor:getValue()
end

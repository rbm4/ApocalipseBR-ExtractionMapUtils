-- Visual coordinates ported from RadioTraders RT_SkinLayout.lua (Workshop 3807707103).
-- Ordinary radio shells only; all interaction and balance behavior belongs to ApocWallet.
local Layout = {
    walkie = { w = 703, h = 1681, feed = {112,603,450,325}, list = {112,988,450,303},
        log = {112,1344,450,69}, keys = {{112,1444,131,75},{265,1444,131,75},
            {419,1444,131,75},{112,1538,131,75},{265,1538,131,75},{419,1538,131,75}} },
    ham = { w = 1965, h = 638, feed = {290,65,508,314}, list = {852,65,584,281},
        log = {852,389,584,89}, keys = {{317,505,162,70},{503,505,162,70},
            {690,505,162,70},{876,505,162,70},{1063,505,162,70},{1249,505,162,70}} },
}
local ordinary = {"standard","woodland","digital","tiger","gold","leopard","bloodmoon","flag"}
Layout.walkie.skins = {}
Layout.ham.skins = {}
for _, name in ipairs(ordinary) do
    Layout.walkie.skins[#Layout.walkie.skins+1] = name
    Layout.ham.skins[#Layout.ham.skins+1] = name
end
Layout.walkie.skins[#Layout.walkie.skins+1] = "blackmarket"
return Layout

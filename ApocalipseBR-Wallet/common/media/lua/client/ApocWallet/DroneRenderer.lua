-- Rendering port of DroneCompanion (mirusona, Workshop 3834621996): cached
-- WorldStaticModel items, separate counter-rotating rotors, native Render3DItem.
-- No companion AI, inventory ownership, combat or DroneCompanion dependency.
require "ApocWallet/Protocol"
if ApocWallet.DroneRenderer then return ApocWallet.DroneRenderer end
local Renderer = { copies = {} }
ApocWallet.DroneRenderer = Renderer
local function copy(name)
    if not Renderer.copies[name] then Renderer.copies[name] = instanceItem("ApocWallet." .. name) end
    return Renderer.copies[name]
end

function Renderer.draw(x, y, floor, height, yaw, seconds)
    local cell = getCell()
    local square = cell and cell:getGridSquare(math.floor(x), math.floor(y), floor)
    if not square then return false end
    local body, rotor = copy("CourierVisual"), copy("CourierRotorVisual")
    if not body or not rotor then return false end
    local z = floor + height + math.sin(seconds * 2) * 0.025
    Render3DItem(body, square, x, y, z, yaw)
    local a = math.rad(yaw)
    local ca, sa, radius = math.cos(a), math.sin(a), 0.16 * 0.7
    for i, offset in ipairs({{1,1},{-1,1},{-1,-1},{1,-1}}) do
        local rx = x + (offset[1] * ca - offset[2] * sa) * radius
        local ry = y + (offset[1] * sa + offset[2] * ca) * radius
        local rsq = cell:getGridSquare(math.floor(rx), math.floor(ry), floor)
        if rsq then
            local spin = (yaw + seconds * 2160 * (i % 2 == 0 and 1 or -1)) % 360
            Render3DItem(rotor, rsq, rx, ry, z + 0.095 * 0.7 * 0.7, spin)
        end
    end
    return true
end
return Renderer

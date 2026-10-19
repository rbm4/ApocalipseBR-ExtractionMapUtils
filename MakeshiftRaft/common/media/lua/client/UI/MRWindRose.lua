
MakeshitRaft = MakeshitRaft or {}
MakeshitRaft.WindRose = ISPanelJoypad:derive("MakeshitRaft.WindRose");

function MakeshitRaft.WindRose.loadTextures()
    MakeshitRaft.WindRoseTexture = getTexture('media/textures/MRWindRose512.png')
    MakeshitRaft.ArrowTexture = getTexture('media/textures/MRArrow.png')
end
MakeshitRaft.WindRose.loadTextures()

local function getTextureFromBeaufort(beaufort)
    if beaufort < 1 then return nil end
    return MakeshitRaft.ArrowTexture
end

function MakeshitRaft.WindRose:initialise()
    ISPanelJoypad.initialise(self);
end

function MakeshitRaft.WindRose:render()
    local roseColor = MakeshitRaft.getWindRoseColor()
    local arroColor = MakeshitRaft.getArrowColor()
    local roseX = self.width
    local roseY = self.height
    self:drawTextureScaled(MakeshitRaft.WindRoseTexture, 0, 0, roseX, roseY, roseColor.a, roseColor.r, roseColor.g, roseColor.b);
    if self.javaObject ~= nil then
        local windAngle = MakeshiftRaft.convertWindAngleClimateToEastRef(getClimateManager():getWindAngleDegrees())
        local windAngleDisplay = 27.6+windAngle--ongle between horizontal screen right direction and wind rose east direction
        local arrowX = roseX / 2 --offset to understand and correct or compensate / tune
        local arrowY = roseY / 2 --offset to understand and correct or compensate / tune
        
        local windSpeed = getClimateManager():getWindspeedKph()
        local beaufort = MakeshiftRaft.getBeaufort(windSpeed)
        local arrowTexture = getTextureFromBeaufort(beaufort)
        if arrowTexture then
            local redColor = arroColor.r
            if beaufort > 4 then--starts the danger
                redColor = redColor + (1-redColor) * (beaufort-4) / 7--(11-4)
            end
            self.javaObject:DrawTextureAngle(arrowTexture, arrowX, arrowY, windAngleDisplay , redColor, arroColor.g, arroColor.b, arroColor.a)--not scalable!
        end
    end
end

function MakeshitRaft.WindRose:new()
    local x = 128;--getCore():getScreenWidth()/4;--in my book it should be divided by 2.. but I must have messed something
    local y = 0;
    local size = 128--AutoLoot.displayLootIconSize();--was 256: texture redrawn smaller/clearer, no need for that much screen space
    local o = ISPanelJoypad:new(x,y,size,size);
    setmetatable(o, self);
    self.__index = self;
    o.background = false
    o.moveWithMouse = true
    o.x = x;
    o.y = y;
    o.width = size;
    o.height = size;
    o.roseColor = { r=0, g=0, b=0.5}
    o.arroColor = { r=0.2, g=0.79, b=0.14}

    return o;
end

function MakeshitRaft.WindRose.show()
    if not MakeshitRaft.WindRose.instance then
        MakeshitRaft.WindRose.instance = MakeshitRaft.WindRose:new()
        MakeshitRaft.WindRose.instance:initialise();
    end
    local self = MakeshitRaft.WindRose.instance
    if self and not self.isDisplayed then
        self:addToUIManager();
        self:setAlwaysOnTop(true);
        self:setVisible(true);
        self.isDisplayed = true;
    end
end

function MakeshitRaft.WindRose.hide()
    local self = MakeshitRaft.WindRose.instance
    if self.isDisplayed then
        self:removeFromUIManager();
        self:setVisible(false);
        self.isDisplayed = false;
    end
end

function MakeshitRaft.WindRose.start()
    local instance = MakeshitRaft.WindRose.instance
    if MakeshitRaft.getShowWindRose() then
        if not (instance and instance.isDisplayed) then
            MakeshitRaft.WindRose.loadTextures()--just for tests
            MakeshitRaft.WindRose.show()
        end
    else
        if instance and instance then
            MakeshitRaft.WindRose.hide()
        end
    end
end

Events.OnTick.Add(MakeshitRaft.WindRose.start)

--[[
-- PEI 1993 Configuration
-- Climate color configuration
-- File: media/lua/server/Climate/ClimateMain.lua
--]]

ClimateMain = {};
ClimateMain.versionStamp = "PEI_1993_Config";

local WARM,NORMAL,CLOUDY = 0,1,2;
local SUMMER,FALL,WINTER,SPRING = 0,1,2,3;

function ClimateMain.onClimateManagerInit(_clim)
    local c;

    -- Base Night Colors (Slightly brighter fog for "snow reflection" at night)
    c = _clim:getColNightNoMoon();
    c:setExterior(0.25,0.25,0.30,0.8); -- Tinted blue for winter feel
    c:setInterior(0.06,0.06,0.35,0.4);

    c = _clim:getColNightMoon();
    c:setExterior(0.33,0.33,0.40,0.8);
    c:setInterior(0.12,0.13,0.45,0.4);

    c = _clim:getColFog();
    c:setExterior(0.25,0.25,0.28,0.85); -- Thicker, whiter fog
    c:setInterior(0.15,0.15,0.20,0.6);

    c = _clim:getColFogLegacy();
    c:setExterior(0.3,0.3,0.35,0.8);
    c:setInterior(0.3,0.3,0.35,0.8);

    c = _clim:getColFogNew();
    c:setExterior(0.5,0.5,0.55,0.8);
    c:setInterior(0.4,0.4,0.45,0.7);

    c = _clim:getFogTintStorm();
    c:setExterior(0.4,0.4,0.45,1.0); -- Storms are grey/white
    c:setInterior(0.4,0.4,0.45,1.0);

    c = _clim:getFogTintTropical();
    c:setExterior(0.8,0.75,0.55,1.0);
    c:setInterior(0.8,0.75,0.55,1.0);

    local w = _clim:getWeatherPeriod();

    c = w:getCloudColorReddish();
    c:setExterior(0.4,0.05,0.05,0.6);
    c:setInterior(0.21,0.05,0.05,0.5);

    c = w:getCloudColorGreenish();
    c:setExterior(0.14,0.27,0.05,0.6);
    c:setInterior(0.07,0.15,0.02,0.5);

    c = w:getCloudColorBlueish();
    c:setExterior(0.13,0.28,0.3,0.6);
    c:setInterior(0.05,0.15,0.16,0.43);

    c = w:getCloudColorPurplish();
    c:setExterior(0.38,0.12,0.49,0.7);
    c:setInterior(0.26,0.03,0.34,0.37);

    c = w:getCloudColorTropical();
    c:setExterior(0.4,0.2,0.2,0.4);
    c:setInterior(0.4,0.2,0.2,0.4);

    c = w:getCloudColorBlizzard();
    c:setExterior(0.85,0.87,0.95,0.9); -- Bright blizzard (snow blindness)
    c:setInterior(0.6,0.65,0.7,0.8);

    -- ###################### Dawn ######################
    -- Summer Dawn: Muted, cooler colors
    _clim:setSeasonColorDawn(WARM,SUMMER,0.50,0.55,0.60,0.70,true);		--exterior
    _clim:setSeasonColorDawn(WARM,SUMMER,0.20,0.25,0.30,0.30,false);		--interior

    _clim:setSeasonColorDawn(CLOUDY,SUMMER,0.35,0.40,0.45,0.60,true);		--exterior
    _clim:setSeasonColorDawn(CLOUDY,SUMMER,0.15,0.18,0.20,0.35,false);		--interior

    _clim:setSeasonColorDawn(WARM,FALL,0.55,0.45,0.40,0.75,true);		--exterior
    _clim:setSeasonColorDawn(WARM,FALL,0.25,0.18,0.25,0.26,false);		--interior

    _clim:setSeasonColorDawn(CLOUDY,FALL,0.40,0.35,0.35,0.68,true);		--exterior
    _clim:setSeasonColorDawn(CLOUDY,FALL,0.20,0.15,0.20,0.37,false);		--interior

    -- Winter Dawn: Very pale, cold
    _clim:setSeasonColorDawn(WARM,WINTER,0.40,0.45,0.50,0.80,true);		--exterior
    _clim:setSeasonColorDawn(WARM,WINTER,0.15,0.20,0.25,0.35,false);		--interior

    _clim:setSeasonColorDawn(CLOUDY,WINTER,0.20,0.25,0.30,0.70,true);		--exterior
    _clim:setSeasonColorDawn(CLOUDY,WINTER,0.10,0.12,0.15,0.55,false);		--interior

    _clim:setSeasonColorDawn(WARM,SPRING,0.50,0.55,0.50,0.70,true);		--exterior
    _clim:setSeasonColorDawn(WARM,SPRING,0.20,0.25,0.20,0.40,false);		--interior

    _clim:setSeasonColorDawn(CLOUDY,SPRING,0.35,0.40,0.35,0.65,true);		--exterior
    _clim:setSeasonColorDawn(CLOUDY,SPRING,0.15,0.18,0.15,0.55,false);		--interior

    -- ###################### Day ######################
    -- Summer Day: SIGNIFICANTLY DARKER/GREYER for overcast/rain
    _clim:setSeasonColorDay(WARM,SUMMER,0.60,0.62,0.65,0.75,true);		--exterior (Was 0.86, now 0.60)
    _clim:setSeasonColorDay(WARM,SUMMER,0.30,0.30,0.35,0.20,false);		--interior (Was 0.41, now 0.30)

    _clim:setSeasonColorDay(CLOUDY,SUMMER,0.45,0.48,0.52,0.80,true);		--exterior (Was 0.55)
    _clim:setSeasonColorDay(CLOUDY,SUMMER,0.20,0.22,0.25,0.35,false);		--interior (Was 0.25)

    _clim:setSeasonColorDay(WARM,FALL,0.65,0.55,0.50,0.80,true);		--exterior
    _clim:setSeasonColorDay(WARM,FALL,0.40,0.25,0.20,0.20,false);		--interior

    _clim:setSeasonColorDay(CLOUDY,FALL,0.45,0.40,0.42,0.75,true);		--exterior
    _clim:setSeasonColorDay(CLOUDY,FALL,0.25,0.20,0.22,0.35,false);		--interior

    -- Winter Day: Pale and Cold (Not pitch black, just "White/Grey")
    _clim:setSeasonColorDay(WARM,WINTER,0.55,0.58,0.62,0.80,true);		--exterior
    _clim:setSeasonColorDay(WARM,WINTER,0.25,0.28,0.32,0.40,false);		--interior

    _clim:setSeasonColorDay(CLOUDY,WINTER,0.35,0.38,0.42,0.75,true);		--exterior
    _clim:setSeasonColorDay(CLOUDY,WINTER,0.15,0.18,0.22,0.60,false);		--interior

    _clim:setSeasonColorDay(WARM,SPRING,0.60,0.65,0.60,0.70,true);		--exterior
    _clim:setSeasonColorDay(WARM,SPRING,0.30,0.35,0.30,0.20,false);		--interior

    _clim:setSeasonColorDay(CLOUDY,SPRING,0.45,0.50,0.45,0.65,true);		--exterior
    _clim:setSeasonColorDay(CLOUDY,SPRING,0.20,0.25,0.20,0.45,false);		--interior

    -- ###################### Dusk ######################
    -- Summer Dusk: Greyish-blue instead of Orange
    _clim:setSeasonColorDusk(WARM,SUMMER,0.55,0.50,0.55,0.80,true);		--exterior (Was Orange, now Grey)
    _clim:setSeasonColorDusk(WARM,SUMMER,0.25,0.20,0.25,0.60,false);		--interior

    _clim:setSeasonColorDusk(NORMAL,SUMMER,0.45,0.50,0.60,0.75,true);		--exterior
    _clim:setSeasonColorDusk(NORMAL,SUMMER,0.20,0.25,0.30,0.40,false);		--interior

    _clim:setSeasonColorDusk(CLOUDY,SUMMER,0.40,0.38,0.45,0.80,true);		--exterior
    _clim:setSeasonColorDusk(CLOUDY,SUMMER,0.20,0.18,0.22,0.50,false);		--interior

    _clim:setSeasonColorDusk(WARM,FALL,0.60,0.45,0.40,0.80,true);		--exterior
    _clim:setSeasonColorDusk(WARM,FALL,0.30,0.20,0.15,0.40,false);		--interior

    _clim:setSeasonColorDusk(NORMAL,FALL,0.40,0.35,0.45,0.70,true);		--exterior
    _clim:setSeasonColorDusk(NORMAL,FALL,0.20,0.15,0.20,0.40,false);		--interior

    _clim:setSeasonColorDusk(CLOUDY,FALL,0.45,0.35,0.40,0.75,true);		--exterior
    _clim:setSeasonColorDusk(CLOUDY,FALL,0.25,0.18,0.20,0.45,false);		--interior

    _clim:setSeasonColorDusk(WARM,WINTER,0.45,0.45,0.50,0.85,true);		--exterior
    _clim:setSeasonColorDusk(WARM,WINTER,0.25,0.25,0.30,0.45,false);		--interior

    _clim:setSeasonColorDusk(NORMAL,WINTER,0.35,0.40,0.45,0.85,true);		--exterior
    _clim:setSeasonColorDusk(NORMAL,WINTER,0.20,0.25,0.30,0.45,false);		--interior

    _clim:setSeasonColorDusk(CLOUDY,WINTER,0.35,0.35,0.40,0.80,true);		--exterior
    _clim:setSeasonColorDusk(CLOUDY,WINTER,0.20,0.20,0.25,0.50,false);		--interior

    _clim:setSeasonColorDusk(WARM,SPRING,0.55,0.45,0.40,0.80,true);		--exterior
    _clim:setSeasonColorDusk(WARM,SPRING,0.25,0.20,0.15,0.50,false);		--interior

    _clim:setSeasonColorDusk(NORMAL,SPRING,0.40,0.45,0.40,0.75,true);		--exterior
    _clim:setSeasonColorDusk(NORMAL,SPRING,0.20,0.25,0.20,0.65,false);		--interior

    _clim:setSeasonColorDusk(CLOUDY,SPRING,0.45,0.40,0.45,0.80,true);		--exterior
    _clim:setSeasonColorDusk(CLOUDY,SPRING,0.20,0.18,0.20,0.60,false);		--interior

end

Events.OnClimateManagerInit.Add(ClimateMain.onClimateManagerInit);
Events.OnInitSeasons.Add( 
  function(_season) 
    _season:init(
      24,   -- Summer Max: Lowered from 46 to 24 (Cool/Rainy)
      18,   -- Fall Max: Lowered from 30 (Mild autumn)
      -24,  -- Winter Max: Kept at -22 (Very snowy)
      12,   -- Spring Max: Lowered from 8 (Late thaw)
        _season:getSeasonLag(),
        _season:getHighNoon(),
        _season:getSeedA(),
        _season:getSeedB(),
        _season:getSeedC()
    );                          
end
);
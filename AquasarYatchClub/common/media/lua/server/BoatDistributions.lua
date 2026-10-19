require "CommonTemplates/CommonDistributions"

local distributionTable = VehicleDistributions[1]

if VehicleDistributions and VehicleDistributions.CommonTemplatesDist then
    if not VehicleDistributions.CommonTemplatesDist.seatboxwooden or VehicleDistributions.CommonTemplatesDist.seatboxwooden == CommonVehicleDistributions.Null then
            VehicleDistributions.CommonTemplatesDist.seatboxwooden = {
            rolls = 4,
            items = {
                -- Keys/Keyrings
                "KeyRing_EagleFlag", 0.2,
                -- TODO: Sort Me!
                "Aquatsar.BoatMag", 2,
                "Aquatsar.DivingMask", 2,
                "Aquatsar.DivingMask", 1,
                "Aquatsar.Compass", 2,
                "Aquatsar.Lifebuoy", 10,
                "Aquatsar.Lifebuoy", 2,
                "Aquatsar.Sails", 1,
                "Aquatsar.SwimMag", 2,
                "Aquatsar.TaintedLiterature", 1,
                "CardDeck", 1,
                "Cashbox", 0.5,
                "CigarBox", 0.1,
                "CigarettePack", 1,
                "CreditCard", 1,
                "Glasses_Aviators", 1,
                "Glasses_Prescription_Aviators", 0.1,
                "Glasses_Prescription_Sun", 0.5,
                "Glasses_Sun", 2,
                "Gum", 1,
                "MechanicMag1", 0.1,
                "MechanicMag2", 0.1,
                "MechanicMag3", 0.1,
                "Money", 1,
                "MoneyBundle", 0.1,
                "PillsVitamins", 0.1,
                "PokerChips", 1,
                "Whiskey", 0.1,
            },
            junk = ClutterTables.GloveBoxJunk,
        }

    end
end


distributionTable["BoatSailingYacht"] = {
    Normal = VehicleDistributions.CommonTemplatesDist,
}
    
--distributionTable["BoatZeroPatient"] = {
--    Normal = VehicleDistributions.CommonTemplatesDist,
--}

distributionTable["BoatMotor"] = {
    Normal = VehicleDistributions.CommonTemplatesDist,
}

distributionTable["TrailerWithBoatSailingYacht"] = {
    Normal = VehicleDistributions.CommonTemplatesDist,
}
    
distributionTable["TrailerWithBoatMotor"] = {
    Normal = VehicleDistributions.CommonTemplatesDist,
}

table.insert(VehicleDistributions, 1, distributionTable);



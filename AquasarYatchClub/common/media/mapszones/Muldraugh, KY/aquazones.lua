if globalTsarZones then
    globalTsarZones["aquazones"] = {  
       -- лодка западнее x - 4 лодка восточнее x + 3 
       -- лодка севернее у - 4 лодка южнее у + 3
      
      -- { name = "river", type = "ParkingStall", x = 3898, y = 5785, z = 1, width = 20, height = 20 },

      -- louisville boat club: 
      { name = "harbour", type = "ParkingStall", x = 12819, y = 1153 - 1, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- width=x, height=y
      { name = "harbour", type = "ParkingStall", x = 12819, y = 1161, z = 1, width = 3, height = 2, properties = { Direction = "W" } },
      { name = "harbour", type = "ParkingStall", x = 12827, y = 1136, z = 1, width = 3, height = 2, properties = { Direction = "W" } },
      { name = "harbour", type = "ParkingStall", x = 12816, y = 1136, z = 1, width = 3, height = 2, properties = { Direction = "W" } },
      { name = "harbour", type = "ParkingStall", x = 12837, y = 1124, z = 1, width = 2, height = 3, properties = { Direction = "N" } },
      
      
      { name = "harbour", type = "ParkingStall", x = 12875, y = 1133, z = 1, width = 2, height = 3},
      { name = "harbour", type = "ParkingStall", x = 12875, y = 1163, z = 1, width = 3, height = 2, properties = { Direction = "W" } },
      
      -- 2
      { name = "harbour", type = "ParkingStall", x = 12892, y = 1147, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      { name = "harbour", type = "ParkingStall", x = 12892, y = 1165, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      { name = "harbour", type = "ParkingStall", x = 12905, y = 1150, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      { name = "harbour", type = "ParkingStall", x = 12905, y = 1168, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      
      -- 3
      { name = "harbour", type = "ParkingStall", x = 12980, y = 1124 - 1, z = 1, width = 3, height = 2, properties = { Direction = "W" } },
      { name = "harbour", type = "ParkingStall", x = 12975 - 1, y = 1129, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      { name = "harbour", type = "ParkingStall", x = 12975 - 1, y = 1143, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      { name = "harbour", type = "ParkingStall", x = 12992, y = 1134, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      { name = "harbour", type = "ParkingStall", x = 12992, y = 1150, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      
      -- 4
      { name = "harbour", type = "ParkingStall", x = 11989 - 5, y = 2107, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, 
      { name = "harbour", type = "ParkingStall", x = 11986, y = 2205 - 1, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, 
       
     -- 5 
      -- sea: randomAngle BoatSailingYacht BoatMotor spawnRate 30
      { name = "sea", type = "ParkingStall", x = 11967, y = 2255, z = 1, width = 3, height = 3 },
      { name = "harbour", type = "ParkingStall", x = 11986 - 1, y = 2315, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- corrected B42 
      { name = "sea", type = "ParkingStall", x = 11972, y = 2363, z = 1, width = 3, height = 3 },
      { name = "harbour", type = "ParkingStall", x = 11984 - 1, y = 2372, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- added B42 
      { name = "sea", type = "ParkingStall", x = 11980, y = 2433, z = 1, width = 3, height = 3 },--OK B42
      { name = "harbour", type = "ParkingStall", x = 11986, y = 2532 - 5, z = 1, width = 3, height = 2, properties = { Direction = "W" } },--added B42
      { name = "harbour", type = "ParkingStall", x = 11986, y = 2533 + 3, z = 1, width = 3, height = 2, properties = { Direction = "W" } },--corrected B42
      { name = "harbour", type = "ParkingStall", x = 11973 - 1, y = 2662, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- added B42 
      { name = "sea", type = "ParkingStall", x = 11956, y = 2664, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 11989, y = 2762, z = 1, width = 3, height = 3 },
      { name = "harbour", type = "ParkingStall", x = 11984 - 1, y = 2829, z = 1, width = 2, height = 3, properties = { Direction = "N" } },--OK B42
      { name = "harbour", type = "ParkingStall", x = 11986, y = 2951 - 5, z = 1, width = 3, height = 2, properties = { Direction = "W" } },--added B42
      { name = "harbour", type = "ParkingStall", x = 11986, y = 2952 + 3, z = 1, width = 3, height = 2, properties = { Direction = "W" } },--OK B42
      { name = "harbour", type = "ParkingStall", x = 11986, y = 3058 - 5, z = 1, width = 3, height = 2, properties = { Direction = "W" } },--added B42
      { name = "harbour", type = "ParkingStall", x = 11986, y = 3063 + 5, z = 1, width = 3, height = 2, properties = { Direction = "W" } },--added B42
      { name = "sea", type = "ParkingStall", x = 11984, y = 3025, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 11969, y = 3110, z = 1, width = 3, height = 3 },
     -- 11
      { name = "sea", type = "ParkingStall", x = 12464, y = 5278, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 12469, y = 5298, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 12480, y = 5312, z = 1, width = 3, height = 3 },
     -- Причал
      { name = "harbour", type = "ParkingStall", x = 11827 - 5, y = 6574, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- западнее
      { name = "harbour", type = "ParkingStall", x = 11828 + 3, y = 6578, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- восточнее
    -- Причал2
      { name = "harbour", type = "ParkingStall", x = 11259, y = 6574 - 4, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- севернее
      { name = "sea", type = "ParkingStall", x = 11296, y = 6572, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 11279, y = 6565, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 10713, y = 6553, z = 1, width = 3, height = 3 },
    --22
      { name = "harbour", type = "ParkingStall", x = 10148, y = 6574, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- западнее 
      { name = "harbour", type = "ParkingStall", x = 10153 + 2, y = 6570, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- восточнее

      { name = "sea", type = "ParkingStall", x = 9431, y = 6875, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 7527, y = 6112, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 5950, y = 5163, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 6446, y = 5165, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 6503, y = 5163, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 5763, y = 5195, z = 1, width = 3, height = 3 }, -- AYC 42.17: was 5760,5195: yacht over land at 15/36 headings
      { name = "sea", type = "ParkingStall", x = 4908, y = 5513, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 4890, y = 5513, z = 1, width = 3, height = 3 },
      
    --33
      { name = "sea", type = "ParkingStall", x = 3646, y = 5683, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 3663, y = 5679, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 3698, y = 5678, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 3686, y = 5658, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 3667, y = 5666, z = 1, width = 3, height = 3 },

    -- на реке
      { name = "sea", type = "ParkingStall", x = 9760, y = 6527, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 12559, y = 5945, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 12528, y = 5663, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 14161, y = 1167, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 14132, y = 1176, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 14204, y = 1168, z = 1, width = 3, height = 3 },
      
    -- в глуши
      { name = "sea", type = "ParkingStall", x = 12761, y = 8794, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 13775, y = 7375, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 13902, y = 6705, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 13934, y = 4549, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 14440, y = 2162, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 4623, y = 8149, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 4601, y = 8285, z = 1, width = 3, height = 3 },
      { name = "harbour", type = "ParkingStall", x = 4264, y = 7267, z = 1, width = 3, height = 2 , properties = { Direction = "W" } },
      { name = "sea", type = "ParkingStall", x = 10050, y = 10276, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 10187, y = 6728, z = 1, width = 3, height = 3 },
      { name = "sea", type = "ParkingStall", x = 12725, y = 6733, z = 1, width = 3, height = 3 },
      
    --B42 Unusual Farm lake
      { name = "harbour", type = "ParkingStall", x = 3809 - 1, y = 12379, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- West of bridge
      { name = "harbour", type = "ParkingStall", x = 3816 + 1, y = 12379, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- East of bridge
      { name = "harbour", type = "ParkingStall", x = 3814, y = 12385 + 3, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- South of bridge
      { name = "sea", type = "ParkingStall", x = 3970, y = 12500, z = 1, width = 3, height = 3 },

    --B42 Dark Wallow lake - Camp Arthur
      { name = "harbour", type = "ParkingStall", x = 8361 + 3, y = 14609, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- East of bridges
      { name = "harbour", type = "ParkingStall", x = 8355, y = 14620, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- South of bridges
      { name = "sea", type = "ParkingStall", x = 8384, y = 14613, z = 1, width = 3, height = 3 },

    --B42 Dark Wallow lake - Vacation Resort
      { name = "harbour", type = "ParkingStall", x = 8468 + 3, y = 14453, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- West of west pier / East / North
      { name = "harbour", type = "ParkingStall", x = 8468 + 3, y = 14474, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- West of west pier / East / South
      { name = "harbour", type = "ParkingStall", x = 8463, y = 14485, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- West of west pier / South
      { name = "sea", type = "ParkingStall", x = 8465, y = 14500, z = 1, width = 3, height = 3 }, -- West of west pier / South / South
      { name = "harbour", type = "ParkingStall", x = 8486 + 3, y = 14457, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- East of west pier / East / North
      { name = "harbour", type = "ParkingStall", x = 8486 + 3, y = 14472, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- East of west pier / East / South
      { name = "harbour", type = "ParkingStall", x = 8481, y = 14482 + 3, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- East of west pier / South
      { name = "sea", type = "ParkingStall", x = 8458, y = 14500, z = 1, width = 3, height = 3 }, -- East of west pier / South / South
      { name = "bigboat", type = "ParkingStall", x = 8571 - 5, y = 14462, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- West of East pier North
      { name = "smallboat", type = "ParkingStall", x = 8567 - 1, y = 14476, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- West of East pier Middle
      { name = "harbour", type = "ParkingStall", x = 8570, y = 14485 + 3, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- South of East pier
      { name = "harbour", type = "ParkingStall", x = 8575 + 3, y = 14462, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- East of East pier North
      { name = "harbour", type = "ParkingStall", x = 8575 + 3, y = 14476, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- East of East pier Middle
      
    --B42 Dark Wallow lake - South Houses
      { name = "smallboat", type = "ParkingStall", x = 8772, y = 15049 - 1, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- North of North house
      { name = "bigboat", type = "ParkingStall", x = 8771, y = 15057, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- South of North house
      { name = "sea", type = "ParkingStall", x = 8756, y = 15054, z = 1, width = 3, height = 3 },
      { name = "smallboat", type = "ParkingStall", x = 8813, y = 15125 - 1, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- North of South house
      { name = "bigboat", type = "ParkingStall", x = 8814, y = 15133, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- South of South house
      { name = "sea", type = "ParkingStall", x = 8800, y = 15129, z = 1, width = 3, height = 3 },
      { name = "bigboat", type = "ParkingStall", x = 8655, y = 15268 + 3, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- South of Island house

    --B42 Dark Wallow lake - Water Treatment Plant
      { name = "smallboat", type = "ParkingStall", x = 8088 + 3, y = 15354, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- South
      { name = "smallboat", type = "ParkingStall", x = 8088 + 3, y = 15327, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- North
      
    --B42 Brandenburg
      { name = "bigboat", type = "ParkingStall", x = 1631, y = 5576 - 5, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- Pier, North
      { name = "smallboat", type = "ParkingStall", x = 1633 - 1, y = 5581, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- Pier, West
      { name = "harbour", type = "ParkingStall", x = 1640 + 1, y = 5583, z = 1, width = 2, height = 3, properties = { Direction = "N" } }, -- Pier, East
      { name = "bigboat", type = "ParkingStall", x = 1905, y = 5701 - 5, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- Shore / City
      { name = "bigboat", type = "ParkingStall", x = 3228, y = 5697 - 5, z = 1, width = 3, height = 2, properties = { Direction = "W" } }, -- Shore / Island
      
      
    -- bigboat:
      -- { name = "bigboat", type = "ParkingStall", x = 4025, y = 5825, z = 1, width = 15, height = 15 },

      
     -- shipwreckland: average 24 trailers
      -- { name = "shipwreckland", type = "ParkingStall", x = 4025, y = 5825, z = 1, width = 15, height = 15 },
       
    }
end
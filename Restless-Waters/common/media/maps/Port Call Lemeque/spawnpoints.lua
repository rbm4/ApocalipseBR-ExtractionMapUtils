function SpawnPoints()
	local spawns = {
	  { posX = 289, posY = 14423, posZ = 0 },
	  { posX = 284, posY = 14423, posZ = 0 },
	  { posX = 294, posY = 14423, posZ = 0 },
	
	}

	return {
		moduletags = {"none"},
		chef = spawns,
		constructionworker = spawns,
		doctor = spawns,
		fireofficer = spawns,
		parkranger = spawns,
		policeofficer = spawns,
		repairman = spawns,
		securityguard = spawns,
		unemployed = spawns
	}
end


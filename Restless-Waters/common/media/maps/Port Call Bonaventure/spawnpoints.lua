function SpawnPoints()
	local spawns = {
	  { posX = 319, posY = 9692, posZ = 0 }
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


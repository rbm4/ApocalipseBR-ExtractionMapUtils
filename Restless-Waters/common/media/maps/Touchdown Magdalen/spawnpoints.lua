function SpawnPoints()
	local spawns = {
	  { posX = 14295, posY = 11860, posZ = 0 },
	  { posX = 14295, posY = 11864, posZ = 0 },
	}

	return {
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


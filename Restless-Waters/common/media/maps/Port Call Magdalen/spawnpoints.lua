function SpawnPoints()
	local spawns = {
	  { posX = 14247, posY = 12325, posZ = 0 },
	  { posX = 14253, posY = 12325, posZ = 0 },
          { posX = 14257, posY = 12325, posZ = 0 },
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


local MobSpawnConfig = {}

-- Natural spawning on at server start (devs can toggle it from the Mob Spawner panel)
MobSpawnConfig.Enabled = true

-- Seconds after server start before the first spawn
MobSpawnConfig.InitialDelay = 3

-- Seconds between two spawn passes
MobSpawnConfig.SpawnInterval = 5

-- Max herds spawned per pass (avoids a burst of mobs at once)
MobSpawnConfig.MaxHerdsPerPass = 2

-- Seconds after a natural mob dies or despawns before its type can spawn again
MobSpawnConfig.RespawnDelay = 45

-- Spawn zone: same as the trees (TreeSpawnConfig)
MobSpawnConfig.OutsideFolderName = "Outside"
MobSpawnConfig.GroundTag = "Ground"

-- Minimum distance between two herd centers (studs)
MobSpawnConfig.MinHerdSeparation = 40

-- Herds never spawn closer than this to a player (no mobs popping in front of someone)
MobSpawnConfig.MinPlayerDistance = 60

-- Herd members spawn within this radius of the herd center (studs)
MobSpawnConfig.HerdRadius = 6

-- Per mob type: max natural mobs alive, herd size range, relative chance per pass
MobSpawnConfig.Mobs = {
	Cow = { maxAlive = 12, herdSize = { 2, 4 }, weight = 3 },
	Sheep = { maxAlive = 12, herdSize = { 2, 4 }, weight = 3 },
	Chicken = { maxAlive = 10, herdSize = { 2, 3 }, weight = 2 },
}

return MobSpawnConfig

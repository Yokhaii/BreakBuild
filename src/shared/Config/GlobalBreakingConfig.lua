return {
	-- Grid dimensions (in blocks)
	GridSizeX = 50,
	GridSizeZ = 50,
	BlockSize = Vector3.new(4, 4, 4),

	-- Cycle settings
	CycleDuration = 480, -- 8 minutes in seconds
	TimerUpdateInterval = 1, -- How often to send timer updates to clients

	-- Origin marker (Part in Workspace)
	OriginPartName = "GlobalBreakingArea",

	-- Global breakable sentinel
	GlobalPlayerId = 0,

	-- Mountain Biome Noise (above ground)
	MountainNoise = {
		Scale = 0.13,
		Amplitude = 10,
		BaseHeight = 0,
		Octaves = 1,
		Persistence = 1,
		Lacunarity = 0,
	},

	-- Underground
	MaxDepth = 10, -- Max layers below ground (Y=-1 to Y=-10)
	InitialUndergroundLayers = 3, -- How many underground layers to place at start

	-- Ore Generation
	OreConfig = {
		IronOreBlock = {
			spawnChance = 0.008, -- 6% chance per stone block
			clusterSize = { min = 2, max = 3 },
			minDepth = -2, -- Only spawns at Y=-2 and below
		},
		CoalOreBlock = {
			spawnChance = 0.012, -- 8% chance per stone block
			clusterSize = { min = 2, max = 6 },
			minDepth = -1, -- Spawns at Y=-1 and below
		},
	},

	-- Breaking
	BreakRange = 24,

	-- Performance
	PlacementBatchSize = 400,
}

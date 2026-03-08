--[[
	BreakingConfig.lua
	Configuration for the Breaking system grid and spawning
]]

return {
	-- Grid settings
	GridSize = 2, -- 2-stud grid
	BlockSize = Vector3.new(4, 4, 4), -- 4x4x4 blocks
	ZoneSize = 64, -- 64 studs per axis
	BlocksPerAxis = 16, -- 64/4 = 16 blocks per axis

	-- Floor settings
	MaxFloors = 3,
	FloorYPositions = {
		[1] = 2, -- Floor 1: spans Y=0-4, center at Y=2
		[2] = 6, -- Floor 2: spans Y=4-8, center at Y=6
		[3] = 10, -- Floor 3: spans Y=8-12, center at Y=10
	},

	-- Spawning settings
	DefaultSpawnInterval = 5, -- seconds between spawns
	MaxBlocks = 768, -- 16*16*3 = 768 total blocks

	-- Breaking settings
	BreakRange = 24, -- Studs (slightly larger than building since blocks are bigger)
	BreakConeAngle = 60, -- Degrees (total cone, so 30 degrees each side)

	-- Bare hand breaking (no tool equipped)
	BareHandBreakSpeed = 0.25, -- Very slow break speed (4x slower than normal)
	BareHandToolTier = "Hand", -- Can only break materials that require "Hand" tier or lower

	-- Spawn animation settings
	SpawnAnimationDuration = 0.8, -- Total animation time in seconds
	SpawnStartOffset = -6, -- How far underground the block starts (negative Y)
	SpawnOvershootHeight = 3, -- How high above final position the block shoots
}

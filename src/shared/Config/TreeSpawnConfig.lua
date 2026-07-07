local TreeSpawnConfig = {}

-- Max number of world trees alive at any time
TreeSpawnConfig.MaxTrees = 64

-- Seconds between spawn attempts (when below MaxTrees)
TreeSpawnConfig.SpawnInterval = 5

-- Seconds before a broken tree slot can be refilled
TreeSpawnConfig.RespawnDelay = 30

-- Minimum distance between any two trees (studs)
TreeSpawnConfig.MinTreeSeparation = 8

-- CollectionService tag that marks parts trees can spawn on top of
TreeSpawnConfig.GroundTag = "Ground"

-- Workspace folder that contains the Outside boundary parts
TreeSpawnConfig.OutsideFolderName = "Outside"

-- Name of the parts inside the Outside folder that define spawn bounds
TreeSpawnConfig.BoundaryPartName = "Outside"

-- Raycast height offset: how far above the boundary part to start the downward ray
TreeSpawnConfig.RaycastStartHeight = 500

-- Vertical offset applied to the raycast hit position before placing the tree (studs)
TreeSpawnConfig.SpawnHeightOffset = 2

-- Tree type spawn weights (higher = more common)
-- These are normalized at runtime, so only relative values matter
-- Spawn weight per tree type (higher = more common, relative values)
TreeSpawnConfig.TreeWeights = {
	Spruce   = 7,
	FirTree = 3,
	ApricotTree = 1,
}

return TreeSpawnConfig

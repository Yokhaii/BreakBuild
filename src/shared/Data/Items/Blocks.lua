-- Blocks.lua
-- Item data for block-type items

local Blocks = {
	Dirt = {
		name = "Dirt",
		displayName = "Dirt",
		type = "Block",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Basic dirt block",
		modelPath = "ReplicatedStorage.Assets.Items.Dirt",
		blockSize = Vector3.new(4, 4, 4), -- Building block size in studs
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.Dirt",
	},

	Stone = {
		name = "Stone",
		displayName = "Stone",
		type = "Block",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Solid stone block",
		modelPath = "ReplicatedStorage.Assets.Items.Stone",
		blockSize = Vector3.new(4, 4, 4),
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.Stone",
	},

	Sand = {
		name = "Sand",
		displayName = "Sand",
		type = "Block",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Sandy block",
		modelPath = "ReplicatedStorage.Assets.Items.Sand",
		blockSize = Vector3.new(4, 4, 4),
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.Sand",
	},

	Log = {
		name = "Log",
		displayName = "Log",
		type = "Block",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Wooden log",
		modelPath = "ReplicatedStorage.Assets.Items.Log",
		blockSize = Vector3.new(4, 4, 4),
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.Log",
	},
}

return Blocks

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
	Grass = {
		name = "Grass",
		displayName = "Grass",
		type = "Block",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Basic dirt block",
		modelPath = "ReplicatedStorage.Assets.Items.Grass",
		blockSize = Vector3.new(4, 4, 4), -- Building block size in studs
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.Grass",
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
		fuelValue = 1,
	},

	SprucePlank = {
		name = "SprucePlank",
		displayName = "Spruce Plank",
		type = "Block",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Wooden plank made from spruce logs",
		modelPath = "ReplicatedStorage.Assets.Items.SprucePlank",
		blockSize = Vector3.new(2, 2, 2),
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.SprucePlank",
		fuelValue = 1,
	},
	HalfStone = {
		name = "HalfStone",
		displayName = "Half Stone",
		type = "Block",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Half a stone block",
		modelPath = "ReplicatedStorage.Assets.Items.HalfStone",
		blockSize = Vector3.new(2, 2, 2),
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.HalfStone",
	},

	Bedrock = {
		name = "Bedrock",
		displayName = "Bedrock",
		type = "Block",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "Indestructible block",
		blockSize = Vector3.new(4, 4, 4),
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.Bedrock",
	},

	IronOreBlock = {
		name = "IronOreBlock",
		displayName = "Iron Ore",
		type = "Block",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "Iron ore vein found underground",
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.IronOreBlock",
	},

	CoalOreBlock = {
		name = "CoalOreBlock",
		displayName = "Coal Ore",
		type = "Block",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "Coal ore vein found underground",
		buildingPartPath = "ReplicatedStorage.Assets.BuildingParts.CoalOreBlock",
	},
}

return Blocks

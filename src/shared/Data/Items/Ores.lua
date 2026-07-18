-- Ores.lua
-- Item data for ore-type items

local Ores = {
	StoneShard = {
		name = "StoneShard",
		displayName = "Stone Shard",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Stone shard used to craft stone tools",
		modelPath = "ReplicatedStorage.Assets.Items.StoneShard",
	},
	IronOre = {
		name = "IronOre",
		displayName = "IronOre",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Unprocessed iron ore",
		modelPath = "ReplicatedStorage.Assets.Items.IronOre",
	},

	RawGold = {
		name = "RawGold",
		displayName = "Raw Gold",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Unprocessed gold ore",
		modelPath = "ReplicatedStorage.Assets.Items.RawGold",
	},

	RawDiamond = {
		name = "RawDiamond",
		displayName = "Raw Diamond",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Unprocessed diamond ore",
		modelPath = "ReplicatedStorage.Assets.Items.RawDiamond",
	},
	IronIngot = {
		name = "IronIngot",
		displayName = "Iron Ingot",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "iron ingot",
		modelPath = "ReplicatedStorage.Assets.Items.IronIngot",
	},
	Charcoal = {
		name = "Charcoal",
		displayName = "Charcoal",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Burned wood, efficient fuel source",
		modelPath = "ReplicatedStorage.Assets.Items.Charcoal",
		fuelValue = 2,
	},
	Coal = {
		name = "Coal",
		displayName = "Coal",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Mined coal, efficient fuel source",
		modelPath = "ReplicatedStorage.Assets.Items.Coal",
		fuelValue = 2,
	},
}

return Ores

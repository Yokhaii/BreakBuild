-- Ores.lua
-- Item data for ore-type items

local Ores = {
	RawIron = {
		name = "RawIron",
		displayName = "Raw Iron",
		type = "Ore",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Unprocessed iron ore",
		modelPath = "ReplicatedStorage.Assets.Items.RawIron",
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
}

return Ores

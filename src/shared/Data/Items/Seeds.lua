-- Seeds.lua
-- Item data for seed-type items (planted on the CropField, see CropData)

local Seeds = {
	WheatSeeds = {
		name = "WheatSeeds",
		displayName = "Wheat Seeds",
		type = "Seed",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Click a Crop Field plot to plant them. Grows into wheat",
		modelPath = "ReplicatedStorage.Assets.Items.WheatSeeds",
	},
	CarrotSeeds = {
		name = "CarrotSeeds",
		displayName = "Carrot Seeds",
		type = "Seed",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Click a Crop Field plot to plant them. Grows into carrots",
		modelPath = "ReplicatedStorage.Assets.Items.CarrotSeeds",
	},
	MelonSeeds = {
		name = "MelonSeeds",
		displayName = "Melon Seeds",
		type = "Seed",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "Click a Crop Field plot to plant them. Grows into a melon",
		modelPath = "ReplicatedStorage.Assets.Items.MelonSeeds",
	},
}

return Seeds

-- Crops.lua
-- Item data for crops harvested from the CropField (see CropData)

local Crops = {
	Wheat = {
		name = "Wheat",
		displayName = "Wheat",
		type = "Crop",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "A bundle of wheat grown on a Crop Field",
		modelPath = "ReplicatedStorage.Assets.Items.Wheat",
	},
	Carrot = {
		name = "Carrot",
		displayName = "Carrot",
		type = "Crop",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "A fresh carrot grown on a Crop Field",
		modelPath = "ReplicatedStorage.Assets.Items.Carrot",
	},
	Melon = {
		name = "Melon",
		displayName = "Melon",
		type = "Crop",
		stackable = true,
		maxStack = 64,
		dropable = true,
		description = "A whole melon grown on a Crop Field",
		modelPath = "ReplicatedStorage.Assets.Items.Melon",
	},
}

return Crops

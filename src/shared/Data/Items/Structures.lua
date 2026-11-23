-- Structures.lua
-- Item data for completed blueprint structures
-- These are the items you get when breaking a completed blueprint

local Structures = {
	CompletedWorkbench = {
		name = "CompletedWorkbench",
		displayName = "Workbench",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "A completed workbench. Place it to use for crafting.",
		modelPath = "Assets.Items.CompletedWorkbench",
		isStructure = true,
		blueprintType = "Workbench",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Workbench",
	},

	CompletedFurnace = {
		name = "CompletedFurnace",
		displayName = "Furnace",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "A completed furnace. Place it to smelt ores.",
		modelPath = "Assets.Items.CompletedFurnace",
		isStructure = true,
		blueprintType = "Furnace",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Furnace",
	},

	CompletedChest = {
		name = "CompletedChest",
		displayName = "Chest",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "A completed chest. Place it to store items.",
		modelPath = "Assets.Items.CompletedChest",
		isStructure = true,
		blueprintType = "Chest",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Chest",
	},

	CompletedBirdNest = {
		name = "CompletedBirdNest",
		displayName = "Bird Nest",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "A completed bird nest. Its bird brings back items every few minutes.",
		modelPath = "Assets.Items.CompletedBirdNest",
		isStructure = true,
		blueprintType = "BirdNest",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.BirdNest",
	},

	CompletedCropField = {
		name = "CompletedCropField",
		displayName = "Crop Field",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "A completed crop field. Plant seeds on it and harvest the crops.",
		modelPath = "Assets.Items.CompletedCropField",
		isStructure = true,
		blueprintType = "CropField",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.CropField",
	},
}

return Structures

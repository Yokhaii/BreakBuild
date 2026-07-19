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
		dropable = true,
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
		dropable = true,
		description = "A completed furnace. Place it to smelt ores.",
		modelPath = "Assets.Items.CompletedFurnace",
		isStructure = true,
		blueprintType = "Furnace",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Furnace",
	},

	CompletedStoneCutter = {
		name = "CompletedStoneCutter",
		displayName = "Stone Cutter",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A completed stone cutter. Place it to cut stone.",
		modelPath = "Assets.Items.CompletedStoneCutter",
		isStructure = true,
		blueprintType = "StoneCutter",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.StoneCutter",
	},

	CompletedLogCutter = {
		name = "CompletedLogCutter",
		displayName = "Log Cutter",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A log cutter. Place it to cut logs into planks.",
		modelPath = "Assets.Items.CompletedLogCutter",
		isStructure = true,
		blueprintType = "LogCutter",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.LogCutter",
	},

	CompletedChest = {
		name = "CompletedChest",
		displayName = "Chest",
		type = "Structure",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A completed chest. Place it to store items.",
		modelPath = "Assets.Items.CompletedChest",
		isStructure = true,
		blueprintType = "Chest",
		placementModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Chest",
	},
}

return Structures

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
}

return Structures

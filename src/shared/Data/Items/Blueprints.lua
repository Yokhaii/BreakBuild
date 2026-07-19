-- Blueprints.lua
-- Item data for blueprint-type items
-- Each blueprint type gets its own item entry

local Blueprints = {
	WorkbenchBlueprint = {
		name = "WorkbenchBlueprint",
		displayName = "Workbench Blueprint",
		type = "Blueprint",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A blueprint for building a Workbench",
		modelPath = "Assets.Items.Blueprint",
		isBlueprintTool = true,
		blueprintType = "Workbench",
	},

	FurnaceBlueprint = {
		name = "FurnaceBlueprint",
		displayName = "Furnace Blueprint",
		type = "Blueprint",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A blueprint for building a Furnace",
		modelPath = "Assets.Items.Blueprint",
		isBlueprintTool = true,
		blueprintType = "Furnace",
	},

	StoneCutterBlueprint = {
		name = "StoneCutterBlueprint",
		displayName = "Stone Cutter Blueprint",
		type = "Blueprint",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A blueprint for building a Stone Cutter",
		modelPath = "Assets.Items.Blueprint",
		isBlueprintTool = true,
		blueprintType = "StoneCutter",
	},

	ChestBlueprint = {
		name = "ChestBlueprint",
		displayName = "Chest Blueprint",
		type = "Blueprint",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A blueprint for building a Chest",
		modelPath = "Assets.Items.Blueprint",
		isBlueprintTool = true,
		blueprintType = "Chest",
	},
}

return Blueprints

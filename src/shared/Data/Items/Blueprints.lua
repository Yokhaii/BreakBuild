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
}

return Blueprints

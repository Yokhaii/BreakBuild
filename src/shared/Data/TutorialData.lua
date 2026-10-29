--[=[
	TutorialData
	Ordered list of onboarding tutorial tasks and the hint texts shown for each sub-step.

	Goal types (evaluated server-side by TutorialService):
	  CollectItem       — own at least `amount` of `itemName`
	  GetBlueprint      — own the "<blueprintType>Blueprint" item (or already have one placed)
	  PlaceBlueprint    — have a `blueprintType` blueprint placed in the BuildingArea
	  CompleteBlueprint — have a completed `blueprintType` (progress = correctly filled slots)

	The other fields of each task are read by TutorialController to build the guidance.
]=]

local TutorialData = {}

TutorialData.Tasks = {
	{
		id = "CollectLogs",
		title = "Collect Logs",
		goal = { type = "CollectItem", itemName = "Log", amount = 4 },
		materialType = "Log",
	},
	{
		id = "GetWorkbenchBlueprint",
		title = "Get the Workbench Blueprint",
		goal = { type = "GetBlueprint", blueprintType = "Workbench" },
		blueprintType = "Workbench",
	},
	{
		id = "PlaceWorkbench",
		title = "Place the Workbench Blueprint",
		goal = { type = "PlaceBlueprint", blueprintType = "Workbench" },
		blueprintType = "Workbench",
	},
	{
		id = "BuildWorkbench",
		title = "Build the Workbench",
		goal = { type = "CompleteBlueprint", blueprintType = "Workbench" },
		blueprintType = "Workbench",
		blockType = "SprucePlank",
		blockRecipeId = "SprucePlank", -- Inventory recipe used to craft the blocks
	},
	{
		id = "CraftPickaxe",
		title = "Craft a Wooden Pickaxe",
		goal = { type = "CollectItem", itemName = "WoodenPickaxe", amount = 1 },
		recipeId = "WoodenPickaxe", -- Station recipe (Workbench)
		ingredientRecipeId = "SprucePlank", -- Inventory recipe used to craft the ingredients
	},
	{
		id = "CollectStone",
		title = "Collect Stone",
		goal = { type = "CollectItem", itemName = "Stone", amount = 4 },
		materialType = "Stone",
		toolCategory = "Pickaxe",
	},
}

-- %s placeholders are filled by TutorialController (recipe / station names)
TutorialData.Hints = {
	CollectLogs = "Break Logs from the trees around you",
	CollectMoreLogs = "Collect more Logs from the trees",
	OpenBlueprintTable = "Go to the Blueprint table and click it",
	SelectBlueprint = "Click the %s blueprint",
	ClickGet = "Click GET to receive the blueprint",
	EquipBlueprint = "Click the blueprint in your hotbar",
	MoveToHotbar = "Move the %s to your hotbar",
	PlaceBlueprint = "Place the blueprint in your Building Area",
	OpenBackpack = "Open your backpack",
	CloseBackpack = "Close your backpack",
	SelectRecipe = "Click the %s recipe",
	SelectRecipeCount = "Click the %s recipe (%d/%d)", -- Add every input to the pool, one click each
	ClickCraft = "Click CRAFT",
	WaitForCraft = "Crafting...",
	EquipBlocks = "Equip your %s",
	FillBlueprint = "Click the blueprint to fill it with your %s",
	OpenStation = "Click your %s",
	EquipTool = "Equip your %s",
	CollectStone = "Break Stone in the Breaking Area",
}

TutorialData.TaskCompletedText = "Task complete: %s"
TutorialData.TutorialCompletedText = "Tutorial complete!"

return TutorialData

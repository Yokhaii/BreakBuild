--[=[
	TutorialData
	Hint texts shown by TutorialController for each sub-step of the tutorial.
	The tutorial tasks themselves are the main objectives flagged `tutorial` in ObjectiveData.
]=]

local TutorialData = {}

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
	CloseObjectives = "Close the Objectives menu",
}

return TutorialData

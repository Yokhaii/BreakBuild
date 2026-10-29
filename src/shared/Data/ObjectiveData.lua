--[=[
	ObjectiveData
	Every objective of the game, evaluated server-side by ObjectiveService.

	MAIN objectives form one ordered chain: only the current one is active, it is always
	shown in the HUD, and completing it moves on to the next. Main objectives flagged `tutorial`
	are guided step by step by TutorialController (beam, spotlight, hints); their extra
	fields (materialType, blueprintType, recipeId...) are read by its resolvers.

	SIDE objectives are broader goals listed in the Objectives frame. They unlock once the
	main objective named in `unlockAfter` is completed (or right away when it is nil).
	The player pins up to MaxPinned of them to the HUD; `autoPin` pins one on unlock if there is room.

	Goal types:
	  Counters (progress only counts while the objective is active, i.e. from its unlock):
	    CollectItem       — gather `amount` of `itemName` from world breakables (trees, Breaking Area)
	    CraftItem         — craft `amount` of `itemName` (any station or the backpack)
	    EarnDollars       — earn `amount` Dollars
	  States (checked against the player's current data):
	    GetBlueprint      — own the "<blueprintType>Blueprint" item (or already have one placed)
	    PlaceBlueprint    — have a `blueprintType` blueprint placed in the BuildingArea
	    CompleteBlueprint — have a completed `blueprintType` (progress = correctly filled slots)

	Display:
	  title        — name shown in the Objectives frame
	  task         — short task text shown in the HUD tracker (e.g. "Collect 4 Logs"), falls back to title
	  description  — longer text shown in the Objectives frame
	  icon         — optional item name whose image is shown next to the task; by default it comes
	                 from the goal (itemName, the blueprint item, or the completed structure)

	Objectives complete by themselves; their rewards wait in the Objectives frame until the
	player clicks CLAIM (a red dot on the HUD title signals unclaimed rewards):
	  rewards = { Dollars = number?, Items = { { itemName, quantity } }? }
]=]

local ObjectiveData = {}

-- Maximum number of side objectives pinned to the HUD (the main objective is always shown)
ObjectiveData.MaxPinned = 3

ObjectiveData.Main = {
	-- Tutorial
	{
		id = "CollectLogs",
		title = "Collect Logs",
		task = "Collect 4 Logs",
		description = "Break Logs from the trees around you.",
		goal = { type = "CollectItem", itemName = "Log", amount = 4 },
		rewards = { Dollars = 10, Items = { { itemName = "Log", quantity = 2 } } },
		tutorial = true,
		materialType = "Log",
	},
	{
		id = "GetWorkbenchBlueprint",
		title = "Get the Workbench Blueprint",
		task = "Get the Workbench Blueprint",
		description = "Grab the Workbench blueprint from the Blueprint table.",
		goal = { type = "GetBlueprint", blueprintType = "Workbench" },
		rewards = { Dollars = 10 },
		tutorial = true,
		blueprintType = "Workbench",
	},
	{
		id = "PlaceWorkbench",
		title = "Place the Workbench Blueprint",
		task = "Place the Workbench Blueprint",
		description = "Place the Workbench blueprint in your Building Area.",
		goal = { type = "PlaceBlueprint", blueprintType = "Workbench" },
		rewards = { Dollars = 10 },
		tutorial = true,
		blueprintType = "Workbench",
	},
	{
		id = "BuildWorkbench",
		title = "Build the Workbench",
		task = "Build the Workbench",
		description = "Fill the Workbench blueprint with Spruce Planks.",
		goal = { type = "CompleteBlueprint", blueprintType = "Workbench" },
		rewards = { Dollars = 25, Items = { { itemName = "SprucePlank", quantity = 4 } } },
		tutorial = true,
		blueprintType = "Workbench",
		blockType = "SprucePlank",
		blockRecipeId = "SprucePlank", -- Inventory recipe used to craft the blocks
	},
	{
		id = "CraftPickaxe",
		title = "Craft a Wooden Pickaxe",
		task = "Craft a Wooden Pickaxe",
		description = "Use your Workbench to craft a Wooden Pickaxe.",
		goal = { type = "CraftItem", itemName = "WoodenPickaxe", amount = 1 },
		rewards = { Dollars = 25 },
		tutorial = true,
		recipeId = "WoodenPickaxe", -- Station recipe (Workbench)
		ingredientRecipeId = "SprucePlank", -- Inventory recipe used to craft the ingredients
	},
	{
		id = "CollectStone",
		title = "Collect Stone",
		task = "Collect 4 Stone",
		description = "Break Stone in the Breaking Area with your pickaxe.",
		goal = { type = "CollectItem", itemName = "Stone", amount = 4 },
		rewards = { Dollars = 50, Items = { { itemName = "Stone", quantity = 2 } } },
		tutorial = true,
		materialType = "Stone",
		toolCategory = "Pickaxe",
	},

	-- Furnace
	{
		id = "CraftHalfStone",
		title = "Craft Half Stone",
		task = "Craft 24 Half Stone",
		description = "Craft Half Stone from Stone in your backpack.",
		goal = { type = "CraftItem", itemName = "HalfStone", amount = 24 },
		rewards = { Dollars = 50 },
	},
	{
		id = "GetFurnaceBlueprint",
		title = "Get the Furnace Blueprint",
		task = "Get the Furnace Blueprint",
		description = "Grab the Furnace blueprint from the Blueprint table.",
		goal = { type = "GetBlueprint", blueprintType = "Furnace" },
		rewards = { Dollars = 25 },
	},
	{
		id = "BuildFurnace",
		title = "Build the Furnace",
		task = "Build the Furnace",
		description = "Place the Furnace blueprint and fill it with Half Stone.",
		goal = { type = "CompleteBlueprint", blueprintType = "Furnace" },
		rewards = { Dollars = 150 },
	},
}

ObjectiveData.Side = {
	{
		id = "Lumberjack1",
		title = "Lumberjack I",
		task = "Collect 25 Logs",
		description = "Collect 25 Logs.",
		goal = { type = "CollectItem", itemName = "Log", amount = 25 },
		rewards = { Dollars = 50 },
		unlockAfter = "CollectLogs",
	},
	{
		id = "Miner1",
		title = "Miner I",
		task = "Collect 50 Stone",
		description = "Collect 50 Stone.",
		goal = { type = "CollectItem", itemName = "Stone", amount = 50 },
		rewards = { Dollars = 100 },
		unlockAfter = "CollectStone",
		autoPin = true,
	},
	{
		id = "StoneToolsmith",
		title = "Stone Age",
		task = "Craft a Stone Pickaxe",
		description = "Craft a Stone Pickaxe.",
		goal = { type = "CraftItem", itemName = "StonePickaxe", amount = 1 },
		rewards = { Dollars = 100 },
		unlockAfter = "CollectStone",
	},
	{
		id = "Lumberjack2",
		title = "Lumberjack II",
		task = "Collect 250 Logs",
		description = "Collect 250 Logs.",
		goal = { type = "CollectItem", itemName = "Log", amount = 250 },
		rewards = { Dollars = 500 },
		unlockAfter = "BuildFurnace",
	},
	{
		id = "Earn1K",
		title = "First Thousand",
		task = "Earn $1,000",
		description = "Earn $1,000.",
		goal = { type = "EarnDollars", amount = 1000 },
		rewards = { Dollars = 100 },
		unlockAfter = "CollectStone",
	},
	{
		id = "Earn100K",
		title = "Entrepreneur",
		task = "Earn $100,000",
		description = "Earn $100,000.",
		goal = { type = "EarnDollars", amount = 100000 },
		rewards = { Dollars = 5000 },
		unlockAfter = "BuildFurnace",
	},
	{
		id = "Earn1M",
		title = "Millionaire",
		task = "Earn $1,000,000",
		description = "Earn $1,000,000.",
		goal = { type = "EarnDollars", amount = 1000000 },
		rewards = { Dollars = 50000 },
		unlockAfter = "BuildFurnace",
	},
}

-- Lookup tables
local byId = {}
local mainIndexById = {}

for index, objective in ipairs(ObjectiveData.Main) do
	objective.isMain = true
	byId[objective.id] = objective
	mainIndexById[objective.id] = index
end

for _, objective in ipairs(ObjectiveData.Side) do
	byId[objective.id] = objective
end

function ObjectiveData.GetObjective(objectiveId: string)
	return byId[objectiveId]
end

-- Index of a main objective in the chain (nil for side objectives)
function ObjectiveData.GetMainIndex(objectiveId: string): number?
	return mainIndexById[objectiveId]
end

-- True once the main objective `objectiveId` is completed, given the player's current main index
function ObjectiveData.IsMainCompleted(objectiveId: string?, mainIndex: number): boolean
	if not objectiveId then return true end
	local index = mainIndexById[objectiveId]
	return index ~= nil and mainIndex > index
end

-- Index of the first main objective after the tutorial
function ObjectiveData.GetFirstNonTutorialIndex(): number
	for index, objective in ipairs(ObjectiveData.Main) do
		if not objective.tutorial then
			return index
		end
	end
	return #ObjectiveData.Main + 1
end

ObjectiveData.Texts = {
	ObjectiveCompleted = "Objective complete: %s",
	TutorialCompleted = "Tutorial complete!",
	RewardClaimed = "+$%s",
	InventoryFull = "Not enough inventory space to claim this reward",
}

return ObjectiveData

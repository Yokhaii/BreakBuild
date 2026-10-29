--[=[
	TutorialService
	Tracks each player's progress through the onboarding tutorial (TutorialData.Tasks).
	A task completes automatically as soon as its goal is met; goals are re-evaluated
	whenever the player's inventory or blueprints change.
	The step-by-step guidance (beam, spotlight, hints) is derived client-side by TutorialController.
]=]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TutorialData = require(ReplicatedStorage.Shared.Data.TutorialData)
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)

-- Services (to be initialized)
local DataService
local InventoryService
local BlueprintService

local TutorialService = Knit.CreateService({
	Name = "TutorialService",
	Client = {
		TutorialUpdated = Knit.CreateSignal(), -- ({ CurrentTask, Completed, Current, Required })
	},
})

-- Constants
local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21

-- Last state sent to each player (serialized), to skip duplicate updates
local lastSentState = {} -- { [Player]: string }

--|| Private Functions ||--

local function countItem(inventory, itemName: string): number
	local total = 0

	for slot = 1, HOTBAR_SIZE do
		local item = inventory.Hotbar[slot]
		if item and item.itemName == itemName then
			total = total + item.quantity
		end
	end

	for slot = 1, BACKPACK_SIZE do
		local item = inventory.Backpack[tostring(slot)]
		if item and item.itemName == itemName then
			total = total + item.quantity
		end
	end

	return total
end

local function getPlacedBlueprints(playerData, blueprintType: string)
	local results = {}
	for _, bpData in ipairs(playerData.Blueprints.PlacedBlueprints) do
		if bpData.blueprintType == blueprintType then
			table.insert(results, bpData)
		end
	end
	return results
end

-- Count the slots of a placed blueprint filled with the correct block type
local function countCorrectFills(bpData, definition): number
	local requiredTypes = {}
	for _, block in ipairs(definition.blocks) do
		local offsetKey = string.format("%d,%d,%d", block.offset.X, block.offset.Y, block.offset.Z)
		requiredTypes[offsetKey] = block.blockType
	end

	local count = 0
	for offsetKey, fill in pairs(bpData.filledBlocks or {}) do
		if requiredTypes[offsetKey] == fill.blockType then
			count = count + 1
		end
	end
	return count
end

-- Returns (current, required) progress for a task goal
local function getGoalProgress(playerData, goal): (number, number)
	local inventory = playerData.Inventory

	if goal.type == "CollectItem" then
		return math.min(countItem(inventory, goal.itemName), goal.amount), goal.amount

	elseif goal.type == "GetBlueprint" then
		local hasItem = countItem(inventory, goal.blueprintType .. "Blueprint") > 0
		local isPlaced = #getPlacedBlueprints(playerData, goal.blueprintType) > 0
		return (hasItem or isPlaced) and 1 or 0, 1

	elseif goal.type == "PlaceBlueprint" then
		return #getPlacedBlueprints(playerData, goal.blueprintType) > 0 and 1 or 0, 1

	elseif goal.type == "CompleteBlueprint" then
		local definition = BlueprintDefinitions.GetDefinition(goal.blueprintType)
		local required = definition and #definition.blocks or 0
		local best = 0
		for _, bpData in ipairs(getPlacedBlueprints(playerData, goal.blueprintType)) do
			if bpData.completedAt and bpData.completedAt > 0 then
				return required, required
			end
			best = math.max(best, countCorrectFills(bpData, definition))
		end
		return best, required
	end

	warn("[TutorialService] Unknown goal type:", goal.type)
	return 0, 1
end

local function buildState(playerData)
	local tutorial = playerData.Tutorial
	local state = {
		CurrentTask = tutorial.CurrentTask,
		Completed = tutorial.Completed,
		Current = 0,
		Required = 0,
	}

	local task = TutorialData.Tasks[tutorial.CurrentTask]
	if task and not tutorial.Completed then
		state.Current, state.Required = getGoalProgress(playerData, task.goal)
	end

	return state
end

local function syncState(self, player: Player, playerData)
	local state = buildState(playerData)
	local serialized = string.format("%d|%s|%d|%d", state.CurrentTask, tostring(state.Completed), state.Current, state.Required)
	if lastSentState[player] == serialized then return end

	lastSentState[player] = serialized
	self.Client.TutorialUpdated:Fire(player, state)
end

-- Players who already played before the tutorial existed skip it
local function hasExistingProgress(playerData): boolean
	if #playerData.Building.PlacedBlocks > 0 or #playerData.Blueprints.PlacedBlueprints > 0 then
		return true
	end
	return next(playerData.Inventory.Hotbar) ~= nil or next(playerData.Inventory.Backpack) ~= nil
end

-- Advance through every task whose goal is already met, then sync the client
local function evaluateTutorial(self, player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return end

	local tutorial = playerData.Tutorial
	if tutorial.CurrentTask >= 1 then
		while not tutorial.Completed do
			local task = TutorialData.Tasks[tutorial.CurrentTask]
			if not task then
				tutorial.Completed = true
				break
			end

			local current, required = getGoalProgress(playerData, task.goal)
			if current < required then break end

			print("[TutorialService]", player.Name, "completed tutorial task:", task.id)
			tutorial.CurrentTask = tutorial.CurrentTask + 1
			if tutorial.CurrentTask > #TutorialData.Tasks then
				tutorial.Completed = true
			end
		end
	end

	syncState(self, player, playerData)
end

local function initializeTutorial(self, player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return end

	local tutorial = playerData.Tutorial
	if tutorial.CurrentTask == 0 and not tutorial.Completed then
		if hasExistingProgress(playerData) then
			tutorial.Completed = true
		else
			tutorial.CurrentTask = 1
		end
	end

	evaluateTutorial(self, player)
end

--|| Client Functions ||--

function TutorialService.Client:GetTutorialState(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return buildState(playerData)
end

--|| KnitStart ||--

function TutorialService:KnitStart()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	BlueprintService = Knit.GetService("BlueprintService")

	InventoryService.InventoryChanged:Connect(function(player)
		evaluateTutorial(self, player)
	end)

	BlueprintService.BlueprintChanged:Connect(function(player)
		evaluateTutorial(self, player)
	end)

	local function onPlayerAdded(player)
		initializeTutorial(self, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSentState[player] = nil
	end)
end

return TutorialService

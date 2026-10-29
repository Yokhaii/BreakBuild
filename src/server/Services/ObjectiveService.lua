--[=[
	ObjectiveService
	Tracks each player's objectives (ObjectiveData): the main chain, side objectives,
	counters, pins and reward claims.

	  - Counter goals (CollectItem, CraftItem, EarnDollars) only progress while the objective
	    is active, from server events (BreakingService, CraftingService, ShopService).
	  - State goals (GetBlueprint, PlaceBlueprint, CompleteBlueprint) are checked against the
	    player's data whenever the inventory or blueprints change.
	  - An objective COMPLETES by itself as soon as its goal is met: the main chain moves on to
	    the next main objective right away (and unlocks the side objectives waiting for it).
	  - Rewards are separate: a completed objective stays claimable in the Objectives frame
	    until the player CLAIMS it.

	The tutorial is the first main objectives (flagged `tutorial`); TutorialController guides them.
]=]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local ObjectiveData = require(ReplicatedStorage.Shared.Data.ObjectiveData)
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local ItemCategorization = require(ReplicatedStorage.Shared.Utils.ItemCategorization)

-- Services (to be initialized)
local DataService
local InventoryService
local BlueprintService
local BreakingService
local CraftingService
local ShopService

local ObjectiveService = Knit.CreateService({
	Name = "ObjectiveService",
	Client = {
		ObjectivesUpdated = Knit.CreateSignal(), -- ({ MainIndex, Progress, Completed, Claimed, Pinned })
		ObjectiveClaimed = Knit.CreateSignal(), -- (objectiveId)
	},
})

-- Constants
local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21

-- Last state sent to each player (serialized), to skip duplicate updates
local lastSentState = {} -- { [Player]: string }

--|| Inventory Helpers ||--

local function countItem(inventory, itemName: string, includeHotbar: boolean?): number
	local total = 0

	if includeHotbar ~= false then
		for slot = 1, HOTBAR_SIZE do
			local item = inventory.Hotbar[slot]
			if item and item.itemName == itemName then
				total = total + item.quantity
			end
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

local function countEmptySlots(inventory): number
	local empty = 0
	for slot = 1, HOTBAR_SIZE do
		if not inventory.Hotbar[slot] then
			empty = empty + 1
		end
	end
	for slot = 1, BACKPACK_SIZE do
		if not inventory.Backpack[tostring(slot)] then
			empty = empty + 1
		end
	end
	return empty
end

-- Stackable rewards merge into an existing stack (as InventoryService:AddItem does), others need a free slot
local function hasSpaceForItems(inventory, items): boolean
	local slotsNeeded = 0
	for _, reward in ipairs(items) do
		local itemConfig = ItemData.GetItem(reward.itemName)
		if itemConfig then
			local searchesHotbar = ItemCategorization.getItemCategory(itemConfig) == "hotbar"
			local hasStack = itemConfig.stackable and countItem(inventory, reward.itemName, searchesHotbar) > 0
			if not hasStack then
				slotsNeeded = slotsNeeded + 1
			end
		end
	end
	return slotsNeeded <= countEmptySlots(inventory)
end

--|| Goal Evaluation ||--

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

local COUNTER_GOALS = {
	CollectItem = true,
	CraftItem = true,
	EarnDollars = true,
}

-- Returns (current, required) progress for an objective
local function getGoalProgress(playerData, objective): (number, number)
	local goal = objective.goal

	if COUNTER_GOALS[goal.type] then
		local current = playerData.Objectives.Progress[objective.id] or 0
		return math.min(current, goal.amount), goal.amount

	elseif goal.type == "GetBlueprint" then
		local hasItem = countItem(playerData.Inventory, goal.blueprintType .. "Blueprint") > 0
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

	warn("[ObjectiveService] Unknown goal type:", goal.type)
	return 0, 1
end

local function isUnlocked(objectives, objective): boolean
	if objective.isMain then
		return ObjectiveData.GetMainIndex(objective.id) <= objectives.MainIndex
	end
	return ObjectiveData.IsMainCompleted(objective.unlockAfter, objectives.MainIndex)
end

-- Active = unlocked and not completed yet: the current main objective + unlocked side ones
local function isActive(objectives, objective): boolean
	return not objectives.Completed[objective.id] and isUnlocked(objectives, objective)
end

local function getActiveObjectives(objectives)
	local active = {}

	local mainObjective = ObjectiveData.Main[objectives.MainIndex]
	if mainObjective and not objectives.Completed[mainObjective.id] then
		table.insert(active, mainObjective)
	end

	for _, objective in ipairs(ObjectiveData.Side) do
		if isActive(objectives, objective) then
			table.insert(active, objective)
		end
	end

	return active
end

--|| State Sync ||--

local function buildState(playerData)
	local objectives = playerData.Objectives
	local progress = {}

	for _, objective in ipairs(getActiveObjectives(objectives)) do
		local current, required = getGoalProgress(playerData, objective)
		progress[objective.id] = { Current = current, Required = required }
	end

	return {
		MainIndex = objectives.MainIndex,
		Progress = progress,
		Completed = objectives.Completed,
		Claimed = objectives.Claimed,
		Pinned = objectives.Pinned,
	}
end

local function syncState(self, player: Player)
	local playerData = DataService:GetData(player)
	if not playerData or playerData.Objectives.MainIndex == 0 then return end

	local state = buildState(playerData)
	local serialized = HttpService:JSONEncode(state)
	if lastSentState[player] == serialized then return end

	lastSentState[player] = serialized
	self.Client.ObjectivesUpdated:Fire(player, state)
end

--|| Pins ||--

local function removePin(objectives, objectiveId: string)
	local index = table.find(objectives.Pinned, objectiveId)
	if index then
		table.remove(objectives.Pinned, index)
	end
end

-- Side objectives can stay pinned from their unlock until they are claimed
local function canBePinned(objectives, objective): boolean
	return not objective.isMain and not objectives.Claimed[objective.id] and isUnlocked(objectives, objective)
end

-- Pin newly unlocked `autoPin` side objectives while there is room (each one only once)
local function applyAutoPins(objectives)
	for _, objective in ipairs(ObjectiveData.Side) do
		if objective.autoPin and not objectives.AutoPinned[objective.id] and isActive(objectives, objective) then
			objectives.AutoPinned[objective.id] = true
			if #objectives.Pinned < ObjectiveData.MaxPinned and not table.find(objectives.Pinned, objective.id) then
				table.insert(objectives.Pinned, objective.id)
			end
		end
	end
end

-- Drop pins that no longer point to a pinnable side objective (removed from data, claimed...)
local function cleanupPins(objectives)
	for index = #objectives.Pinned, 1, -1 do
		local objective = ObjectiveData.GetObjective(objectives.Pinned[index])
		if not objective or not canBePinned(objectives, objective) or index > ObjectiveData.MaxPinned then
			table.remove(objectives.Pinned, index)
		end
	end
end

--|| Evaluation ||--

local function markCompleted(player: Player, objectives, objective)
	objectives.Completed[objective.id] = true
	objectives.Progress[objective.id] = nil
	print("[ObjectiveService]", player.Name, "completed objective:", objective.id)
end

-- Complete every active objective whose goal is met. Main objectives complete one after
-- another (so the tutorial moves on by itself); rewards wait for the player to claim them.
local function evaluateObjectives(self, player: Player)
	local playerData = DataService:GetData(player)
	if not playerData or playerData.Objectives.MainIndex == 0 then return end

	local objectives = playerData.Objectives

	while true do
		local mainObjective = ObjectiveData.Main[objectives.MainIndex]
		if not mainObjective then break end

		if not objectives.Completed[mainObjective.id] then
			local current, required = getGoalProgress(playerData, mainObjective)
			if current < required then break end
			markCompleted(player, objectives, mainObjective)
		end
		objectives.MainIndex = objectives.MainIndex + 1
	end

	for _, objective in ipairs(ObjectiveData.Side) do
		if isActive(objectives, objective) then
			local current, required = getGoalProgress(playerData, objective)
			if current >= required then
				markCompleted(player, objectives, objective)
			end
		end
	end

	applyAutoPins(objectives)
	syncState(self, player)
end

--|| Counters ||--

-- Add `amount` to every active counter objective of `goalType` (matching `itemName` if the goal has one)
local function addCounterProgress(self, player: Player, goalType: string, itemName: string?, amount: number)
	if amount <= 0 then return end

	local playerData = DataService:GetData(player)
	if not playerData or playerData.Objectives.MainIndex == 0 then return end

	local objectives = playerData.Objectives
	local changed = false

	for _, objective in ipairs(getActiveObjectives(objectives)) do
		local goal = objective.goal
		if goal.type == goalType and (goal.itemName == nil or goal.itemName == itemName) then
			local current = objectives.Progress[objective.id] or 0
			if current < goal.amount then
				objectives.Progress[objective.id] = math.min(current + amount, goal.amount)
				changed = true
			end
		end
	end

	if changed then
		evaluateObjectives(self, player)
	end
end

--|| Initialization ||--

-- Players who already played before the objectives existed skip the tutorial
local function hasExistingProgress(playerData): boolean
	if #playerData.Building.PlacedBlocks > 0 or #playerData.Blueprints.PlacedBlueprints > 0 then
		return true
	end
	return next(playerData.Inventory.Hotbar) ~= nil or next(playerData.Inventory.Backpack) ~= nil
end

-- First main objective for a player loading the objectives for the first time
-- (the legacy tutorial tasks map 1:1 to the first main objectives)
local function getStartingMainIndex(playerData): number
	local firstNonTutorial = ObjectiveData.GetFirstNonTutorialIndex()
	local tutorial = playerData.Tutorial

	if tutorial and tutorial.Completed then
		return firstNonTutorial
	elseif tutorial and tutorial.CurrentTask >= 1 then
		return math.min(tutorial.CurrentTask, firstNonTutorial)
	elseif hasExistingProgress(playerData) then
		return firstNonTutorial
	end
	return 1
end

local function initializeObjectives(self, player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return end

	local objectives = playerData.Objectives
	if objectives.MainIndex == 0 then
		objectives.MainIndex = getStartingMainIndex(playerData)
	end

	-- Main objectives skipped by the migration count as done, without rewards
	for index = 1, math.min(objectives.MainIndex - 1, #ObjectiveData.Main) do
		local objective = ObjectiveData.Main[index]
		if not objectives.Completed[objective.id] then
			objectives.Completed[objective.id] = true
			objectives.Claimed[objective.id] = true
		end
	end

	cleanupPins(objectives)
	evaluateObjectives(self, player)
end

--|| Public Functions ||--

function ObjectiveService:ClaimObjective(player: Player, objectiveId: string)
	local playerData = DataService:GetData(player)
	if not playerData then
		return { success = false, reason = "Data not loaded" }
	end

	local objectives = playerData.Objectives
	local objective = ObjectiveData.GetObjective(objectiveId)
	if not objective or not objectives.Completed[objectiveId] then
		return { success = false, reason = "Objective not complete" }
	end
	if objectives.Claimed[objectiveId] then
		return { success = false, reason = "Reward already claimed" }
	end

	local rewards = objective.rewards or {}
	local rewardItems = rewards.Items or {}
	if not hasSpaceForItems(playerData.Inventory, rewardItems) then
		return { success = false, reason = ObjectiveData.Texts.InventoryFull }
	end

	-- Mark claimed first so the rewards' inventory updates already see it
	objectives.Claimed[objectiveId] = true
	removePin(objectives, objectiveId)

	print("[ObjectiveService]", player.Name, "claimed objective:", objectiveId)

	if rewards.Dollars and rewards.Dollars > 0 then
		ShopService:AddDollars(player, rewards.Dollars)
	end
	for _, reward in ipairs(rewardItems) do
		InventoryService:AddItem(player, reward.itemName, reward.quantity)
	end

	self.Client.ObjectiveClaimed:Fire(player, objectiveId)
	syncState(self, player)
	return { success = true }
end

function ObjectiveService:SetPinned(player: Player, objectiveId: string, pinned: boolean)
	local playerData = DataService:GetData(player)
	if not playerData then
		return { success = false, reason = "Data not loaded" }
	end

	local objectives = playerData.Objectives
	local objective = ObjectiveData.GetObjective(objectiveId)
	if not objective or objective.isMain then
		return { success = false, reason = "Only side objectives can be pinned" }
	end

	if pinned then
		if not canBePinned(objectives, objective) then
			return { success = false, reason = "Objective not available" }
		end
		if not table.find(objectives.Pinned, objectiveId) then
			if #objectives.Pinned >= ObjectiveData.MaxPinned then
				return { success = false, reason = "Pinned objectives are full" }
			end
			table.insert(objectives.Pinned, objectiveId)
		end
	else
		removePin(objectives, objectiveId)
	end

	syncState(self, player)
	return { success = true }
end

--|| Client Functions ||--

function ObjectiveService.Client:GetObjectivesState(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData or playerData.Objectives.MainIndex == 0 then return nil end
	return buildState(playerData)
end

function ObjectiveService.Client:ClaimObjective(player: Player, objectiveId: string)
	if type(objectiveId) ~= "string" then
		return { success = false, reason = "Invalid objective" }
	end
	return self.Server:ClaimObjective(player, objectiveId)
end

function ObjectiveService.Client:SetPinned(player: Player, objectiveId: string, pinned: boolean)
	if type(objectiveId) ~= "string" or type(pinned) ~= "boolean" then
		return { success = false, reason = "Invalid objective" }
	end
	return self.Server:SetPinned(player, objectiveId, pinned)
end

--|| KnitStart ||--

function ObjectiveService:KnitStart()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	BlueprintService = Knit.GetService("BlueprintService")
	BreakingService = Knit.GetService("BreakingService")
	CraftingService = Knit.GetService("CraftingService")
	ShopService = Knit.GetService("ShopService")

	-- State goals
	InventoryService.InventoryChanged:Connect(function(player)
		evaluateObjectives(self, player)
	end)

	BlueprintService.BlueprintChanged:Connect(function(player)
		evaluateObjectives(self, player)
	end)

	-- Counter goals (only world breakables count, not the player's own building blocks)
	BreakingService.BreakableDestroyed:Connect(function(player, _breakableId, dropItem, _position, dropAmount, isGlobal)
		if isGlobal and dropItem and dropItem ~= "" then
			addCounterProgress(self, player, "CollectItem", dropItem, dropAmount or 1)
		end
	end)

	CraftingService.ItemCrafted:Connect(function(player, itemName, quantity)
		addCounterProgress(self, player, "CraftItem", itemName, quantity)
	end)

	ShopService.DollarsEarned:Connect(function(player, amount)
		addCounterProgress(self, player, "EarnDollars", nil, amount)
	end)

	local function onPlayerAdded(player)
		initializeObjectives(self, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSentState[player] = nil
	end)
end

return ObjectiveService

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)

local BlueprintService
local InventoryService

local CraftingService = Knit.CreateService({
	Name = "CraftingService",
	Client = {
		SessionStarted = Knit.CreateSignal(),
		SessionEnded = Knit.CreateSignal(),
		CraftStarted = Knit.CreateSignal(),
		CraftCompleted = Knit.CreateSignal(),
		CraftFailed = Knit.CreateSignal(),
	},
})

local CRAFT_COOLDOWN = 0.3

local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21

local sessions = {} -- { [Player]: CraftingSession }
local lastCraftTime = {} -- { [Player]: number }

--|| Private Functions ||--

local function findItemsByName(inventory, itemName: string): (number, {{id: string, quantity: number}})
	local total = 0
	local sources = {}

	for slot = 1, HOTBAR_SIZE do
		local item = inventory.Hotbar[slot]
		if item and item.itemName == itemName then
			total = total + item.quantity
			table.insert(sources, { id = item.id, quantity = item.quantity })
		end
	end

	for slot = 1, BACKPACK_SIZE do
		local item = inventory.Backpack[tostring(slot)]
		if item and item.itemName == itemName then
			total = total + item.quantity
			table.insert(sources, { id = item.id, quantity = item.quantity })
		end
	end

	return total, sources
end

local function hasRequiredInputs(player: Player, recipe): (boolean, string?)
	local inventory = InventoryService:GetInventory(player)
	if not inventory then return false, "Cannot access inventory" end

	for _, input in ipairs(recipe.inputs) do
		local total = findItemsByName(inventory, input.itemName)
		if total < input.quantity then
			return false, string.format("Missing %s (need %d, have %d)", input.itemName, input.quantity, total)
		end
	end

	return true
end

local function removeInputs(player: Player, recipe): boolean
	local inventory = InventoryService:GetInventory(player)
	if not inventory then return false end

	for _, input in ipairs(recipe.inputs) do
		local remaining = input.quantity
		local _, sources = findItemsByName(inventory, input.itemName)

		for _, source in ipairs(sources) do
			if remaining <= 0 then break end
			local toRemove = math.min(remaining, source.quantity)
			InventoryService:RemoveItem(player, source.id, toRemove)
			remaining = remaining - toRemove
		end

		if remaining > 0 then return false end
	end

	return true
end

local function addOutputs(player: Player, recipe): boolean
	for _, output in ipairs(recipe.outputs) do
		local success = InventoryService:AddItem(player, output.itemName, output.quantity)
		if not success then return false end
	end
	return true
end

local function endSession(self, player: Player)
	local session = sessions[player]
	if not session then return end

	if session.craftThread then
		task.cancel(session.craftThread)
		session.craftThread = nil
	end

	sessions[player] = nil
	self.Client.SessionEnded:Fire(player)
end

--|| Public Functions ||--

function CraftingService:StartSession(player: Player, blueprintId: string)
	if sessions[player] then
		endSession(self, player)
	end

	local blueprint = BlueprintService:GetBlueprint(player, blueprintId)
	if not blueprint then
		return { success = false, reason = "Blueprint not found" }
	end

	if not blueprint:CanPlayerUse(player.UserId) then
		return { success = false, reason = "Cannot use this station" }
	end

	local stationType = blueprint.BlueprintType
	local recipes = Recipes.GetRecipesForStation(stationType)

	sessions[player] = {
		blueprintId = blueprintId,
		stationType = stationType,
		startedAt = os.time(),
		craftThread = nil,
	}

	self.Client.SessionStarted:Fire(player, recipes)

	return { success = true, stationType = stationType, recipes = recipes }
end

function CraftingService:EndSession(player: Player)
	endSession(self, player)
end

function CraftingService:CraftItem(player: Player, recipeId: string)
	local session = sessions[player]
	if not session then
		return { success = false, reason = "No active crafting session" }
	end

	local now = os.clock()
	if lastCraftTime[player] and (now - lastCraftTime[player]) < CRAFT_COOLDOWN then
		return { success = false, reason = "Crafting too fast" }
	end
	lastCraftTime[player] = now

	if session.craftThread then
		return { success = false, reason = "Already crafting" }
	end

	local recipe = Recipes.GetRecipe(recipeId)
	if not recipe then
		return { success = false, reason = "Invalid recipe" }
	end

	if recipe.stationType ~= session.stationType then
		return { success = false, reason = "Recipe requires a different station" }
	end

	local blueprint = BlueprintService:GetBlueprint(player, session.blueprintId)
	if not blueprint or not blueprint:CanPlayerUse(player.UserId) then
		endSession(self, player)
		return { success = false, reason = "Station no longer available" }
	end

	local hasInputs, missingReason = hasRequiredInputs(player, recipe)
	if not hasInputs then
		self.Client.CraftFailed:Fire(player, missingReason)
		return { success = false, reason = missingReason }
	end

	local craftTime = recipe.craftTime or 0

	if craftTime <= 0 then
		if not removeInputs(player, recipe) then
			self.Client.CraftFailed:Fire(player, "Failed to consume materials")
			return { success = false, reason = "Failed to consume materials" }
		end
		if not addOutputs(player, recipe) then
			self.Client.CraftFailed:Fire(player, "Inventory full")
			return { success = false, reason = "Inventory full" }
		end
		self.Client.CraftCompleted:Fire(player, recipeId)
		return { success = true }
	end

	self.Client.CraftStarted:Fire(player, recipeId, craftTime)

	session.craftThread = task.delay(craftTime, function()
		local currentSession = sessions[player]
		if not currentSession or currentSession ~= session then return end

		session.craftThread = nil

		local bp = BlueprintService:GetBlueprint(player, session.blueprintId)
		if not bp or not bp:CanPlayerUse(player.UserId) then
			endSession(self, player)
			return
		end

		local stillHasInputs = hasRequiredInputs(player, recipe)
		if not stillHasInputs then
			self.Client.CraftFailed:Fire(player, "Materials no longer available")
			return
		end

		if not removeInputs(player, recipe) then
			self.Client.CraftFailed:Fire(player, "Failed to consume materials")
			return
		end

		if not addOutputs(player, recipe) then
			self.Client.CraftFailed:Fire(player, "Inventory full")
			return
		end

		self.Client.CraftCompleted:Fire(player, recipeId)
	end)

	return { success = true, crafting = true }
end

function CraftingService:GetSession(player: Player)
	return sessions[player]
end

--|| Client Methods ||--

function CraftingService.Client:StartSession(player: Player, blueprintId: string)
	return self.Server:StartSession(player, blueprintId)
end

function CraftingService.Client:EndSession(player: Player)
	return self.Server:EndSession(player)
end

function CraftingService.Client:CraftItem(player: Player, recipeId: string)
	return self.Server:CraftItem(player, recipeId)
end

--|| Lifecycle ||--

function CraftingService:KnitStart()
	BlueprintService = Knit.GetService("BlueprintService")
	InventoryService = Knit.GetService("InventoryService")

	Players.PlayerRemoving:Connect(function(player)
		if sessions[player] then
			sessions[player] = nil
		end
		lastCraftTime[player] = nil
	end)
end

return CraftingService

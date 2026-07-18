local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local BlueprintService
local InventoryService
local DataService

local CraftingService = Knit.CreateService({
	Name = "CraftingService",
	Client = {
		SessionStarted = Knit.CreateSignal(),
		SessionEnded = Knit.CreateSignal(),
		-- (recipeId, totalDuration, elapsed) — elapsed lets client reconstruct progress position
		CraftStarted = Knit.CreateSignal(),
		CraftCompleted = Knit.CreateSignal(),
		CraftFailed = Knit.CreateSignal(),
		-- Fired when the timer finishes but no session is open. (blueprintId, recipeId)
		CraftReady = Knit.CreateSignal(),
	},
})

local CRAFT_COOLDOWN = 0.3
local PROGRESS_TICK = 0.1

local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21

-- Craft execution state — survives UI session open/close.
-- { [Player]: { blueprintId, recipe, qty, startedAt, duration, isReady, craftThread, progressThread } }
local activeCrafts = {}

-- UI session state only — which station the player currently has open.
-- { [Player]: { blueprintId, stationType } }
local sessions = {}

local lastCraftTime = {}

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

local function findFuelByTier(inventory, requiredTier: number): (number, {{id: string, quantity: number, multiplier: number}})
	local effectiveTotal = 0
	local sources = {}

	for slot = 1, HOTBAR_SIZE do
		local item = inventory.Hotbar[slot]
		if item then
			local itemDef = ItemData.GetItem(item.itemName)
			if itemDef and itemDef.fuelValue and itemDef.fuelValue >= requiredTier then
				local multiplier = math.floor(itemDef.fuelValue / requiredTier)
				effectiveTotal = effectiveTotal + (item.quantity * multiplier)
				table.insert(sources, { id = item.id, quantity = item.quantity, multiplier = multiplier })
			end
		end
	end

	for slot = 1, BACKPACK_SIZE do
		local item = inventory.Backpack[tostring(slot)]
		if item then
			local itemDef = ItemData.GetItem(item.itemName)
			if itemDef and itemDef.fuelValue and itemDef.fuelValue >= requiredTier then
				local multiplier = math.floor(itemDef.fuelValue / requiredTier)
				effectiveTotal = effectiveTotal + (item.quantity * multiplier)
				table.insert(sources, { id = item.id, quantity = item.quantity, multiplier = multiplier })
			end
		end
	end

	return effectiveTotal, sources
end

local function hasRequiredInputs(player: Player, recipe, quantity: number): (boolean, string?)
	local inventory = InventoryService:GetInventory(player)
	if not inventory then return false, "Cannot access inventory" end

	for _, input in ipairs(recipe.inputs) do
		local needed = input.quantity * quantity
		if input.fuelTier then
			local total = findFuelByTier(inventory, input.fuelTier)
			if total < needed then
				return false, string.format("Missing Tier %d fuel (need %d, have %d)", input.fuelTier, needed, total)
			end
		else
			local total = findItemsByName(inventory, input.itemName)
			if total < needed then
				return false, string.format("Missing %s (need %d, have %d)", input.itemName, needed, total)
			end
		end
	end

	return true
end

local function removeInputs(player: Player, recipe, quantity: number): boolean
	local inventory = InventoryService:GetInventory(player)
	if not inventory then return false end

	for _, input in ipairs(recipe.inputs) do
		local remaining = input.quantity * quantity

		if input.fuelTier then
			local _, sources = findFuelByTier(inventory, input.fuelTier)
			for _, source in ipairs(sources) do
				if remaining <= 0 then break end
				local effectivePerUnit = source.multiplier
				local unitsNeeded = math.ceil(remaining / effectivePerUnit)
				local toRemove = math.min(unitsNeeded, source.quantity)
				InventoryService:RemoveItem(player, source.id, toRemove)
				remaining = remaining - (toRemove * effectivePerUnit)
			end
		else
			local _, sources = findItemsByName(inventory, input.itemName)
			for _, source in ipairs(sources) do
				if remaining <= 0 then break end
				local toRemove = math.min(remaining, source.quantity)
				InventoryService:RemoveItem(player, source.id, toRemove)
				remaining = remaining - toRemove
			end
		end

		if remaining > 0 then return false end
	end

	return true
end

local function addOutputs(player: Player, recipe, quantity: number): boolean
	for _, output in ipairs(recipe.outputs) do
		local success = InventoryService:AddItem(player, output.itemName, output.quantity * quantity)
		if not success then return false end
	end
	return true
end

local function saveActiveCraft(player: Player, craftData)
	local playerData = DataService:GetData(player)
	if not playerData then return end
	playerData.Crafting.ActiveCraft = craftData
end

local function clearSavedCraft(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return end
	playerData.Crafting.ActiveCraft = {}
end

local startCraftExecution -- forward declaration

-- Deliver a completed craft: consume inputs, give outputs, clean up.
-- Returns true on success, false on failure (with reason string).
local function deliverCraft(self, player: Player, craftEntry): (boolean, string?)
	local recipe = craftEntry.recipe
	local qty = craftEntry.qty
	local blueprintId = craftEntry.blueprintId

	local bp = BlueprintService:GetBlueprint(player, blueprintId)
	if not bp or not bp:CanPlayerUse(player.UserId) then
		return false, "Station no longer available"
	end

	local stillHasInputs, missingReason = hasRequiredInputs(player, recipe, qty)
	if not stillHasInputs then
		return false, missingReason or "Materials no longer available"
	end

	if not removeInputs(player, recipe, qty) then
		return false, "Failed to consume materials"
	end

	if not addOutputs(player, recipe, qty) then
		return false, "Inventory full"
	end

	return true
end

-- Called when the timer fires. If the player has the right session open, deliver
-- immediately. Otherwise mark the craft as ready and wait for them to open it.
local function onTimerExpired(self, player: Player, craftEntry)
	if activeCrafts[player] ~= craftEntry then return end

	-- Stop the progress loop — the bar is now full.
	if craftEntry.progressThread then
		task.cancel(craftEntry.progressThread)
		craftEntry.progressThread = nil
	end
	craftEntry.craftThread = nil

	local session = sessions[player]
	local blueprintOpen = session and session.blueprintId == craftEntry.blueprintId

	if blueprintOpen then
		-- Player is watching — deliver right away.
		local success, reason = deliverCraft(self, player, craftEntry)

		activeCrafts[player] = nil
		clearSavedCraft(player)
		BlueprintService.Client.CraftingProgressCleared:Fire(player, craftEntry.blueprintId)

		if success then
			self.Client.CraftCompleted:Fire(player, craftEntry.recipe.id, craftEntry.blueprintId)
		else
			self.Client.CraftFailed:Fire(player, reason)
		end
	else
		-- Player isn't watching — mark ready, leave billboard frozen at 100%.
		craftEntry.isReady = true
		self.Client.CraftReady:Fire(player, craftEntry.blueprintId, craftEntry.recipe.id)
	end
end

startCraftExecution = function(self, player: Player, blueprintId: string, recipe, qty: number, craftStartedAt: number, craftDuration: number)
	local craftEntry = {
		blueprintId = blueprintId,
		recipe = recipe,
		qty = qty,
		startedAt = craftStartedAt,
		duration = craftDuration,
		isReady = false,
		craftThread = nil,
		progressThread = nil,
	}
	activeCrafts[player] = craftEntry

	-- Progress broadcast loop — keeps billboard alive whether or not the UI is open.
	craftEntry.progressThread = task.spawn(function()
		while true do
			task.wait(PROGRESS_TICK)
			if activeCrafts[player] ~= craftEntry then break end

			local elapsed = os.time() - craftStartedAt
			local progress = math.clamp(elapsed / craftDuration, 0, 1)
			local secsRemaining = math.max(0, craftDuration - elapsed)

			BlueprintService.Client.CraftingProgressUpdated:Fire(player, blueprintId, progress, secsRemaining)

			-- Stop once full — onTimerExpired will handle delivery.
			if progress >= 1 then break end
		end
	end)

	-- Completion timer.
	local remaining = math.max(0, craftDuration - (os.time() - craftStartedAt))
	if remaining <= 0 then
		craftEntry.craftThread = task.spawn(function()
			onTimerExpired(self, player, craftEntry)
		end)
	else
		craftEntry.craftThread = task.delay(remaining, function()
			onTimerExpired(self, player, craftEntry)
		end)
	end
end

--|| Public Functions ||--

-- Called by BlueprintService after LoadPlayerBlueprints so the billboard appears
-- immediately on join without needing the player to open the UI first.
function CraftingService:ResumePlayerCraft(player: Player)
	if activeCrafts[player] then return end

	local playerData = DataService:GetData(player)
	local savedCraft = playerData and playerData.Crafting and playerData.Crafting.ActiveCraft
	if not (savedCraft and savedCraft.blueprintId and savedCraft.recipeId) then return end

	local recipe = Recipes.GetRecipe(savedCraft.recipeId)
	if not recipe then
		clearSavedCraft(player)
		return
	end

	if not BlueprintService:GetBlueprint(player, savedCraft.blueprintId) then
		clearSavedCraft(player)
		return
	end

	local qty = savedCraft.quantity or 1
	startCraftExecution(self, player, savedCraft.blueprintId, recipe, qty, savedCraft.startedAt, savedCraft.duration)
end

function CraftingService:StartSession(player: Player, blueprintId: string)
	if sessions[player] then
		sessions[player] = nil
		self.Client.SessionEnded:Fire(player)
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
	}

	local craft = activeCrafts[player]

	-- Craft is ready (timer expired while UI was closed) — deliver now.
	if craft and craft.blueprintId == blueprintId and craft.isReady then
		local success, reason = deliverCraft(self, player, craft)

		activeCrafts[player] = nil
		clearSavedCraft(player)
		BlueprintService.Client.CraftingProgressCleared:Fire(player, blueprintId)

		if success then
			self.Client.CraftCompleted:Fire(player, craft.recipe.id, blueprintId)
		else
			self.Client.CraftFailed:Fire(player, reason)
		end

	-- Craft is still running — tell client so bar shows the right position.
	elseif craft and craft.blueprintId == blueprintId and not craft.isReady then
		local elapsed = os.time() - craft.startedAt
		self.Client.CraftStarted:Fire(player, craft.recipe.id, craft.duration, elapsed)
	end

	self.Client.SessionStarted:Fire(player, recipes)
	return { success = true, stationType = stationType, recipes = recipes }
end

function CraftingService:EndSession(player: Player)
	if not sessions[player] then return end
	sessions[player] = nil
	self.Client.SessionEnded:Fire(player)
	-- activeCrafts[player] intentionally untouched — craft keeps running / stays ready.
end

function CraftingService:CraftItem(player: Player, recipeId: string, quantity: number?)
	local session = sessions[player]
	if not session then
		return { success = false, reason = "No active crafting session" }
	end

	local now = os.clock()
	if lastCraftTime[player] and (now - lastCraftTime[player]) < CRAFT_COOLDOWN then
		return { success = false, reason = "Crafting too fast" }
	end
	lastCraftTime[player] = now

	if activeCrafts[player] then
		return { success = false, reason = "Already crafting" }
	end

	local qty = math.clamp(math.floor(quantity or 1), 1, 99)

	local recipe = Recipes.GetRecipe(recipeId)
	if not recipe then
		return { success = false, reason = "Invalid recipe" }
	end

	if recipe.stationType ~= session.stationType then
		return { success = false, reason = "Recipe requires a different station" }
	end

	local blueprint = BlueprintService:GetBlueprint(player, session.blueprintId)
	if not blueprint or not blueprint:CanPlayerUse(player.UserId) then
		sessions[player] = nil
		self.Client.SessionEnded:Fire(player)
		return { success = false, reason = "Station no longer available" }
	end

	local hasInputs, missingReason = hasRequiredInputs(player, recipe, qty)
	if not hasInputs then
		self.Client.CraftFailed:Fire(player, missingReason)
		return { success = false, reason = missingReason }
	end

	local craftTime = (recipe.craftTime or 0) * qty

	if craftTime <= 0 then
		if not removeInputs(player, recipe, qty) then
			self.Client.CraftFailed:Fire(player, "Failed to consume materials")
			return { success = false, reason = "Failed to consume materials" }
		end
		if not addOutputs(player, recipe, qty) then
			self.Client.CraftFailed:Fire(player, "Inventory full")
			return { success = false, reason = "Inventory full" }
		end
		self.Client.CraftCompleted:Fire(player, recipeId, session.blueprintId)
		return { success = true }
	end

	local craftStartedAt = os.time()

	saveActiveCraft(player, {
		blueprintId = session.blueprintId,
		recipeId = recipeId,
		quantity = qty,
		startedAt = craftStartedAt,
		duration = craftTime,
	})

	self.Client.CraftStarted:Fire(player, recipeId, craftTime, 0)
	startCraftExecution(self, player, session.blueprintId, recipe, qty, craftStartedAt, craftTime)

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

function CraftingService.Client:CraftItem(player: Player, recipeId: string, quantity: number?)
	return self.Server:CraftItem(player, recipeId, quantity)
end

--|| Lifecycle ||--

function CraftingService:KnitStart()
	BlueprintService = Knit.GetService("BlueprintService")
	InventoryService = Knit.GetService("InventoryService")
	DataService = Knit.GetService("DataService")

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil

		local craft = activeCrafts[player]
		if craft then
			if craft.craftThread then task.cancel(craft.craftThread) end
			if craft.progressThread then task.cancel(craft.progressThread) end
			activeCrafts[player] = nil
		end

		lastCraftTime[player] = nil
	end)
end

return CraftingService

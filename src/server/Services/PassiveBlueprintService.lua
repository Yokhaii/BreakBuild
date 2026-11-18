--[=[
	PassiveBlueprintService
	Completed blueprints whose definition has a `passive` table (BirdNest...) produce
	loot on their own: one roll from `passive.loot` every `passive.interval` seconds.

	- Loot waits in playerData.PassiveBlueprints[blueprintType].Stored (one entry per trip,
	  up to passive.maxStored) until the owner clicks the structure to collect it.
	  Like the Chest, it is kept when the structure is picked up.
	- The timer lives on the placed blueprint (bpData.passiveLastRollAt, os.time()), so
	  offline time counts on rejoin, but time spent picked up does not.
	- While storage is full the timer is paused.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local DataService
local InventoryService
local BlueprintService

local PassiveBlueprintService = Knit.CreateService({
	Name = "PassiveBlueprintService",
	Client = {
		StateUpdated = Knit.CreateSignal(), -- (blueprintId, state)
		ItemsReturned = Knit.CreateSignal(), -- (blueprintId, items, wasOffline)
	},
})

local TICK_INTERVAL = 1

--|| Private Helpers ||--

local function getStorage(player: Player, blueprintType: string)
	local data = DataService:GetData(player)
	if not data then return nil end
	if not data.PassiveBlueprints then
		data.PassiveBlueprints = {}
	end
	if not data.PassiveBlueprints[blueprintType] then
		data.PassiveBlueprints[blueprintType] = { Stored = {} }
	end
	return data.PassiveBlueprints[blueprintType]
end

local function getPlacedBlueprintData(player: Player, blueprintId: string)
	local data = DataService:GetData(player)
	if not data or not data.Blueprints then return nil end
	for _, bpData in ipairs(data.Blueprints.PlacedBlueprints) do
		if bpData.id == blueprintId then
			return bpData
		end
	end
	return nil
end

-- Only placed, completed blueprints with a passive definition that are loaded in the world produce
local function getActivePassive(player: Player, bpData)
	local definition = BlueprintDefinitions.GetDefinition(bpData.blueprintType)
	if not definition or not definition.passive then return nil end
	if not bpData.completedAt or bpData.completedAt <= 0 then return nil end
	if not BlueprintService:GetBlueprint(player, bpData.id) then return nil end
	return definition.passive
end

local function rollLoot(lootTable)
	local totalWeight = 0
	for _, entry in ipairs(lootTable) do
		totalWeight = totalWeight + entry.weight
	end

	local roll = math.random() * totalWeight
	for _, entry in ipairs(lootTable) do
		roll = roll - entry.weight
		if roll <= 0 then
			return {
				itemName = entry.itemName,
				quantity = math.random(entry.min or 1, entry.max or 1),
			}
		end
	end

	local last = lootTable[#lootTable]
	return { itemName = last.itemName, quantity = last.min or 1 }
end

local function buildState(passive, storage, bpData, now: number)
	local stored = #storage.Stored
	local isFull = stored >= passive.maxStored
	local lastRollAt = bpData.passiveLastRollAt or bpData.completedAt
	return {
		stored = stored,
		maxStored = passive.maxStored,
		interval = passive.interval,
		secsRemaining = not isFull and math.max(0, lastRollAt + passive.interval - now) or nil,
	}
end

-- Roll every trip finished since the last roll. Returns the new loot entries
local function produce(passive, storage, bpData, now: number)
	local lastRollAt = bpData.passiveLastRollAt or bpData.completedAt
	local room = passive.maxStored - #storage.Stored

	if room <= 0 then
		-- Full: the bird waits, the next trip starts once the nest is emptied
		bpData.passiveLastRollAt = now
		return {}
	end

	local trips = math.floor((now - lastRollAt) / passive.interval)
	if trips <= 0 then
		bpData.passiveLastRollAt = lastRollAt
		return {}
	end

	local newItems = {}
	for _ = 1, math.min(trips, room) do
		local loot = rollLoot(passive.loot)
		table.insert(storage.Stored, loot)
		table.insert(newItems, loot)
	end

	if trips >= room then
		bpData.passiveLastRollAt = now
	else
		bpData.passiveLastRollAt = lastRollAt + trips * passive.interval
	end

	return newItems
end

--|| Public Functions ||--

function PassiveBlueprintService:GetState(player: Player, blueprintId: string)
	local bpData = getPlacedBlueprintData(player, blueprintId)
	if not bpData then return nil end

	local passive = getActivePassive(player, bpData)
	if not passive then return nil end

	local storage = getStorage(player, bpData.blueprintType)
	if not storage then return nil end

	return buildState(passive, storage, bpData, os.time())
end

-- Give the stored loot to the player. Stops at the first item that does not fit
-- Returns: collectedCount, remainingCount
function PassiveBlueprintService:Collect(player: Player, blueprintId: string)
	local bpData = getPlacedBlueprintData(player, blueprintId)
	if not bpData or bpData.ownerId ~= player.UserId then return 0, 0 end

	local passive = getActivePassive(player, bpData)
	if not passive then return 0, 0 end

	local storage = getStorage(player, bpData.blueprintType)
	if not storage then return 0, 0 end

	local wasFull = #storage.Stored >= passive.maxStored
	local collected = 0
	while #storage.Stored > 0 do
		local loot = storage.Stored[1]
		if not InventoryService:AddItem(player, loot.itemName, loot.quantity) then
			break
		end
		table.remove(storage.Stored, 1)
		collected = collected + 1
	end

	local now = os.time()
	if wasFull and collected > 0 then
		-- The bird leaves again now that there is room
		bpData.passiveLastRollAt = now
	end

	self.Client.StateUpdated:Fire(player, blueprintId, buildState(passive, storage, bpData, now))
	return collected, #storage.Stored
end

--|| Client Functions ||--

function PassiveBlueprintService.Client:GetState(player: Player, blueprintId: string)
	return self.Server:GetState(player, blueprintId)
end

function PassiveBlueprintService.Client:Collect(player: Player, blueprintId: string)
	return self.Server:Collect(player, blueprintId)
end

--|| KnitStart ||--

function PassiveBlueprintService:KnitStart()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	BlueprintService = Knit.GetService("BlueprintService")

	-- Catch typos in loot tables early
	for blueprintType, definition in pairs(BlueprintDefinitions.GetAllDefinitions()) do
		if definition.passive then
			for _, entry in ipairs(definition.passive.loot) do
				if not ItemData.IsValidItem(entry.itemName) then
					warn("[PassiveBlueprintService] Unknown loot item in", blueprintType, ":", entry.itemName)
				end
			end
		end
	end

	-- A nest that just got completed or placed shows its timer right away
	BlueprintService.BlueprintChanged:Connect(function(player, blueprintId)
		local state = self:GetState(player, blueprintId)
		if state then
			self.Client.StateUpdated:Fire(player, blueprintId, state)
		end
	end)

	-- Players whose first tick already ran: everything rolled on the first tick
	-- was produced while they were offline
	local tickedPlayers = {}

	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL)
			local now = os.time()

			for _, player in ipairs(Players:GetPlayers()) do
				-- Read the profile directly: GetData yields until the data is loaded
				local profile = DataService.Profiles[player]
				local data = profile and profile.Data
				if not data or not data.Blueprints then continue end

				local hasLoadedPassive = false
				for _, bpData in ipairs(data.Blueprints.PlacedBlueprints) do
					local passive = getActivePassive(player, bpData)
					if not passive then continue end
					hasLoadedPassive = true

					local storage = getStorage(player, bpData.blueprintType)
					local newItems = produce(passive, storage, bpData, now)
					if #newItems > 0 then
						self.Client.ItemsReturned:Fire(player, bpData.id, newItems, not tickedPlayers[player])
						self.Client.StateUpdated:Fire(player, bpData.id, buildState(passive, storage, bpData, now))
					end
				end

				if hasLoadedPassive then
					tickedPlayers[player] = true
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		tickedPlayers[player] = nil
	end)
end

return PassiveBlueprintService

--[=[
	CropFieldService
	Completed blueprints whose definition has a `plotBlockType` (CropField) grow crops:
	the owner plants the seeds they hold by clicking a free plot, the crop grows through
	its CropData stage models, and any other click on the field harvests every ripe plot.

	- Plots live in playerData.CropFields[blueprintType].Plots, keyed by tostring(plotIndex):
	  { seed = "WheatSeeds", plantedAt = os.time() }. Like the Chest, they are kept when the
	  field is picked up, and crops keep growing while offline or picked up.
	- The server class (Classes/Blueprints/CropField) shows the crop models; this service
	  ticks every second so the models follow the growth stages.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)
local CropData = require(ReplicatedStorage.Shared.Data.CropData)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local DataService
local InventoryService
local BlueprintService

local CropFieldService = Knit.CreateService({
	Name = "CropFieldService",
	Client = {
		StateUpdated = Knit.CreateSignal(), -- (blueprintId, state)
	},
})

local TICK_INTERVAL = 1

--|| Private Helpers ||--

local function getStorage(player: Player, blueprintType: string)
	local data = DataService:GetData(player)
	if not data then return nil end
	if not data.CropFields then
		data.CropFields = {}
	end
	if not data.CropFields[blueprintType] then
		data.CropFields[blueprintType] = { Plots = {} }
	end
	return data.CropFields[blueprintType]
end

-- The loaded, completed crop field instance owned by the player, or nil
local function getField(player: Player, blueprintId: string)
	local field = BlueprintService:GetBlueprint(player, blueprintId)
	if not field or not field.SyncPlots or field.OwnerId ~= player.UserId then return nil end
	if field.CompletedAt <= 0 then return nil end
	return field
end

-- { plots = { [tostring(plotIndex)] = { seed, secsRemaining } } }
local function buildState(storage, now: number)
	local plots = {}
	for key, plot in pairs(storage.Plots) do
		local crop = CropData.GetBySeed(plot.seed)
		if crop then
			plots[key] = {
				seed = plot.seed,
				secsRemaining = math.max(0, plot.plantedAt + crop.growTime - now),
			}
		end
	end
	return { plots = plots }
end

local function isRipe(plot, now: number): boolean
	local crop = CropData.GetBySeed(plot.seed)
	return crop ~= nil and now - plot.plantedAt >= crop.growTime
end

--|| Public Functions ||--

function CropFieldService:GetState(player: Player, blueprintId: string)
	local field = getField(player, blueprintId)
	if not field then return nil end

	local storage = getStorage(player, field.BlueprintType)
	if not storage then return nil end

	return buildState(storage, os.time())
end

-- Plant one of the equipped seeds on plotIndex
-- Returns: success, errorMessage?
function CropFieldService:Plant(player: Player, blueprintId: string, plotIndex: number)
	local field = getField(player, blueprintId)
	if not field then return false, nil end

	local inventory = InventoryService:GetInventory(player)
	local slot = inventory and inventory.EquippedSlot
	local item = slot and slot > 0 and inventory.Hotbar[slot]
	if not item or not CropData.GetBySeed(item.itemName) then
		return false, "Hold seeds to plant them"
	end

	local storage = getStorage(player, field.BlueprintType)
	if not storage then return false, nil end

	if typeof(plotIndex) ~= "number" or plotIndex ~= math.floor(plotIndex)
		or plotIndex < 1 or plotIndex > field:GetPlotCount() then
		return false, nil
	end
	if storage.Plots[tostring(plotIndex)] then
		return false, "This plot is already planted"
	end

	if not InventoryService:RemoveItem(player, item.id, 1) then
		return false, nil
	end

	local now = os.time()
	storage.Plots[tostring(plotIndex)] = { seed = item.itemName, plantedAt = now }
	field:SyncPlots(storage.Plots, now)
	self.Client.StateUpdated:Fire(player, blueprintId, buildState(storage, now))
	return true, nil
end

-- Harvest every ripe plot. Stops at the first harvest that does not fit in the inventory
-- Returns: harvestedCount, message?, inventoryFull
function CropFieldService:Harvest(player: Player, blueprintId: string)
	local field = getField(player, blueprintId)
	if not field then return 0, nil, false end

	local storage = getStorage(player, field.BlueprintType)
	if not storage then return 0, nil, false end

	local now = os.time()
	local harvested = 0
	local message = nil
	local inventoryFull = false
	for plotIndex = 1, field:GetPlotCount() do
		local key = tostring(plotIndex)
		local plot = storage.Plots[key]
		if not plot or not isRipe(plot, now) then continue end

		-- The crop comes first: the plot is cleared once it is given
		local given = 0
		for _, output in ipairs(CropData.GetBySeed(plot.seed).harvest) do
			if not InventoryService:AddItem(player, output.itemName, output.quantity) then
				break
			end
			given = given + 1
		end
		if given == 0 then
			message = "Inventory full!"
			inventoryFull = true
			break
		end

		storage.Plots[key] = nil
		harvested = harvested + 1
	end

	if harvested == 0 and not message then
		message = next(storage.Plots) and "Nothing is ready to harvest yet"
			or "Hold seeds and click a plot to plant them"
	end

	field:SyncPlots(storage.Plots, now)
	self.Client.StateUpdated:Fire(player, blueprintId, buildState(storage, now))
	return harvested, message, inventoryFull
end

--|| Client Functions ||--

function CropFieldService.Client:GetState(player: Player, blueprintId: string)
	return self.Server:GetState(player, blueprintId)
end

function CropFieldService.Client:Plant(player: Player, blueprintId: string, plotIndex: number)
	return self.Server:Plant(player, blueprintId, plotIndex)
end

function CropFieldService.Client:Harvest(player: Player, blueprintId: string)
	return self.Server:Harvest(player, blueprintId)
end

--|| KnitStart ||--

function CropFieldService:KnitStart()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	BlueprintService = Knit.GetService("BlueprintService")

	-- Catch typos in the crop table early
	for seed, crop in pairs(CropData.Crops) do
		for _, itemName in ipairs({ seed, crop.cropName }) do
			if not ItemData.IsValidItem(itemName) then
				warn("[CropFieldService] Unknown item in CropData:", itemName)
			end
		end
	end

	-- A field that just got completed or placed shows its crops right away
	BlueprintService.BlueprintChanged:Connect(function(player, blueprintId)
		local field = getField(player, blueprintId)
		if not field then return end
		local storage = getStorage(player, field.BlueprintType)
		local now = os.time()
		field:SyncPlots(storage.Plots, now)
		self.Client.StateUpdated:Fire(player, blueprintId, buildState(storage, now))
	end)

	-- Move the crop models to their next growth stage
	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL)
			local now = os.time()

			for _, player in ipairs(Players:GetPlayers()) do
				-- Read the profile directly: GetData yields until the data is loaded
				local profile = DataService.Profiles[player]
				local data = profile and profile.Data
				if not data or not data.Blueprints then continue end

				for _, bpData in ipairs(data.Blueprints.PlacedBlueprints) do
					local definition = BlueprintDefinitions.GetDefinition(bpData.blueprintType)
					if not definition or not definition.plotBlockType then continue end

					local field = getField(player, bpData.id)
					if field then
						field:SyncPlots(getStorage(player, bpData.blueprintType).Plots, now)
					end
				end
			end
		end
	end)
end

return CropFieldService

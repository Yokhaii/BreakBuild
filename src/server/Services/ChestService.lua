--[=[
	ChestService
	One chest per player. Items are stored in playerData.Chest.Items and persist
	regardless of which blueprint instance is currently placed.
]=]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local DataService
local InventoryService
local BlueprintService

local ChestService = Knit.CreateService({
	Name = "ChestService",
	Client = {
		ChestUpdated = Knit.CreateSignal(), -- (items)
	},
})

-- { [Player]: blueprintId } — just tracks whether a session is open
local openSessions = {}

--|| Private Helpers ||--

local function getChestData(player: Player)
	local data = DataService:GetData(player)
	if not data then return nil end
	if not data.Chest then
		data.Chest = { Items = {} }
	end
	return data.Chest
end

local function getChestInstance(player: Player, blueprintId: string)
	local blueprints = BlueprintService:GetPlayerBlueprints(player)
	if not blueprints then return nil end
	return blueprints[blueprintId]
end

local function addItem(chestData, itemName: string, quantity: number, itemId: string)
	for _, entry in ipairs(chestData.Items) do
		if entry.itemName == itemName then
			entry.quantity = entry.quantity + quantity
			return
		end
	end
	table.insert(chestData.Items, { id = itemId, itemName = itemName, quantity = quantity })
end

local function removeItem(chestData, itemName: string, quantity: number): number
	local removed = 0
	for i = #chestData.Items, 1, -1 do
		if removed >= quantity then break end
		local entry = chestData.Items[i]
		if entry.itemName == itemName then
			local take = math.min(entry.quantity, quantity - removed)
			entry.quantity = entry.quantity - take
			removed = removed + take
			if entry.quantity <= 0 then
				table.remove(chestData.Items, i)
			end
		end
	end
	return removed
end

--|| Client Functions ||--

function ChestService.Client:OpenChest(player: Player, blueprintId: string)
	return self.Server:OpenChest(player, blueprintId)
end

function ChestService.Client:CloseChest(player: Player)
	return self.Server:CloseChest(player)
end

function ChestService.Client:DepositItem(player: Player, itemId: string, quantity: number)
	return self.Server:DepositItem(player, itemId, quantity)
end

function ChestService.Client:WithdrawItem(player: Player, itemName: string, quantity: number)
	return self.Server:WithdrawItem(player, itemName, quantity)
end

--|| Server Functions ||--

function ChestService:OpenChest(player: Player, blueprintId: string)
	local chest = getChestInstance(player, blueprintId)
	if not chest then
		return { success = false, reason = "Chest not found" }
	end
	if not chest:CanPlayerUse(player.UserId) then
		return { success = false, reason = "Cannot use chest" }
	end

	local chestData = getChestData(player)
	if not chestData then
		return { success = false, reason = "No player data" }
	end

	openSessions[player] = blueprintId
	return { success = true, items = chestData.Items }
end

function ChestService:CloseChest(player: Player)
	openSessions[player] = nil
	return { success = true }
end

function ChestService:DepositItem(player: Player, itemId: string, quantity: number)
	if not openSessions[player] then
		return { success = false, reason = "Chest not open" }
	end

	local inventory = InventoryService:GetInventory(player)
	if not inventory then
		return { success = false, reason = "No inventory" }
	end

	-- Find item name by ID
	local itemName = nil
	for slot = 1, 7 do
		local item = inventory.Hotbar[slot]
		if item and item.id == itemId then
			itemName = item.itemName
			break
		end
	end
	if not itemName then
		for slot = 1, 21 do
			local item = inventory.Backpack[tostring(slot)]
			if item and item.id == itemId then
				itemName = item.itemName
				break
			end
		end
	end
	if not itemName then
		return { success = false, reason = "Item not found in inventory" }
	end

	local removed = InventoryService:RemoveItem(player, itemId, quantity)
	if not removed then
		return { success = false, reason = "Failed to remove from inventory" }
	end

	local chestData = getChestData(player)
	addItem(chestData, itemName, quantity, itemId)

	self.Client.ChestUpdated:Fire(player, chestData.Items)
	return { success = true, items = chestData.Items }
end

function ChestService:WithdrawItem(player: Player, itemName: string, quantity: number)
	if not openSessions[player] then
		return { success = false, reason = "Chest not open" }
	end

	local chestData = getChestData(player)
	if not chestData then
		return { success = false, reason = "No player data" }
	end

	local available = 0
	for _, entry in ipairs(chestData.Items) do
		if entry.itemName == itemName then
			available = available + entry.quantity
		end
	end
	if available < quantity then
		return { success = false, reason = "Not enough in chest" }
	end

	local removed = removeItem(chestData, itemName, quantity)
	if removed == 0 then
		return { success = false, reason = "Failed to remove from chest" }
	end

	local added = InventoryService:AddItem(player, itemName, removed)
	if not added then
		-- Rollback
		addItem(chestData, itemName, removed, tostring(tick()))
		return { success = false, reason = "Inventory full" }
	end

	self.Client.ChestUpdated:Fire(player, chestData.Items)
	return { success = true, items = chestData.Items }
end

--|| Initialization ||--

function ChestService:KnitStart()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	BlueprintService = Knit.GetService("BlueprintService")

	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player)
		openSessions[player] = nil
	end)
end

return ChestService

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ShopData = require(ReplicatedStorage.Shared.Data.ShopData)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local InventoryService
local DataService

local ShopService = Knit.CreateService({
	Name = "ShopService",
	Client = {
		BalanceUpdated = Knit.CreateSignal(),
	},

	-- Server-side: fired whenever a player gains Dollars. (player, amount)
	DollarsEarned = Signal.new(),
})

local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21

local function findItemsByName(inventory, itemName: string): (number, { { id: string, quantity: number } })
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

function ShopService:OpenShop(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then
		return { success = false, reason = "Data not loaded" }
	end

	return { success = true, balance = playerData.Dollars or 0 }
end

function ShopService:BuyItems(player: Player, basket: { [string]: number })
	local playerData = DataService:GetData(player)
	if not playerData then
		return { success = false, reason = "Data not loaded" }
	end

	if type(basket) ~= "table" then
		return { success = false, reason = "Invalid basket" }
	end

	local totalCost = 0
	local validatedItems = {}

	for itemName, quantity in pairs(basket) do
		if type(itemName) ~= "string" or type(quantity) ~= "number" then
			return { success = false, reason = "Invalid basket entry" }
		end

		quantity = math.floor(quantity)
		if quantity <= 0 or quantity > 9999 then
			return { success = false, reason = "Invalid quantity for " .. tostring(itemName) }
		end

		local buyPrice = ShopData.GetBuyPrice(itemName)
		if not buyPrice then
			return { success = false, reason = itemName .. " is not for sale" }
		end

		local itemConfig = ItemData.GetItem(itemName)
		if not itemConfig then
			return { success = false, reason = "Unknown item: " .. tostring(itemName) }
		end

		totalCost = totalCost + (buyPrice * quantity)
		table.insert(validatedItems, { itemName = itemName, quantity = quantity, config = itemConfig })
	end

	if totalCost > (playerData.Dollars or 0) then
		return { success = false, reason = "Not enough Dollars" }
	end

	local inventory = InventoryService:GetInventory(player)
	if not inventory then
		return { success = false, reason = "Cannot access inventory" }
	end

	local slotsNeeded = 0
	for _, entry in ipairs(validatedItems) do
		if entry.config.stackable then
			local existingTotal = findItemsByName(inventory, entry.itemName)
			local maxStack = entry.config.maxStack or 64
			local remaining = entry.quantity
			local freeInExisting = 0

			for slot = 1, HOTBAR_SIZE do
				local item = inventory.Hotbar[slot]
				if item and item.itemName == entry.itemName then
					freeInExisting = freeInExisting + (maxStack - item.quantity)
				end
			end
			for slot = 1, BACKPACK_SIZE do
				local item = inventory.Backpack[tostring(slot)]
				if item and item.itemName == entry.itemName then
					freeInExisting = freeInExisting + (maxStack - item.quantity)
				end
			end

			remaining = remaining - freeInExisting
			if remaining > 0 then
				slotsNeeded = slotsNeeded + math.ceil(remaining / maxStack)
			end
		else
			slotsNeeded = slotsNeeded + entry.quantity
		end
	end

	if slotsNeeded > countEmptySlots(inventory) then
		return { success = false, reason = "Not enough inventory space" }
	end

	playerData.Dollars = (playerData.Dollars or 0) - totalCost

	for _, entry in ipairs(validatedItems) do
		InventoryService:AddItem(player, entry.itemName, entry.quantity)
	end

	self.Client.BalanceUpdated:Fire(player, playerData.Dollars)
	return { success = true, newBalance = playerData.Dollars }
end

function ShopService:SellItems(player: Player, sellPool: { [string]: number })
	local playerData = DataService:GetData(player)
	if not playerData then
		return { success = false, reason = "Data not loaded" }
	end

	if type(sellPool) ~= "table" then
		return { success = false, reason = "Invalid sell pool" }
	end

	local inventory = InventoryService:GetInventory(player)
	if not inventory then
		return { success = false, reason = "Cannot access inventory" }
	end

	local totalValue = 0
	local itemsToRemove = {}

	for itemName, quantity in pairs(sellPool) do
		if type(itemName) ~= "string" or type(quantity) ~= "number" then
			return { success = false, reason = "Invalid sell pool entry" }
		end

		quantity = math.floor(quantity)
		if quantity <= 0 or quantity > 9999 then
			return { success = false, reason = "Invalid quantity for " .. tostring(itemName) }
		end

		local sellPrice = ShopData.GetSellPrice(itemName)
		if not sellPrice then
			return { success = false, reason = itemName .. " cannot be sold" }
		end

		local total, sources = findItemsByName(inventory, itemName)
		if total < quantity then
			return { success = false, reason = "Not enough " .. itemName .. " (have " .. total .. ", need " .. quantity .. ")" }
		end

		totalValue = totalValue + (sellPrice * quantity)
		table.insert(itemsToRemove, { itemName = itemName, quantity = quantity, sources = sources })
	end

	for _, entry in ipairs(itemsToRemove) do
		local remaining = entry.quantity
		for _, source in ipairs(entry.sources) do
			if remaining <= 0 then break end
			local toRemove = math.min(remaining, source.quantity)
			InventoryService:RemoveItem(player, source.id, toRemove)
			remaining = remaining - toRemove
		end
	end

	self:AddDollars(player, totalValue)
	return { success = true, newBalance = playerData.Dollars }
end

-- Give Dollars to a player (sales, objective rewards...)
function ShopService:AddDollars(player: Player, amount: number): boolean
	local playerData = DataService:GetData(player)
	if not playerData or amount <= 0 then return false end

	playerData.Dollars = (playerData.Dollars or 0) + amount

	self.Client.BalanceUpdated:Fire(player, playerData.Dollars)
	self.DollarsEarned:Fire(player, amount)
	return true
end

function ShopService.Client:GetBalance(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return 0 end
	return playerData.Dollars or 0
end

function ShopService.Client:OpenShop(player: Player)
	return self.Server:OpenShop(player)
end

function ShopService.Client:BuyItems(player: Player, basket: { [string]: number })
	return self.Server:BuyItems(player, basket)
end

function ShopService.Client:SellItems(player: Player, sellPool: { [string]: number })
	return self.Server:SellItems(player, sellPool)
end

function ShopService:KnitStart()
	InventoryService = Knit.GetService("InventoryService")
	DataService = Knit.GetService("DataService")

	Players.PlayerRemoving:Connect(function(_player)
	end)
end

return ShopService

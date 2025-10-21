-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

-- Services (to be initialized)
local DataService

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {
		-- Signals for client updates
		InventoryUpdated = Knit.CreateSignal(), -- Fires when inventory changes
		ItemEquipped = Knit.CreateSignal(), -- (slot, itemName)
		ItemUnequipped = Knit.CreateSignal(), -- ()
		ItemDropped = Knit.CreateSignal(), -- (itemName, quantity)
	},
})

-- Constants
local HOTBAR_SIZE = 10
local DROP_DISTANCE = 5 -- Distance in front of player to drop items

-- Types
type InventoryItem = {
	id: string,
	itemName: string,
	quantity: number,
}

-- Private variables
local equippedModels: {[Player]: Model?} = {} -- Currently equipped model instances
local equippedWelds: {[Player]: WeldConstraint?} = {} -- Welds for equipped items

--|| Private Functions ||--

-- Generate unique item ID
local function generateItemId(player: Player): string
	local playerData = DataService:GetData(player)
	if not playerData then return tostring(tick()) end

	local id = string.format("%s_%d", player.UserId, playerData.Inventory.NextItemId)
	playerData.Inventory.NextItemId = playerData.Inventory.NextItemId + 1

	return id
end

-- Get inventory data for player
local function getInventory(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return playerData.Inventory
end

-- Find item in hotbar by ID
local function findInHotbar(inventory, itemId: string): number?
	for slot = 1, HOTBAR_SIZE do
		if inventory.Hotbar[slot] and inventory.Hotbar[slot].id == itemId then
			return slot
		end
	end
	return nil
end

-- Find item in backpack by ID
local function findInBackpack(inventory, itemId: string): number?
	for index, item in ipairs(inventory.Backpack) do
		if item.id == itemId then
			return index
		end
	end
	return nil
end

-- Serialize inventory for network transmission
-- Converts sparse Hotbar array into string-keyed format to prevent data loss
local function serializeInventory(inventory)
	-- Use string keys to avoid sparse array serialization issues
	local serialized = {
		Hotbar = {},
		Backpack = inventory.Backpack, -- Backpack is already an array
		EquippedSlot = inventory.EquippedSlot,
		NextItemId = inventory.NextItemId,
	}

	-- Use string keys like "1", "2", etc. instead of numeric indices
	-- This prevents Roblox network layer from treating it as a sparse array
	for i = 1, HOTBAR_SIZE do
		serialized.Hotbar[tostring(i)] = inventory.Hotbar[i]
	end

	return serialized
end

-- Fire inventory update to client (with proper serialization)
local function fireInventoryUpdate(self, player: Player, inventory)
	local serialized = serializeInventory(inventory)
	self.Client.InventoryUpdated:Fire(player, serialized)
end

-- Create physical dropped item in world
local function createDroppedItem(itemName: string, quantity: number, position: Vector3): Model?
	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig then
		warn("Cannot create dropped item: invalid item", itemName)
		return nil
	end

	-- Navigate to item model
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		warn("Assets folder not found")
		return nil
	end

	-- Parse model path (e.g., "Items.Dirt" -> Assets/Items/Dirt)
	local pathParts = string.split(itemConfig.modelPath, ".")
	local current = assetsFolder
	for _, part in ipairs(pathParts) do
		current = current:FindFirstChild(part)
		if not current then
			warn("Item model not found at path:", itemConfig.modelPath)
			return nil
		end
	end

	if not current:IsA("Model") then
		warn("Item path does not point to a Model:", itemConfig.modelPath)
		return nil
	end

	-- Clone the model
	local droppedModel = current:Clone()
	droppedModel.Name = itemName .. "_Dropped"

	-- Set position
	if droppedModel.PrimaryPart then
		droppedModel:SetPrimaryPartCFrame(CFrame.new(position))
		droppedModel.PrimaryPart.Anchored = false
		droppedModel.PrimaryPart.CanCollide = true
	end

	-- Add quantity value
	local quantityValue = Instance.new("IntValue")
	quantityValue.Name = "Quantity"
	quantityValue.Value = quantity
	quantityValue.Parent = droppedModel

	-- Add item name value
	local itemNameValue = Instance.new("StringValue")
	itemNameValue.Name = "ItemName"
	itemNameValue.Value = itemName
	itemNameValue.Parent = droppedModel

	droppedModel.Parent = workspace

	return droppedModel
end

--|| Public Functions ||--

-- Add item to inventory (tries hotbar first, then backpack)
function InventoryService:AddItem(player: Player, itemName: string, quantity: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig then
		warn("Invalid item name:", itemName)
		return false
	end

	-- If stackable, try to find existing stack
	if itemConfig.stackable then
		-- Check hotbar for existing stack
		for slot = 1, HOTBAR_SIZE do
			if inventory.Hotbar[slot] and inventory.Hotbar[slot].itemName == itemName then
				inventory.Hotbar[slot].quantity = inventory.Hotbar[slot].quantity + quantity
				fireInventoryUpdate(self, player, inventory)
				return true
			end
		end

		-- Check backpack for existing stack
		for _, item in ipairs(inventory.Backpack) do
			if item.itemName == itemName then
				item.quantity = item.quantity + quantity
				fireInventoryUpdate(self, player, inventory)
				return true
			end
		end
	end

	-- No existing stack or not stackable - create new item
	local newItem: InventoryItem = {
		id = generateItemId(player),
		itemName = itemName,
		quantity = quantity,
	}

	-- Try to add to hotbar first
	for slot = 1, HOTBAR_SIZE do
		if not inventory.Hotbar[slot] then
			inventory.Hotbar[slot] = newItem
			fireInventoryUpdate(self, player, inventory)
			return true
		end
	end

	-- Hotbar full, add to backpack
	table.insert(inventory.Backpack, newItem)
	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Remove item from inventory by ID
function InventoryService:RemoveItem(player: Player, itemId: string, quantity: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	-- Check hotbar
	local hotbarSlot = findInHotbar(inventory, itemId)
	if hotbarSlot then
		local item = inventory.Hotbar[hotbarSlot]
		if item.quantity <= quantity then
			-- Remove entire stack
			inventory.Hotbar[hotbarSlot] = nil
		else
			-- Reduce quantity
			item.quantity = item.quantity - quantity
		end
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	-- Check backpack
	local backpackIndex = findInBackpack(inventory, itemId)
	if backpackIndex then
		local item = inventory.Backpack[backpackIndex]
		if item.quantity <= quantity then
			-- Remove entire stack
			table.remove(inventory.Backpack, backpackIndex)
		else
			-- Reduce quantity
			item.quantity = item.quantity - quantity
		end
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	warn("Item not found in inventory:", itemId)
	return false
end

-- Move item from backpack to hotbar
function InventoryService:MoveToHotbar(player: Player, itemId: string, targetSlot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if targetSlot < 1 or targetSlot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", targetSlot)
		return false
	end

	-- Find item in backpack
	local backpackIndex = findInBackpack(inventory, itemId)
	if not backpackIndex then
		warn("Item not found in backpack:", itemId)
		return false
	end

	local item = inventory.Backpack[backpackIndex]

	-- If target slot occupied, swap
	if inventory.Hotbar[targetSlot] then
		local swapItem = inventory.Hotbar[targetSlot]
		inventory.Hotbar[targetSlot] = item
		inventory.Backpack[backpackIndex] = swapItem
	else
		-- Move to empty slot
		inventory.Hotbar[targetSlot] = item
		table.remove(inventory.Backpack, backpackIndex)
	end

	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Move item from hotbar to backpack
function InventoryService:MoveToBackpack(player: Player, slot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if slot < 1 or slot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", slot)
		return false
	end

	local item = inventory.Hotbar[slot]
	if not item then
		warn("No item in hotbar slot:", slot)
		return false
	end

	-- Unequip if this slot is equipped
	if inventory.EquippedSlot == slot then
		self:UnequipItem(player)
	end

	-- Move to backpack
	table.insert(inventory.Backpack, item)
	inventory.Hotbar[slot] = nil

	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Swap two items in inventory
function InventoryService:SwapItems(player: Player, itemId1: string, itemId2: string): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	-- Find both items
	local slot1 = findInHotbar(inventory, itemId1)
	local slot2 = findInHotbar(inventory, itemId2)
	local backpack1 = findInBackpack(inventory, itemId1)
	local backpack2 = findInBackpack(inventory, itemId2)

	-- Hotbar to Hotbar swap
	if slot1 and slot2 then
		local temp = inventory.Hotbar[slot1]
		inventory.Hotbar[slot1] = inventory.Hotbar[slot2]
		inventory.Hotbar[slot2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	-- Backpack to Backpack swap
	if backpack1 and backpack2 then
		local temp = inventory.Backpack[backpack1]
		inventory.Backpack[backpack1] = inventory.Backpack[backpack2]
		inventory.Backpack[backpack2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	-- Hotbar to Backpack swap
	if slot1 and backpack2 then
		local temp = inventory.Hotbar[slot1]
		inventory.Hotbar[slot1] = inventory.Backpack[backpack2]
		inventory.Backpack[backpack2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	-- Backpack to Hotbar swap
	if backpack1 and slot2 then
		local temp = inventory.Backpack[backpack1]
		inventory.Backpack[backpack1] = inventory.Hotbar[slot2]
		inventory.Hotbar[slot2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	warn("Cannot swap items - one or both not found")
	return false
end

-- Move item from one hotbar slot to another (including empty slots)
function InventoryService:MoveHotbarSlot(player: Player, fromSlot: number, toSlot: number): boolean
	local inventory = getInventory(player)
	if not inventory then
		warn("MoveHotbarSlot: No inventory found")
		return false
	end

	if fromSlot < 1 or fromSlot > HOTBAR_SIZE or toSlot < 1 or toSlot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", fromSlot, toSlot)
		return false
	end

	if fromSlot == toSlot then
		return true -- No-op
	end

	local fromItem = inventory.Hotbar[fromSlot]
	if not fromItem then
		warn("No item in source slot:", fromSlot)
		return false
	end

	local toItem = inventory.Hotbar[toSlot]

	-- Unequip if moving from or to equipped slot (handle inline to avoid stale inventory reference)
	if inventory.EquippedSlot == fromSlot or inventory.EquippedSlot == toSlot then
		-- Destroy equipped model and weld
		if equippedModels[player] then
			equippedModels[player]:Destroy()
			equippedModels[player] = nil
		end
		if equippedWelds[player] then
			equippedWelds[player]:Destroy()
			equippedWelds[player] = nil
		end

		inventory.EquippedSlot = nil
	end

	-- Move or swap items
	if toItem then
		-- Swap: put fromItem in toSlot, put toItem in fromSlot
		inventory.Hotbar[toSlot] = fromItem
		inventory.Hotbar[fromSlot] = toItem
	else
		-- Move: put fromItem in toSlot, clear fromSlot
		inventory.Hotbar[toSlot] = fromItem
		inventory.Hotbar[fromSlot] = nil
	end

	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Equip item from hotbar slot
function InventoryService:EquipItem(player: Player, slot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if slot < 1 or slot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", slot)
		return false
	end

	-- Unequip current item if any
	if inventory.EquippedSlot then
		self:UnequipItem(player)
	end

	local item = inventory.Hotbar[slot]
	if not item then
		warn("No item in slot:", slot)
		return false
	end

	local itemConfig = ItemData.GetItem(item.itemName)
	if not itemConfig then
		warn("Invalid item config:", item.itemName)
		return false
	end

	-- Get player character
	local character = player.Character
	if not character then
		warn("Player has no character")
		return false
	end

	local rightHand = character:FindFirstChild("RightHand")
	if not rightHand then
		warn("RightHand not found")
		return false
	end

	local rightGripAttachment = rightHand:FindFirstChild("RightGripAttachment")
	if not rightGripAttachment then
		warn("RightGripAttachment not found")
		return false
	end

	-- Parse model path (e.g., "ReplicatedStorage.Assets.Items.Dirt")
	local pathParts = string.split(itemConfig.modelPath, ".")

	-- Start from ReplicatedStorage
	local current = ReplicatedStorage

	-- Skip first part if it's "ReplicatedStorage" since we already have it
	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then
		startIndex = 2
	end

	-- Traverse the path
	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("Item model not found at path:", itemConfig.modelPath, "- missing:", pathParts[i])
			return false
		end
	end

	if not current:IsA("Model") then
		warn("Item path does not point to a Model:", itemConfig.modelPath)
		return false
	end

	-- Clone and position model
	local itemModel = current:Clone()
	itemModel.Name = item.itemName .. "_Equipped"

	if not itemModel.PrimaryPart then
		warn("Item model has no PrimaryPart")
		itemModel:Destroy()
		return false
	end

	-- Unanchor for welding
	itemModel.PrimaryPart.Anchored = false

	-- Position at grip attachment
	itemModel:SetPrimaryPartCFrame(rightGripAttachment.WorldCFrame)

	-- Create weld
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = itemModel.PrimaryPart
	weld.Parent = itemModel.PrimaryPart

	itemModel.Parent = character

	-- Store equipped state
	inventory.EquippedSlot = slot
	equippedModels[player] = itemModel
	equippedWelds[player] = weld

	-- Notify client
	fireInventoryUpdate(self, player, inventory)
	self.Client.ItemEquipped:Fire(player, slot, item.itemName)

	return true
end

-- Unequip current item
function InventoryService:UnequipItem(player: Player): boolean
	local inventory = getInventory(player)
	if not inventory or not inventory.EquippedSlot then
		return false
	end

	-- Destroy equipped model and weld
	if equippedModels[player] then
		equippedModels[player]:Destroy()
		equippedModels[player] = nil
	end

	if equippedWelds[player] then
		equippedWelds[player]:Destroy()
		equippedWelds[player] = nil
	end

	inventory.EquippedSlot = nil

	-- Notify client
	fireInventoryUpdate(self, player, inventory)
	self.Client.ItemUnequipped:Fire(player)

	return true
end

-- Drop equipped item (called when player presses G)
function InventoryService:DropEquippedItem(player: Player): boolean
	local inventory = getInventory(player)
	if not inventory or not inventory.EquippedSlot then
		warn("No item equipped to drop")
		return false
	end

	local slot = inventory.EquippedSlot
	local item = inventory.Hotbar[slot]
	if not item then return false end

	local itemConfig = ItemData.GetItem(item.itemName)
	if not itemConfig or not itemConfig.dropable then
		warn("Item is not dropable:", item.itemName)
		return false
	end

	-- Get drop position (in front of player)
	local character = player.Character
	if not character or not character.PrimaryPart then
		warn("Cannot get player position")
		return false
	end

	local lookVector = character.PrimaryPart.CFrame.LookVector
	local dropPosition = character.PrimaryPart.Position + (lookVector * DROP_DISTANCE)

	-- Unequip first
	self:UnequipItem(player)

	-- Create dropped item in world
	createDroppedItem(item.itemName, item.quantity, dropPosition)

	-- Remove from inventory
	inventory.Hotbar[slot] = nil

	-- Notify client
	self.Client.ItemDropped:Fire(player, item.itemName, item.quantity)
	fireInventoryUpdate(self, player, inventory)

	return true
end

-- Get player's inventory
function InventoryService:GetInventory(player: Player)
	return getInventory(player)
end

--|| Client Functions ||--

function InventoryService.Client:GetInventory(player: Player)
	return self.Server:GetInventory(player)
end

function InventoryService.Client:MoveToHotbar(player: Player, itemId: string, targetSlot: number)
	return self.Server:MoveToHotbar(player, itemId, targetSlot)
end

function InventoryService.Client:MoveToBackpack(player: Player, slot: number)
	return self.Server:MoveToBackpack(player, slot)
end

function InventoryService.Client:SwapItems(player: Player, itemId1: string, itemId2: string)
	return self.Server:SwapItems(player, itemId1, itemId2)
end

function InventoryService.Client:MoveHotbarSlot(player: Player, fromSlot: number, toSlot: number)
	return self.Server:MoveHotbarSlot(player, fromSlot, toSlot)
end

function InventoryService.Client:EquipItem(player: Player, slot: number)
	return self.Server:EquipItem(player, slot)
end

function InventoryService.Client:UnequipItem(player: Player)
	return self.Server:UnequipItem(player)
end

function InventoryService.Client:DropEquippedItem(player: Player)
	return self.Server:DropEquippedItem(player)
end

-- KNIT START
function InventoryService:KnitStart()
	DataService = Knit.GetService("DataService")

	-- Send initial inventory when player joins
	local function playerAdded(player)
		-- Wait for character and data to load
		player.CharacterAdded:Connect(function()
			task.wait(0.5) -- Small delay to ensure data is loaded
			local inventory = getInventory(player)
			if inventory then
				-- Never load equipped state - always start unequipped
				inventory.EquippedSlot = nil
				fireInventoryUpdate(self, player, inventory)
			end
		end)

		-- Also send if character already exists
		if player.Character then
			task.wait(0.5)
			local inventory = getInventory(player)
			if inventory then
				-- Never load equipped state - always start unequipped
				inventory.EquippedSlot = nil
				fireInventoryUpdate(self, player, inventory)
			end
		end
	end

	Players.PlayerAdded:Connect(playerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		playerAdded(player)
	end

	-- Listen for player leaving to cleanup
	Players.PlayerRemoving:Connect(function(player)
		equippedModels[player] = nil
		equippedWelds[player] = nil
	end)
end

return InventoryService

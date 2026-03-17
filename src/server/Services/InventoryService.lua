-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local ItemCategorization = require(ReplicatedStorage.Shared.Utils.ItemCategorization)

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
		ModeChanged = Knit.CreateSignal(), -- (newMode)
	},
})

-- Constants
local HOTBAR_SIZE = 6 -- Per mode (6 slots each)
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

-- Get the appropriate hotbar based on mode
local function getHotbarForMode(inventory, mode: string)
	if mode == "Break" then
		return inventory.BreakHotbar
	else
		return inventory.BuildHotbar
	end
end

-- Get current mode's hotbar
local function getCurrentHotbar(inventory)
	return getHotbarForMode(inventory, inventory.CurrentMode)
end

-- Ensure Hammer is in Build hotbar slot 1 (permanent tool)
local function ensureHammerInBuildSlot1(inventory)
	-- Check if Hammer is already in BuildHotbar slot 1
	if inventory.BuildHotbar[1] and inventory.BuildHotbar[1].itemName == "Hammer" then
		return -- Already there, nothing to do
	end

	-- Check if Hammer exists elsewhere in BuildHotbar
	local hammerInBuildHotbar = nil
	for slot = 2, HOTBAR_SIZE do
		if inventory.BuildHotbar[slot] and inventory.BuildHotbar[slot].itemName == "Hammer" then
			hammerInBuildHotbar = slot
			break
		end
	end

	-- Check BreakHotbar
	local hammerInBreakHotbar = nil
	for slot = 1, HOTBAR_SIZE do
		if inventory.BreakHotbar[slot] and inventory.BreakHotbar[slot].itemName == "Hammer" then
			hammerInBreakHotbar = slot
			break
		end
	end

	-- Check backpack
	local hammerInBackpack = nil
	for index, item in ipairs(inventory.Backpack) do
		if item.itemName == "Hammer" then
			hammerInBackpack = index
			break
		end
	end

	-- Create Hammer item
	local hammerItem = {
		id = "hammer_permanent",
		itemName = "Hammer",
		quantity = 1,
	}

	-- If Hammer exists elsewhere, remove it
	if hammerInBuildHotbar then
		inventory.BuildHotbar[hammerInBuildHotbar] = nil
	elseif hammerInBreakHotbar then
		inventory.BreakHotbar[hammerInBreakHotbar] = nil
	elseif hammerInBackpack then
		table.remove(inventory.Backpack, hammerInBackpack)
	end

	-- If slot 1 is occupied, move that item to first available slot
	if inventory.BuildHotbar[1] then
		local existingItem = inventory.BuildHotbar[1]

		-- Try to find empty BuildHotbar slot
		local movedToHotbar = false
		for slot = 2, HOTBAR_SIZE do
			if not inventory.BuildHotbar[slot] then
				inventory.BuildHotbar[slot] = existingItem
				movedToHotbar = true
				break
			end
		end

		-- If no empty hotbar slot, move to backpack
		if not movedToHotbar then
			table.insert(inventory.Backpack, existingItem)
		end
	end

	-- Place Hammer in BuildHotbar slot 1
	inventory.BuildHotbar[1] = hammerItem
end

-- Ensure WoodenPickaxe is in Break hotbar slot 1 (starting tool)
local function ensureWoodenPickaxeInBreakSlot1(inventory)
	-- Check if WoodenPickaxe is already in BreakHotbar slot 1
	if inventory.BreakHotbar[1] and inventory.BreakHotbar[1].itemName == "WoodenPickaxe" then
		return -- Already there
	end

	-- Check if WoodenPickaxe exists elsewhere in BreakHotbar
	local pickaxeInBreakHotbar = nil
	for slot = 2, HOTBAR_SIZE do
		if inventory.BreakHotbar[slot] and inventory.BreakHotbar[slot].itemName == "WoodenPickaxe" then
			pickaxeInBreakHotbar = slot
			break
		end
	end

	-- Check BuildHotbar
	local pickaxeInBuildHotbar = nil
	for slot = 1, HOTBAR_SIZE do
		if inventory.BuildHotbar[slot] and inventory.BuildHotbar[slot].itemName == "WoodenPickaxe" then
			pickaxeInBuildHotbar = slot
			break
		end
	end

	-- Check backpack
	local pickaxeInBackpack = nil
	for index, item in ipairs(inventory.Backpack) do
		if item.itemName == "WoodenPickaxe" then
			pickaxeInBackpack = index
			break
		end
	end

	-- If already exists somewhere, move it to BreakHotbar slot 1
	local pickaxeItem = nil
	if pickaxeInBreakHotbar then
		pickaxeItem = inventory.BreakHotbar[pickaxeInBreakHotbar]
		inventory.BreakHotbar[pickaxeInBreakHotbar] = nil
	elseif pickaxeInBuildHotbar then
		pickaxeItem = inventory.BuildHotbar[pickaxeInBuildHotbar]
		inventory.BuildHotbar[pickaxeInBuildHotbar] = nil
	elseif pickaxeInBackpack then
		pickaxeItem = inventory.Backpack[pickaxeInBackpack]
		table.remove(inventory.Backpack, pickaxeInBackpack)
	else
		-- Create new WoodenPickaxe item
		pickaxeItem = {
			id = "woodenpickaxe_starter",
			itemName = "WoodenPickaxe",
			quantity = 1,
		}
	end

	-- If slot 1 is occupied, move that item to first available slot
	if inventory.BreakHotbar[1] then
		local existingItem = inventory.BreakHotbar[1]

		-- Try to find empty BreakHotbar slot
		local movedToHotbar = false
		for slot = 2, HOTBAR_SIZE do
			if not inventory.BreakHotbar[slot] then
				inventory.BreakHotbar[slot] = existingItem
				movedToHotbar = true
				break
			end
		end

		-- If no empty hotbar slot, move to backpack
		if not movedToHotbar then
			table.insert(inventory.Backpack, existingItem)
		end
	end

	-- Place WoodenPickaxe in BreakHotbar slot 1
	inventory.BreakHotbar[1] = pickaxeItem
end

-- Migrate old inventory format to new dual-hotbar format
local function migrateInventory(inventory)
	-- Check if already migrated (has BreakHotbar)
	if inventory.BreakHotbar ~= nil then
		return false -- Already using new format
	end

	-- Initialize new hotbars
	inventory.BreakHotbar = {}
	inventory.BuildHotbar = {}
	inventory.CurrentMode = "Build"

	-- Migrate items from old Hotbar to appropriate new hotbar
	if inventory.Hotbar then
		for slot = 1, 10 do
			local item = inventory.Hotbar[slot]
			if item then
				local itemConfig = ItemData.GetItem(item.itemName)
				local category = ItemCategorization.getItemCategory(itemConfig)

				if category == "break" then
					-- Find first empty Break slot
					for newSlot = 1, HOTBAR_SIZE do
						if not inventory.BreakHotbar[newSlot] then
							inventory.BreakHotbar[newSlot] = item
							break
						end
					end
				elseif category == "build" then
					-- Skip slot 1 for Build (reserved for Hammer) unless it's the Hammer
					local startSlot = (item.itemName == "Hammer") and 1 or 2
					for newSlot = startSlot, HOTBAR_SIZE do
						if not inventory.BuildHotbar[newSlot] then
							inventory.BuildHotbar[newSlot] = item
							break
						end
					end
				else
					-- Move to backpack (ores and uncategorized)
					table.insert(inventory.Backpack, item)
				end
			end
		end

		-- Remove old Hotbar
		inventory.Hotbar = nil
	end

	return true -- Migration performed
end

-- Get inventory data for player
local function getInventory(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return playerData.Inventory
end

-- Find item in current mode's hotbar by ID
local function findInCurrentHotbar(inventory, itemId: string): number?
	local hotbar = getCurrentHotbar(inventory)
	for slot = 1, HOTBAR_SIZE do
		if hotbar[slot] and hotbar[slot].id == itemId then
			return slot
		end
	end
	return nil
end

-- Find item in a specific hotbar by ID
local function findInHotbar(hotbar, itemId: string): number?
	for slot = 1, HOTBAR_SIZE do
		if hotbar[slot] and hotbar[slot].id == itemId then
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
-- Converts sparse Hotbar arrays into string-keyed format to prevent data loss
local function serializeInventory(inventory)
	-- Use string keys to avoid sparse array serialization issues
	local serialized = {
		BreakHotbar = {},
		BuildHotbar = {},
		Backpack = inventory.Backpack, -- Backpack is already an array
		CurrentMode = inventory.CurrentMode,
		EquippedSlot = inventory.EquippedSlot,
		NextItemId = inventory.NextItemId,
	}

	-- Use string keys like "1", "2", etc. instead of numeric indices
	-- This prevents Roblox network layer from treating it as a sparse array
	for i = 1, HOTBAR_SIZE do
		serialized.BreakHotbar[tostring(i)] = inventory.BreakHotbar[i]
		serialized.BuildHotbar[tostring(i)] = inventory.BuildHotbar[i]
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

-- Add item to inventory (routes to correct hotbar based on item category)
function InventoryService:AddItem(player: Player, itemName: string, quantity: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig then
		warn("Invalid item name:", itemName)
		return false
	end

	local category = ItemCategorization.getItemCategory(itemConfig)

	-- Determine target hotbar based on category
	local targetHotbar
	local startSlot = 1

	if category == "break" then
		targetHotbar = inventory.BreakHotbar
	elseif category == "build" then
		targetHotbar = inventory.BuildHotbar
		startSlot = 2 -- Skip slot 1 (reserved for Hammer)
	else
		-- Backpack only (ores and uncategorized)
		targetHotbar = nil
	end

	-- If stackable, try to find existing stack in appropriate hotbar
	if itemConfig.stackable then
		if targetHotbar then
			for slot = startSlot, HOTBAR_SIZE do
				if targetHotbar[slot] and targetHotbar[slot].itemName == itemName then
					targetHotbar[slot].quantity = targetHotbar[slot].quantity + quantity
					fireInventoryUpdate(self, player, inventory)
					return true
				end
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

	-- Try to add to target hotbar first (if applicable)
	if targetHotbar then
		for slot = startSlot, HOTBAR_SIZE do
			if not targetHotbar[slot] then
				targetHotbar[slot] = newItem
				fireInventoryUpdate(self, player, inventory)
				return true
			end
		end
	end

	-- Target hotbar full or backpack-only item, add to backpack
	table.insert(inventory.Backpack, newItem)
	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Remove item from inventory by ID
function InventoryService:RemoveItem(player: Player, itemId: string, quantity: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	-- Check current mode's hotbar
	local currentHotbar = getCurrentHotbar(inventory)
	local hotbarSlot = findInHotbar(currentHotbar, itemId)
	if hotbarSlot then
		local item = currentHotbar[hotbarSlot]
		if item.quantity <= quantity then
			-- Remove entire stack
			currentHotbar[hotbarSlot] = nil
		else
			-- Reduce quantity
			item.quantity = item.quantity - quantity
		end
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	-- Check other hotbar
	local otherHotbar = inventory.CurrentMode == "Break" and inventory.BuildHotbar or inventory.BreakHotbar
	hotbarSlot = findInHotbar(otherHotbar, itemId)
	if hotbarSlot then
		local item = otherHotbar[hotbarSlot]
		if item.quantity <= quantity then
			otherHotbar[hotbarSlot] = nil
		else
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

-- Move item from backpack to current mode's hotbar
function InventoryService:MoveToHotbar(player: Player, itemId: string, targetSlot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if targetSlot < 1 or targetSlot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", targetSlot)
		return false
	end

	-- Prevent moving to Build slot 1 (reserved for Hammer)
	if inventory.CurrentMode == "Build" and targetSlot == 1 then
		warn("Cannot move item to Build slot 1 (reserved for Hammer)")
		return false
	end

	-- Find item in backpack
	local backpackIndex = findInBackpack(inventory, itemId)
	if not backpackIndex then
		warn("Item not found in backpack:", itemId)
		return false
	end

	local item = inventory.Backpack[backpackIndex]

	-- Validate item can be placed in current mode
	local itemConfig = ItemData.GetItem(item.itemName)
	if not ItemCategorization.canPlaceInMode(itemConfig, inventory.CurrentMode) then
		warn("Item cannot be placed in current mode:", item.itemName, inventory.CurrentMode)
		return false
	end

	local currentHotbar = getCurrentHotbar(inventory)

	-- If target slot occupied, swap
	if currentHotbar[targetSlot] then
		local swapItem = currentHotbar[targetSlot]
		currentHotbar[targetSlot] = item
		inventory.Backpack[backpackIndex] = swapItem
	else
		-- Move to empty slot
		currentHotbar[targetSlot] = item
		table.remove(inventory.Backpack, backpackIndex)
	end

	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Move item from current mode's hotbar to backpack
function InventoryService:MoveToBackpack(player: Player, slot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if slot < 1 or slot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", slot)
		return false
	end

	-- Prevent moving Hammer from Build slot 1
	if inventory.CurrentMode == "Build" and slot == 1 then
		warn("Cannot move Hammer from Build slot 1")
		return false
	end

	local currentHotbar = getCurrentHotbar(inventory)
	local item = currentHotbar[slot]
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
	currentHotbar[slot] = nil

	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Swap two items in inventory
function InventoryService:SwapItems(player: Player, itemId1: string, itemId2: string): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	local currentHotbar = getCurrentHotbar(inventory)

	-- Find both items
	local slot1 = findInHotbar(currentHotbar, itemId1)
	local slot2 = findInHotbar(currentHotbar, itemId2)
	local backpack1 = findInBackpack(inventory, itemId1)
	local backpack2 = findInBackpack(inventory, itemId2)

	-- Hotbar to Hotbar swap (within current mode)
	if slot1 and slot2 then
		-- Prevent swapping involving Build slot 1
		if inventory.CurrentMode == "Build" and (slot1 == 1 or slot2 == 1) then
			warn("Cannot swap items involving Build slot 1 (Hammer)")
			return false
		end
		local temp = currentHotbar[slot1]
		currentHotbar[slot1] = currentHotbar[slot2]
		currentHotbar[slot2] = temp
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
		-- Prevent swap involving Build slot 1
		if inventory.CurrentMode == "Build" and slot1 == 1 then
			warn("Cannot swap items involving Build slot 1 (Hammer)")
			return false
		end
		-- Validate backpack item can go into current mode
		local backpackItem = inventory.Backpack[backpack2]
		local itemConfig = ItemData.GetItem(backpackItem.itemName)
		if not ItemCategorization.canPlaceInMode(itemConfig, inventory.CurrentMode) then
			warn("Backpack item cannot be placed in current mode")
			return false
		end
		local temp = currentHotbar[slot1]
		currentHotbar[slot1] = inventory.Backpack[backpack2]
		inventory.Backpack[backpack2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	-- Backpack to Hotbar swap
	if backpack1 and slot2 then
		-- Prevent swap involving Build slot 1
		if inventory.CurrentMode == "Build" and slot2 == 1 then
			warn("Cannot swap items involving Build slot 1 (Hammer)")
			return false
		end
		-- Validate backpack item can go into current mode
		local backpackItem = inventory.Backpack[backpack1]
		local itemConfig = ItemData.GetItem(backpackItem.itemName)
		if not ItemCategorization.canPlaceInMode(itemConfig, inventory.CurrentMode) then
			warn("Backpack item cannot be placed in current mode")
			return false
		end
		local temp = inventory.Backpack[backpack1]
		inventory.Backpack[backpack1] = currentHotbar[slot2]
		currentHotbar[slot2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	warn("Cannot swap items - one or both not found")
	return false
end

-- Move item from one hotbar slot to another (within current mode)
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

	-- Prevent moving from/to Build slot 1 (Hammer is locked)
	if inventory.CurrentMode == "Build" then
		if fromSlot == 1 or toSlot == 1 then
			warn("Cannot move items to/from Build slot 1 (Hammer slot)")
			return false
		end
	end

	local currentHotbar = getCurrentHotbar(inventory)
	local fromItem = currentHotbar[fromSlot]
	if not fromItem then
		warn("No item in source slot:", fromSlot)
		return false
	end

	local toItem = currentHotbar[toSlot]

	-- Unequip if moving from or to equipped slot
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
		currentHotbar[toSlot] = fromItem
		currentHotbar[fromSlot] = toItem
	else
		-- Move: put fromItem in toSlot, clear fromSlot
		currentHotbar[toSlot] = fromItem
		currentHotbar[fromSlot] = nil
	end

	fireInventoryUpdate(self, player, inventory)
	return true
end

-- Equip item from current mode's hotbar slot
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

	local currentHotbar = getCurrentHotbar(inventory)
	local item = currentHotbar[slot]
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

-- Switch between Break and Build modes
function InventoryService:SwitchMode(player: Player): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	-- 1. Unequip current item
	if inventory.EquippedSlot then
		self:UnequipItem(player)
	end

	-- 2. Toggle mode
	local newMode = inventory.CurrentMode == "Break" and "Build" or "Break"
	inventory.CurrentMode = newMode

	-- 3. Auto-equip slot 1 of new mode (if item exists there)
	local newHotbar = getHotbarForMode(inventory, newMode)
	if newHotbar[1] then
		self:EquipItem(player, 1)
	end

	-- 4. Notify client
	fireInventoryUpdate(self, player, inventory)
	self.Client.ModeChanged:Fire(player, newMode)

	return true
end

-- Get current mode
function InventoryService:GetCurrentMode(player: Player): string?
	local inventory = getInventory(player)
	return inventory and inventory.CurrentMode or nil
end

-- Drop equipped item (called when player presses G)
function InventoryService:DropEquippedItem(player: Player): boolean
	local inventory = getInventory(player)
	if not inventory or not inventory.EquippedSlot then
		warn("No item equipped to drop")
		return false
	end

	local slot = inventory.EquippedSlot
	local currentHotbar = getCurrentHotbar(inventory)
	local item = currentHotbar[slot]
	if not item then return false end

	local itemConfig = ItemData.GetItem(item.itemName)
	if not itemConfig or not itemConfig.dropable then
		warn("Item is not dropable:", item.itemName)
		return false
	end

	-- Prevent dropping Hammer from Build mode slot 1
	if inventory.CurrentMode == "Build" and slot == 1 then
		warn("Cannot drop Hammer")
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
	currentHotbar[slot] = nil

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

function InventoryService.Client:SwitchMode(player: Player)
	return self.Server:SwitchMode(player)
end

function InventoryService.Client:GetCurrentMode(player: Player)
	return self.Server:GetCurrentMode(player)
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
				-- Migrate old format if needed
				local migrated = migrateInventory(inventory)
				if migrated then
					print("[InventoryService] Migrated inventory for", player.Name)
				end

				-- Ensure starter tools
				ensureHammerInBuildSlot1(inventory)
				ensureWoodenPickaxeInBreakSlot1(inventory)

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
				-- Migrate old format if needed
				local migrated = migrateInventory(inventory)
				if migrated then
					print("[InventoryService] Migrated inventory for", player.Name)
				end

				-- Ensure starter tools
				ensureHammerInBuildSlot1(inventory)
				ensureWoodenPickaxeInBreakSlot1(inventory)

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

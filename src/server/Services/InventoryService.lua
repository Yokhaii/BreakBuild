-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local ItemCategorization = require(ReplicatedStorage.Shared.Utils.ItemCategorization)

-- Services (to be initialized)
local DataService

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {
		InventoryUpdated = Knit.CreateSignal(),
		ItemEquipped = Knit.CreateSignal(),
		ItemUnequipped = Knit.CreateSignal(),
		ItemDropped = Knit.CreateSignal(),
	},
})

-- Constants
local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21
local DROP_DISTANCE = 5

-- Types
type InventoryItem = {
	id: string,
	itemName: string,
	quantity: number,
}

-- Private variables
local equippedModels: {[Player]: Model?} = {}
local equippedWelds: {[Player]: WeldConstraint?} = {}

--|| Private Functions ||--

-- Backpack uses string keys for JSON-safe persistence
local function bpKey(slot: number): string
	return tostring(slot)
end

local function bpGet(backpack, slot: number)
	return backpack[bpKey(slot)]
end

local function bpSet(backpack, slot: number, item)
	backpack[bpKey(slot)] = item
end

local function generateItemId(player: Player): string
	local playerData = DataService:GetData(player)
	if not playerData then return tostring(tick()) end

	local id = string.format("%s_%d", player.UserId, playerData.Inventory.NextItemId)
	playerData.Inventory.NextItemId = playerData.Inventory.NextItemId + 1

	return id
end

-- Migrate old formats to string-keyed backpack
local function migrateBackpack(inventory)
	local oldBackpack = inventory.Backpack
	if not oldBackpack then
		inventory.Backpack = {}
		return
	end

	-- Check if empty
	if next(oldBackpack) == nil then
		return
	end

	-- Check what kind of keys we have
	local hasNumericKeys = false
	local hasStringKeys = false
	for key, _ in pairs(oldBackpack) do
		if type(key) == "number" then
			hasNumericKeys = true
		elseif type(key) == "string" then
			hasStringKeys = true
		end
	end

	-- Already string-keyed — no migration needed
	if hasStringKeys and not hasNumericKeys then
		return
	end

	-- Has numeric keys — migrate to string keys
	local newBackpack = {}
	for i = 1, BACKPACK_SIZE do
		if oldBackpack[i] then
			newBackpack[bpKey(i)] = oldBackpack[i]
		end
	end
	inventory.Backpack = newBackpack
end

-- Migrate old dual-hotbar format to unified hotbar
local function migrateToUnifiedHotbar(inventory)
	if not inventory.BreakHotbar then
		return false
	end

	local items = {}

	for slot = 1, HOTBAR_SIZE do
		local item = inventory.BreakHotbar[slot]
		if item then
			table.insert(items, item)
		end
	end

	for slot = 2, HOTBAR_SIZE do
		local item = inventory.BuildHotbar[slot]
		if item then
			table.insert(items, item)
		end
	end

	inventory.Hotbar = {}
	for i = 1, math.min(#items, HOTBAR_SIZE) do
		inventory.Hotbar[i] = items[i]
	end

	-- Overflow to Backpack
	inventory.Backpack = {}
	local backpackSlot = 1
	for i = HOTBAR_SIZE + 1, #items do
		if backpackSlot <= BACKPACK_SIZE then
			bpSet(inventory.Backpack, backpackSlot, items[i])
			backpackSlot = backpackSlot + 1
		end
	end

	inventory.BreakHotbar = nil
	inventory.BuildHotbar = nil
	inventory.CurrentMode = nil

	return true
end

local function cleanupInvalidItems(inventory)
	local removedCount = 0

	for slot = 1, HOTBAR_SIZE do
		local item = inventory.Hotbar[slot]
		if item and not ItemData.GetItem(item.itemName) then
			inventory.Hotbar[slot] = nil
			removedCount = removedCount + 1
		end
	end

	for slot = 1, BACKPACK_SIZE do
		local item = bpGet(inventory.Backpack, slot)
		if item and not ItemData.GetItem(item.itemName) then
			bpSet(inventory.Backpack, slot, nil)
			removedCount = removedCount + 1
		end
	end

	return removedCount
end

local function findFirstEmptyBackpackSlot(inventory): number?
	for slot = 1, BACKPACK_SIZE do
		if not bpGet(inventory.Backpack, slot) then
			return slot
		end
	end
	return nil
end

local function ensureStarterPickaxe(inventory)
	for slot = 1, HOTBAR_SIZE do
		if inventory.Hotbar[slot] and inventory.Hotbar[slot].itemName == "WoodenPickaxe" then
			return
		end
	end
	for slot = 1, BACKPACK_SIZE do
		if bpGet(inventory.Backpack, slot) and bpGet(inventory.Backpack, slot).itemName == "WoodenPickaxe" then
			return
		end
	end

	local pickaxeItem = {
		id = "woodenpickaxe_starter",
		itemName = "WoodenPickaxe",
		quantity = 1,
	}

	for slot = 1, HOTBAR_SIZE do
		if not inventory.Hotbar[slot] then
			inventory.Hotbar[slot] = pickaxeItem
			return
		end
	end

	local emptySlot = findFirstEmptyBackpackSlot(inventory)
	if emptySlot then
		bpSet(inventory.Backpack, emptySlot, pickaxeItem)
	end
end

local function removeHammerFromInventory(inventory)
	for slot = 1, HOTBAR_SIZE do
		if inventory.Hotbar[slot] and inventory.Hotbar[slot].itemName == "Hammer" then
			inventory.Hotbar[slot] = nil
		end
	end

	for slot = 1, BACKPACK_SIZE do
		if bpGet(inventory.Backpack, slot) and bpGet(inventory.Backpack, slot).itemName == "Hammer" then
			bpSet(inventory.Backpack, slot, nil)
		end
	end
end

local function getInventory(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return playerData.Inventory
end

local function findInHotbar(hotbar, itemId: string): number?
	for slot = 1, HOTBAR_SIZE do
		if hotbar[slot] and hotbar[slot].id == itemId then
			return slot
		end
	end
	return nil
end

local function findInBackpack(inventory, itemId: string): number?
	for slot = 1, BACKPACK_SIZE do
		local item = bpGet(inventory.Backpack, slot)
		if item and item.id == itemId then
			return slot
		end
	end
	return nil
end

-- Serialize inventory for network transmission
local function serializeInventory(inventory)
	local serialized = {
		Hotbar = {},
		Backpack = {},
		EquippedSlot = inventory.EquippedSlot,
		NextItemId = inventory.NextItemId,
	}

	for i = 1, HOTBAR_SIZE do
		serialized.Hotbar[tostring(i)] = inventory.Hotbar[i]
	end

	for i = 1, BACKPACK_SIZE do
		serialized.Backpack[tostring(i)] = bpGet(inventory.Backpack, i)
	end

	return serialized
end

local function fireInventoryUpdate(self, player: Player, inventory)
	local serialized = serializeInventory(inventory)
	self.Client.InventoryUpdated:Fire(player, serialized)
end

-- Check if player is inside their BuildingArea
local function isPlayerInBuildingArea(player: Player): boolean
	local character = player.Character
	if not character or not character.PrimaryPart then
		return false
	end

	local buildingZone = workspace:FindFirstChild("BuildingZone")
	if not buildingZone then return false end

	local buildingArea = buildingZone:FindFirstChild("BuildingArea")
	if not buildingArea then return false end

	local areaPosition = buildingArea.Position
	local halfSize = buildingArea.Size / 2
	local playerPosition = character.PrimaryPart.Position

	return math.abs(playerPosition.X - areaPosition.X) <= halfSize.X
		and math.abs(playerPosition.Y - areaPosition.Y) <= halfSize.Y
		and math.abs(playerPosition.Z - areaPosition.Z) <= halfSize.Z
end

local function createDroppedItem(itemName: string, quantity: number, position: Vector3): Model?
	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig then
		warn("Cannot create dropped item: invalid item", itemName)
		return nil
	end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		warn("Assets folder not found")
		return nil
	end

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

	local droppedModel = current:Clone()
	droppedModel.Name = itemName .. "_Dropped"

	if droppedModel.PrimaryPart then
		droppedModel:SetPrimaryPartCFrame(CFrame.new(position))
		droppedModel.PrimaryPart.Anchored = false
		droppedModel.PrimaryPart.CanCollide = true
	end

	local quantityValue = Instance.new("IntValue")
	quantityValue.Name = "Quantity"
	quantityValue.Value = quantity
	quantityValue.Parent = droppedModel

	local itemNameValue = Instance.new("StringValue")
	itemNameValue.Name = "ItemName"
	itemNameValue.Value = itemName
	itemNameValue.Parent = droppedModel

	droppedModel.Parent = workspace

	return droppedModel
end

--|| Public Functions ||--

function InventoryService:AddItem(player: Player, itemName: string, quantity: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig then
		warn("Invalid item name:", itemName)
		return false
	end

	local category = ItemCategorization.getItemCategory(itemConfig)
	local targetHotbar = category == "hotbar" and inventory.Hotbar or nil

	-- If stackable, try to find existing stack
	if itemConfig.stackable then
		if targetHotbar then
			for slot = 1, HOTBAR_SIZE do
				if targetHotbar[slot] and targetHotbar[slot].itemName == itemName then
					targetHotbar[slot].quantity = targetHotbar[slot].quantity + quantity
					fireInventoryUpdate(self, player, inventory)
					return true
				end
			end
		end

		for slot = 1, BACKPACK_SIZE do
			local item = bpGet(inventory.Backpack, slot)
			if item and item.itemName == itemName then
				item.quantity = item.quantity + quantity
				fireInventoryUpdate(self, player, inventory)
				return true
			end
		end
	end

	-- Create new item
	local newItem: InventoryItem = {
		id = generateItemId(player),
		itemName = itemName,
		quantity = quantity,
	}

	-- Try hotbar first
	if targetHotbar then
		for slot = 1, HOTBAR_SIZE do
			if not targetHotbar[slot] then
				targetHotbar[slot] = newItem
				fireInventoryUpdate(self, player, inventory)
				return true
			end
		end
	end

	-- Hotbar full or backpack-only item
	local emptySlot = findFirstEmptyBackpackSlot(inventory)
	if emptySlot then
		bpSet(inventory.Backpack, emptySlot, newItem)
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	warn("Inventory full, cannot add item:", itemName)
	return false
end

function InventoryService:AddBlueprintItem(player: Player, blueprintType: string): boolean
	local itemName = blueprintType .. "Blueprint"
	return self:AddItem(player, itemName, 1)
end

function InventoryService:RemoveItem(player: Player, itemId: string, quantity: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	-- Check hotbar
	local hotbarSlot = findInHotbar(inventory.Hotbar, itemId)
	if hotbarSlot then
		local item = inventory.Hotbar[hotbarSlot]
		if item.quantity <= quantity then
			inventory.Hotbar[hotbarSlot] = nil
		else
			item.quantity = item.quantity - quantity
		end
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	-- Check backpack
	local backpackSlot = findInBackpack(inventory, itemId)
	if backpackSlot then
		local item = bpGet(inventory.Backpack, backpackSlot)
		if item.quantity <= quantity then
			bpSet(inventory.Backpack, backpackSlot, nil)
		else
			item.quantity = item.quantity - quantity
		end
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	warn("Item not found in inventory:", itemId)
	return false
end

function InventoryService:MoveToHotbar(player: Player, itemId: string, targetSlot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if targetSlot < 1 or targetSlot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", targetSlot)
		return false
	end

	local backpackSlot = findInBackpack(inventory, itemId)
	if not backpackSlot then
		warn("Item not found in backpack:", itemId)
		return false
	end

	local item = bpGet(inventory.Backpack, backpackSlot)

	if inventory.Hotbar[targetSlot] then
		local swapItem = inventory.Hotbar[targetSlot]
		inventory.Hotbar[targetSlot] = item
		bpSet(inventory.Backpack, backpackSlot, swapItem)
	else
		inventory.Hotbar[targetSlot] = item
		bpSet(inventory.Backpack, backpackSlot, nil)
	end

	fireInventoryUpdate(self, player, inventory)
	return true
end

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

	if inventory.EquippedSlot == slot then
		self:UnequipItem(player)
	end

	local emptySlot = findFirstEmptyBackpackSlot(inventory)
	if not emptySlot then
		warn("Backpack full, cannot move item")
		return false
	end

	bpSet(inventory.Backpack, emptySlot, item)
	inventory.Hotbar[slot] = nil

	fireInventoryUpdate(self, player, inventory)
	return true
end

function InventoryService:SwapItems(player: Player, itemId1: string, itemId2: string): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	local slot1 = findInHotbar(inventory.Hotbar, itemId1)
	local slot2 = findInHotbar(inventory.Hotbar, itemId2)
	local backpack1 = findInBackpack(inventory, itemId1)
	local backpack2 = findInBackpack(inventory, itemId2)

	if slot1 and slot2 then
		local temp = inventory.Hotbar[slot1]
		inventory.Hotbar[slot1] = inventory.Hotbar[slot2]
		inventory.Hotbar[slot2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	if backpack1 and backpack2 then
		local temp = bpGet(inventory.Backpack, backpack1)
		bpSet(inventory.Backpack, backpack1, bpGet(inventory.Backpack, backpack2))
		bpSet(inventory.Backpack, backpack2, temp)
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	if slot1 and backpack2 then
		local temp = inventory.Hotbar[slot1]
		inventory.Hotbar[slot1] = bpGet(inventory.Backpack, backpack2)
		bpSet(inventory.Backpack, backpack2, temp)
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	if backpack1 and slot2 then
		local temp = bpGet(inventory.Backpack, backpack1)
		bpSet(inventory.Backpack, backpack1, inventory.Hotbar[slot2])
		inventory.Hotbar[slot2] = temp
		fireInventoryUpdate(self, player, inventory)
		return true
	end

	warn("Cannot swap items - one or both not found")
	return false
end

function InventoryService:MoveHotbarSlot(player: Player, fromSlot: number, toSlot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if fromSlot < 1 or fromSlot > HOTBAR_SIZE or toSlot < 1 or toSlot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", fromSlot, toSlot)
		return false
	end

	if fromSlot == toSlot then
		return true
	end

	local fromItem = inventory.Hotbar[fromSlot]
	if not fromItem then
		warn("No item in source slot:", fromSlot)
		return false
	end

	if inventory.EquippedSlot == fromSlot or inventory.EquippedSlot == toSlot then
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

	local toItem = inventory.Hotbar[toSlot]
	if toItem then
		inventory.Hotbar[toSlot] = fromItem
		inventory.Hotbar[fromSlot] = toItem
	else
		inventory.Hotbar[toSlot] = fromItem
		inventory.Hotbar[fromSlot] = nil
	end

	fireInventoryUpdate(self, player, inventory)
	return true
end

function InventoryService:EquipItem(player: Player, slot: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	-- Hammer slot (contextual)
	if slot == 0 then
		if not isPlayerInBuildingArea(player) then
			warn("Cannot equip Hammer outside BuildingArea")
			return false
		end

		if inventory.EquippedSlot then
			self:UnequipItem(player)
		end

		local itemConfig = ItemData.GetItem("Hammer")
		if not itemConfig then return false end

		local character = player.Character
		if not character then return false end

		local rightHand = character:FindFirstChild("RightHand")
		if not rightHand then return false end

		local rightGripAttachment = rightHand:FindFirstChild("RightGripAttachment")
		if not rightGripAttachment then return false end

		local pathParts = string.split(itemConfig.modelPath, ".")
		local current = ReplicatedStorage
		local startIndex = pathParts[1] == "ReplicatedStorage" and 2 or 1
		for i = startIndex, #pathParts do
			current = current:FindFirstChild(pathParts[i])
			if not current then return false end
		end

		if not current:IsA("Model") then return false end

		local itemModel = current:Clone()
		itemModel.Name = "Hammer_Equipped"
		if not itemModel.PrimaryPart then
			itemModel:Destroy()
			return false
		end

		itemModel.PrimaryPart.Anchored = false
		itemModel:SetPrimaryPartCFrame(rightGripAttachment.WorldCFrame)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rightHand
		weld.Part1 = itemModel.PrimaryPart
		weld.Parent = itemModel.PrimaryPart

		itemModel.Parent = character

		inventory.EquippedSlot = 0
		equippedModels[player] = itemModel
		equippedWelds[player] = weld

		fireInventoryUpdate(self, player, inventory)
		self.Client.ItemEquipped:Fire(player, 0, "Hammer")

		return true
	end

	-- Regular slots (1-7)
	if slot < 1 or slot > HOTBAR_SIZE then
		warn("Invalid hotbar slot:", slot)
		return false
	end

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

	local character = player.Character
	if not character then return false end

	local rightHand = character:FindFirstChild("RightHand")
	if not rightHand then return false end

	local rightGripAttachment = rightHand:FindFirstChild("RightGripAttachment")
	if not rightGripAttachment then return false end

	local pathParts = string.split(itemConfig.modelPath, ".")
	local current = ReplicatedStorage
	local startIndex = pathParts[1] == "ReplicatedStorage" and 2 or 1
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

	local itemModel = current:Clone()
	itemModel.Name = item.itemName .. "_Equipped"

	if not itemModel.PrimaryPart then
		warn("Item model has no PrimaryPart")
		itemModel:Destroy()
		return false
	end

	itemModel.PrimaryPart.Anchored = false
	itemModel:SetPrimaryPartCFrame(rightGripAttachment.WorldCFrame)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = itemModel.PrimaryPart
	weld.Parent = itemModel.PrimaryPart

	itemModel.Parent = character

	inventory.EquippedSlot = slot
	equippedModels[player] = itemModel
	equippedWelds[player] = weld

	fireInventoryUpdate(self, player, inventory)
	self.Client.ItemEquipped:Fire(player, slot, item.itemName)

	return true
end

function InventoryService:UnequipItem(player: Player): boolean
	local inventory = getInventory(player)
	if not inventory or inventory.EquippedSlot == nil then
		return false
	end

	if equippedModels[player] then
		equippedModels[player]:Destroy()
		equippedModels[player] = nil
	end

	if equippedWelds[player] then
		equippedWelds[player]:Destroy()
		equippedWelds[player] = nil
	end

	inventory.EquippedSlot = nil

	fireInventoryUpdate(self, player, inventory)
	self.Client.ItemUnequipped:Fire(player)

	return true
end

function InventoryService:DropEquippedItem(player: Player): boolean
	local inventory = getInventory(player)
	if not inventory or inventory.EquippedSlot == nil then
		warn("No item equipped to drop")
		return false
	end

	local slot = inventory.EquippedSlot

	if slot == 0 then
		warn("Cannot drop Hammer")
		return false
	end

	local item = inventory.Hotbar[slot]
	if not item then return false end

	local itemConfig = ItemData.GetItem(item.itemName)
	if not itemConfig or not itemConfig.dropable then
		warn("Item is not dropable:", item.itemName)
		return false
	end

	local character = player.Character
	if not character or not character.PrimaryPart then
		warn("Cannot get player position")
		return false
	end

	local lookVector = character.PrimaryPart.CFrame.LookVector
	local dropPosition = character.PrimaryPart.Position + (lookVector * DROP_DISTANCE)

	self:UnequipItem(player)

	createDroppedItem(item.itemName, item.quantity, dropPosition)

	inventory.Hotbar[slot] = nil

	self.Client.ItemDropped:Fire(player, item.itemName, item.quantity)
	fireInventoryUpdate(self, player, inventory)

	return true
end

-- Swap two slots in the inventory grid (1-21 = backpack slots, 22-28 = hotbar slots 1-7)
function InventoryService:SwapGridSlots(player: Player, fromGridIndex: number, toGridIndex: number): boolean
	local inventory = getInventory(player)
	if not inventory then return false end

	if fromGridIndex < 1 or fromGridIndex > 28 or toGridIndex < 1 or toGridIndex > 28 then
		warn("Invalid grid index:", fromGridIndex, toGridIndex)
		return false
	end

	if fromGridIndex == toGridIndex then return true end

	local function getSlotRef(gridIndex)
		if gridIndex <= BACKPACK_SIZE then
			return "backpack", gridIndex
		else
			return "hotbar", gridIndex - BACKPACK_SIZE
		end
	end

	local fromType, fromIdx = getSlotRef(fromGridIndex)
	local toType, toIdx = getSlotRef(toGridIndex)

	local fromItem, toItem

	if fromType == "backpack" then
		fromItem = bpGet(inventory.Backpack, fromIdx)
	else
		fromItem = inventory.Hotbar[fromIdx]
	end

	if toType == "backpack" then
		toItem = bpGet(inventory.Backpack, toIdx)
	else
		toItem = inventory.Hotbar[toIdx]
	end

	-- Unequip if moving from/to an equipped hotbar slot
	if fromType == "hotbar" and inventory.EquippedSlot == fromIdx then
		self:UnequipItem(player)
	end
	if toType == "hotbar" and inventory.EquippedSlot == toIdx then
		self:UnequipItem(player)
	end

	-- Perform swap
	if fromType == "backpack" then
		bpSet(inventory.Backpack, fromIdx, toItem)
	else
		inventory.Hotbar[fromIdx] = toItem
	end

	if toType == "backpack" then
		bpSet(inventory.Backpack, toIdx, fromItem)
	else
		inventory.Hotbar[toIdx] = fromItem
	end

	fireInventoryUpdate(self, player, inventory)
	return true
end

function InventoryService:GetInventory(player: Player)
	return getInventory(player)
end

--|| Client Functions ||--

function InventoryService.Client:GetInventory(player: Player)
	local inventory = getInventory(player)
	if not inventory then return nil end
	return serializeInventory(inventory)
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

function InventoryService.Client:SwapGridSlots(player: Player, fromGridIndex: number, toGridIndex: number)
	return self.Server:SwapGridSlots(player, fromGridIndex, toGridIndex)
end

local RunService = game:GetService("RunService")

local DEV_USER_IDS = {
	[4882453838] = true, -- Yokhaii
}

function InventoryService.Client:AddItem(player: Player, itemName: string, quantity: number)
	if not RunService:IsStudio() and not DEV_USER_IDS[player.UserId] then
		return false
	end
	return self.Server:AddItem(player, itemName, quantity or 1)
end

function InventoryService.Client:DevRemoveItem(player: Player, itemId: string)
	if not RunService:IsStudio() and not DEV_USER_IDS[player.UserId] then
		return false
	end
	return self.Server:RemoveItem(player, itemId, math.huge)
end

-- KNIT START
function InventoryService:KnitStart()
	DataService = Knit.GetService("DataService")

	local function initializeInventory(player)
		local inventory = getInventory(player)
		if not inventory then return end

		-- Migrate old dual-hotbar format
		local migrated = migrateToUnifiedHotbar(inventory)
		if migrated then
			print("[InventoryService] Migrated inventory to unified hotbar for", player.Name)
		end

		-- Initialize Hotbar if nil (new player)
		if not inventory.Hotbar then
			inventory.Hotbar = {}
		end

		-- Initialize Backpack if nil
		if not inventory.Backpack then
			inventory.Backpack = {}
		end

		-- Migrate numeric-keyed backpack to string-keyed
		migrateBackpack(inventory)

		-- Remove any leftover Hammer from inventory data
		removeHammerFromInventory(inventory)

		-- Clean up invalid items
		local removedCount = cleanupInvalidItems(inventory)
		if removedCount > 0 then
			print("[InventoryService] Cleaned up", removedCount, "invalid items for", player.Name)
		end

		-- Ensure starter tool
		ensureStarterPickaxe(inventory)

		-- Always start unequipped
		inventory.EquippedSlot = nil

		fireInventoryUpdate(self, player, inventory)
	end

	local function playerAdded(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			initializeInventory(player)
		end)

		if player.Character then
			task.wait(0.5)
			initializeInventory(player)
		end
	end

	Players.PlayerAdded:Connect(playerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		playerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		equippedModels[player] = nil
		equippedWelds[player] = nil
	end)
end

return InventoryService

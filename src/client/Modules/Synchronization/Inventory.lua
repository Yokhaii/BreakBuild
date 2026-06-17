--[=[
	Inventory Synchronization Module
	Connects InventoryService signals to Rodux store
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Modules
local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)

-- Actions
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local InventoryActions = require(Actions.InventoryActions)

-- Constants
local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21

local Inventory = {}

function Inventory:Init()
	local InventoryService = Knit.GetService("InventoryService")

	InventoryService.InventoryUpdated:Connect(function(inventory)
		-- Convert string-keyed hotbar to numeric indices
		local convertedHotbar = {}
		for i = 1, HOTBAR_SIZE do
			convertedHotbar[i] = inventory.Hotbar[tostring(i)]
		end

		-- Convert string-keyed backpack to numeric indices
		local convertedBackpack = {}
		for i = 1, BACKPACK_SIZE do
			convertedBackpack[i] = inventory.Backpack[tostring(i)]
		end

		Store:dispatch(InventoryActions.setInventory({
			Hotbar = convertedHotbar,
			Backpack = convertedBackpack,
			EquippedSlot = inventory.EquippedSlot,
		}))
	end)

	InventoryService.ItemEquipped:Connect(function(slot, itemName)
		Store:dispatch(InventoryActions.setEquippedSlot(slot))
	end)

	InventoryService.ItemUnequipped:Connect(function()
		Store:dispatch(InventoryActions.setEquippedSlot(nil))
	end)
end

return Inventory

--[=[
	Owner: Yokhaii
	Version: 0.0.2
	Contact owner if any question, concern or feedback

	Inventory Synchronization Module
	Connects InventoryService signals to Rodux store
	Updated for dual-mode hotbar system (Break/Build)
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
local HOTBAR_SIZE = 7 -- Per mode

local Inventory = {}

function Inventory:Init()
	local InventoryService = Knit.GetService("InventoryService")

	-- Handle inventory updates from server
	InventoryService.InventoryUpdated:Connect(function(inventory)
		-- Convert string-keyed hotbars to numeric indices
		local convertedBreakHotbar = {}
		local convertedBuildHotbar = {}

		for i = 1, HOTBAR_SIZE do
			convertedBreakHotbar[i] = inventory.BreakHotbar[tostring(i)]
			convertedBuildHotbar[i] = inventory.BuildHotbar[tostring(i)]
		end

		-- Dispatch to store
		Store:dispatch(InventoryActions.setInventory({
			BreakHotbar = convertedBreakHotbar,
			BuildHotbar = convertedBuildHotbar,
			Backpack = inventory.Backpack,
			CurrentMode = inventory.CurrentMode,
			EquippedSlot = inventory.EquippedSlot,
		}))
	end)

	-- Handle mode change
	InventoryService.ModeChanged:Connect(function(newMode)
		Store:dispatch(InventoryActions.setCurrentMode(newMode))
	end)

	-- Handle item equipped
	InventoryService.ItemEquipped:Connect(function(slot, itemName)
		Store:dispatch(InventoryActions.setEquippedSlot(slot))
	end)

	-- Handle item unequipped
	InventoryService.ItemUnequipped:Connect(function()
		Store:dispatch(InventoryActions.setEquippedSlot(nil))
	end)

	print("[Inventory Sync] Initialized (Dual-Mode)")
end

return Inventory

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local HOTBAR_SIZE = 6 -- Per mode

-- Default state
local defaultState = {
	BreakHotbar = {}, -- { [1] = { id, itemName, quantity }, [2] = nil, ... }
	BuildHotbar = {}, -- { [1] = Hammer, [2] = nil, ... }
	Backpack = {}, -- { { id, itemName, quantity }, ... }
	CurrentMode = "Build", -- "Break" or "Build"
	EquippedSlot = nil, -- 1-6, relative to current mode
	BackpackOpen = false,
	SearchQuery = "",
}

-- Initialize empty hotbar slots
for i = 1, HOTBAR_SIZE do
	defaultState.BreakHotbar[i] = nil
	defaultState.BuildHotbar[i] = nil
end

local InventoryReducer = Rodux.createReducer(defaultState, {
	setInventory = function(state, action)
		return {
			BreakHotbar = action.inventory.BreakHotbar or state.BreakHotbar,
			BuildHotbar = action.inventory.BuildHotbar or state.BuildHotbar,
			Backpack = action.inventory.Backpack or state.Backpack,
			CurrentMode = action.inventory.CurrentMode or state.CurrentMode,
			EquippedSlot = action.inventory.EquippedSlot,
			BackpackOpen = state.BackpackOpen,
			SearchQuery = state.SearchQuery,
		}
	end,

	setBreakHotbar = function(state, action)
		return {
			BreakHotbar = action.hotbar,
			BuildHotbar = state.BuildHotbar,
			Backpack = state.Backpack,
			CurrentMode = state.CurrentMode,
			EquippedSlot = state.EquippedSlot,
			BackpackOpen = state.BackpackOpen,
			SearchQuery = state.SearchQuery,
		}
	end,

	setBuildHotbar = function(state, action)
		return {
			BreakHotbar = state.BreakHotbar,
			BuildHotbar = action.hotbar,
			Backpack = state.Backpack,
			CurrentMode = state.CurrentMode,
			EquippedSlot = state.EquippedSlot,
			BackpackOpen = state.BackpackOpen,
			SearchQuery = state.SearchQuery,
		}
	end,

	setCurrentMode = function(state, action)
		return {
			BreakHotbar = state.BreakHotbar,
			BuildHotbar = state.BuildHotbar,
			Backpack = state.Backpack,
			CurrentMode = action.mode,
			EquippedSlot = state.EquippedSlot,
			BackpackOpen = state.BackpackOpen,
			SearchQuery = state.SearchQuery,
		}
	end,

	setBackpack = function(state, action)
		return {
			BreakHotbar = state.BreakHotbar,
			BuildHotbar = state.BuildHotbar,
			Backpack = action.backpack,
			CurrentMode = state.CurrentMode,
			EquippedSlot = state.EquippedSlot,
			BackpackOpen = state.BackpackOpen,
			SearchQuery = state.SearchQuery,
		}
	end,

	setEquippedSlot = function(state, action)
		return {
			BreakHotbar = state.BreakHotbar,
			BuildHotbar = state.BuildHotbar,
			Backpack = state.Backpack,
			CurrentMode = state.CurrentMode,
			EquippedSlot = action.slot,
			BackpackOpen = state.BackpackOpen,
			SearchQuery = state.SearchQuery,
		}
	end,

	setBackpackOpen = function(state, action)
		return {
			BreakHotbar = state.BreakHotbar,
			BuildHotbar = state.BuildHotbar,
			Backpack = state.Backpack,
			CurrentMode = state.CurrentMode,
			EquippedSlot = state.EquippedSlot,
			BackpackOpen = action.isOpen,
			SearchQuery = state.SearchQuery,
		}
	end,

	setSearchQuery = function(state, action)
		return {
			BreakHotbar = state.BreakHotbar,
			BuildHotbar = state.BuildHotbar,
			Backpack = state.Backpack,
			CurrentMode = state.CurrentMode,
			EquippedSlot = state.EquippedSlot,
			BackpackOpen = state.BackpackOpen,
			SearchQuery = action.query,
		}
	end,
})

return InventoryReducer

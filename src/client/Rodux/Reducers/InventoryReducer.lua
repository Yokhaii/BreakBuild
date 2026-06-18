local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21

local defaultState = {
	Hotbar = {},
	Backpack = {},
	EquippedSlot = nil,
	HammerAvailable = false,
	BackpackOpen = false,
}

for i = 1, HOTBAR_SIZE do
	defaultState.Hotbar[i] = nil
end

local InventoryReducer = Rodux.createReducer(defaultState, {
	setInventory = function(state, action)
		return {
			Hotbar = action.inventory.Hotbar or state.Hotbar,
			Backpack = action.inventory.Backpack or state.Backpack,
			EquippedSlot = action.inventory.EquippedSlot,
			HammerAvailable = state.HammerAvailable,
			BackpackOpen = state.BackpackOpen,
		}
	end,

	setHotbar = function(state, action)
		return {
			Hotbar = action.hotbar,
			Backpack = state.Backpack,
			EquippedSlot = state.EquippedSlot,
			HammerAvailable = state.HammerAvailable,
			BackpackOpen = state.BackpackOpen,
		}
	end,

	setHammerAvailable = function(state, action)
		return {
			Hotbar = state.Hotbar,
			Backpack = state.Backpack,
			EquippedSlot = state.EquippedSlot,
			HammerAvailable = action.available,
			BackpackOpen = state.BackpackOpen,
		}
	end,

	setBackpack = function(state, action)
		return {
			Hotbar = state.Hotbar,
			Backpack = action.backpack,
			EquippedSlot = state.EquippedSlot,
			HammerAvailable = state.HammerAvailable,
			BackpackOpen = state.BackpackOpen,
		}
	end,

	setEquippedSlot = function(state, action)
		return {
			Hotbar = state.Hotbar,
			Backpack = state.Backpack,
			EquippedSlot = action.slot,
			HammerAvailable = state.HammerAvailable,
			BackpackOpen = state.BackpackOpen,
		}
	end,

	setBackpackOpen = function(state, action)
		return {
			Hotbar = state.Hotbar,
			Backpack = state.Backpack,
			EquippedSlot = state.EquippedSlot,
			HammerAvailable = state.HammerAvailable,
			BackpackOpen = action.isOpen,
		}
	end,

	removeGridSlot = function(state, action)
		local gridIndex = action.gridIndex

		local newHotbar = {}
		for i = 1, HOTBAR_SIZE do
			newHotbar[i] = state.Hotbar[i]
		end

		local newBackpack = {}
		for i = 1, BACKPACK_SIZE do
			newBackpack[i] = state.Backpack[i]
		end

		if gridIndex <= BACKPACK_SIZE then
			newBackpack[gridIndex] = nil
		else
			newHotbar[gridIndex - BACKPACK_SIZE] = nil
		end

		return {
			Hotbar = newHotbar,
			Backpack = newBackpack,
			EquippedSlot = state.EquippedSlot,
			HammerAvailable = state.HammerAvailable,
			BackpackOpen = state.BackpackOpen,
		}
	end,

	swapGridSlots = function(state, action)
		local fromGridIndex = action.fromGridIndex
		local toGridIndex = action.toGridIndex

		local newHotbar = {}
		for i = 1, HOTBAR_SIZE do
			newHotbar[i] = state.Hotbar[i]
		end

		local newBackpack = {}
		for i = 1, BACKPACK_SIZE do
			newBackpack[i] = state.Backpack[i]
		end

		local function getItem(gridIndex)
			if gridIndex <= 21 then
				return newBackpack[gridIndex]
			else
				return newHotbar[gridIndex - 21]
			end
		end

		local function setItem(gridIndex, item)
			if gridIndex <= 21 then
				newBackpack[gridIndex] = item
			else
				newHotbar[gridIndex - 21] = item
			end
		end

		local fromItem = getItem(fromGridIndex)
		local toItem = getItem(toGridIndex)
		setItem(fromGridIndex, toItem)
		setItem(toGridIndex, fromItem)

		return {
			Hotbar = newHotbar,
			Backpack = newBackpack,
			EquippedSlot = state.EquippedSlot,
			HammerAvailable = state.HammerAvailable,
			BackpackOpen = state.BackpackOpen,
		}
	end,
})

return InventoryReducer

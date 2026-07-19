local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	ActiveChestId = nil, -- blueprintId of the currently open chest
	Items = {},          -- array of { id, itemName, quantity }
}

local ChestReducer = Rodux.createReducer(defaultState, {
	setChest = function(state, action)
		return {
			ActiveChestId = action.blueprintId,
			Items = action.items or {},
		}
	end,

	updateChestItems = function(state, action)
		return {
			ActiveChestId = state.ActiveChestId,
			Items = action.items or {},
		}
	end,

	clearChest = function(state, action)
		return {
			ActiveChestId = nil,
			Items = {},
		}
	end,
})

return ChestReducer

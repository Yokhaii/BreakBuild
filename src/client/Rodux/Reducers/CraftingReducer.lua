local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	ActiveSession = nil, -- { blueprintId, stationType, recipes }
	CurrentCraft = nil, -- { recipeId, startedAt, craftTime }
}

local CraftingReducer = Rodux.createReducer(defaultState, {
	setSession = function(state, action)
		return {
			ActiveSession = action.session,
			CurrentCraft = nil,
		}
	end,

	clearSession = function(state, action)
		return {
			ActiveSession = nil,
			CurrentCraft = nil,
		}
	end,

	setCraftInProgress = function(state, action)
		return {
			ActiveSession = state.ActiveSession,
			CurrentCraft = action.craftData,
		}
	end,

	clearCraft = function(state, action)
		return {
			ActiveSession = state.ActiveSession,
			CurrentCraft = nil,
		}
	end,
})

return CraftingReducer

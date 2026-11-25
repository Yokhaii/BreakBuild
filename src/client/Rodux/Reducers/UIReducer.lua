local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	CurrentFrame = "HUD", -- Current visible frame
	IsFirstPerson = false, -- Camera is in first person (set by CameraController)
	PrimaryAction = nil, -- Left click action for the held item and aimed target (set by ControlHintsController)
}

local UIReducer = Rodux.createReducer(defaultState, {
	setCurrentFrame = function(state, action)
		return {
			CurrentFrame = action.frameName,
			IsFirstPerson = state.IsFirstPerson,
			PrimaryAction = state.PrimaryAction,
		}
	end,

	setFirstPerson = function(state, action)
		return {
			CurrentFrame = state.CurrentFrame,
			IsFirstPerson = action.isFirstPerson,
			PrimaryAction = state.PrimaryAction,
		}
	end,

	setPrimaryAction = function(state, action)
		return {
			CurrentFrame = state.CurrentFrame,
			IsFirstPerson = state.IsFirstPerson,
			PrimaryAction = action.primaryAction,
		}
	end,
})

return UIReducer

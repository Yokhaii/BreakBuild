local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	CurrentFrame = "HUD", -- Current visible frame
	IsFirstPerson = false, -- Camera is in first person (set by CameraController)
}

local UIReducer = Rodux.createReducer(defaultState, {
	setCurrentFrame = function(state, action)
		return {
			CurrentFrame = action.frameName,
			IsFirstPerson = state.IsFirstPerson,
		}
	end,

	setFirstPerson = function(state, action)
		return {
			CurrentFrame = state.CurrentFrame,
			IsFirstPerson = action.isFirstPerson,
		}
	end,
})

return UIReducer

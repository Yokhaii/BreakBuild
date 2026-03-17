local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	CurrentFrame = "HUD", -- Current visible frame
}

local UIReducer = Rodux.createReducer(defaultState, {
	setCurrentFrame = function(state, action)
		return {
			CurrentFrame = action.frameName,
		}
	end,
})

return UIReducer

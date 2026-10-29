local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

-- Tutorial progress lives in ObjectiveReducer (the tutorial is the first main objectives)
local defaultState = {
	Hint = nil, -- Sub-step instruction text
	SpotlightTarget = nil, -- TutorialTargets id to spotlight, or nil
}

local TutorialReducer = Rodux.createReducer(defaultState, {
	setTutorialGuide = function(_, action)
		return {
			Hint = action.hint,
			SpotlightTarget = action.spotlightTarget,
		}
	end,
})

return TutorialReducer

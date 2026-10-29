local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	CurrentTask = 0, -- Index into TutorialData.Tasks (0 = not started / not synced yet)
	Completed = false,
	Current = 0, -- Progress of the current task
	Required = 0,
	Hint = nil, -- Sub-step instruction text
	SpotlightTarget = nil, -- TutorialTargets id to spotlight, or nil
}

local TutorialReducer = Rodux.createReducer(defaultState, {
	setTutorialState = function(state, action)
		local tutorialState = action.tutorialState
		return {
			CurrentTask = tutorialState.CurrentTask,
			Completed = tutorialState.Completed,
			Current = tutorialState.Current,
			Required = tutorialState.Required,
			Hint = state.Hint,
			SpotlightTarget = state.SpotlightTarget,
		}
	end,

	setTutorialGuide = function(state, action)
		return {
			CurrentTask = state.CurrentTask,
			Completed = state.Completed,
			Current = state.Current,
			Required = state.Required,
			Hint = action.hint,
			SpotlightTarget = action.spotlightTarget,
		}
	end,
})

return TutorialReducer

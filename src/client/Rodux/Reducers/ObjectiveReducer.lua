local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	MainIndex = 0, -- Index into ObjectiveData.Main (0 = not synced yet)
	Progress = {}, -- { [objectiveId]: { Current, Required } } for every active objective
	Completed = {}, -- { [objectiveId]: true } goal met
	Claimed = {}, -- { [objectiveId]: true } reward claimed
	Pinned = {}, -- Side objective ids pinned to the HUD
}

local ObjectiveReducer = Rodux.createReducer(defaultState, {
	setObjectivesState = function(_, action)
		local objectivesState = action.objectivesState
		return {
			MainIndex = objectivesState.MainIndex,
			Progress = objectivesState.Progress or {},
			Completed = objectivesState.Completed or {},
			Claimed = objectivesState.Claimed or {},
			Pinned = objectivesState.Pinned or {},
		}
	end,
})

return ObjectiveReducer

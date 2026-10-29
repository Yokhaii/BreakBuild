local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local ObjectiveActions = {}

-- Objectives synced from ObjectiveService: { MainIndex, Progress, Completed, Claimed, Pinned }
ObjectiveActions.setObjectivesState = Rodux.makeActionCreator("setObjectivesState", function(objectivesState)
	return {
		objectivesState = objectivesState,
	}
end)

return ObjectiveActions

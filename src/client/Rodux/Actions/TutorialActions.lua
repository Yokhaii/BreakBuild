local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local TutorialActions = {}

-- Task progress synced from TutorialService: { CurrentTask, Completed, Current, Required }
TutorialActions.setTutorialState = Rodux.makeActionCreator("setTutorialState", function(tutorialState)
	return {
		tutorialState = tutorialState,
	}
end)

-- Current sub-step computed by TutorialController
TutorialActions.setTutorialGuide = Rodux.makeActionCreator("setTutorialGuide", function(hint, spotlightTarget)
	return {
		hint = hint,
		spotlightTarget = spotlightTarget,
	}
end)

return TutorialActions

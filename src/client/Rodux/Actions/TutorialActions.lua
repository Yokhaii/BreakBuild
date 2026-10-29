local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local TutorialActions = {}

-- Current sub-step computed by TutorialController
TutorialActions.setTutorialGuide = Rodux.makeActionCreator("setTutorialGuide", function(hint, spotlightTarget)
	return {
		hint = hint,
		spotlightTarget = spotlightTarget,
	}
end)

return TutorialActions

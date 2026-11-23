local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local UIActions = {}

-- Set current frame (for frame switching)
UIActions.setCurrentFrame = Rodux.makeActionCreator("setCurrentFrame", function(frameName)
	return {
		frameName = frameName,
	}
end)

-- Set whether the camera is in first person (for the view toggle button)
UIActions.setFirstPerson = Rodux.makeActionCreator("setFirstPerson", function(isFirstPerson)
	return {
		isFirstPerson = isFirstPerson,
	}
end)

return UIActions

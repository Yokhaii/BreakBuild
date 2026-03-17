local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local UIActions = {}

-- Set current frame (for frame switching)
UIActions.setCurrentFrame = Rodux.makeActionCreator("setCurrentFrame", function(frameName)
	return {
		frameName = frameName,
	}
end)

return UIActions

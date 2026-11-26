local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local DevMobActions = {}

-- Live mob counts for the Mob Spawner dev panel (MobService:GetDevState)
DevMobActions.setDevMobState = Rodux.makeActionCreator("setDevMobState", function(state)
	return {
		state = state,
	}
end)

return DevMobActions

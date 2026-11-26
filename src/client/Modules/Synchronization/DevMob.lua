local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local DevMobActions = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions.DevMobActions)

local DevMob = {}

-- Mob counts for the Mob Spawner dev panel (only sent to dev players)
function DevMob:Init()
	local MobService = Knit.GetService("MobService")

	MobService.DevStateChanged:Connect(function(state)
		Store:dispatch(DevMobActions.setDevMobState(state))
	end)

	MobService:GetDevState():andThen(function(state)
		if state then
			Store:dispatch(DevMobActions.setDevMobState(state))
		end
	end)
end

return DevMob

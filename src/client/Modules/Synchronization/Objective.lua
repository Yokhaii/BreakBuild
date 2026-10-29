local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local ObjectiveActions = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions.ObjectiveActions)

local Objective = {}

function Objective:Init()
	local ObjectiveService = Knit.GetService("ObjectiveService")

	ObjectiveService.ObjectivesUpdated:Connect(function(objectivesState)
		Store:dispatch(ObjectiveActions.setObjectivesState(objectivesState))
	end)

	ObjectiveService:GetObjectivesState()
		:andThen(function(objectivesState)
			if objectivesState then
				Store:dispatch(ObjectiveActions.setObjectivesState(objectivesState))
			end
		end)
		:catch(function(err)
			warn("[ObjectiveSync] Failed to get initial objectives state:", err)
		end)
end

return Objective

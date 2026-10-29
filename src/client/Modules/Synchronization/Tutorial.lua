local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local TutorialActions = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions.TutorialActions)

local Tutorial = {}

function Tutorial:Init()
	local TutorialService = Knit.GetService("TutorialService")

	TutorialService.TutorialUpdated:Connect(function(tutorialState)
		Store:dispatch(TutorialActions.setTutorialState(tutorialState))
	end)

	TutorialService:GetTutorialState()
		:andThen(function(tutorialState)
			if tutorialState then
				Store:dispatch(TutorialActions.setTutorialState(tutorialState))
			end
		end)
		:catch(function(err)
			warn("[TutorialSync] Failed to get initial tutorial state:", err)
		end)
end

return Tutorial

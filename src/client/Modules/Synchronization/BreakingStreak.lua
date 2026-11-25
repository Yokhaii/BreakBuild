local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local BreakingStreakActions = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions.BreakingStreakActions)

local BreakingStreak = {}

function BreakingStreak:Init()
	local BreakingService = Knit.GetService("BreakingService")

	BreakingService.StreakUpdated:Connect(function(step, blocks, bonus, isIdle)
		Store:dispatch(BreakingStreakActions.setBreakingStreak(step, blocks, bonus, isIdle))
	end)
end

return BreakingStreak

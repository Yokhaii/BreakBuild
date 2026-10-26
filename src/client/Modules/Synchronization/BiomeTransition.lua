local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local BiomeTransitionActions = require(Client.Rodux.Actions.BiomeTransitionActions)

local BiomeTransitionSync = {}

function BiomeTransitionSync:Init()
	local GlobalBreakingAreaService = Knit.GetService("GlobalBreakingAreaService")

	-- Listen for the biome cycle reset signal
	GlobalBreakingAreaService.CycleReset:Connect(function()
		-- Show the transition screen
		Store:dispatch(BiomeTransitionActions.showTransition())
	end)
end

return BiomeTransitionSync

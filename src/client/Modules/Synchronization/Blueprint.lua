--[=[
	Blueprint Synchronization Module
	Connects BlueprintService signals to Rodux store for UI state
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Modules
local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)

-- Actions
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local BlueprintActions = require(Actions.BlueprintActions)

local Blueprint = {}

function Blueprint:Init()
	local BlueprintService = Knit.GetService("BlueprintService")

	-- Handle blueprint placed (for UI display)
	BlueprintService.BlueprintPlaced:Connect(function(blueprintData)
		Store:dispatch(BlueprintActions.addBlueprint(blueprintData))
	end)

	-- Handle blueprint removed (for UI display)
	BlueprintService.BlueprintRemoved:Connect(function(blueprintId)
		Store:dispatch(BlueprintActions.removeBlueprint(blueprintId))
	end)

	-- Handle blueprint completed (for UI display)
	BlueprintService.BlueprintCompleted:Connect(function(blueprintId)
		Store:dispatch(BlueprintActions.completeBlueprint(blueprintId))
	end)

	-- Note: Blueprints are loaded via BlueprintPlaced signal from server's LoadPlayerBlueprints
	-- No need to manually fetch them here

	print("[Blueprint Sync] Initialized")
end

return Blueprint

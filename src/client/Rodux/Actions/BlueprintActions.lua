--[=[
	Blueprint Actions
	Rodux actions for blueprint UI state management
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local BlueprintActions = {}

-- Add a placed blueprint to UI state
BlueprintActions.addBlueprint = Rodux.makeActionCreator("addBlueprint", function(blueprintData)
	return {
		blueprintData = blueprintData,
	}
end)

-- Remove a blueprint from UI state
BlueprintActions.removeBlueprint = Rodux.makeActionCreator("removeBlueprint", function(blueprintId)
	return {
		blueprintId = blueprintId,
	}
end)

-- Mark a blueprint as completed in UI state
BlueprintActions.completeBlueprint = Rodux.makeActionCreator("completeBlueprint", function(blueprintId)
	return {
		blueprintId = blueprintId,
	}
end)

return BlueprintActions

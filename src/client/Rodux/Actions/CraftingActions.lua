local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local CraftingActions = {}

CraftingActions.setSession = Rodux.makeActionCreator("setSession", function(session)
	return {
		session = session,
	}
end)

CraftingActions.clearSession = Rodux.makeActionCreator("clearSession", function()
	return {}
end)

CraftingActions.setCraftInProgress = Rodux.makeActionCreator("setCraftInProgress", function(craftData)
	return {
		craftData = craftData,
	}
end)

CraftingActions.clearCraft = Rodux.makeActionCreator("clearCraft", function()
	return {}
end)

return CraftingActions

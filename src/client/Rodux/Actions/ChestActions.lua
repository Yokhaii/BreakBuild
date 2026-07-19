local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local ChestActions = {}

ChestActions.setChest = Rodux.makeActionCreator("setChest", function(blueprintId, items)
	return {
		blueprintId = blueprintId,
		items = items,
	}
end)

ChestActions.updateChestItems = Rodux.makeActionCreator("updateChestItems", function(items)
	return {
		items = items,
	}
end)

ChestActions.clearChest = Rodux.makeActionCreator("clearChest", function()
	return {}
end)

return ChestActions

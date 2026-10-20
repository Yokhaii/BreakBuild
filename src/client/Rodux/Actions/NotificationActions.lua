local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local NotificationActions = {}

NotificationActions.addNotification = Rodux.makeActionCreator("addNotification", function(itemName, quantity)
	return {
		itemName = itemName,
		quantity = quantity,
	}
end)

NotificationActions.startFading = Rodux.makeActionCreator("startFading", function(id)
	return {
		id = id,
	}
end)

NotificationActions.removeNotification = Rodux.makeActionCreator("removeNotification", function(id)
	return {
		id = id,
	}
end)

return NotificationActions

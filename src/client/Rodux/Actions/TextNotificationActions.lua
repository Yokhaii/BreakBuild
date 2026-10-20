local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local TextNotificationActions = {}

TextNotificationActions.showTextNotification = Rodux.makeActionCreator("showTextNotification", function(id, text, color, persistent)
	return {
		id = id,
		text = text,
		color = color,
		persistent = persistent,
	}
end)

TextNotificationActions.releaseTextNotification = Rodux.makeActionCreator("releaseTextNotification", function(id)
	return {
		id = id,
	}
end)

TextNotificationActions.startFadingTextNotification = Rodux.makeActionCreator("startFadingTextNotification", function(id)
	return {
		id = id,
	}
end)

TextNotificationActions.removeTextNotification = Rodux.makeActionCreator("removeTextNotification", function(id)
	return {
		id = id,
	}
end)

return TextNotificationActions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	Notifications = {},
}

local function copyNotif(notif, overrides)
	local new = {
		id = notif.id,
		text = notif.text,
		color = notif.color,
		timestamp = notif.timestamp,
		persistent = notif.persistent,
		released = notif.released,
		releasedAt = notif.releasedAt,
		fading = notif.fading,
	}
	if overrides then
		for k, v in pairs(overrides) do
			new[k] = v
		end
	end
	return new
end

local TextNotificationReducer = Rodux.createReducer(defaultState, {
	showTextNotification = function(state, action)
		local newNotifications = {}
		for _, notif in ipairs(state.Notifications) do
			table.insert(newNotifications, notif)
		end

		table.insert(newNotifications, {
			id = action.id,
			text = action.text,
			color = action.color or Color3.fromRGB(255, 255, 255),
			timestamp = tick(),
			persistent = action.persistent or false,
			released = false,
			releasedAt = 0,
			fading = false,
		})

		return {
			Notifications = newNotifications,
		}
	end,

	releaseTextNotification = function(state, action)
		local newNotifications = {}
		for _, notif in ipairs(state.Notifications) do
			if notif.id == action.id and notif.persistent and not notif.released then
				table.insert(newNotifications, copyNotif(notif, {
					released = true,
					releasedAt = tick(),
				}))
			else
				table.insert(newNotifications, notif)
			end
		end

		return {
			Notifications = newNotifications,
		}
	end,

	startFadingTextNotification = function(state, action)
		local newNotifications = {}
		for _, notif in ipairs(state.Notifications) do
			if notif.id == action.id then
				table.insert(newNotifications, copyNotif(notif, { fading = true }))
			else
				table.insert(newNotifications, notif)
			end
		end

		return {
			Notifications = newNotifications,
		}
	end,

	removeTextNotification = function(state, action)
		local newNotifications = {}
		for _, notif in ipairs(state.Notifications) do
			if notif.id ~= action.id then
				table.insert(newNotifications, notif)
			end
		end

		return {
			Notifications = newNotifications,
		}
	end,
})

return TextNotificationReducer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)
local HttpService = game:GetService("HttpService")

local defaultState = {
	Notifications = {},
	NextSlot = 0,
}

local NotificationReducer = Rodux.createReducer(defaultState, {
	addNotification = function(state, action)
		local newNotifications = {}
		local merged = false

		for _, notif in ipairs(state.Notifications) do
			if notif.itemName == action.itemName and not notif.fading then
				table.insert(newNotifications, {
					id = notif.id,
					itemName = notif.itemName,
					quantity = notif.quantity + action.quantity,
					timestamp = notif.timestamp,
					fading = false,
					slot = notif.slot,
				})
				merged = true
			else
				table.insert(newNotifications, notif)
			end
		end

		local nextSlot = state.NextSlot
		if not merged then
			table.insert(newNotifications, {
				id = HttpService:GenerateGUID(false),
				itemName = action.itemName,
				quantity = action.quantity,
				timestamp = tick(),
				fading = false,
				slot = nextSlot,
			})
			nextSlot = nextSlot + 1
		end

		return {
			Notifications = newNotifications,
			NextSlot = nextSlot,
		}
	end,

	startFading = function(state, action)
		local newNotifications = {}
		for _, notif in ipairs(state.Notifications) do
			if notif.id == action.id then
				table.insert(newNotifications, {
					id = notif.id,
					itemName = notif.itemName,
					quantity = notif.quantity,
					timestamp = notif.timestamp,
					fading = true,
					slot = notif.slot,
				})
			else
				table.insert(newNotifications, notif)
			end
		end

		return {
			Notifications = newNotifications,
			NextSlot = state.NextSlot,
		}
	end,

	removeNotification = function(state, action)
		local newNotifications = {}
		for _, notif in ipairs(state.Notifications) do
			if notif.id ~= action.id then
				table.insert(newNotifications, notif)
			end
		end

		local nextSlot = state.NextSlot
		if #newNotifications == 0 then
			nextSlot = 0
		end

		return {
			Notifications = newNotifications,
			NextSlot = nextSlot,
		}
	end,
})

return NotificationReducer

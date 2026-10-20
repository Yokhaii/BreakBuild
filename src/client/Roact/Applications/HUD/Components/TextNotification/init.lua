local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local TextNotificationItem = require(script.TextNotificationItem)

local ITEM_HEIGHT = 0.3
local ITEM_PADDING = 0.05
local ROW_STEP = ITEM_HEIGHT + ITEM_PADDING

local function TextNotification(_, hooks)
	local state = RoduxHooks.useSelector(hooks, function(state)
		return state.TextNotificationReducer
	end)

	local notifications = state.Notifications

	local children = {}

	for i, notification in ipairs(notifications) do
		local count = #notifications
		local slotFromCenter = (i - 1) - (count - 1) / 2
		local yOffset = slotFromCenter * ROW_STEP

		children["TextNotif_" .. notification.id] = Roact.createElement(TextNotificationItem, {
			notification = notification,
			yPosition = yOffset,
		})
	end

	return Roact.createElement("Frame", {
		Name = "TextNotification",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, -0.6),
		Size = UDim2.fromScale(3, 0.8),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 100,
	}, children)
end

TextNotification = RoactHooks.new(Roact)(TextNotification)
return TextNotification

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local NotificationItem = require(script.NotificationItem)

local Config = require(script.Config)

local ITEM_HEIGHT = Config.NotificationHeight.Scale
local ITEM_PADDING = Config.Padding.Scale
local ROW_STEP = ITEM_HEIGHT + ITEM_PADDING

local function Notifications(_, hooks)
	local notifState = RoduxHooks.useSelector(hooks, function(state)
		return state.NotificationReducer
	end)

	local notifications = notifState.Notifications
	local totalSlots = notifState.NextSlot

	local children = {}

	for _, notification in ipairs(notifications) do
		local slotFromCenter = notification.slot - (totalSlots - 1) / 2
		local yOffset = slotFromCenter * ROW_STEP

		children["Notif_" .. notification.id] = Roact.createElement(NotificationItem, {
			notification = notification,
			yPosition = yOffset,
		})
	end

	return Roact.createElement("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.99, 0.4),
		Size = UDim2.fromScale(0.15, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 100,
	}, children)
end

Notifications = RoactHooks.new(Roact)(Notifications)
return Notifications

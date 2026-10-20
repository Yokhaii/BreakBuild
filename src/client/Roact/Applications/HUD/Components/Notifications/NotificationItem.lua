local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Images = require(ReplicatedStorage.Shared.Data.Images)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local NotificationActions = require(Actions.NotificationActions)

local Config = require(script.Parent.Config)

local function NotificationItem(props, hooks)
	local notification = props.notification
	local yPosition = props.yPosition

	local alpha, setAlpha = hooks.useState(0)
	local slideIn, setSlideIn = hooks.useState(1)

	hooks.useEffect(function()
		local startTime = tick()
		local connection

		connection = RunService.RenderStepped:Connect(function()
			local progress = math.min((tick() - startTime) / Config.SlideInDuration, 1)
			local eased = 1 - (1 - progress) * (1 - progress)
			setSlideIn(1 - eased)

			if progress >= 1 then
				connection:Disconnect()
			end
		end)

		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { notification.id })

	hooks.useEffect(function()
		local startTime = tick()
		local currentPhase = "visible"
		local connection

		connection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime

			if currentPhase == "visible" then
				if elapsed >= Config.DisplayDuration then
					currentPhase = "fading"
					Store:dispatch(NotificationActions.startFading(notification.id))
					startTime = tick()
				end

			elseif currentPhase == "fading" then
				local fadeProgress = math.min(elapsed / Config.FadeOutDuration, 1)
				setAlpha(fadeProgress)

				if fadeProgress >= 1 then
					connection:Disconnect()
					Store:dispatch(NotificationActions.removeNotification(notification.id))
				end
			end
		end)

		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { notification.id, notification.quantity })

	local slideInOffset = slideIn * Config.SlideInDistance
	local slideOffset = alpha * -Config.SlideUpDistance
	local transparency = alpha

	local itemImage = Images[notification.itemName]

	return Roact.createElement("Frame", {
		Name = "Notification_" .. notification.id,
		Size = UDim2.new(Config.NotificationWidth, Config.NotificationHeight),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, slideInOffset, 0.5 + yPosition, slideOffset),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = Config.IconPadding,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		Icon = itemImage and Roact.createElement("ImageLabel", {
			Size = Config.IconSize,
			BackgroundTransparency = 1,
			Image = itemImage,
			ScaleType = Enum.ScaleType.Fit,
			ImageTransparency = transparency,
			LayoutOrder = 1,
		}) or nil,

		Amount = Roact.createElement("TextLabel", {
			Name = "Amount",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			FontFace = Config.FontFace,
			Text = "x" .. tostring(notification.quantity),
			TextColor3 = Config.TextColor,
			TextScaled = true,
			TextTransparency = transparency,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.StrokeColor,
				Thickness = Config.StrokeThickness,
				Transparency = transparency,
			}),
		}),
	})
end

NotificationItem = RoactHooks.new(Roact)(NotificationItem)
return NotificationItem

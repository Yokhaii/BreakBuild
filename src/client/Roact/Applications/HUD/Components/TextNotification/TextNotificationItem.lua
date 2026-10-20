local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local TextNotificationActions = require(Actions.TextNotificationActions)

local Config = require(script.Parent.Config)

local function TextNotificationItem(props, hooks)
	local notification = props.notification
	local yPosition = props.yPosition

	local alpha, setAlpha = hooks.useState(0)
	local shakeOffset, setShakeOffset = hooks.useState(0)

	hooks.useEffect(function()
		local startTime = tick()
		local createdAt = tick()
		local currentPhase = "visible"
		local shaking = false
		local connection

		if notification.persistent then
			currentPhase = "waiting"
		end

		connection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime

			if currentPhase == "visible" then
				if elapsed >= Config.DisplayDuration then
					currentPhase = "fading"
					Store:dispatch(TextNotificationActions.startFadingTextNotification(notification.id))
					startTime = tick()
				end

			elseif currentPhase == "waiting" then
				if not shaking and (tick() - createdAt) >= Config.ShakeDelay then
					shaking = true
				end

				if shaking then
					local t = tick()
					setShakeOffset(math.sin(t * Config.ShakeFrequency * math.pi * 2) * Config.ShakeAmplitude)
				end

				if notification.released then
					currentPhase = "holdBeforeFade"
					shaking = false
					setShakeOffset(0)
					startTime = tick()
				end

			elseif currentPhase == "holdBeforeFade" then
				if elapsed >= Config.ReleaseHoldDuration then
					currentPhase = "fading"
					Store:dispatch(TextNotificationActions.startFadingTextNotification(notification.id))
					startTime = tick()
				end

			elseif currentPhase == "fading" then
				local fadeProgress = math.min(elapsed / Config.FadeOutDuration, 1)
				setAlpha(fadeProgress)

				if fadeProgress >= 1 then
					connection:Disconnect()
					Store:dispatch(TextNotificationActions.removeTextNotification(notification.id))
				end
			end
		end)

		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { notification.id, notification.released })

	local slideOffset = alpha * -Config.SlideUpDistance
	local transparency = alpha

	return Roact.createElement("Frame", {
		Name = "TextNotif_" .. notification.id,
		Size = UDim2.fromScale(1, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, shakeOffset, 0.5 + yPosition, slideOffset),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, {
		Label = Roact.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Config.FontFace,
			Text = notification.text,
			TextColor3 = notification.color,
			TextScaled = true,
			TextTransparency = transparency,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.StrokeColor,
				Thickness = Config.StrokeThickness,
				Transparency = transparency,
			}),
		}),
	})
end

TextNotificationItem = RoactHooks.new(Roact)(TextNotificationItem)
return TextNotificationItem

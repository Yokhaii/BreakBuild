local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local Store = require(Client.Rodux.Store)
local BiomeTransitionActions = require(Client.Rodux.Actions.BiomeTransitionActions)

local Config = require(script.Config)

local function BiomeTransition(props, hooks)
	local transitionState = RoduxHooks.useSelector(hooks, function(state)
		return state.BiomeTransitionReducer
	end)

	local isActive = transitionState.IsActive

	local frameRef = hooks.useValue(Roact.createRef())
	local currentTween = hooks.useValue(nil)

	hooks.useEffect(function()
		local frame = frameRef.value:getValue()
		if not frame then return end

		if isActive then
			frame.Visible = true
			frame.Position = UDim2.fromScale(-0.5, 0.5) -- Off-screen left

			local tweenIn = TweenService:Create(
				frame,
				TweenInfo.new(Config.WipeInDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromScale(0.5, 0.5) }
			)

			currentTween.value = tweenIn
			tweenIn:Play()

			tweenIn.Completed:Connect(function()
				task.wait(Config.HoldDuration)

				local tweenOut = TweenService:Create(
					frame,
					TweenInfo.new(Config.WipeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = UDim2.fromScale(1.5, 0.5) }
				)

				currentTween.value = tweenOut
				tweenOut:Play()

				tweenOut.Completed:Connect(function()
					frame.Visible = false
					currentTween.value = nil
					Store:dispatch(BiomeTransitionActions.hideTransition())
				end)
			end)
		else
			if currentTween.value then
				currentTween.value:Cancel()
				currentTween.value = nil
			end
			frame.Visible = false
		end

		return function()
			if currentTween.value then
				currentTween.value:Cancel()
				currentTween.value = nil
			end
		end
	end, { isActive })

	return Roact.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(-0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = Config.ZIndex,
		[Roact.Ref] = frameRef.value,
	}, {
		Background = Roact.createElement(StudBackground, {
			ZIndex = Config.ZIndex,
			BackgroundColor = Config.ScreenColor,
			ImageTransparency = Config.StudImageTransparency,
		}),

		Text = Roact.createElement("TextLabel", {
			Text = Config.TextContent,
			Position = Config.TextPosition,
			AnchorPoint = Config.TextAnchorPoint,
			Size = Config.TextSize,
			BackgroundTransparency = 1,
			TextColor3 = Config.TextColor,
			TextScaled = true,
			FontFace = Config.TextFont,
			ZIndex = Config.ZIndex + 1,
		}),
	})
end

BiomeTransition = RoactHooks.new(Roact)(BiomeTransition)
return BiomeTransition

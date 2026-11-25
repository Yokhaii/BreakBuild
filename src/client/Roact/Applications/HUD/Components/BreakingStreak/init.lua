--[=[
	BreakingStreak - Top right "x14 / STREAK +10%" counter
	Shown once the breaking streak reaches step 1 (see BreakingService)
	The bar drains over BreakingConfig.StreakResetDelay while the player is not breaking
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local BreakingConfig = require(ReplicatedStorage.Shared.Config.BreakingConfig)

local Config = require(script.Config)

local function BreakingStreak(_, hooks)
	local streak = RoduxHooks.useSelector(hooks, function(state)
		return state.BreakingStreakReducer
	end)

	local scaleRef = hooks.useValue(Roact.createRef())
	local fillRef = hooks.useValue(Roact.createRef())

	local isVisible = streak.Step > 0

	-- Pop on every block broken
	hooks.useEffect(function()
		local scale = scaleRef.value:getValue()
		if not scale or not isVisible then return end

		scale.Scale = Config.PopScale
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(Config.PopDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		tween:Play()

		return function()
			tween:Cancel()
		end
	end, { streak.Blocks })

	-- Drain the bar while idle, refill it when breaking again
	hooks.useEffect(function()
		local fill = fillRef.value:getValue()
		if not fill then return end

		local tween
		if streak.IsIdle then
			local remaining = fill.Size.X.Scale * BreakingConfig.StreakResetDelay
			tween = TweenService:Create(
				fill,
				TweenInfo.new(remaining, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(0, 1) }
			)
		else
			tween = TweenService:Create(
				fill,
				TweenInfo.new(Config.BarRefillDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(1, 1) }
			)
		end
		tween:Play()

		return function()
			tween:Cancel()
		end
	end, { streak.IsIdle })

	local color = Config.StepColors[streak.Step] or Config.StepColors[1]

	return Roact.createElement("Frame", {
		Name = "BreakingStreak",
		Position = Config.Position,
		AnchorPoint = Config.AnchorPoint,
		Size = Config.Size,
		BackgroundTransparency = 1,
		Visible = isVisible,
		ZIndex = Config.ZIndex,
	}, {
		UIScale = Roact.createElement("UIScale", {
			[Roact.Ref] = scaleRef.value,
		}),

		Count = Roact.createElement(FancyText, {
			Text = "x" .. tostring(streak.Blocks),
			Size = Config.CountSize,
			TextColor3 = color,
			StrokeColor = Config.StrokeColor,
			StrokeThickness = Config.StrokeThickness,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = Config.ZIndex,
		}),

		Label = Roact.createElement(FancyText, {
			Text = string.format("%s +%d%%", Config.LabelText, math.round(streak.Bonus * 100)),
			Position = Config.LabelPosition,
			Size = Config.LabelSize,
			TextColor3 = color,
			StrokeColor = Config.StrokeColor,
			StrokeThickness = Config.StrokeThickness,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = Config.ZIndex,
		}),

		Bar = Roact.createElement("Frame", {
			Position = Config.BarPosition,
			AnchorPoint = Config.BarAnchorPoint,
			Size = Config.BarSize,
			BackgroundColor3 = Config.BarBackgroundColor,
			BackgroundTransparency = Config.BarBackgroundTransparency,
			ClipsDescendants = true,
			ZIndex = Config.ZIndex,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.BarCornerRadius,
			}),
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.StrokeColor,
				Thickness = Config.BarStrokeThickness,
			}),

			Fill = Roact.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = Config.ZIndex + 1,
				[Roact.Ref] = fillRef.value,
			}, {
				UICorner = Roact.createElement("UICorner", {
					CornerRadius = Config.BarCornerRadius,
				}),
			}),
		}),
	})
end

BreakingStreak = RoactHooks.new(Roact)(BreakingStreak)
return BreakingStreak

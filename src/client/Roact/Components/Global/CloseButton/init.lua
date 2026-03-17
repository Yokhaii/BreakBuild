--[=[
	CloseButton Component
	Animated close button with hover and click effects
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactSpring = require(ReplicatedStorage.Packages.RoactSpring)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(script.Config)

local function CloseButton(props, hooks)
	local styles, api = RoactSpring.useSpring(hooks, function()
		return {
			sizeAlpha = 1,
			imageColor3 = Config.DefaultColor,
		}
	end)

	local function getSize()
		return styles.sizeAlpha:map(function(alpha)
			return UDim2.fromScale(alpha, alpha)
		end)
	end

	local function playHoverSound()
		local success, SoundController = pcall(function()
			return Knit.GetController("SoundController")
		end)
		if success and SoundController and SoundController.PlaySound then
			pcall(function()
				SoundController:PlaySound(SoundController:SpawnSound("Hover_UI"))
			end)
		end
	end

	return Roact.createElement("Frame", {
		Name = "CloseButtonContainer",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(0.1, 0.1),
		ZIndex = props.ZIndex or 10,
	}, {
		Button = Roact.createElement("ImageButton", {
			Name = "CloseButton",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Size = getSize(),
			Image = props.Image or Config.Image,
			ImageColor3 = styles.imageColor3,
			ZIndex = props.ZIndex or 10,

			[Roact.Event.MouseButton1Click] = function()
				if props.OnClick then
					props.OnClick()
				end
			end,

			[Roact.Event.MouseButton1Down] = function()
				api.start({
					sizeAlpha = Config.ClickScale,
					config = { tension = 400, friction = 20 },
				})
			end,

			[Roact.Event.MouseButton1Up] = function()
				api.start({
					sizeAlpha = 1,
					config = { tension = Config.SpringTension, friction = Config.SpringFriction },
				})
			end,

			[Roact.Event.MouseEnter] = function()
				playHoverSound()
				api.start({
					sizeAlpha = Config.HoverScale,
					imageColor3 = Config.HoverColor,
					config = { tension = Config.SpringTension, friction = Config.SpringFriction },
				})
			end,

			[Roact.Event.MouseLeave] = function()
				api.start({
					sizeAlpha = 1,
					imageColor3 = Config.DefaultColor,
					config = { tension = Config.SpringTension, friction = Config.SpringFriction },
				})
			end,
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
		}),

		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),
	})
end

CloseButton = RoactHooks.new(Roact)(CloseButton)
return CloseButton

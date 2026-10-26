--[=[
	SpawnButton Component
	Button on middle left of HUD to teleport player back to their BuildingArea
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function SpawnButton(props, hooks)
	local isHovered, setIsHovered = hooks.useState(false)

	local handleClick = hooks.useCallback(function()
		local ZoneService = Knit.GetService("ZoneService")
		if ZoneService then
			ZoneService:TeleportToZone()
		end
	end, {})

	local backgroundColor = isHovered and Config.HoverColor or Config.DefaultColor

	return Roact.createElement("TextButton", {
		Name = "SpawnButton",
		Size = Config.ButtonSize,
		Position = Config.ButtonPosition,
		AnchorPoint = Config.ButtonAnchorPoint,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = props.ZIndex or 1,
		[Roact.Event.MouseButton1Click] = handleClick,
		[Roact.Event.MouseEnter] = function()
			setIsHovered(true)
		end,
		[Roact.Event.MouseLeave] = function()
			setIsHovered(false)
		end,
	}, {
		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = Config.AspectRatio,
		}),

		Background = Roact.createElement(StudBackground, {
			ZIndex = props.ZIndex or 1,
			BackgroundColor = backgroundColor,
			ImageTransparency = Config.StudImageTransparency,
			StrokeColor = Config.StrokeColor,
			StrokeThickness = Config.StrokeThickness,
			StrokeTransparency = Config.StrokeTransparency,
		}),

		Label = Roact.createElement("TextLabel", {
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = Config.Text,
			TextColor3 = Config.TextColor,
			TextScaled = true,
			FontFace = Config.Font,
			ZIndex = (props.ZIndex or 1) + 1,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.TextStrokeColor,
				Thickness = Config.TextStrokeThickness,
			}),
			UITextSizeConstraint = Roact.createElement("UITextSizeConstraint", {
				MaxTextSize = 24,
				MinTextSize = 10,
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = UDim.new(0.1, 0),
				PaddingRight = UDim.new(0.1, 0),
				PaddingTop = UDim.new(0.15, 0),
				PaddingBottom = UDim.new(0.15, 0),
			}),
		}),
	})
end

SpawnButton = RoactHooks.new(Roact)(SpawnButton)
return SpawnButton

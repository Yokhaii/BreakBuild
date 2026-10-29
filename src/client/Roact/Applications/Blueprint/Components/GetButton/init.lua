--[=[
	GetButton Component
	Green stud button below the blueprint viewport that grants the selected blueprint.
	Styled like the HUD SpawnButton.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function GetButton(props, hooks)
	local isHovered, setIsHovered = hooks.useState(false)

	local zIndex = props.ZIndex or 1
	local backgroundColor = isHovered and Config.HoverColor or Config.DefaultColor

	return Roact.createElement("TextButton", {
		Name = "GetButton",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = zIndex,
		[Roact.Ref] = props.TargetRef,
		[Roact.Event.MouseButton1Click] = props.OnClick,
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
			ZIndex = zIndex,
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
			ZIndex = zIndex + 1,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.TextStrokeColor,
				Thickness = Config.TextStrokeThickness,
			}),
			UITextSizeConstraint = Roact.createElement("UITextSizeConstraint", {
				MaxTextSize = Config.MaxTextSize,
				MinTextSize = Config.MinTextSize,
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

GetButton = RoactHooks.new(Roact)(GetButton)
return GetButton

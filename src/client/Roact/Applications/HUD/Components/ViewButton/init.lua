--[=[
	ViewButton Component
	Button next to the SpawnButton to switch between first person and the normal view
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function ViewButton(props, hooks)
	local isHovered, setIsHovered = hooks.useState(false)

	local isFirstPerson = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer.IsFirstPerson
	end)

	local handleClick = hooks.useCallback(function()
		Knit.GetController("CameraController"):ToggleFirstPerson()
	end, {})

	local backgroundColor = isHovered and Config.HoverColor or Config.DefaultColor

	return Roact.createElement("TextButton", {
		Name = "ViewButton",
		Size = Config.ButtonSize,
		Position = Config.ButtonPosition,
		AnchorPoint = Config.ButtonAnchorPoint,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = props.ZIndex or 1,
		[Roact.Event.Activated] = handleClick,
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
			-- Shows the view the button switches to
			Text = isFirstPerson and Config.ThirdPersonText or Config.FirstPersonText,
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

ViewButton = RoactHooks.new(Roact)(ViewButton)
return ViewButton

--[=[
	ObjectiveButton Component
	Stud button used by the objective UIs (CLAIM, PIN, UNPIN...). Styled like the HUD SpawnButton.

	Props:
		Text         (string)
		Variant      (string?)   -- "Claim" | "Pin" | "Unpin" | "Neutral" (Config.Variants)
		Size, Position, AnchorPoint, LayoutOrder, ZIndex
		AspectRatio  (number?)   -- optional width:height constraint
		OnClick      (function?)
		TargetRef    (ref?)      -- TutorialTargets ref for the spotlight
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function ObjectiveButton(props, hooks)
	local isHovered, setIsHovered = hooks.useState(false)

	local zIndex = props.ZIndex or 1
	local colors = Config.Variants[props.Variant or Config.DefaultVariant] or Config.Variants[Config.DefaultVariant]
	local backgroundColor = isHovered and colors.Hover or colors.Default

	return Roact.createElement("TextButton", {
		Name = props.Name or "ObjectiveButton",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
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
		UIAspectRatioConstraint = props.AspectRatio and Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = props.AspectRatio,
		}) or nil,

		Background = Roact.createElement(StudBackground, {
			ZIndex = zIndex,
			BackgroundColor = backgroundColor,
			ImageTransparency = Config.StudImageTransparency,
			CornerRadius = Config.CornerRadius,
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
			Text = props.Text or "",
			TextColor3 = Config.TextColor,
			TextScaled = true,
			FontFace = Config.Font,
			ZIndex = zIndex + 1,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.TextStrokeColor,
				Thickness = Config.TextStrokeThickness,
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.PaddingHorizontal,
				PaddingRight = Config.PaddingHorizontal,
				PaddingTop = Config.PaddingVertical,
				PaddingBottom = Config.PaddingVertical,
			}),
		}),
	})
end

ObjectiveButton = RoactHooks.new(Roact)(ObjectiveButton)
return ObjectiveButton

--[=[
	FancyText Component
	Styled text label with configurable stroke and gradient support
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Config = require(script.Config)

local function FancyText(props, hooks)
	-- Extract special children for gradients
	local children = props[Roact.Children] or {}
	local strokeUIGradient = children.StrokeUIGradient
	local textUIGradient = children.TextUIGradient
	local textUISizeConstraint = children.UITextSizeConstraint

	return Roact.createElement("TextLabel", {
		Name = props.Name or "FancyText",
		AutomaticSize = props.AutomaticSize,
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Visible = props.Visible ~= false,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0, 0),
		FontFace = props.FontFace or Config.FontFace,
		LayoutOrder = props.LayoutOrder,
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Config.TextColor,
		TextScaled = props.TextScaled ~= false,
		TextWrapped = props.TextWrapped ~= false,
		TextSize = props.TextSize,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex or 1,
		Rotation = props.Rotation or 0,
		[Roact.Ref] = props[Roact.Ref],
	}, {
		UIStroke = Roact.createElement("UIStroke", {
			Color = props.StrokeColor or Config.StrokeColor,
			Thickness = props.StrokeThickness or Config.StrokeThickness,
			Transparency = props.StrokeTransparency or 0,
		}, {
			StrokeUIGradient = strokeUIGradient,
		}),

		TextUIGradient = textUIGradient,
		UITextSizeConstraint = textUISizeConstraint,
	})
end

FancyText = RoactHooks.new(Roact)(FancyText)
return FancyText

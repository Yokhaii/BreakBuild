--[=[
	DevButton Component
	Flat colored button with a label, used by the dev panels (Mob Spawner).
	Props: Text, OnClick, Color?, Size?, Position?, AnchorPoint?, AspectRatio?, LayoutOrder?, ZIndex?
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)

local Config = require(script.Config)

local function DevButton(props, hooks)
	local hovered, setHovered = hooks.useState(false)
	local zIndex = props.ZIndex or 15
	local color = props.Color or Config.Color

	return Roact.createElement("TextButton", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = hovered and color:Lerp(Config.HoverTint, Config.HoverAmount) or color,
		AutoButtonColor = false,
		Text = "",
		ZIndex = zIndex,
		[Roact.Event.Activated] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
		[Roact.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[Roact.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),
		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.StrokeColor,
			Thickness = Config.StrokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIAspectRatioConstraint = props.AspectRatio and Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = props.AspectRatio,
		}) or nil,
		Label = Roact.createElement(FancyText, {
			Text = props.Text or "",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = Config.LabelSize,
			TextColor3 = Config.TextColor,
			StrokeColor = Config.TextStrokeColor,
			StrokeThickness = Config.TextStrokeThickness,
			ZIndex = zIndex + 1,
		}),
	})
end

DevButton = RoactHooks.new(Roact)(DevButton)
return DevButton

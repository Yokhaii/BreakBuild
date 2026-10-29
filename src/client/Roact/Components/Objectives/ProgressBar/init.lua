--[=[
	ProgressBar Component
	Rounded progress bar with an optional centered label.

	Props:
		Progress     (number)   -- 0..1
		Text         (string?)  -- label drawn on the bar (e.g. "12/24")
		Size, Position, AnchorPoint, LayoutOrder, ZIndex
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)

local Config = require(script.Config)

local function ProgressBar(props, hooks)
	local zIndex = props.ZIndex or 1
	local progress = math.clamp(props.Progress or 0, 0, 1)

	return Roact.createElement("Frame", {
		Name = "ProgressBar",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = Config.TrackColor,
		BackgroundTransparency = Config.TrackTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),
		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.StrokeColor,
			Thickness = Config.StrokeThickness,
		}),

		Fill = progress > 0 and Roact.createElement("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(progress, 1),
			BackgroundColor3 = progress >= 1 and Config.CompleteFillColor or Config.FillColor,
			BorderSizePixel = 0,
			ZIndex = zIndex + 1,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),
		}) or nil,

		Label = props.Text and Roact.createElement(FancyText, {
			Text = props.Text,
			Size = Config.TextSize,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Config.TextColor,
			StrokeColor = Config.TextStrokeColor,
			StrokeThickness = Config.TextStrokeThickness,
			ZIndex = zIndex + 2,
		}) or nil,
	})
end

ProgressBar = RoactHooks.new(Roact)(ProgressBar)
return ProgressBar

--[=[
	PanelFrame Component
	Grey stud outer frame with a dark stud inner content area.
	Children are rendered inside the content area.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)

local Config = require(script.Config)

local function PanelFrame(props, hooks)
	local zIndex = props.ZIndex or 5

	return Roact.createElement("Frame", {
		Name = props.Name or "PanelFrame",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(0.3, 0.5),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		ClipsDescendants = true,
		[Roact.Ref] = props[Roact.Ref],
	}, {
		UIAspectRatioConstraint = props.AspectRatio and Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = props.AspectRatio,
		}) or nil,

		UICorner = Roact.createElement("UICorner", {
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = props.StrokeColor or Config.StrokeColor,
			Thickness = props.StrokeThickness or Config.StrokeThickness,
			Transparency = props.StrokeTransparency or Config.StrokeTransparency,
		}),

		Title = props.Title and Roact.createElement(FancyText, {
			Name = "PanelTitle",
			AnchorPoint = Vector2.new(0, 0),
			Position = Config.TitlePosition,
			Size = Config.TitleSize,
			Text = props.Title,
			TextColor3 = Config.TitleColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeTransparency = 1,
			ZIndex = zIndex + 2,
		}) or nil,

		MainBackground = Roact.createElement(StudBackground, {
			ZIndex = zIndex,
			BackgroundColor = props.MainStudBackgroundColor or Config.MainStudBackgroundColor,
			ImageTransparency = props.MainStudImageTransparency or Config.MainStudImageTransparency,
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		Content = Roact.createElement("Frame", {
			Name = "Content",
			AnchorPoint = props.ContentAnchorPoint or Config.ContentAnchorPoint,
			Position = props.ContentPosition or Config.ContentPosition,
			Size = props.ContentSize or Config.ContentSize,
			BackgroundTransparency = 1,
			ZIndex = zIndex + 1,
			ClipsDescendants = true,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = props.ContentCornerRadius or Config.ContentCornerRadius,
			}),

			UIStroke = Roact.createElement("UIStroke", {
				Color = props.ContentStrokeColor or Config.ContentStrokeColor,
				Thickness = props.ContentStrokeThickness or Config.ContentStrokeThickness,
				Transparency = props.ContentStrokeTransparency or Config.ContentStrokeTransparency,
			}),

			ContentBackground = Roact.createElement(StudBackground, {
				ZIndex = zIndex + 1,
				BackgroundColor = props.ContentStudBackgroundColor or Config.ContentStudBackgroundColor,
				ImageTransparency = props.ContentStudImageTransparency or Config.ContentStudImageTransparency,
				CornerRadius = props.ContentCornerRadius or Config.ContentCornerRadius,
			}),

			Children = Roact.createFragment(props[Roact.Children]),
		}),
	})
end

PanelFrame = RoactHooks.new(Roact)(PanelFrame)
return PanelFrame

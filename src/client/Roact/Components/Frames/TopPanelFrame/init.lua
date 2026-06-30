--[=[
	TopPanelFrame Component
	Grey stud outer frame with a dark stud inner content area.
	Sits on top of the backpack, symmetric to PanelFrame.
	Children are rendered inside the content area.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function TopPanelFrame(props, hooks)
	local zIndex = props.ZIndex or 5

	return Roact.createElement("Frame", {
		Name = props.Name or "TopPanelFrame",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(0.3, 0.2),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		ClipsDescendants = false,
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
			Children = Roact.createFragment(props[Roact.Children]),
		}),
	})
end

TopPanelFrame = RoactHooks.new(Roact)(TopPanelFrame)
return TopPanelFrame

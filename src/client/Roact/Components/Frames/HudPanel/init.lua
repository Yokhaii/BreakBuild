--[=[
	HudPanel Component
	Small HUD panel: a light grey stud title bar on top of a dark see-through stud content
	area, drawn as ONE frame (single outline and rounded corners). Each background is twice
	as tall as its clipping section, so only the outer corners are rounded and the title
	and content meet flush.

	Props:
		Title         (string)
		TitleShare    (number)     -- fraction of the panel height used by the title (1 = title only)
		OnTitleClick  (function?)  -- makes the title a button (with hover color)
		TitleRef      (ref?)       -- TutorialTargets ref on the title
		ShowBadge     (boolean?)   -- red dot on the title's top-right corner
		Name, Size, Position, AnchorPoint, ZIndex
		[Roact.Children]           -- rendered inside the content area
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function HudPanel(props, hooks)
	local zIndex = props.ZIndex or 1
	local titleShare = math.clamp(props.TitleShare or 1, 0, 1)
	local hasContent = titleShare < 1

	local isTitleHovered, setIsTitleHovered = hooks.useState(false)
	local isClickable = props.OnTitleClick ~= nil

	return Roact.createElement("Frame", {
		Name = props.Name or "HudPanel",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),
		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.StrokeColor,
			Thickness = Config.StrokeThickness,
			Transparency = Config.StrokeTransparency,
		}),

		Title = Roact.createElement(isClickable and "TextButton" or "Frame", {
			Name = "Title",
			Size = UDim2.fromScale(1, titleShare),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = zIndex,
			Text = isClickable and "" or nil,
			AutoButtonColor = isClickable and false or nil,
			[Roact.Ref] = props.TitleRef,
			[Roact.Event.MouseButton1Click] = props.OnTitleClick,
			[Roact.Event.MouseEnter] = isClickable and function()
				setIsTitleHovered(true)
			end or nil,
			[Roact.Event.MouseLeave] = isClickable and function()
				setIsTitleHovered(false)
			end or nil,
		}, {
			Background = Roact.createElement(StudBackground, {
				Size = UDim2.fromScale(1, hasContent and 2 or 1),
				Position = UDim2.fromScale(0, 0),
				AnchorPoint = Vector2.new(0, 0),
				ZIndex = zIndex,
				BackgroundColor = isTitleHovered and Config.TitleHoverColor or Config.TitleColor,
				ImageTransparency = Config.TitleStudImageTransparency,
				CornerRadius = Config.CornerRadius,
			}),

			Label = Roact.createElement(FancyText, {
				Text = props.Title or "",
				Size = Config.TitleTextSize,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = zIndex + 1,
			}),
		}),

		Badge = props.ShowBadge and Roact.createElement("Frame", {
			Name = "Badge",
			Size = Config.BadgeSize,
			Position = Config.BadgePosition,
			AnchorPoint = Config.BadgeAnchorPoint,
			BackgroundTransparency = 1,
			ZIndex = zIndex + 5,
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				DominantAxis = Enum.DominantAxis.Width,
			}),
			Dot = Roact.createElement(StudBackground, {
				ZIndex = zIndex + 5,
				BackgroundColor = Config.BadgeColor,
				ImageTransparency = Config.BadgeStudImageTransparency,
				CornerRadius = Config.BadgeCornerRadius,
				StrokeColor = Config.BadgeStrokeColor,
				StrokeThickness = Config.BadgeStrokeThickness,
			}),
		}) or nil,

		Separator = hasContent and Roact.createElement("Frame", {
			Name = "Separator",
			Size = UDim2.fromScale(1, Config.SeparatorHeight),
			Position = UDim2.fromScale(0, titleShare),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Config.SeparatorColor,
			BackgroundTransparency = Config.SeparatorTransparency,
			BorderSizePixel = 0,
			ZIndex = zIndex + 3,
		}) or nil,

		Content = hasContent and Roact.createElement("Frame", {
			Name = "Content",
			Size = UDim2.fromScale(1, 1 - titleShare),
			Position = UDim2.fromScale(0, titleShare),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = zIndex,
		}, {
			Background = Roact.createElement(StudBackground, {
				Size = UDim2.fromScale(1, 2),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				ZIndex = zIndex,
				BackgroundColor = Config.ContentColor,
				BackgroundTransparency = Config.ContentTransparency,
				ImageTransparency = Config.ContentStudImageTransparency,
				CornerRadius = Config.CornerRadius,
			}),

			Children = Roact.createFragment(props[Roact.Children]),
		}) or nil,
	})
end

HudPanel = RoactHooks.new(Roact)(HudPanel)
return HudPanel

--[=[
	BaseFrame Component
	Simple frame template with CloseButton, Title, and Content area
	Used as the foundation for all App frames
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local CloseButton = require(Components.Global.CloseButton)
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function BaseFrame(props, hooks)
	-- Don't render if not visible
	if not props.Visible then
		return Roact.createElement("Frame", {
			Visible = false,
		})
	end

	return Roact.createElement("Frame", {
		Name = props.Name or "BaseFrame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or Config.DefaultSize,
		BackgroundColor3 = props.BackgroundColor3 or Config.BackgroundColor,
		BackgroundTransparency = props.BackgroundTransparency or Config.BackgroundTransparency,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 5,
		Visible = props.Visible,
		ClipsDescendants = true,
	}, {
		-- Corner rounding
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		-- Border stroke
		UIStroke = Roact.createElement("UIStroke", {
			Color = props.StrokeColor or Config.StrokeColor,
			Thickness = props.StrokeThickness or Config.StrokeThickness,
			Transparency = 0,
		}),

		-- Aspect ratio (optional)
		UIAspectRatioConstraint = props.AspectRatio and Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = props.AspectRatio,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}) or nil,

		-- Main background
		Background = Roact.createElement(StudBackground, {
			ZIndex = (props.ZIndex or 5),
			BackgroundColor = props.MainStudBackgroundColor or Config.MainStudBackgroundColor,
			ImageTransparency = props.MainStudImageTransparency or Config.MainStudImageTransparency,
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		-- Title at the top
		TitleContainer = Roact.createElement("Frame", {
			Name = "TitleContainer",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.02),
			Size = props.TitleSize or Config.TitleSize,
			BackgroundTransparency = 1,
			ZIndex = (props.ZIndex or 5) + 1,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = props.TitleCornerRadius or Config.TitleCornerRadius,
			}),
			UIStroke = Roact.createElement("UIStroke", {
				Color = props.TitleFrameStrokeColor or Config.TitleFrameStrokeColor,
				Thickness = props.TitleFrameStrokeThickness or Config.TitleFrameStrokeThickness,
				Transparency = props.TitleFrameStrokeTransparency or Config.TitleFrameStrokeTransparency,
			}),
			TitleBackground = Roact.createElement(StudBackground, {
				ZIndex = (props.ZIndex or 5) + 1,
				BackgroundColor = props.TitleStudBackgroundColor or Config.TitleStudBackgroundColor,
				ImageTransparency = props.TitleStudImageTransparency or Config.TitleStudImageTransparency,
				CornerRadius = props.TitleCornerRadius or Config.TitleCornerRadius,
			}),
			Title = Roact.createElement(FancyText, {
				Text = props.Title or "Title",
				Size = UDim2.fromScale(1, 1),
				TextColor3 = props.TitleColor or Config.TitleColor,
				StrokeColor = props.TitleStrokeColor or Config.TitleStrokeColor,
				StrokeThickness = props.TitleStrokeThickness or Config.TitleStrokeThickness,
				ZIndex = (props.ZIndex or 5) + 3,
			}),
			Title2 = Roact.createElement(FancyText, {
				Text = props.Title or "Title",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(5, 5),
				TextColor3 = props.TitleColor2 or Config.TitleColor2,
				StrokeColor = props.TitleStrokeColor2 or Config.TitleStrokeColor2,
				StrokeThickness = props.TitleStrokeThickness2 or Config.TitleStrokeThickness2,
				ZIndex = (props.ZIndex or 5) + 2,
			}),
		}),

		-- Close button
		CloseButton = Roact.createElement(CloseButton, {
			Position = props.CloseButtonPosition or UDim2.fromScale(0.98, 0.02),
			AnchorPoint = Vector2.new(1, 0),
			Size = props.CloseButtonSize or Config.CloseButtonSize,
			ZIndex = (props.ZIndex or 5) + 3,
			OnClick = props.OnClose,
		}),

		-- Content area
		Content = Roact.createElement("Frame", {
			Name = "Content",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = props.ContentPosition or UDim2.fromScale(0.5, 0.98),
			Size = props.ContentSize or Config.ContentSize,
			BackgroundTransparency = 1,
			ZIndex = (props.ZIndex or 5) + 1,
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
				ZIndex = (props.ZIndex or 5) + 1,
				BackgroundColor = props.ContentStudBackgroundColor or Config.ContentStudBackgroundColor,
				ImageTransparency = props.ContentStudImageTransparency or Config.ContentStudImageTransparency,
				CornerRadius = props.ContentCornerRadius or Config.ContentCornerRadius,
			}),
			Children = Roact.createFragment(props[Roact.Children]),
		}),
	})
end

BaseFrame = RoactHooks.new(Roact)(BaseFrame)
return BaseFrame

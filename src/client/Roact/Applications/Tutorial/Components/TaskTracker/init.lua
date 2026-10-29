--[=[
	TaskTracker Component
	Small card showing the current tutorial task, its progress and the current sub-step hint.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function TaskTracker(props, hooks)
	local baseZIndex = props.ZIndex or 1

	local titleText = props.Title or ""
	if (props.Required or 0) > 1 then
		titleText = string.format(Config.ProgressFormat, titleText, props.Current or 0, props.Required)
	end

	return Roact.createElement("Frame", {
		Name = "TaskTracker",
		AnchorPoint = Config.AnchorPoint,
		Position = Config.Position,
		Size = Config.Size,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, {
		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = Config.AspectRatio,
		}),

		Background = Roact.createElement(StudBackground, {
			ZIndex = baseZIndex,
			BackgroundColor = Config.StudBackgroundColor,
			ImageTransparency = Config.StudImageTransparency,
			CornerRadius = Config.CornerRadius,
			StrokeColor = Config.StrokeColor,
			StrokeThickness = Config.StrokeThickness,
		}),

		Content = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = baseZIndex + 1,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.PaddingHorizontal,
				PaddingRight = Config.PaddingHorizontal,
				PaddingTop = Config.PaddingVertical,
				PaddingBottom = Config.PaddingVertical,
			}),

			UIListLayout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = Config.ListPadding,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			Header = Roact.createElement(FancyText, {
				Text = string.format(Config.HeaderText, props.TaskIndex or 1, props.TaskCount or 1),
				Size = Config.HeaderSize,
				TextColor3 = Config.HeaderColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				ZIndex = baseZIndex + 2,
			}),

			Title = Roact.createElement(FancyText, {
				Text = titleText,
				Size = Config.TitleSize,
				TextColor3 = Config.TitleColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				ZIndex = baseZIndex + 2,
			}),

			Hint = props.Hint and Roact.createElement("TextLabel", {
				Text = props.Hint,
				Size = Config.HintSize,
				BackgroundTransparency = 1,
				TextColor3 = Config.HintColor,
				TextScaled = true,
				TextWrapped = true,
				FontFace = Config.HintFont,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 3,
				ZIndex = baseZIndex + 2,
			}) or nil,
		}),
	})
end

TaskTracker = RoactHooks.new(Roact)(TaskTracker)
return TaskTracker

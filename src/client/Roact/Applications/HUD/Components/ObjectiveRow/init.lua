--[=[
	ObjectiveRow Component
	One line in the HUD ObjectivesTracker: task text, progress ("0/4") and item icon.
	Completed objectives show their progress in green (rewards are claimed from the
	Objectives frame). Upcoming (locked) main objectives are drawn greyed out.

	Props:
		Objective    (table)    -- ObjectiveData entry
		Status       (string)   -- ObjectiveStatus value
		Current, Required (number)
		Size, LayoutOrder, ZIndex
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local ObjectiveStatus = require(Client.Modules.ObjectiveStatus)

local Config = require(script.Config)

local function ObjectiveRow(props, hooks)
	local baseZIndex = props.ZIndex or 1
	local objective = props.Objective
	local isComplete = props.Status == ObjectiveStatus.Complete
	local isUpcoming = props.Status == ObjectiveStatus.Locked
	local textColor = isUpcoming and Config.UpcomingTextColor or Config.TextColor
	local progressColor = isComplete and Config.CompleteTextColor or textColor
	local icon = ObjectiveStatus.GetIcon(objective)

	return Roact.createElement("Frame", {
		Name = "ObjectiveRow_" .. objective.id,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, {
		Task = Roact.createElement(FancyText, {
			Text = ObjectiveStatus.GetTaskText(objective),
			Size = Config.TaskSize,
			Position = Config.TaskPosition,
			AnchorPoint = Config.TaskAnchorPoint,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = baseZIndex + 1,
		}),

		Right = Roact.createElement("Frame", {
			Size = Config.RightSize,
			Position = Config.RightPosition,
			AnchorPoint = Config.RightAnchorPoint,
			BackgroundTransparency = 1,
			ZIndex = baseZIndex + 1,
		}, {
			UIListLayout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = Config.RightPadding,
			}),

			Progress = Roact.createElement(FancyText, {
				Text = ObjectiveStatus.FormatNumber(props.Current or 0) .. "/" .. ObjectiveStatus.FormatNumber(props.Required or 1),
				Size = Config.ProgressSize,
				TextColor3 = progressColor,
				TextXAlignment = Enum.TextXAlignment.Right,
				LayoutOrder = 1,
				ZIndex = baseZIndex + 2,
			}),

			Icon = icon and Roact.createElement("ImageLabel", {
				Size = Config.IconSize,
				BackgroundTransparency = 1,
				Image = icon,
				ImageTransparency = isUpcoming and Config.UpcomingIconTransparency or 0,
				ScaleType = Enum.ScaleType.Fit,
				LayoutOrder = 2,
				ZIndex = baseZIndex + 2,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
			}) or nil,
		}),
	})
end

ObjectiveRow = RoactHooks.new(Roact)(ObjectiveRow)
return ObjectiveRow

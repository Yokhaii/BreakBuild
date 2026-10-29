--[=[
	ObjectiveList Component
	Scrollable list of ObjectiveCards.

	Props:
		Entries  ({ { Objective, Status, Current, Required, IsPinned } })
		Size, Position, ZIndex
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)

local ObjectiveCard = require(script.Parent.ObjectiveCard)

local Config = require(script.Config)

local function ObjectiveList(props, hooks)
	local baseZIndex = props.ZIndex or 1
	local entries = props.Entries or {}

	if #entries == 0 then
		return Roact.createElement(FancyText, {
			Text = Config.EmptyText,
			Size = Config.EmptyTextSize,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Config.EmptyTextColor,
			ZIndex = baseZIndex,
		})
	end

	local cards = {}
	for index, entry in ipairs(entries) do
		cards["Objective_" .. entry.Objective.id] = Roact.createElement(ObjectiveCard, {
			Objective = entry.Objective,
			Status = entry.Status,
			Current = entry.Current,
			Required = entry.Required,
			IsPinned = entry.IsPinned,
			LayoutOrder = index,
			ZIndex = baseZIndex,
		})
	end

	return Roact.createElement("ScrollingFrame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ScrollBarThickness = Config.ScrollBarThickness,
		ScrollBarImageColor3 = Config.ScrollBarColor,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = baseZIndex,
	}, {
		UIPadding = Roact.createElement("UIPadding", {
			PaddingTop = Config.ListPadding,
			PaddingBottom = Config.ListPadding,
			PaddingLeft = Config.ListPadding,
			PaddingRight = Config.ListPadding,
		}),

		UIListLayout = Roact.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = Config.Padding,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),

		Cards = Roact.createFragment(cards),
	})
end

ObjectiveList = RoactHooks.new(Roact)(ObjectiveList)
return ObjectiveList

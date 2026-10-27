--[=[
	BlueprintList Component
	Scrollable list of BlueprintCards
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local BlueprintCard = require(script.Parent.BlueprintCard)

local Config = require(script.Config)

local function BlueprintList(props, hooks)
	local blueprints = props.Blueprints or {}
	local baseZIndex = props.ZIndex or 1
	local selectedId = props.SelectedBlueprintId

	-- Sort blueprints: first by requiredRebirth, then by order
	local sortedBlueprints = {}
	for _, blueprint in ipairs(blueprints) do
		table.insert(sortedBlueprints, blueprint)
	end
	table.sort(sortedBlueprints, function(a, b)
		if a.RequiredRebirth ~= b.RequiredRebirth then
			return a.RequiredRebirth < b.RequiredRebirth
		end
		return (a.Order or 999) < (b.Order or 999)
	end)

	local cardElements = {}
	for i, blueprint in ipairs(sortedBlueprints) do
		cardElements["Blueprint_" .. i] = Roact.createElement(BlueprintCard, {
			LayoutOrder = i,
			Name = blueprint.Name,
			Description = blueprint.Description,
			BlueprintData = blueprint,
			IsUnlocked = blueprint.IsUnlocked ~= false,
			IsSelected = selectedId == blueprint.Id,
			RequiredRebirth = blueprint.RequiredRebirth,
			OnClick = props.OnBlueprintClick,
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
			PaddingTop = Config.ListPadding.Top,
			PaddingBottom = Config.ListPadding.Bottom,
			PaddingLeft = Config.ListPadding.Left,
			PaddingRight = Config.ListPadding.Right,
		}),

		UIListLayout = Roact.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = Config.Padding,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),

		Cards = Roact.createFragment(cardElements),

		BottomSpacer = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0.05, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
		}),
	})
end

BlueprintList = RoactHooks.new(Roact)(BlueprintList)
return BlueprintList

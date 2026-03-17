--[=[
	BlueprintList Component
	Scrollable list of BlueprintCards (unlocked and locked)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local UnlockedBlueprintCard = require(Components.Blueprint.UnlockedBlueprintCard)
local LockedBlueprintCard = require(Components.Blueprint.LockedBlueprintCard)

local Config = require(script.Config)

local function BlueprintList(props, hooks)
	local blueprints = props.Blueprints or {}
	local baseZIndex = props.ZIndex or 1

	-- Build card elements
	local cardElements = {}
	for i, blueprint in ipairs(blueprints) do
		local isUnlocked = blueprint.IsUnlocked ~= false

		if isUnlocked then
			cardElements["Blueprint_" .. i] = Roact.createElement(UnlockedBlueprintCard, {
				LayoutOrder = i,
				Title = blueprint.Name,
				Description = blueprint.Description,
				Image = blueprint.Image,
				Materials = blueprint.Materials,
				BlueprintData = blueprint,
				OnClick = props.OnBlueprintClick,
				ZIndex = baseZIndex,
			})
		else
			cardElements["Blueprint_" .. i] = Roact.createElement(LockedBlueprintCard, {
				LayoutOrder = i,
				Title = blueprint.Name,
				Description = blueprint.Description,
				Image = blueprint.Image,
				Materials = blueprint.Materials,
				RequiredRebirth = blueprint.RequiredRebirth,
				BlueprintData = blueprint,
				ZIndex = baseZIndex,
			})
		end
	end

	return Roact.createElement("ScrollingFrame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = Config.ScrollBarThickness,
		ScrollBarImageColor3 = Config.ScrollBarColor,
		CanvasSize = UDim2.fromScale(0, 0), -- Auto-sized by UIListLayout
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
		}),

		Cards = Roact.createFragment(cardElements),

		-- Bottom spacer to ensure last card fully fits
		BottomSpacer = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0.05, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
		}),
	})
end

BlueprintList = RoactHooks.new(Roact)(BlueprintList)
return BlueprintList

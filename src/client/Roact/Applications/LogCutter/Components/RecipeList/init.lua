local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local RecipeCard = require(script.Parent.RecipeCard)

local Config = require(script.Config)

local function RecipeList(props, hooks)
	local recipes = props.Recipes or {}
	local baseZIndex = props.ZIndex or 1
	local selectedRecipeId = props.SelectedRecipeId

	local cardElements = {}
	local i = 0
	for recipeId, recipe in pairs(recipes) do
		i = i + 1
		local isSelected = selectedRecipeId == recipeId

		cardElements["Recipe_" .. recipeId] = Roact.createElement(RecipeCard, {
			LayoutOrder = i,
			Recipe = recipe,
			OnSelect = props.OnRecipeSelect,
			IsSelected = isSelected,
			ZIndex = baseZIndex,
		})
	end

	return Roact.createElement("ScrollingFrame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
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
		}),

		Cards = Roact.createFragment(cardElements),

		BottomSpacer = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0.05, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
		}),
	})
end

RecipeList = RoactHooks.new(Roact)(RecipeList)
return RecipeList

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local RecipeCard = require(script.Parent.RecipeCard)

local Config = require(script.Config)

local function RecipeList(props, hooks)
	local recipes = props.Recipes or {}
	local baseZIndex = props.ZIndex or 1
	local selectedRecipeId = props.SelectedRecipeId

	local sortedRecipes = {}
	for recipeId, recipe in pairs(recipes) do
		table.insert(sortedRecipes, { id = recipeId, recipe = recipe })
	end
	table.sort(sortedRecipes, function(a, b)
		return (a.recipe.order or 999) < (b.recipe.order or 999)
	end)

	local countItem = props.CountItem

	local cardElements = {}
	for i, entry in ipairs(sortedRecipes) do
		local isSelected = selectedRecipeId == entry.id

		local canCraft = true
		if countItem and entry.recipe.inputs then
			for _, input in ipairs(entry.recipe.inputs) do
				if countItem(input.itemName) < input.quantity then
					canCraft = false
					break
				end
			end
		end

		cardElements["Recipe_" .. entry.id] = Roact.createElement(RecipeCard, {
			LayoutOrder = i,
			Recipe = entry.recipe,
			OnSelect = props.OnRecipeSelect,
			OnRemove = isSelected and props.OnRemove or nil,
			IsSelected = isSelected,
			IsLocked = not canCraft,
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

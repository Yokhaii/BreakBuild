--[=[
	LeftPanel Component
	Shows available inventory crafts (recipes with stationType = "Inventory")
	Positioned to the left of the inventory backpack frame.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local PanelFrame = require(Components.Frames.PanelFrame)

local RecipeCard = require(script.Components.RecipeCard)
local Config = require(script.Config)

local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)

local function LeftPanel(props, hooks)
	local selectedRecipeId = props.SelectedRecipeId
	local onRecipeSelect = props.OnRecipeSelect
	local onRemove = props.OnRemove
	local countItem = props.CountItem
	local baseZIndex = props.ZIndex or 11

	-- Get all inventory recipes
	local inventoryRecipes = Recipes.GetRecipesForStation("Inventory")

	-- Sort recipes by display name
	local sortedRecipes = {}
	for recipeId, recipe in pairs(inventoryRecipes) do
		table.insert(sortedRecipes, { id = recipeId, recipe = recipe })
	end
	table.sort(sortedRecipes, function(a, b)
		return (a.recipe.displayName or a.id) < (b.recipe.displayName or b.id)
	end)

	-- Build recipe cards
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
			OnSelect = onRecipeSelect,
			OnRemove = isSelected and onRemove or nil,
			IsSelected = isSelected,
			IsLocked = not canCraft,
			ZIndex = baseZIndex + 2,
		})
	end

	return Roact.createElement(PanelFrame, {
		Name = "InventoryCraftsPanel",
		AnchorPoint = Config.PanelAnchorPoint,
		Position = Config.PanelPosition,
		Size = Config.PanelSize,
		AspectRatio = Config.PanelAspectRatio,
		ZIndex = baseZIndex,
	}, {
		ScrollFrame = Roact.createElement("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = true,
			ScrollBarThickness = Config.ScrollBarThickness,
			ScrollBarImageColor3 = Config.ScrollBarColor,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = baseZIndex + 1,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingTop = Config.ListPadding.Top,
				PaddingBottom = Config.ListPadding.Bottom,
				PaddingLeft = Config.ListPadding.Left,
				PaddingRight = Config.ListPadding.Right,
			}),

			UIListLayout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = Config.RecipeListPadding,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),

			Cards = Roact.createFragment(cardElements),

			BottomSpacer = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0.05, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 9999,
			}),
		}),
	})
end

LeftPanel = RoactHooks.new(Roact)(LeftPanel)
return LeftPanel

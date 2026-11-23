--[=[
	BlueprintDetails Component
	Right panel content: one scrollable list with the blueprint description box
	at the top, then the "Available recipes" label and the station's RecipeCards,
	or the "Possible finds" label and LootCards for passive blueprints (BirdNest).
	Blueprints without recipes or loot only show the description.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local RecipeCard = require(Client.Roact.Applications.Furnace.Components.RecipeCard)
local LootCard = require(script.Parent.LootCard)

local Config = require(script.Config)

local function BlueprintDetails(props, hooks)
	local recipes = props.Recipes or {}
	local loot = props.Loot or {}
	local baseZIndex = props.ZIndex or 1

	local sortedRecipes = {}
	for _, recipe in pairs(recipes) do
		table.insert(sortedRecipes, recipe)
	end
	table.sort(sortedRecipes, function(a, b)
		return (a.order or 999) < (b.order or 999)
	end)

	-- Description takes LayoutOrder 1, the label 2, cards start at 3
	local cardElements = {}
	for i, recipe in ipairs(sortedRecipes) do
		cardElements["Recipe_" .. i] = Roact.createElement(RecipeCard, {
			LayoutOrder = i + 2,
			Recipe = recipe,
			ZIndex = baseZIndex,
		})
	end

	local totalWeight = 0
	for _, entry in ipairs(loot) do
		totalWeight += entry.weight
	end

	local lootElements = {}
	for i, entry in ipairs(loot) do
		lootElements["Loot_" .. i] = Roact.createElement(LootCard, {
			LayoutOrder = i + 2,
			Loot = entry,
			Chance = entry.weight / totalWeight,
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

		Description = Roact.createElement("Frame", {
			Size = Config.DescriptionSize,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			ZIndex = baseZIndex,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.DescriptionCornerRadius,
			}),

			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.DescriptionStrokeColor,
				Thickness = Config.DescriptionStrokeThickness,
				Transparency = Config.DescriptionStrokeTransparency,
			}),

			Background = Roact.createElement(StudBackground, {
				ZIndex = baseZIndex + 1,
				BackgroundColor = Config.DescriptionStudBackgroundColor,
				ImageTransparency = Config.DescriptionStudImageTransparency,
				CornerRadius = Config.DescriptionCornerRadius,
			}),

			Text = Roact.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.Description or "",
				TextColor3 = Config.DescriptionTextColor,
				TextScaled = true,
				TextWrapped = true,
				FontFace = Config.DescriptionFont,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = baseZIndex + 2,
			}, {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingTop = Config.DescriptionTextPadding,
					PaddingBottom = Config.DescriptionTextPadding,
					PaddingLeft = Config.DescriptionTextPadding,
					PaddingRight = Config.DescriptionTextPadding,
				}),
				UITextSizeConstraint = Roact.createElement("UITextSizeConstraint", {
					MaxTextSize = Config.DescriptionMaxTextSize,
				}),
			}),
		}),

		RecipesLabel = #sortedRecipes > 0 and Roact.createElement(FancyText, {
			Text = Config.RecipesLabelText,
			Size = Config.RecipesLabelSize,
			TextColor3 = Config.RecipesLabelColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			ZIndex = baseZIndex + 1,
		}) or nil,

		LootLabel = #loot > 0 and Roact.createElement(FancyText, {
			Text = Config.LootLabelText,
			Size = Config.RecipesLabelSize,
			TextColor3 = Config.RecipesLabelColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			ZIndex = baseZIndex + 1,
		}) or nil,

		Cards = Roact.createFragment(cardElements),
		LootCards = Roact.createFragment(lootElements),

		BottomSpacer = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0.05, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
		}),
	})
end

BlueprintDetails = RoactHooks.new(Roact)(BlueprintDetails)
return BlueprintDetails

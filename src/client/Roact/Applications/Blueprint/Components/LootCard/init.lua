--[=[
	LootCard Component
	One possible find of a passive blueprint (BirdNest loot table).
	Same visual design as RecipeCard: item icon on the left, name on top,
	then the amount per trip and the chance to get it.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Images = require(ReplicatedStorage.Shared.Data.Images)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local Config = require(script.Config)

-- "x2" or "x1-3"
local function formatAmount(min: number, max: number): string
	if min == max then
		return "x" .. min
	end
	return "x" .. min .. "-" .. max
end

-- Rounded percentage, "<1%" for very rare finds
local function formatChance(chance: number): string
	local percent = math.floor(chance * 100 + 0.5)
	if percent < 1 then
		return "<1%"
	end
	return percent .. "%"
end

local function LootCard(props, hooks)
	local baseZIndex = props.ZIndex or 1
	local loot = props.Loot
	local item = ItemData.GetItem(loot.itemName)
	local min = loot.min or 1
	local max = loot.max or min

	return Roact.createElement("Frame", {
		Size = props.Size or Config.CardSize,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		ZIndex = baseZIndex,
		ClipsDescendants = true,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.CardStrokeColor,
			Thickness = Config.CardStrokeThickness,
			Transparency = Config.CardStrokeTransparency,
		}),

		CardBackground = Roact.createElement(StudBackground, {
			ZIndex = baseZIndex + 1,
			BackgroundColor = Config.CardStudBackgroundColor,
			ImageTransparency = Config.CardStudImageTransparency,
			CornerRadius = Config.CornerRadius,
		}),

		ContentContainer = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = baseZIndex + 2,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.ContentPaddingLeft,
				PaddingRight = Config.ContentPaddingRight,
				PaddingTop = Config.ContentPaddingTop,
				PaddingBottom = Config.ContentPaddingBottom,
			}),

			ImageContainer = Roact.createElement("Frame", {
				Size = Config.ImageSize,
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				ZIndex = baseZIndex + 2,
				ClipsDescendants = true,
			}, {
				UICorner = Roact.createElement("UICorner", {
					CornerRadius = Config.ImageCornerRadius,
				}),
				UIStroke = Roact.createElement("UIStroke", {
					Color = Config.ImageStrokeColor,
					Thickness = Config.ImageStrokeThickness,
					Transparency = Config.ImageStrokeTransparency,
				}),
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				ImageBackground = Roact.createElement(StudBackground, {
					ZIndex = baseZIndex + 2,
					BackgroundColor = Config.ImageStudBackgroundColor,
					ImageTransparency = Config.ImageStudImageTransparency,
					CornerRadius = Config.ImageCornerRadius,
				}),
				ItemIcon = Roact.createElement("ImageLabel", {
					Size = Config.IconSize,
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = Images[loot.itemName] or "",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = baseZIndex + 3,
				}),
			}),

			InfoContainer = Roact.createElement("Frame", {
				Size = Config.InfoContainerSize,
				Position = Config.InfoContainerPosition,
				AnchorPoint = Config.InfoContainerAnchorPoint,
				BackgroundTransparency = 1,
				ZIndex = baseZIndex + 3,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = Config.InfoLayoutPadding,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				Title = Roact.createElement(FancyText, {
					Text = item and item.displayName or loot.itemName,
					Size = Config.TitleSize,
					TextColor3 = Config.TitleColor,
					StrokeColor = Config.TitleStrokeColor,
					StrokeThickness = Config.TitleStrokeThickness,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				Detail = Roact.createElement("TextLabel", {
					Size = Config.DetailSize,
					BackgroundTransparency = 1,
					Text = formatAmount(min, max) .. "  ·  " .. formatChance(props.Chance or 0),
					TextColor3 = Config.DetailColor,
					TextScaled = true,
					FontFace = Config.DetailFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}),
			}),
		}),
	})
end

LootCard = RoactHooks.new(Roact)(LootCard)
return LootCard

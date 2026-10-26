local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local ShopData = require(ReplicatedStorage.Shared.Data.ShopData)

local ShopItemCard = require(script.Parent.ShopItemCard)
local CategoryFilter = require(script.Parent.CategoryFilter)

local Config = require(script.Config)

local function ShopItemList(props, hooks)
	local baseZIndex = props.ZIndex or 12
	local categoryFilter = props.CategoryFilter
	local isBuyMode = props.IsBuyMode
	local onAdd = props.OnAdd

	local items = ShopData.GetItemsByCategory(categoryFilter)

	local cardElements = {}
	for i, itemConfig in ipairs(items) do
		local buyPrice = ShopData.GetBuyPrice(itemConfig.name)
		local sellPrice = ShopData.GetSellPrice(itemConfig.name)

		cardElements["Item_" .. itemConfig.name] = Roact.createElement(ShopItemCard, {
			LayoutOrder = i + 1,
			ItemConfig = itemConfig,
			BuyPrice = buyPrice,
			SellPrice = sellPrice,
			IsBuyMode = isBuyMode,
			OnAdd = isBuyMode and onAdd or nil,
			ZIndex = baseZIndex,
		})
	end

	return Roact.createElement("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),

		Filter = Roact.createElement(CategoryFilter, {
			ZIndex = baseZIndex,
			LayoutOrder = 0,
		}),

		ItemScroll = Roact.createElement("ScrollingFrame", {
			Size = UDim2.fromScale(1, 0.9),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = true,
			ScrollBarThickness = Config.ScrollBarThickness,
			ScrollBarImageColor3 = Config.ScrollBarColor,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = baseZIndex,
			LayoutOrder = 1,
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
		}),
	})
end

ShopItemList = RoactHooks.new(Roact)(ShopItemList)
return ShopItemList

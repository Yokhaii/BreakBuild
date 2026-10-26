local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local ShopActions = require(Client.Rodux.Actions.ShopActions)
local InventoryActions = require(Client.Rodux.Actions.InventoryActions)

local Components = Client.Roact.Components
local ItemSlot = require(Components.Global.ItemSlot)
local CloseButton = require(Components.Global.CloseButton)

local Images = require(ReplicatedStorage.Shared.Data.Images)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local Config = require(script.Config)

local function BasketPanel(props, hooks)
	local baseZIndex = props.ZIndex or 12
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd

	local shopState = RoduxHooks.useSelector(hooks, function(state)
		return state.ShopReducer
	end)

	local mode = shopState.Mode
	local isBuyMode = mode == "Buy"

	local slotElements = {}

	if isBuyMode then
		local basket = shopState.Basket
		local i = 0
		for itemName, quantity in pairs(basket) do
			i = i + 1
			local itemConfig = ItemData.GetItem(itemName)
			local image = Images[itemName] or ""
			local displayName = itemConfig and (itemConfig.displayName or itemConfig.name) or itemName

			slotElements["Basket_" .. itemName] = Roact.createElement("Frame", {
				Size = UDim2.fromScale(1 / Config.GridColumns - 0.03, 1 / Config.GridColumns - 0.03),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				ZIndex = baseZIndex,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				Slot = Roact.createElement(ItemSlot, {
					Size = UDim2.fromScale(1, 1),
					Image = image,
					ItemName = displayName,
					Quantity = quantity,
					OnHoverStart = onHoverStart,
					OnHoverEnd = onHoverEnd,
					ZIndex = baseZIndex,
				}),
				RemoveButton = Roact.createElement(CloseButton, {
					Position = Config.CloseButtonPosition,
					AnchorPoint = Config.CloseButtonAnchorPoint,
					Size = Config.CloseButtonSize,
					ZIndex = baseZIndex + 5,
					OnClick = function()
						Store:dispatch(ShopActions.removeFromBasket(itemName))
					end,
				}),
			})
		end
	else
		local sellPool = shopState.SellPool
		local aggregated = {}
		local entryMap = {}
		for _, entry in ipairs(sellPool) do
			if aggregated[entry.itemName] then
				aggregated[entry.itemName] = aggregated[entry.itemName] + entry.quantity
			else
				aggregated[entry.itemName] = entry.quantity
			end
			if not entryMap[entry.itemName] then
				entryMap[entry.itemName] = {}
			end
			table.insert(entryMap[entry.itemName], entry)
		end

		local i = 0
		for itemName, quantity in pairs(aggregated) do
			i = i + 1
			local itemConfig = ItemData.GetItem(itemName)
			local image = Images[itemName] or ""
			local displayName = itemConfig and (itemConfig.displayName or itemConfig.name) or itemName

			slotElements["Sell_" .. itemName] = Roact.createElement("Frame", {
				Size = UDim2.fromScale(1 / Config.GridColumns - 0.03, 1 / Config.GridColumns - 0.03),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				ZIndex = baseZIndex,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				Slot = Roact.createElement(ItemSlot, {
					Size = UDim2.fromScale(1, 1),
					Image = image,
					ItemName = displayName,
					Quantity = quantity,
					OnHoverStart = onHoverStart,
					OnHoverEnd = onHoverEnd,
					ZIndex = baseZIndex,
				}),
				RemoveButton = Roact.createElement(CloseButton, {
					Position = Config.CloseButtonPosition,
					AnchorPoint = Config.CloseButtonAnchorPoint,
					Size = Config.CloseButtonSize,
					ZIndex = baseZIndex + 5,
					OnClick = function()
						local entries = entryMap[itemName]
						if entries then
							for _, entry in ipairs(entries) do
								if entry.gridIndex and entry.itemId then
									Store:dispatch(InventoryActions.restoreGridSlot(entry.gridIndex, {
										id = entry.itemId,
										itemName = entry.itemName,
										quantity = entry.quantity,
									}))
								end
							end
						end
						Store:dispatch(ShopActions.removeFromSellPool(itemName))
					end,
				}),
			})
		end
	end

	local hasItems = next(slotElements) ~= nil

	return Roact.createElement("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, {
		EmptyLabel = (not hasItems) and Roact.createElement("TextLabel", {
			Size = UDim2.fromScale(0.8, 0.2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = (not isBuyMode) and Config.EmptyText or "",
			TextColor3 = Config.EmptyTextColor,
			TextScaled = true,
			FontFace = Config.EmptyFont,
			TextWrapped = true,
			ZIndex = baseZIndex,
		}) or nil,

		ItemGrid = hasItems and Roact.createElement("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
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
				PaddingTop = Config.Padding,
				PaddingBottom = Config.Padding,
				PaddingLeft = Config.Padding,
				PaddingRight = Config.Padding,
			}),

			UIGridLayout = Roact.createElement("UIGridLayout", {
				CellSize = UDim2.fromScale(1 / Config.GridColumns - 0.03, 1 / Config.GridColumns - 0.03),
				CellPadding = Config.CellPadding,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),

			Slots = Roact.createFragment(slotElements),
		}) or nil,
	})
end

BasketPanel = RoactHooks.new(Roact)(BasketPanel)
return BasketPanel

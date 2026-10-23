--[=[
	Shop Application
	Mounted as a child of the Backpack's InventoryFrame when CurrentFrame == "Shop".
	Three-panel layout: left catalog, right basket, top action bar + mode toggle.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local ShopActions = require(Client.Rodux.Actions.ShopActions)
local InventoryActions = require(Client.Rodux.Actions.InventoryActions)

local Components = Client.Roact.Components
local PanelFrame = require(Components.Frames.PanelFrame)
local TopPanelFrame = require(Components.Frames.TopPanelFrame)
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local ShopData = require(ReplicatedStorage.Shared.Data.ShopData)

local ModeToggle = require(script.Components.ModeToggle)
local ShopItemList = require(script.Components.ShopItemList)
local BasketPanel = require(script.Components.BasketPanel)

local Config = require(script.Config)

local SELL_DROP_ZONE_ID = "shop_sell_zone"

local function ShopApplication(props, hooks)
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd

	local shopState = RoduxHooks.useSelector(hooks, function(state)
		return state.ShopReducer
	end)

	local mode = shopState.Mode
	local basket = shopState.Basket
	local sellPool = shopState.SellPool
	local balance = shopState.Balance
	local categoryFilter = shopState.CategoryFilter
	local isBuyMode = mode == "Buy"

	local sellPanelRef = hooks.useValue(Roact.createRef())

	hooks.useEffect(function()
		local frame = sellPanelRef.value:getValue()
		if not frame then return end

		local InventoryController = Knit.GetController("InventoryController")
		if not InventoryController then return end

		local cleanup = InventoryController:RegisterDropZone(
			SELL_DROP_ZONE_ID,
			nil,
			frame,
			function(item, fromGridIndex)
				if not item or not item.itemName then return end
				local currentMode = Store:getState().ShopReducer.Mode
				if currentMode ~= "Sell" then return end
				Store:dispatch(InventoryActions.removeGridSlot(fromGridIndex))
				Store:dispatch(ShopActions.addToSellPool(item.itemName, item.quantity or 1, item.id, fromGridIndex))
			end
		)

		return cleanup
	end, {})

	local function onAddToBasket(itemName, quantity)
		Store:dispatch(ShopActions.addToBasket(itemName, quantity))
	end

	local totalCost = 0
	if isBuyMode then
		for itemName, qty in pairs(basket) do
			local price = ShopData.GetBuyPrice(itemName)
			if price then
				totalCost = totalCost + (price * qty)
			end
		end
	else
		for _, entry in ipairs(sellPool) do
			local price = ShopData.GetSellPrice(entry.itemName)
			if price then
				totalCost = totalCost + (price * entry.quantity)
			end
		end
	end

	local canAction = false
	if isBuyMode then
		canAction = totalCost > 0 and totalCost <= balance
	else
		canAction = totalCost > 0
	end

	local function onAction()
		if not canAction then return end
		local ShopController = Knit.GetController("ShopController")
		if not ShopController then return end

		if isBuyMode then
			ShopController:BuyItems(basket)
		else
			local sellTable = {}
			for _, entry in ipairs(sellPool) do
				sellTable[entry.itemName] = (sellTable[entry.itemName] or 0) + entry.quantity
			end
			ShopController:SellItems(sellTable)
		end
	end

	local actionButtonColor
	if not canAction then
		actionButtonColor = Config.DisabledButtonColor
	elseif isBuyMode then
		actionButtonColor = Config.BuyButtonColor
	else
		actionButtonColor = Config.SellButtonColor
	end

	local totalText
	if isBuyMode then
		totalText = "Total: $" .. tostring(totalCost)
	else
		totalText = "Value: $" .. tostring(totalCost)
	end

	-- Top panel content
	local topPanelChildren = {}

	topPanelChildren.Title = Roact.createElement(FancyText, {
		Text = Config.TitleText,
		AnchorPoint = Config.TitleAnchorPoint,
		Position = Config.TitlePosition,
		Size = Config.TitleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = Config.TitleZIndex,
	})

	topPanelChildren.Balance = Roact.createElement(FancyText, {
		Text = "Balance: $" .. tostring(balance),
		Position = Config.BalancePosition,
		AnchorPoint = Config.BalanceAnchorPoint,
		Size = Config.BalanceSize,
		TextColor3 = Config.BalanceColor,
		StrokeColor = Color3.fromRGB(0, 0, 0),
		StrokeThickness = 1.5,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 14,
	})

	topPanelChildren.TotalLabel = Roact.createElement(FancyText, {
		Text = totalText,
		Position = Config.TotalPosition,
		AnchorPoint = Config.TotalAnchorPoint,
		Size = Config.TotalSize,
		TextColor3 = Config.TotalColor,
		StrokeColor = Color3.fromRGB(0, 0, 0),
		StrokeThickness = 1.5,
		ZIndex = 14,
	})

	topPanelChildren.ActionButton = Roact.createElement("TextButton", {
		Size = Config.ActionButtonSize,
		Position = Config.ActionButtonPosition,
		AnchorPoint = Config.ActionButtonAnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = isBuyMode and "Buy" or "Sell",
		TextColor3 = Config.ActionButtonTextColor,
		TextScaled = true,
		FontFace = Config.ActionButtonFont,
		ZIndex = 14,
		AutoButtonColor = false,
		[Roact.Event.MouseButton1Click] = onAction,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.ActionButtonCornerRadius,
		}),
		StudBackground = Roact.createElement(StudBackground, {
			ZIndex = 12,
			BackgroundColor = actionButtonColor,
			ImageTransparency = Config.ActionButtonStudImageTransparency,
			CornerRadius = Config.ActionButtonCornerRadius,
		}),
		UIPadding = Roact.createElement("UIPadding", {
			PaddingLeft = Config.ActionButtonPaddingH,
			PaddingRight = Config.ActionButtonPaddingH,
			PaddingTop = Config.ActionButtonPaddingV,
			PaddingBottom = Config.ActionButtonPaddingV,
		}),
	})

	local leftPanelTitle = isBuyMode and "Buy Items" or "Sell Prices"
	local rightPanelTitle = isBuyMode and "Basket" or "Sell Pool"

	return Roact.createFragment({
		ShopModeToggle = Roact.createElement(ModeToggle, {
			ZIndex = 11,
		}),

		ShopCatalogPanel = Roact.createElement(PanelFrame, {
			Name = "ShopCatalogPanel",
			AnchorPoint = Config.PanelAnchorPoint,
			Position = Config.PanelPosition,
			Size = Config.PanelSize,
			AspectRatio = Config.PanelAspectRatio,
			Title = leftPanelTitle,
			ZIndex = 11,
		}, {
			ShopItemList = Roact.createElement(ShopItemList, {
				Size = UDim2.fromScale(1, 1),
				CategoryFilter = categoryFilter,
				IsBuyMode = isBuyMode,
				OnAdd = onAddToBasket,
				ZIndex = 12,
			}),
		}),

		ShopBasketPanel = Roact.createElement(PanelFrame, {
			Name = "ShopBasketPanel",
			AnchorPoint = Config.RightPanelAnchorPoint,
			Position = Config.RightPanelPosition,
			Size = Config.RightPanelSize,
			AspectRatio = Config.RightPanelAspectRatio,
			Title = rightPanelTitle,
			ZIndex = 11,
			[Roact.Ref] = sellPanelRef.value,
		}, {
			BasketContent = Roact.createElement(BasketPanel, {
				Size = UDim2.fromScale(1, 1),
				OnHoverStart = onHoverStart,
				OnHoverEnd = onHoverEnd,
				ZIndex = 12,
			}),
		}),

		ShopTopPanel = Roact.createElement(TopPanelFrame, {
			Name = "ShopTopPanel",
			AnchorPoint = Config.TopPanelAnchorPoint,
			Position = Config.TopPanelPosition,
			Size = Config.TopPanelSize,
			ZIndex = 11,
		}, topPanelChildren),
	})
end

ShopApplication = RoactHooks.new(Roact)(ShopApplication)
return ShopApplication

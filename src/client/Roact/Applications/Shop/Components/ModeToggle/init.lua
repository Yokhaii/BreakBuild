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
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function ModeToggle(props, hooks)
	local mode = RoduxHooks.useSelector(hooks, function(state)
		return state.ShopReducer.Mode
	end)

	local baseZIndex = props.ZIndex or 11

	local function restoreSellPool()
		local pool = Store:getState().ShopReducer.SellPool
		for _, entry in ipairs(pool) do
			if entry.gridIndex and entry.itemId then
				Store:dispatch(InventoryActions.restoreGridSlot(entry.gridIndex, {
					id = entry.itemId,
					itemName = entry.itemName,
					quantity = entry.quantity,
				}))
			end
		end
	end

	local function onBuyClick()
		if mode ~= "Buy" then
			restoreSellPool()
			Store:dispatch(ShopActions.setMode("Buy"))
		end
	end

	local function onSellClick()
		if mode ~= "Sell" then
			Store:dispatch(ShopActions.setMode("Sell"))
		end
	end

	local buyColor = mode == "Buy" and Config.BuyActiveColor or Config.BuyInactiveColor
	local sellColor = mode == "Sell" and Config.SellActiveColor or Config.SellInactiveColor

	return Roact.createElement("Frame", {
		Size = Config.Size,
		Position = Config.Position,
		AnchorPoint = Config.AnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = Config.ButtonSpacing,
		}),

		BuyButton = Roact.createElement("TextButton", {
			Size = Config.ButtonSize,
			BackgroundTransparency = 1,
			Text = "Buy",
			TextColor3 = Config.ButtonTextColor,
			TextScaled = true,
			FontFace = Config.ButtonFont,
			AutoButtonColor = false,
			LayoutOrder = 1,
			ZIndex = baseZIndex + 2,
			[Roact.Event.MouseButton1Click] = onBuyClick,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.ButtonCornerRadius,
			}),
			StudBackground = Roact.createElement(StudBackground, {
				ZIndex = baseZIndex + 1,
				BackgroundColor = buyColor,
				ImageTransparency = Config.ButtonStudImageTransparency,
				CornerRadius = Config.ButtonCornerRadius,
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.ButtonPaddingH,
				PaddingRight = Config.ButtonPaddingH,
				PaddingTop = Config.ButtonPaddingV,
				PaddingBottom = Config.ButtonPaddingV,
			}),
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 2.5,
			}),
		}),

		SellButton = Roact.createElement("TextButton", {
			Size = Config.ButtonSize,
			BackgroundTransparency = 1,
			Text = "Sell",
			TextColor3 = Config.ButtonTextColor,
			TextScaled = true,
			FontFace = Config.ButtonFont,
			AutoButtonColor = false,
			LayoutOrder = 2,
			ZIndex = baseZIndex + 2,
			[Roact.Event.MouseButton1Click] = onSellClick,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.ButtonCornerRadius,
			}),
			StudBackground = Roact.createElement(StudBackground, {
				ZIndex = baseZIndex + 1,
				BackgroundColor = sellColor,
				ImageTransparency = Config.ButtonStudImageTransparency,
				CornerRadius = Config.ButtonCornerRadius,
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.ButtonPaddingH,
				PaddingRight = Config.ButtonPaddingH,
				PaddingTop = Config.ButtonPaddingV,
				PaddingBottom = Config.ButtonPaddingV,
			}),
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 2.5,
			}),
		}),
	})
end

ModeToggle = RoactHooks.new(Roact)(ModeToggle)
return ModeToggle

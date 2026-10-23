local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function ShopItemCard(props, hooks)
	local baseZIndex = props.ZIndex or 1
	local itemConfig = props.ItemConfig
	local buyPrice = props.BuyPrice
	local sellPrice = props.SellPrice
	local isBuyMode = props.IsBuyMode
	local onAdd = props.OnAdd

	local itemImage = Images[itemConfig.name] or ""

	local priceText
	local priceColor
	if isBuyMode then
		priceText = "$" .. tostring(buyPrice)
		priceColor = Config.PriceColor
	else
		priceText = "$" .. tostring(sellPrice)
		priceColor = Config.PriceSellColor
	end

	local actionButtons = nil
	if isBuyMode and onAdd then
		actionButtons = Roact.createElement("Frame", {
			Size = Config.ButtonContainerSize,
			Position = Config.ButtonContainerPosition,
			AnchorPoint = Config.ButtonContainerAnchorPoint,
			BackgroundTransparency = 1,
			ZIndex = baseZIndex + 3,
		}, {
			UIListLayout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = Config.ButtonSpacing,
			}),

			Add1 = Roact.createElement("TextButton", {
				Size = UDim2.fromScale(0.45, 0.7),
				BackgroundTransparency = 1,
				Text = "+1",
				TextColor3 = Config.ButtonTextColor,
				TextScaled = true,
				FontFace = Config.ButtonFont,
				AutoButtonColor = false,
				LayoutOrder = 1,
				ZIndex = baseZIndex + 5,
				[Roact.Event.MouseButton1Click] = function()
					onAdd(itemConfig.name, 1)
				end,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1.2,
				}),
				UICorner = Roact.createElement("UICorner", {
					CornerRadius = Config.ButtonCornerRadius,
				}),
				StudBackground = Roact.createElement(StudBackground, {
					ZIndex = baseZIndex + 4,
					BackgroundColor = Config.ButtonColor,
					ImageTransparency = Config.ButtonStudImageTransparency,
					CornerRadius = Config.ButtonCornerRadius,
				}),
			}),

			Add10 = Roact.createElement("TextButton", {
				Size = UDim2.fromScale(0.45, 0.7),
				BackgroundTransparency = 1,
				Text = "+10",
				TextColor3 = Config.ButtonTextColor,
				TextScaled = true,
				FontFace = Config.ButtonFont,
				AutoButtonColor = false,
				LayoutOrder = 2,
				ZIndex = baseZIndex + 5,
				[Roact.Event.MouseButton1Click] = function()
					onAdd(itemConfig.name, 10)
				end,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1.2,
				}),
				UICorner = Roact.createElement("UICorner", {
					CornerRadius = Config.ButtonCornerRadius,
				}),
				StudBackground = Roact.createElement(StudBackground, {
					ZIndex = baseZIndex + 4,
					BackgroundColor = Config.ButtonColor,
					ImageTransparency = Config.ButtonStudImageTransparency,
					CornerRadius = Config.ButtonCornerRadius,
				}),
			}),
		})
	end

	return Roact.createElement("ImageButton", {
		Size = props.Size or Config.CardSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
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
					Image = itemImage,
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
					Text = itemConfig.displayName or itemConfig.name,
					Size = Config.TitleSize,
					TextColor3 = Config.TitleColor,
					StrokeColor = Config.TitleStrokeColor,
					StrokeThickness = Config.TitleStrokeThickness,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				Price = Roact.createElement(FancyText, {
					Text = priceText,
					Size = Config.PriceSize,
					TextColor3 = priceColor,
					StrokeColor = Color3.fromRGB(0, 0, 0),
					StrokeThickness = 1.5,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}),
			}),
		}),

		ActionButtons = actionButtons,
	})
end

ShopItemCard = RoactHooks.new(Roact)(ShopItemCard)
return ShopItemCard

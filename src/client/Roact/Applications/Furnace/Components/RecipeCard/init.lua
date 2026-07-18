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

local FUEL_CYCLE_INTERVAL = 1.5

local function RecipeCard(props, hooks)
	local baseZIndex = props.ZIndex or 1
	local recipe = props.Recipe
	local isSelected = props.IsSelected or false
	local isLocked = props.IsLocked or false

	local fuelIndex, setFuelIndex = hooks.useState(1)

	hooks.useEffect(function()
		local hasFuelInput = false
		for _, input in ipairs(recipe.inputs or {}) do
			if input.fuelTier then
				hasFuelInput = true
				break
			end
		end
		if not hasFuelInput then return end

		local running = true
		task.spawn(function()
			while running do
				task.wait(FUEL_CYCLE_INTERVAL)
				if not running then break end
				setFuelIndex(function(prev)
					return prev + 1
				end)
			end
		end)

		return function()
			running = false
		end
	end, {})

	local function onClick()
		if isLocked then return end
		if props.OnSelect then
			props.OnSelect(recipe.id)
		end
	end

	local materialElements = {}
	if recipe.inputs then
		for i, input in ipairs(recipe.inputs) do
			local inputImage
			local displayQuantity = input.quantity
			if input.fuelTier then
				local fuels = ItemData.GetFuelsByTier(input.fuelTier)
				if #fuels > 0 then
					local idx = ((fuelIndex - 1) % #fuels) + 1
					local fuel = fuels[idx]
					inputImage = Images[fuel.name] or ""
					local multiplier = math.floor(fuel.fuelValue / input.fuelTier)
					displayQuantity = math.ceil(input.quantity / multiplier)
				else
					inputImage = ""
				end
			else
				inputImage = Images[input.itemName] or ""
			end
			materialElements["Material_" .. i] = Roact.createElement("Frame", {
				Size = Config.MaterialFrameSize,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				ZIndex = baseZIndex + 4,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = Config.MaterialAspectRatio,
				}),
				Icon = Roact.createElement("ImageLabel", {
					Size = Config.MaterialIconSize,
					Position = UDim2.fromScale(0, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = inputImage,
					ImageColor3 = Color3.new(1, 1, 1),
					ZIndex = baseZIndex + 4,
				}, {
					UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
				Amount = Roact.createElement("TextLabel", {
					Size = Config.MaterialAmountSize,
					Position = Config.MaterialAmountPosition,
					BackgroundTransparency = 1,
					Text = tostring(displayQuantity),
					TextColor3 = Config.MaterialTextColor,
					TextScaled = true,
					FontFace = Config.MaterialFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = baseZIndex + 4,
				}),
			})
		end
	end

	local outputImage = Images[recipe.outputs[1].itemName] or ""

	local strokeColor = isSelected and Config.SelectedStrokeColor or Config.CardStrokeColor
	local strokeTransparency = isSelected and Config.SelectedStrokeTransparency or Config.CardStrokeTransparency
	if isLocked then
		strokeTransparency = Config.LockedStrokeTransparency
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
		[Roact.Event.MouseButton1Click] = onClick,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = Config.CardStrokeThickness,
			Transparency = strokeTransparency,
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
				RecipeIcon = Roact.createElement("ImageLabel", {
					Size = Config.RecipeIconSize,
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = outputImage,
					ImageColor3 = Color3.new(1, 1, 1),
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
					Text = recipe.displayName,
					Size = Config.TitleSize,
					TextColor3 = Config.TitleColor,
					StrokeColor = Config.TitleStrokeColor,
					StrokeThickness = Config.TitleStrokeThickness,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				MaterialsContainer = Roact.createElement("Frame", {
					Size = Config.MaterialsContainerSize,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}, {
					UIListLayout = Roact.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = Config.InfoLayoutPadding,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Materials = Roact.createFragment(materialElements),
				}),
			}),
		}),

		RemoveButton = (isSelected and props.OnRemove) and Roact.createElement("TextButton", {
			Size = Config.RemoveButtonSize,
			Position = Config.RemoveButtonPosition,
			AnchorPoint = Config.RemoveButtonAnchorPoint,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = Config.RemoveButtonText,
			TextColor3 = Config.RemoveButtonTextColor,
			TextScaled = true,
			FontFace = Config.RemoveButtonFont,
			ZIndex = baseZIndex + 6,
			AutoButtonColor = false,
			[Roact.Event.MouseButton1Click] = function()
				props.OnRemove()
			end,
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.RemoveButtonCornerRadius,
			}),
			StudBackground = Roact.createElement(StudBackground, {
				ZIndex = baseZIndex + 5,
				BackgroundColor = Config.RemoveButtonColor,
				ImageTransparency = Config.RemoveButtonStudImageTransparency,
				CornerRadius = Config.RemoveButtonCornerRadius,
			}),
		}) or nil,

		LockedOverlay = isLocked and Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = Config.LockedOverlayTransparency,
			ZIndex = baseZIndex + 10,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),
		}) or nil,
	})
end

RecipeCard = RoactHooks.new(Roact)(RecipeCard)
return RecipeCard

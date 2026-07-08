--[=[
	BlueprintCard Component
	Same visual design as RecipeCard: StudBackground card, dark image box on the
	left showing the CompletedBlueprint icon, title + description on the right.
	Supports selected highlight and locked overlay.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function BlueprintCard(props, hooks)
	local baseZIndex  = props.ZIndex or 1
	local isUnlocked  = props.IsUnlocked ~= false
	local isSelected  = props.IsSelected or false

	-- Icon lives under "Completed<Name>" in the Images table
	local icon = Images["Completed" .. (props.Name or "")] or ""

	local strokeColor        = isSelected and Config.SelectedStrokeColor or Config.CardStrokeColor
	local strokeTransparency = isSelected and Config.SelectedStrokeTransparency or Config.CardStrokeTransparency

	local function onClick()
		if props.OnClick then
			props.OnClick(props.BlueprintData)
		end
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
				PaddingLeft   = Config.ContentPaddingLeft,
				PaddingRight  = Config.ContentPaddingRight,
				PaddingTop    = Config.ContentPaddingTop,
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
				Icon = Roact.createElement("ImageLabel", {
					Size = Config.IconSize,
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = icon,
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
					Text = props.Name or "Blueprint",
					Size = Config.TitleSize,
					TextColor3 = Config.TitleColor,
					StrokeColor = Config.TitleStrokeColor,
					StrokeThickness = Config.TitleStrokeThickness,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				Description = Roact.createElement("TextLabel", {
					Size = Config.DescriptionSize,
					BackgroundTransparency = 1,
					Text = props.Description or "",
					TextColor3 = Config.DescriptionColor,
					TextScaled = true,
					FontFace = Config.DescriptionFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}),
			}),
		}),

		LockedOverlay = not isUnlocked and Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = Config.LockedOverlayTransparency,
			ZIndex = baseZIndex + 10,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),
			LockText = Roact.createElement(FancyText, {
				Text = "Unlock at Rebirth " .. (props.RequiredRebirth or 1),
				Size = UDim2.fromScale(0.8, 0.3),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				TextColor3 = Config.LockedTextColor,
				StrokeColor = Color3.fromRGB(0, 0, 0),
				StrokeThickness = 2,
				ZIndex = baseZIndex + 11,
			}),
		}) or nil,
	})
end

BlueprintCard = RoactHooks.new(Roact)(BlueprintCard)
return BlueprintCard

--[=[
	UnlockedBlueprintCard Component
	Displays an unlocked blueprint with image, title, description, and required materials
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function UnlockedBlueprintCard(props, hooks)
	local baseZIndex = props.ZIndex or 1

	local function onClick()
		if props.OnClick then
			props.OnClick(props.BlueprintData)
		end
	end

	-- Build material icons
	local materialElements = {}
	if props.Materials then
		for i, material in ipairs(props.Materials) do
			materialElements["Material_" .. i] = Roact.createElement("Frame", {
				Size = UDim2.fromScale(0.15, 1),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				ZIndex = baseZIndex + 4,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 2.5,
				}),
				Icon = Roact.createElement("ImageLabel", {
					Size = UDim2.fromScale(0.4, 0.8),
					Position = UDim2.fromScale(0, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = Config.MaterialIcons[material.Type] or "",
					ImageColor3 = Color3.new(1, 1, 1),
					ZIndex = baseZIndex + 4,
				}, {
					UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
				Amount = Roact.createElement("TextLabel", {
					Size = UDim2.fromScale(0.55, 1),
					Position = UDim2.fromScale(0.45, 0),
					BackgroundTransparency = 1,
					Text = tostring(material.Amount),
					TextColor3 = Config.MaterialTextColor,
					TextScaled = true,
					FontFace = Config.MaterialFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = baseZIndex + 4,
				}),
			})
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
				PaddingLeft = UDim.new(0.02, 0),
				PaddingRight = UDim.new(0.02, 0),
				PaddingTop = UDim.new(0.05, 0),
				PaddingBottom = UDim.new(0.05, 0),
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
				BlueprintIcon = Roact.createElement("ImageLabel", {
					Size = UDim2.fromScale(0.8, 0.8),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = props.Image or "",
					ImageColor3 = Color3.new(1, 1, 1),
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = baseZIndex + 3,
				}),
			}),

			InfoContainer = Roact.createElement("Frame", {
				Size = UDim2.fromScale(0.73, 1),
				Position = UDim2.fromScale(0.18, 0),
				BackgroundTransparency = 1,
				ZIndex = baseZIndex + 3,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0.02, 0),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				Title = Roact.createElement(FancyText, {
					Text = props.Title or "Blueprint",
					Size = UDim2.fromScale(1, 0.25),
					TextColor3 = Config.TitleColor,
					StrokeColor = Config.TitleStrokeColor,
					StrokeThickness = Config.TitleStrokeThickness,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				Description = Roact.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 0.4),
					BackgroundTransparency = 1,
					Text = props.Description or "No description",
					TextColor3 = Config.DescriptionColor,
					TextScaled = true,
					FontFace = Config.DescriptionFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}),

				MaterialsContainer = Roact.createElement("Frame", {
					Size = UDim2.fromScale(1, 0.25),
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					ZIndex = baseZIndex + 4,
				}, {
					UIListLayout = Roact.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0.02, 0),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Materials = Roact.createFragment(materialElements),
				}),
			}),
		}),
	})
end

UnlockedBlueprintCard = RoactHooks.new(Roact)(UnlockedBlueprintCard)
return UnlockedBlueprintCard

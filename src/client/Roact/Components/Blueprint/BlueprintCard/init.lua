--[=[
	BlueprintCard Component
	Displays a single blueprint with image, title, description, and required materials
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function BlueprintCard(props, hooks)
	local isUnlocked = props.IsUnlocked ~= false
	local requiredRebirth = props.RequiredRebirth or 1
	local baseZIndex = props.ZIndex or 1

	local function onClick()
		if not isUnlocked then return end
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
					ImageColor3 = isUnlocked and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150),
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
					TextColor3 = isUnlocked and Config.MaterialTextColor or Color3.fromRGB(150, 150, 150),
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
		-- Corner rounding
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		-- Card stroke
		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.CardStrokeColor,
			Thickness = Config.CardStrokeThickness,
			Transparency = Config.CardStrokeTransparency,
		}),

		-- Card StudBackground
		CardBackground = Roact.createElement(StudBackground, {
			ZIndex = baseZIndex + 1,
			BackgroundColor = isUnlocked and Config.CardStudBackgroundColor or Config.LockedStudBackgroundColor,
			ImageTransparency = isUnlocked and Config.CardStudImageTransparency or Config.LockedStudImageTransparency,
			CornerRadius = Config.CornerRadius,
		}),

		-- Content container with padding
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

			-- Blueprint Image container (left side)
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
				-- Image StudBackground
				ImageBackground = Roact.createElement(StudBackground, {
					ZIndex = baseZIndex + 2,
					BackgroundColor = Config.ImageStudBackgroundColor,
					ImageTransparency = Config.ImageStudImageTransparency,
					CornerRadius = Config.ImageCornerRadius,
				}),
				-- Blueprint icon
				BlueprintIcon = Roact.createElement("ImageLabel", {
					Size = UDim2.fromScale(0.8, 0.8),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = props.Image or "",
					ImageColor3 = isUnlocked and Color3.new(1, 1, 1) or Color3.fromRGB(100, 100, 100),
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = baseZIndex + 3,
				}),
			}),

			-- Info container (right side)
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

				-- Title
				Title = Roact.createElement(FancyText, {
					Text = props.Title or "Blueprint",
					Size = UDim2.fromScale(1, 0.25),
					TextColor3 = isUnlocked and Config.TitleColor or Color3.fromRGB(150, 150, 150),
					StrokeColor = Config.TitleStrokeColor,
					StrokeThickness = Config.TitleStrokeThickness,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				-- Description
				Description = Roact.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 0.4),
					BackgroundTransparency = 1,
					Text = props.Description or "No description",
					TextColor3 = isUnlocked and Config.DescriptionColor or Color3.fromRGB(120, 120, 120),
					TextScaled = true,
					FontFace = Config.DescriptionFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}),

				-- Materials container
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

		-- Locked overlay (only for locked cards)
		LockedOverlay = not isUnlocked and Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = Config.LockedOverlayTransparency,
			ZIndex = baseZIndex + 10,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),
			LockText = Roact.createElement(FancyText, {
				Text = "Unlock at Rebirth " .. requiredRebirth,
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

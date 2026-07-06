--[=[
	ItemSlot Component
	Generic square item slot with a StudBackground, optional item image, and optional click handler.
	Intended for reuse across inventory grids, crafting panels, item pickers, etc.

	Props:
		Image       (string?)  -- asset id to display inside the slot
		ZIndex      (number?)  -- base ZIndex; defaults to 1
		LayoutOrder (number?)  -- for use inside UIGridLayout
		OnClick     (function?) -- fired on MouseButton1Click
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function ItemSlot(props, _hooks)
	local zIndex = props.ZIndex or 1
	local image = props.Image
	local itemName = props.ItemName
	local onClickHandler = props.OnClick
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd

	local needsButton = onClickHandler or (itemName and onHoverStart)

	local function handleMouseEnter()
		if itemName and onHoverStart then
			onHoverStart(itemName)
		end
	end

	local function handleMouseLeave()
		if onHoverEnd then
			onHoverEnd()
		end
	end

	return Roact.createElement("Frame", {
		Name = props.Name or "ItemSlot",
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),

		UICorner = Roact.createElement("UICorner", {
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = props.StrokeColor or Config.StrokeColor,
			Thickness = props.StrokeThickness or Config.StrokeThickness,
			Transparency = props.StrokeTransparency or Config.StrokeTransparency,
		}),

		SlotBackground = Roact.createElement(StudBackground, {
			ZIndex = zIndex + 1,
			BackgroundColor = props.BackgroundColor or Config.BackgroundColor,
			ImageTransparency = props.StudImageTransparency or Config.StudImageTransparency,
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		ItemImage = image and Roact.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.75, 0.75),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = image,
			ImageTransparency = props.ImageTransparency or 0,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = zIndex + 2,
		}) or nil,

		Button = needsButton and Roact.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = zIndex + 3,
			[Roact.Event.MouseButton1Click] = onClickHandler,
			[Roact.Event.MouseEnter] = handleMouseEnter,
			[Roact.Event.MouseLeave] = handleMouseLeave,
		}) or nil,

		QuantityLabel = props.Quantity and Roact.createElement("TextLabel", {
			Size = UDim2.fromScale(0.6, 0.38),
			Position = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Text = tostring(props.Quantity),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = zIndex + 4,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		}) or nil,
	})
end

ItemSlot = RoactHooks.new(Roact)(ItemSlot)
return ItemSlot

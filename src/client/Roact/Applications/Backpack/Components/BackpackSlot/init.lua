--[=[
	BackpackSlot Component
	Used in the inventory overlay grid for both backpack and hotbar slots.
	Drag starts immediately on mouse down (no hold delay).
	Registers itself as a drop zone via InventoryController.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function BackpackSlot(props, hooks)
	local gridIndex = props.gridIndex
	local item = props.item
	local isHotbarSlot = props.isHotbarSlot or false
	local isEquipped = props.isEquipped or false
	local onDragStart = props.onDragStart
	local onHoverStart = props.onHoverStart
	local onHoverEnd = props.onHoverEnd
	local layoutOrder = props.LayoutOrder or props.index

	local isEmpty = item == nil
	local displayAmount = ""
	local itemImage = nil

	if item then
		itemImage = Images[item.itemName]

		if item.quantity and item.quantity > 1 then
			displayAmount = "x" .. tostring(item.quantity)
		end
	end

	local buttonRef = hooks.useValue(Roact.createRef())

	-- Register this slot as a drop zone
	hooks.useEffect(function()
		local button = buttonRef.value:getValue()
		if not button then return end

		local InventoryController = Knit.GetController("InventoryController")
		if not InventoryController then return end

		local cleanup = InventoryController:RegisterDropZone(
			"backpack_slot_" .. gridIndex,
			gridIndex,
			button
		)

		return cleanup
	end, { gridIndex })

	local function handleMouseDown()
		if isEmpty then return end
		if onHoverEnd then
			onHoverEnd()
		end
		if onDragStart then
			onDragStart(gridIndex, item)
		end
	end

	local function handleMouseEnter()
		if isEmpty then return end
		if onHoverStart then
			onHoverStart(item.itemName)
		end
	end

	local function handleMouseLeave()
		if onHoverEnd then
			onHoverEnd()
		end
	end

	-- Equipped hotbar slots get golden stroke
	local strokeColor = isEquipped and Config.EquippedStrokeColor or Config.StrokeColor
	local strokeThickness = isEquipped and Config.EquippedStrokeThickness or Config.StrokeThickness
	local strokeTransparency = isEquipped and Config.EquippedStrokeTransparency or Config.StrokeTransparency

	local itemDisplay = nil
	if not isEmpty and itemImage then
		itemDisplay = Roact.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.75, 0.75),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = itemImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 14,
		})
	end

	return Roact.createElement("Frame", {
		Name = "Slot" .. gridIndex,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = true,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = strokeThickness,
			Transparency = strokeTransparency,
		}),

		SlotBackground = Roact.createElement(StudBackground, {
			ZIndex = 12,
			BackgroundColor = isHotbarSlot and Config.HotbarBackgroundColor or Config.BackgroundColor,
			ImageTransparency = Config.StudImageTransparency,
			CornerRadius = Config.CornerRadius,
		}),

		ItemDisplay = itemDisplay,

		Amount = displayAmount ~= "" and Roact.createElement(FancyText, {
			Text = displayAmount,
			Size = UDim2.fromScale(0.5, 0.3),
			Position = UDim2.fromScale(0.95, 0.95),
			AnchorPoint = Vector2.new(1, 1),
			TextColor3 = Config.AmountColor,
			StrokeColor = Config.AmountStrokeColor,
			StrokeThickness = Config.AmountStrokeThickness,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 15,
		}) or nil,

		Button = Roact.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 16,
			[Roact.Event.MouseButton1Down] = handleMouseDown,
			[Roact.Event.MouseEnter] = handleMouseEnter,
			[Roact.Event.MouseLeave] = handleMouseLeave,
			[Roact.Ref] = buttonRef.value,
		}),
	})
end

BackpackSlot = RoactHooks.new(Roact)(BackpackSlot)
return BackpackSlot

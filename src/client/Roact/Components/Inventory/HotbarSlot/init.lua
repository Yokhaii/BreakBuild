--[=[
	HotbarSlot Component
	Individual slot in the hotbar - styled as an image slot (like ImageContainer in BlueprintCard)
	Displays items using ViewportItem for 3D models, ImageLabel for icons, or text fallback
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)
local ViewportItem = require(Components.Global.ViewportItem)

local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local Config = require(script.Config)

-- Resolve a dot-separated path string to the actual instance
local function resolveModelPath(path: string)
	local parts = string.split(path, ".")
	local current = game

	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part)
		if not current then
			return nil
		end
	end

	return current
end

local function HotbarSlot(props, hooks)
	local slotNumber = props.slotNumber
	local item = props.item
	local isEquipped = props.isEquipped or false
	local isLocked = props.isLocked or false
	local onSlotClick = props.onSlotClick
	local onDragStart = props.onDragStart
	local baseZIndex = props.ZIndex or 1

	local isEmpty = item == nil
	local displayNumber = tostring(slotNumber)

	-- Resolve item data and model
	local itemConfig = nil
	local itemModel = nil
	local itemIcon = ""
	local displayAmount = ""

	if item then
		itemConfig = ItemData.GetItem(item.itemName)
		if itemConfig then
			itemIcon = itemConfig.icon or ""

			if itemConfig.modelPath then
				itemModel = resolveModelPath(itemConfig.modelPath)
			end
		end

		if item.quantity and item.quantity > 1 then
			displayAmount = "x" .. tostring(item.quantity)
		end
	end

	-- Hold detection for drag
	local isHolding, setIsHolding = hooks.useState(false)
	local holdStartTime, setHoldStartTime = hooks.useState(0)

	local function handleMouseDown()
		if isEmpty or isLocked then return end
		setIsHolding(true)
		setHoldStartTime(tick())

		task.spawn(function()
			task.wait(Config.DragHoldTime)
			if isHolding then
				if onDragStart then
					onDragStart(slotNumber, item)
				end
			end
		end)
	end

	local function handleMouseUp()
		if isLocked then
			if onSlotClick and not isEmpty then
				onSlotClick(slotNumber)
			end
			return
		end

		if isHolding and (tick() - holdStartTime) < Config.DragHoldTime then
			if onSlotClick then
				onSlotClick(slotNumber)
			end
		end
		setIsHolding(false)
	end

	-- Choose stroke based on equipped state
	local strokeColor = isEquipped and Config.EquippedStrokeColor or Config.ImageStrokeColor
	local strokeThickness = isEquipped and Config.EquippedStrokeThickness or Config.ImageStrokeThickness
	local strokeTransparency = isEquipped and Config.EquippedStrokeTransparency or Config.ImageStrokeTransparency

	-- Determine item display element
	local itemDisplay = nil
	if not isEmpty then
		if itemModel then
			-- 3D model via ViewportItem
			itemDisplay = Roact.createElement(ViewportItem, {
				Model = itemModel,
				Size = UDim2.fromScale(0.85, 0.85),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = baseZIndex + 2,
			})
		elseif itemIcon ~= "" then
			-- 2D icon fallback
			itemDisplay = Roact.createElement("ImageLabel", {
				Size = UDim2.fromScale(0.75, 0.75),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = itemIcon,
				ImageColor3 = isLocked and Color3.fromRGB(180, 180, 180) or Color3.new(1, 1, 1),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = baseZIndex + 2,
			})
		end
	end

	return Roact.createElement("ImageButton", {
		Name = tostring(slotNumber),
		Size = Config.SlotSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		LayoutOrder = slotNumber,
		ZIndex = baseZIndex,
		ClipsDescendants = true,
		[Roact.Event.MouseButton1Down] = handleMouseDown,
		[Roact.Event.MouseButton1Up] = handleMouseUp,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.ImageCornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = strokeThickness,
			Transparency = strokeTransparency,
		}),

		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),

		-- Image slot StudBackground (dark, like ImageContainer in BlueprintCard)
		ImageBackground = Roact.createElement(StudBackground, {
			ZIndex = baseZIndex + 1,
			BackgroundColor = isLocked and Config.LockedBackgroundColor or Config.ImageBackgroundColor,
			ImageTransparency = Config.ImageStudTransparency,
			CornerRadius = Config.ImageCornerRadius,
		}),

		-- Item display (ViewportItem, ImageLabel, or nil)
		ItemDisplay = itemDisplay,

		-- Slot number (top-left)
		Number = Roact.createElement(FancyText, {
			Text = displayNumber,
			Size = UDim2.fromScale(0.3, 0.3),
			Position = UDim2.fromScale(0.05, 0.02),
			AnchorPoint = Vector2.new(0, 0),
			TextColor3 = Config.NumberColor,
			StrokeColor = Config.NumberStrokeColor,
			StrokeThickness = Config.NumberStrokeThickness,
			ZIndex = baseZIndex + 3,
		}),

		-- Quantity amount (bottom-right)
		Amount = displayAmount ~= "" and Roact.createElement(FancyText, {
			Text = displayAmount,
			Size = UDim2.fromScale(0.5, 0.3),
			Position = UDim2.fromScale(0.95, 0.95),
			AnchorPoint = Vector2.new(1, 1),
			TextColor3 = Config.AmountColor,
			StrokeColor = Config.AmountStrokeColor,
			StrokeThickness = Config.AmountStrokeThickness,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = baseZIndex + 3,
		}) or nil,

		-- Lock icon for locked slots
		LockIndicator = isLocked and Roact.createElement("TextLabel", {
			Name = "LockIndicator",
			Size = UDim2.fromScale(0.25, 0.25),
			Position = UDim2.fromScale(0.95, 0.02),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Text = "🔒",
			TextScaled = true,
			ZIndex = baseZIndex + 3,
		}) or nil,
	})
end

HotbarSlot = RoactHooks.new(Roact)(HotbarSlot)
return HotbarSlot

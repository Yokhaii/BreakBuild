--[=[
	HotbarSlot Component
	Individual slot in the hotbar displaying item info
	Supports locked state for Build mode slot 1 (Hammer)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local function HotbarSlot(props, hooks)
	local slotNumber = props.slotNumber
	local item = props.item -- { id, itemName, quantity } or nil
	local isEquipped = props.isEquipped or false
	local isLocked = props.isLocked or false
	local onSlotClick = props.onSlotClick
	local onDragStart = props.onDragStart

	local isEmpty = item == nil
	local displayNumber = tostring(slotNumber) -- Now 1-6 only

	-- Get display name and quantity
	local displayName = ""
	local displayAmount = ""

	if item then
		-- Use itemName for now, can be enhanced to use ItemData for display names
		displayName = item.itemName or ""
		if item.quantity and item.quantity > 1 then
			displayAmount = "x" .. tostring(item.quantity)
		end
	end

	-- Hold detection for drag
	local isHolding, setIsHolding = hooks.useState(false)
	local holdStartTime, setHoldStartTime = hooks.useState(0)
	local DRAG_HOLD_TIME = 0.3

	local function handleMouseDown()
		if isEmpty or isLocked then return end
		setIsHolding(true)
		setHoldStartTime(tick())

		-- Check for drag after hold time
		task.spawn(function()
			task.wait(DRAG_HOLD_TIME)
			if isHolding then
				if onDragStart then
					onDragStart(slotNumber, item)
				end
			end
		end)
	end

	local function handleMouseUp()
		if isLocked then
			-- Locked slots can still be clicked to equip
			if onSlotClick and not isEmpty then
				onSlotClick(slotNumber)
			end
			return
		end

		if isHolding and (tick() - holdStartTime) < DRAG_HOLD_TIME then
			-- Was a click, not a drag
			if onSlotClick then
				onSlotClick(slotNumber)
			end
		end
		setIsHolding(false)
	end

	-- Slot styling
	local backgroundColor = isLocked
		and Color3.fromRGB(60, 60, 80) -- Darker for locked
		or Color3.fromRGB(83, 83, 83)

	local backgroundTransparency = isEmpty and 0.5 or 0.3

	return Roact.createElement("Frame", {
		Name = tostring(slotNumber),
		Size = UDim2.fromScale(0.155, 1), -- Adjusted for 6 slots
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = backgroundTransparency,
		BorderSizePixel = 0,
		LayoutOrder = slotNumber,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Thickness = isEquipped and 3 or 1,
			Color = isLocked and Color3.fromRGB(100, 100, 150) or Color3.fromRGB(0, 0, 0),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),

		Number = Roact.createElement("TextLabel", {
			Name = "Number",
			Size = UDim2.fromOffset(13, 12),
			Position = UDim2.fromScale(0.089, 0),
			BackgroundTransparency = 1,
			Text = displayNumber,
			TextColor3 = Color3.fromRGB(199, 199, 199),
			TextSize = 14,
			Font = Enum.Font.SourceSans,
		}),

		Title = Roact.createElement("TextLabel", {
			Name = "Title",
			Size = UDim2.fromOffset(66, 69),
			Position = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			Text = displayName,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextSize = 14,
			Font = Enum.Font.SourceSans,
		}),

		Amount = Roact.createElement("TextLabel", {
			Name = "Amount",
			Size = UDim2.fromOffset(13, 17),
			Position = UDim2.fromScale(0.691, 0.652),
			BackgroundTransparency = 1,
			Text = displayAmount,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextSize = 14,
			Font = Enum.Font.SourceSans,
		}),

		-- Lock icon for locked slots (optional visual indicator)
		LockIndicator = isLocked and Roact.createElement("TextLabel", {
			Name = "LockIndicator",
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromScale(0.75, 0.05),
			BackgroundTransparency = 1,
			Text = "🔒",
			TextSize = 10,
		}) or nil,

		-- Invisible button for click/drag detection
		Button = Roact.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			[Roact.Event.MouseButton1Down] = handleMouseDown,
			[Roact.Event.MouseButton1Up] = handleMouseUp,
		}),
	})
end

HotbarSlot = RoactHooks.new(Roact)(HotbarSlot)
return HotbarSlot

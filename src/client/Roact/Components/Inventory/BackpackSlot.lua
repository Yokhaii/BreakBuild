--[=[
	BackpackSlot Component
	Individual slot in the backpack displaying item info
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local function BackpackSlot(props, hooks)
	local index = props.index
	local item = props.item -- { id, itemName, quantity }
	local onSlotClick = props.onSlotClick
	local onDragStart = props.onDragStart

	-- Get display name and quantity
	local displayName = item.itemName or ""
	local displayAmount = ""

	if item.quantity and item.quantity > 1 then
		displayAmount = "x" .. tostring(item.quantity)
	end

	-- Hold detection for drag
	local isHolding, setIsHolding = hooks.useState(false)
	local holdStartTime, setHoldStartTime = hooks.useState(0)
	local DRAG_HOLD_TIME = 0.3

	local function handleMouseDown()
		setIsHolding(true)
		setHoldStartTime(tick())

		-- Check for drag after hold time
		task.spawn(function()
			task.wait(DRAG_HOLD_TIME)
			if isHolding then
				if onDragStart then
					onDragStart(index, item)
				end
			end
		end)
	end

	local function handleMouseUp()
		if isHolding and (tick() - holdStartTime) < DRAG_HOLD_TIME then
			-- Was a click, not a drag
			if onSlotClick then
				onSlotClick(index, item)
			end
		end
		setIsHolding(false)
	end

	return Roact.createElement("Frame", {
		Name = "BackpackSlot" .. index,
		Size = UDim2.fromOffset(66, 68),
		BackgroundColor3 = Color3.fromRGB(83, 83, 83),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		LayoutOrder = index,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Thickness = 1,
			Color = Color3.fromRGB(0, 0, 0),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
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

BackpackSlot = RoactHooks.new(Roact)(BackpackSlot)
return BackpackSlot

--[=[
	BackpackSlot Component
	Individual slot in the backpack - styled like HotbarSlot with StudBackground
	Always renders (empty or filled) to show the grid
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

local function BackpackSlot(props, hooks)
	local index = props.index
	local item = props.item
	local onSlotClick = props.onSlotClick
	local onDragStart = props.onDragStart

	local isEmpty = item == nil
	local displayAmount = ""

	local itemModel = nil
	local itemIcon = ""

	if item then
		local itemConfig = ItemData.GetItem(item.itemName)
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

	local isHolding, setIsHolding = hooks.useState(false)
	local holdStartTime, setHoldStartTime = hooks.useState(0)

	local function handleMouseDown()
		if isEmpty then return end
		setIsHolding(true)
		setHoldStartTime(tick())

		task.spawn(function()
			task.wait(Config.DragHoldTime)
			if isHolding then
				if onDragStart then
					onDragStart(index, item)
				end
			end
		end)
	end

	local function handleMouseUp()
		if isEmpty then return end
		if isHolding and (tick() - holdStartTime) < Config.DragHoldTime then
			if onSlotClick then
				onSlotClick(index, item)
			end
		end
		setIsHolding(false)
	end

	local itemDisplay = nil
	if not isEmpty then
		if itemModel then
			itemDisplay = Roact.createElement(ViewportItem, {
				Model = itemModel,
				Size = UDim2.fromScale(0.85, 0.85),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 3,
			})
		elseif itemIcon ~= "" then
			itemDisplay = Roact.createElement("ImageLabel", {
				Size = UDim2.fromScale(0.75, 0.75),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = itemIcon,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
			})
		end
	end

	return Roact.createElement("Frame", {
		Name = "BackpackSlot" .. index,
		Size = Config.SlotSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ClipsDescendants = true,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.StrokeColor,
			Thickness = Config.StrokeThickness,
			Transparency = Config.StrokeTransparency,
		}),

		SlotBackground = Roact.createElement(StudBackground, {
			ZIndex = 1,
			BackgroundColor = Config.BackgroundColor,
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
			ZIndex = 4,
		}) or nil,

		Button = not isEmpty and Roact.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
			[Roact.Event.MouseButton1Down] = handleMouseDown,
			[Roact.Event.MouseButton1Up] = handleMouseUp,
		}) or nil,
	})
end

BackpackSlot = RoactHooks.new(Roact)(BackpackSlot)
return BackpackSlot

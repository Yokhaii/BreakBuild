--[=[
	BackpackSlot Configuration
	Styled like HotbarSlot with StudBackground
]=]

return {
	-- Slot
	SlotSize = UDim2.fromScale(1, 1),
	CornerRadius = UDim.new(0.15, 0),

	-- StudBackground styling (grey, like inventory container)
	BackgroundColor = Color3.fromRGB(85, 85, 85),
    StudImageTransparency = 0.91,

	-- Stroke (matches HotbarSlot)
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeThickness = 2.5,
	StrokeTransparency = 1,

	-- Text styling (FancyText)
	AmountColor = Color3.fromRGB(255, 255, 255),
	AmountStrokeColor = Color3.fromRGB(0, 0, 0),
	AmountStrokeThickness = 1.5,

	-- Drag
	DragHoldTime = 0.3,
}

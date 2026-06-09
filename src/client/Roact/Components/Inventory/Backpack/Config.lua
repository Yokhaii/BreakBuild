--[=[
	Backpack Configuration
	Styled like BlueprintCard with StudBackground
]=]

return {
	-- Frame
	FramePosition = UDim2.fromScale(0.5, 0.675),
	FrameSize = UDim2.fromScale(0.4, 0.303),
	FrameAnchorPoint = Vector2.new(0.5, 0.5),
	CornerRadius = UDim.new(0, 12),
	AspectRatio = 2.4,

	-- StudBackground styling (matches Hotbar)
	StudBackgroundColor = Color3.fromRGB(145, 145, 145),
	StudImageTransparency = 0.7,

	-- Stroke (matches Hotbar)
	StrokeColor = Color3.fromRGB(255, 255, 255),
	StrokeThickness = 3.5,
	StrokeTransparency = 0.87,

	-- Grid
	CellSize = UDim2.fromScale(0.135, 0.305),
	CellPadding = UDim2.fromScale(0.008, 0.04),

	-- Container padding
	PaddingLeft = UDim.new(0.015, 0),
	PaddingRight = UDim.new(0.015, 0),
	PaddingTop = UDim.new(0.03, 0),
	PaddingBottom = UDim.new(0.03, 0),

	-- ScrollingFrame
	ScrollBarThickness = 6,
	ScrollBarColor = Color3.fromRGB(0, 0, 0),

	-- Slots
	MaxSlots = 98,
}

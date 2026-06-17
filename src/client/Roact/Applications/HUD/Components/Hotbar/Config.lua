return {
	-- Hotbar frame
	FramePosition = UDim2.fromScale(0.5, 1),
	FrameSize = UDim2.fromScale(0.4, 0.11),
	FrameAnchorPoint = Vector2.new(0.5, 1),

	-- Aspect ratio
	AspectRatio = 6.42,

	-- Card styling (like BlueprintCard)
	CornerRadius = UDim.new(0, 12),
	StudBackgroundColor = Color3.fromRGB(145, 145, 145),
	StudImageTransparency = 0.7,
	StrokeColor = Color3.fromRGB(255, 255, 255),
	StrokeThickness = 3.5,
	StrokeTransparency = 0.87,

	-- Slots layout
	SlotPadding = UDim.new(0.017, 0),
	SlotCount = 7,

	-- Container padding
	PaddingLeft = UDim.new(0, 0),
	PaddingRight = UDim.new(0, 0),
	PaddingTop = UDim.new(0.04, 0),
	PaddingBottom = UDim.new(0.04,0),
}

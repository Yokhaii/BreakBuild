return {
	-- Inventory frame
	AspectRatio = 1.48,
	FrameSize = UDim2.fromScale(0.4, 0.48),
	FramePosition = UDim2.fromScale(0.5, 0.55),
	FrameAnchorPoint = Vector2.new(0.5, 0.5),

	-- Card styling
	CornerRadius = UDim.new(0, 12),
	StudBackgroundColor = Color3.fromRGB(145, 145, 145),
	StudImageTransparency = 0.7,
	StrokeColor = Color3.fromRGB(255, 255, 255),
	StrokeThickness = 2,
	StrokeTransparency = 0.87,

	-- Grid layout (7 columns, 4 rows)
	GridColumns = 7,
	CellPadding = UDim2.new(0.014, 0, 0.02, 0),

	-- Container padding
	PaddingLeft = UDim.new(0.01, 0),
	PaddingRight = UDim.new(0.01, 0),
	PaddingTop = UDim.new(0.03, 0),
	PaddingBottom = UDim.new(0, 0),

	-- Spacing between backpack grid and hotbar
	SectionPadding = UDim.new(0.02, 0),

	-- Slot counts
	BackpackSlotCount = 21,
	HotbarSlotCount = 7,
	TotalSlotCount = 28,

	-- Separator between backpack and hotbar rows
	SeparatorColor = Color3.fromRGB(200, 200, 200),
	SeparatorTransparency = 0.7,
}

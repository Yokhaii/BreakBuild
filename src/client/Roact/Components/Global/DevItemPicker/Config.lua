return {
	-- Frame sizing & position (to the left of the parent panel)
	FrameSize = UDim2.fromScale(0.6, 1.6),
	FramePosition = UDim2.fromScale(-0.03, 1),
	FrameAnchorPoint = Vector2.new(1, 1),
	AspectRatio = 0.65,

	-- Grid layout
	GridColumns = 4,
	CellPadding = UDim2.new(0.02, 0, 0.01, 0),

	-- Slot styling
	SlotCornerRadius = UDim.new(0.15, 0),
	SlotBackgroundColor = Color3.fromRGB(85, 85, 85),
	SlotStudImageTransparency = 0.91,
	SlotStrokeColor = Color3.fromRGB(0, 0, 0),
	SlotStrokeThickness = 2,
	SlotStrokeTransparency = 1,

	-- Dev whitelist
	DevUserIds = {
		4882453838, -- Yokhaii
	},
}

return {
	-- Slot size and position (centered above the hotbar)
	SlotSize = UDim2.fromScale(0.1, 0.8),
	SlotPosition = UDim2.fromScale(1.08, 1),
	SlotAnchorPoint = Vector2.new(0.5, 1),

	-- Colors (background)
	ActiveBackgroundColor = Color3.fromRGB(100, 160, 100),
	HoverBackgroundColor = Color3.fromRGB(110, 110, 110),
	DefaultBackgroundColor = Color3.fromRGB(85, 85, 85),

	-- Stroke (when active/open)
	ActiveStrokeColor = Color3.fromRGB(120, 200, 120),
	ActiveStrokeThickness = 3,
	ActiveStrokeTransparency = 0.2,

	-- Stroke (default)
	DefaultStrokeColor = Color3.fromRGB(0, 0, 0),
	DefaultStrokeThickness = 2.5,
	DefaultStrokeTransparency = 0.5,
}

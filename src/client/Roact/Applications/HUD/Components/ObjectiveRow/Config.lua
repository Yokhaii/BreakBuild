return {
	-- Task text (left)
	TaskSize = UDim2.fromScale(0.6, 0.75), -- Long tasks wrap on two lines
	TaskPosition = UDim2.fromScale(0, 0.5),
	TaskAnchorPoint = Vector2.new(0, 0.5),

	-- Right side: progress ("0/4"), then the item icon
	RightSize = UDim2.fromScale(0.38, 1),
	RightPosition = UDim2.fromScale(1, 0.5),
	RightAnchorPoint = Vector2.new(1, 0.5),
	RightPadding = UDim.new(0.04, 0),

	ProgressSize = UDim2.fromScale(0.62, 0.6),
	IconSize = UDim2.fromScale(0.3, 0.85),

	-- Colors
	TextColor = Color3.fromRGB(255, 255, 255),
	UpcomingTextColor = Color3.fromRGB(170, 170, 170), -- Next main objectives (not active yet)
	CompleteTextColor = Color3.fromRGB(120, 230, 120),
	UpcomingIconTransparency = 0.45,
}

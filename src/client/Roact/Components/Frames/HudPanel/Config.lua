return {
	-- Outer frame (one outline + rounded corners around the title and the content)
	CornerRadius = UDim.new(0, 3),
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeThickness = 2,
	StrokeTransparency = 0.3,

	-- Line between the title and the content (fraction of the panel height)
	SeparatorHeight = 0.012,
	SeparatorColor = Color3.fromRGB(0, 0, 0),
	SeparatorTransparency = 0.5,

	-- Title
	TitleTextSize = UDim2.fromScale(1, 0.7),
	TitleColor = Color3.fromRGB(191, 191, 191),
	TitleHoverColor = Color3.fromRGB(215, 215, 215),
	TitleStudImageTransparency = 0.6,

	-- Content (dark, see-through)
	ContentColor = Color3.fromRGB(45, 45, 50),
	ContentTransparency = 0.6,
	ContentStudImageTransparency = 0.85,

	-- Red notification dot (top-right corner of the title)
	BadgeSize = UDim2.fromScale(0.08, 0.08), -- Width-driven square
	BadgePosition = UDim2.fromScale(1, 0),
	BadgeAnchorPoint = Vector2.new(0.6, 0.4),
	BadgeColor = Color3.fromRGB(220, 45, 45),
	BadgeStudImageTransparency = 0.6,
	BadgeCornerRadius = UDim.new(0.5, 0),
	BadgeStrokeColor = Color3.fromRGB(0, 0, 0),
	BadgeStrokeThickness = 2,
}

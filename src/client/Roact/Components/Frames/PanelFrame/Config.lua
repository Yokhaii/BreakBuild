return {
	-- Title (top-left of the outer frame)
	TitleSize = UDim2.fromScale(0.35, 0.04),
	TitlePosition = UDim2.fromScale(0.05, 0.01),
	TitleColor = Color3.fromRGB(21, 21, 21),

	-- Outer grey frame
	CornerRadius = UDim.new(0.02, 0),
	MainStudBackgroundColor = Color3.fromRGB(145, 145, 145),
	MainStudImageTransparency = 0.7,
	StrokeColor = Color3.fromRGB(255, 255, 255),
	StrokeThickness = 3.5,
	StrokeTransparency = 0.87,

	-- Inner dark content area
	ContentAnchorPoint = Vector2.new(0.5, 0.5),
	ContentPosition = UDim2.fromScale(0.5, 0.52),
	ContentSize = UDim2.fromScale(0.9, 0.88),
	ContentStudBackgroundColor = Color3.fromRGB(80, 80, 80),
	ContentStudImageTransparency = 0.8,
	ContentCornerRadius = UDim.new(0.01, 0),
	ContentStrokeColor = Color3.fromRGB(77, 77, 77),
	ContentStrokeThickness = 4,
	ContentStrokeTransparency = 0.5,
}

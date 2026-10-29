return {
	-- Button
	ButtonSize = UDim2.fromScale(0.05, 0.05),
	ButtonPosition = UDim2.fromScale(0.005, 0.28),
	ButtonAnchorPoint = Vector2.new(0, 0.5),

	-- Aspect Ratio (2:1 ratio - width:height)
	AspectRatio = 2,

	-- Colors
	HoverColor = Color3.fromRGB(100, 180, 100),
	DefaultColor = Color3.fromRGB(70, 150, 70),
	TextColor = Color3.fromRGB(255, 255, 255),

	-- StudBackground
	StudImageTransparency = 0.4,

	-- Text
	Text = "SPAWN",
	Font = Font.fromEnum(Enum.Font.GothamBold),
	TextStrokeThickness = 1,
	TextStrokeColor = Color3.fromRGB(0, 0, 0),

	-- Border Stroke
	StrokeThickness = 2,
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0,
}

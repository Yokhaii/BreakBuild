return {
	-- Button (same size as the SpawnButton, just to its right)
	ButtonSize = UDim2.fromScale(0.05, 0.05),
	ButtonPosition = UDim2.fromScale(0.06, 0.28),
	ButtonAnchorPoint = Vector2.new(0, 0.5),

	-- Aspect Ratio (2:1 ratio - width:height)
	AspectRatio = 2,

	-- Colors
	HoverColor = Color3.fromRGB(100, 150, 210),
	DefaultColor = Color3.fromRGB(70, 120, 180),
	TextColor = Color3.fromRGB(255, 255, 255),

	-- StudBackground
	StudImageTransparency = 0.4,

	-- Text (the view the button switches to)
	FirstPersonText = "1ST",
	ThirdPersonText = "3RD",
	Font = Font.fromEnum(Enum.Font.GothamBold),
	TextStrokeThickness = 1,
	TextStrokeColor = Color3.fromRGB(0, 0, 0),

	-- Border Stroke
	StrokeThickness = 2,
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0,
}

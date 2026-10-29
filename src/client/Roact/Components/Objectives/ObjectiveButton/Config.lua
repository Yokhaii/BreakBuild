return {
	-- Color variants (default / hover)
	Variants = {
		Claim = { Default = Color3.fromRGB(70, 150, 70), Hover = Color3.fromRGB(100, 180, 100) },
		Pin = { Default = Color3.fromRGB(60, 120, 190), Hover = Color3.fromRGB(90, 150, 220) },
		Unpin = { Default = Color3.fromRGB(110, 110, 110), Hover = Color3.fromRGB(140, 140, 140) },
		Neutral = { Default = Color3.fromRGB(80, 80, 90), Hover = Color3.fromRGB(110, 110, 120) },
	},
	DefaultVariant = "Claim",

	TextColor = Color3.fromRGB(255, 255, 255),
	Font = Font.fromEnum(Enum.Font.GothamBold),
	TextStrokeThickness = 1,
	TextStrokeColor = Color3.fromRGB(0, 0, 0),

	-- StudBackground
	StudImageTransparency = 0.4,
	CornerRadius = UDim.new(0.2, 0),

	-- Border Stroke
	StrokeThickness = 2,
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0,

	-- Label padding
	PaddingHorizontal = UDim.new(0.1, 0),
	PaddingVertical = UDim.new(0.18, 0),
}

return {
	-- Frame (top-right, under the balance display)
	Position = UDim2.fromScale(0.98, 0.08),
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.22, 0.12),
	AspectRatio = 3.2,

	-- Card styling
	CornerRadius = UDim.new(0, 10),
	StudBackgroundColor = Color3.fromRGB(60, 60, 70),
	StudImageTransparency = 0.7,
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeThickness = 2,

	-- Content layout
	PaddingHorizontal = UDim.new(0.04, 0),
	PaddingVertical = UDim.new(0.08, 0),
	ListPadding = UDim.new(0.03, 0),

	-- Header ("TUTORIAL 1/6")
	HeaderText = "TUTORIAL %d/%d",
	HeaderSize = UDim2.fromScale(1, 0.22),
	HeaderColor = Color3.fromRGB(255, 220, 60),

	-- Task title (+ progress when the goal needs more than one)
	ProgressFormat = "%s (%d/%d)",
	TitleSize = UDim2.fromScale(1, 0.32),
	TitleColor = Color3.fromRGB(255, 255, 255),

	-- Sub-step hint
	HintSize = UDim2.fromScale(1, 0.28),
	HintColor = Color3.fromRGB(220, 220, 220),
	HintFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
}

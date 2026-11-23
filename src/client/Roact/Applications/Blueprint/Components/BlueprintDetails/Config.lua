return {
	Padding = UDim.new(0.02, 0),
	ScrollBarThickness = 6,
	ScrollBarColor = Color3.fromRGB(100, 100, 120),

	ListPadding = {
		Top = UDim.new(0.01, 0),
		Bottom = UDim.new(0, 0),
		Left = UDim.new(0, 0),
		Right = UDim.new(0, 0),
	},

	-- Description box: sized so the box + label + two recipe cards fill the panel,
	-- the third recipe starts right below the visible area (scroll to see it)
	DescriptionSize = UDim2.fromScale(0.94, 0.55),
	DescriptionCornerRadius = UDim.new(0.03, 0),
	DescriptionStudBackgroundColor = Color3.fromRGB(145, 145, 145),
	DescriptionStudImageTransparency = 0.7,
	DescriptionStrokeColor = Color3.fromRGB(255, 255, 255),
	DescriptionStrokeThickness = 2,
	DescriptionStrokeTransparency = 0.87,
	DescriptionTextPadding = UDim.new(0.05, 0),
	DescriptionTextColor = Color3.fromRGB(40, 40, 40),
	DescriptionFont = Font.fromEnum(Enum.Font.GothamMedium),
	DescriptionMaxTextSize = 22,

	-- "Available recipes" / "Possible finds" label
	RecipesLabelText = "Available recipes",
	LootLabelText = "Possible finds",
	RecipesLabelSize = UDim2.fromScale(0.94, 0.06),
	RecipesLabelColor = Color3.fromRGB(180, 180, 180),
}

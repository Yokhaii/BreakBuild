return {
	-- Card dimensions (scale-based for responsiveness)
	CardSize = UDim2.fromScale(1, 0.26),
	CornerRadius = UDim.new(0.05, 0),

	-- Card StudBackground
	CardStudBackgroundColor = Color3.fromRGB(145, 145, 145),
	CardStudImageTransparency = 0.7,

	-- Card Stroke
	CardStrokeColor = Color3.fromRGB(255, 255, 255),
	CardStrokeThickness = 3.5,
	CardStrokeTransparency = 0.87,

	-- Image container (left side)
	ImageSize = UDim2.fromScale(0.22, 0.85),
	ImageCornerRadius = UDim.new(0.1, 0),
	ImageStudBackgroundColor = Color3.fromRGB(60, 60, 60),
	ImageStudImageTransparency = 0.91,
	ImageStrokeColor = Color3.fromRGB(0),
	ImageStrokeThickness = 2.5,
	ImageStrokeTransparency = 0.5,

	-- Text colors
	TitleColor = Color3.fromRGB(40, 40, 40),
	TitleStrokeColor = Color3.fromRGB(160, 160, 160),
	TitleStrokeThickness = 1.2,
	DescriptionColor = Color3.fromRGB(0, 0, 0),
	MaterialTextColor = Color3.fromRGB(0, 0, 0),

	-- Fonts
	TitleFont = Font.fromEnum(Enum.Font.GothamBold),
	DescriptionFont = Font.fromEnum(Enum.Font.Gotham),
	MaterialFont = Font.fromEnum(Enum.Font.GothamMedium),

	-- Material display
	MaterialIconSize = UDim2.fromScale(0.6, 0.6),

	-- Material icons (placeholder asset IDs - replace with your actual icons)
	MaterialIcons = {
		Wood = "rbxassetid://0",
		Stone = "rbxassetid://0",
		Metal = "rbxassetid://0",
		Fiber = "rbxassetid://0",
	},
}

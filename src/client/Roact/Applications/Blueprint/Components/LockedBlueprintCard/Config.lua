return {
	-- Card dimensions (scale-based for responsiveness)
	CardSize = UDim2.fromScale(1, 0.26),
	CornerRadius = UDim.new(0.05, 0),

	-- Card StudBackground (darker for locked state)
	CardStudBackgroundColor = Color3.fromRGB(50, 50, 50),
	CardStudImageTransparency = 0.91,

	-- Card Stroke
	CardStrokeColor = Color3.fromRGB(80, 80, 80),
	CardStrokeThickness = 3.5,
	CardStrokeTransparency = 0.7,

	-- Image container (left side)
	ImageSize = UDim2.fromScale(0.22, 0.85),
	ImageCornerRadius = UDim.new(0.1, 0),
	ImageStudBackgroundColor = Color3.fromRGB(30, 30, 30),
	ImageStudImageTransparency = 0.91,
	ImageStrokeColor = Color3.fromRGB(0),
	ImageStrokeThickness = 2.5,
	ImageStrokeTransparency = 0.7,

	-- Image tint (greyed out)
	ImageColor = Color3.fromRGB(100, 100, 100),

	-- Text colors (muted for locked state)
	TitleColor = Color3.fromRGB(30, 30, 30),
	TitleStrokeColor = Color3.fromRGB(30, 30, 30),
	TitleStrokeThickness = 1.2,
	DescriptionColor = Color3.fromRGB(0,0,0),
	MaterialTextColor = Color3.fromRGB(20, 20, 20),
	MaterialIconColor = Color3.fromRGB(150, 150, 150),

	-- Lock overlay
	OverlayTransparency = 0.8,
	OverlayColor = Color3.fromRGB(0, 0, 0),

	-- Lock text
	LockTextColor = Color3.fromRGB(240, 240, 240),
	LockTextStrokeColor = Color3.fromRGB(0, 0, 0),
	LockTextStrokeThickness = 2,

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

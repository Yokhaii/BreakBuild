return {
	Size = UDim2.fromScale(1, 0.08),
	BackgroundTransparency = 1,

	ButtonCornerRadius = UDim.new(0.2, 0),
	ButtonFont = Font.fromEnum(Enum.Font.GothamMedium),
	ButtonTextColor = Color3.fromRGB(255, 255, 255),
	ButtonStudImageTransparency = 0.7,
	ButtonPaddingH = UDim.new(0.05, 0),
	ButtonPaddingV = UDim.new(0.1, 0),
	ButtonSpacing = UDim.new(0.01, 0),

	ActiveColor = Color3.fromRGB(60, 60, 60),
	InactiveColor = Color3.fromRGB(110, 110, 110),

	Categories = {
		{ key = nil, label = "All" },
		{ key = "Block", label = "Blocks" },
		{ key = "Ore", label = "Ores" },
		{ key = "Tool", label = "Tools" },
	},
}

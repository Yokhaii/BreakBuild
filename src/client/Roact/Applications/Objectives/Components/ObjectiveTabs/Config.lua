return {
	ButtonSize = UDim2.fromScale(0.25, 1),
	ButtonSpacing = UDim.new(0.015, 0),
	ButtonCornerRadius = UDim.new(0.2, 0),
	ButtonStudImageTransparency = 0.7,
	ButtonPaddingHorizontal = UDim.new(0.06, 0),
	ButtonPaddingVertical = UDim.new(0.15, 0),
	ButtonFont = Font.fromEnum(Enum.Font.GothamBold),
	ButtonTextColor = Color3.fromRGB(255, 255, 255),

	ActiveColor = Color3.fromRGB(60, 60, 60),
	InactiveColor = Color3.fromRGB(110, 110, 110),

	-- Label with count, e.g. "Active (3)"
	LabelFormat = "%s (%d)",
}

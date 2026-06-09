--[=[
	InventoryButton Configuration
]=]

return {
	-- Button
	ButtonSize = UDim2.fromOffset(140, 32),
	ButtonPosition = UDim2.new(0.5, 0, 0, -10),
	ButtonAnchorPoint = Vector2.new(0.5, 1),
	CornerRadius = UDim.new(0, 8),

	-- Colors
	ActiveColor = Color3.fromRGB(100, 160, 100),
	HoverColor = Color3.fromRGB(120, 120, 120),
	DefaultColor = Color3.fromRGB(90, 90, 90),
	TextColor = Color3.fromRGB(255, 255, 255),

	-- Text
	Text = "INVENTORY",
	TextSize = 14,
	Font = Font.fromEnum(Enum.Font.GothamBold),

	-- Stroke
	StrokeThickness = 2,
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0.5,
}

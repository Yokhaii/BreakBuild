--[=[
	ModeToggle Configuration
	Styling for Break and Build mode toggle button
]=]

return {
	-- Button size and position
	ButtonSize = UDim2.fromOffset(140, 32),
	ButtonPosition = UDim2.new(0.5, 0, 0, -10), -- Relative to hotbar (above it)
	CornerRadius = UDim.new(0, 8),

	-- Stroke
	StrokeThickness = 2,
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0.5,

	-- Text
	Font = Font.fromEnum(Enum.Font.GothamBold),
	TextSize = 14,
	TextColor = Color3.fromRGB(255, 255, 255),

	-- Mode-specific styling
	Break = {
		Text = "BREAK MODE",
		BackgroundColor = Color3.fromRGB(180, 70, 70),
		HoverColor = Color3.fromRGB(200, 90, 90),
	},

	Build = {
		Text = "BUILD MODE",
		BackgroundColor = Color3.fromRGB(70, 130, 180),
		HoverColor = Color3.fromRGB(90, 150, 200),
	},
}

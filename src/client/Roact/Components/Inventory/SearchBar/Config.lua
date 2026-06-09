--[=[
	SearchBar Configuration
	Outer frame styled like Hotbar (grey StudBackground)
	Inner slot styled dark like HotbarSlots
]=]

return {
	-- Outer container (grey card, like Hotbar)
	ContainerSize = UDim2.fromScale(0.3, 0.18),
	ContainerPosition = UDim2.fromScale(0.85, -0.03),
	ContainerAnchorPoint = Vector2.new(0.5, 1),
	ContainerCornerRadius = UDim.new(0, 12),
	ContainerBackgroundColor = Color3.fromRGB(145, 145, 145),
	ContainerStudImageTransparency = 0.7,
	ContainerStrokeColor = Color3.fromRGB(255, 255, 255),
	ContainerStrokeThickness = 3.5,
	ContainerStrokeTransparency = 0.87,

	-- Inner slot (dark, like HotbarSlot)
	SlotSize = UDim2.fromScale(0.9, 0.65),
	SlotPosition = UDim2.fromScale(0.5, 0.5),
	SlotAnchorPoint = Vector2.new(0.5, 0.5),
	SlotCornerRadius = UDim.new(0.15, 0),
	SlotBackgroundColor = Color3.fromRGB(60, 60, 60),
	SlotStudImageTransparency = 0.91,
	SlotStrokeColor = Color3.fromRGB(0, 0, 0),
	SlotStrokeThickness = 2.5,
	SlotStrokeTransparency = 0.5,

	-- TextBox
	TextBoxSize = UDim2.fromScale(0.85, 0.7),
	TextBoxPosition = UDim2.fromScale(0.5, 0.5),
	TextBoxAnchorPoint = Vector2.new(0.5, 0.5),
	TextColor = Color3.fromRGB(220, 220, 220),
	PlaceholderText = "Search",
	PlaceholderColor = Color3.fromRGB(150, 150, 150),
	TextSize = 14,
	Font = Enum.Font.SourceSans,
}

--[=[
	HotbarSlot Configuration
	Styled as image slot (like ImageContainer in BlueprintCard)
]=]

return {
	-- Slot size (square due to aspect ratio constraint, scale-based for responsiveness)
	SlotSize = UDim2.fromScale(0.13, 0.85),

	-- Image slot styling (matches BlueprintCard ImageContainer)
	ImageCornerRadius = UDim.new(0.15, 0),
	ImageBackgroundColor = Color3.fromRGB(85, 85, 85),
	LockedBackgroundColor = Color3.fromRGB(50, 50, 70),
	ImageStudTransparency = 0.91,
	ImageStrokeColor = Color3.fromRGB(0, 0, 0),
	ImageStrokeThickness = 2.5,
	ImageStrokeTransparency = 1,

	-- Equipped state stroke
	EquippedStrokeColor = Color3.fromRGB(255, 220, 100),
	EquippedStrokeThickness = 3,
	EquippedStrokeTransparency = 0.2,

	-- Text styling
	NumberColor = Color3.fromRGB(220, 220, 220),
	NumberStrokeColor = Color3.fromRGB(0, 0, 0),
	NumberStrokeThickness = 1.5,
	AmountColor = Color3.fromRGB(255, 255, 255),
	AmountStrokeColor = Color3.fromRGB(0, 0, 0),
	AmountStrokeThickness = 1.5,

	-- Drag
	DragHoldTime = 0.3,
}

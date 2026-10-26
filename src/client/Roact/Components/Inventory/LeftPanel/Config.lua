return {
	-- Panel positioning (left of inventory frame) - same pattern as Workbench/Furnace
	PanelSize = UDim2.fromScale(0.6, 1.6),
	PanelPosition = UDim2.fromScale(-0.03, 1),
	PanelAnchorPoint = Vector2.new(1, 1),
	PanelAspectRatio = 0.65,

	-- Recipe list
	RecipeListPadding = UDim.new(0.02, 0),
	ScrollBarThickness = 6,
	ScrollBarColor = Color3.fromRGB(100, 100, 120),

	ListPadding = {
		Top = UDim.new(0.01, 0),
		Bottom = UDim.new(0, 0),
		Left = UDim.new(0, 0),
		Right = UDim.new(0, 0),
	},
}

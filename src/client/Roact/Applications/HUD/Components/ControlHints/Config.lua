return {
	-- Frame (bottom right corner, rows stack up from the bottom)
	Position = UDim2.fromScale(0.995, 0.985),
	AnchorPoint = Vector2.new(1, 1),
	Size = UDim2.fromScale(0.112, 0.104),
	RowPadding = UDim.new(0.04, 0),

	-- Row (fraction of the frame height): action text, then the key on the right
	RowSize = UDim2.fromScale(1, 0.28),
	RowItemPadding = UDim.new(0.04, 0),
	LabelSize = UDim2.fromScale(0.75, 0.62),
	LabelColor = Color3.fromRGB(255, 255, 255),
	LabelMaxTextSize = 18,

	-- Key cap
	KeySize = UDim2.fromScale(0.2, 0.9), -- Height-driven, width set by the aspect ratio
	KeyAspectRatio = 1,
	KeyColor = Color3.fromRGB(235, 235, 235),
	KeyStudImageTransparency = 0.7,
	KeyCornerRadius = UDim.new(0.2, 0),
	KeyStrokeColor = Color3.fromRGB(0, 0, 0),
	KeyStrokeThickness = 2,
	KeyTextSize = UDim2.fromScale(0.7, 0.7),
	KeyTextColor = Color3.fromRGB(40, 40, 40),

	-- Mouse (left click): rounded key cap with its left button filled
	MouseAspectRatio = 0.72,
	MouseCornerRadius = UDim.new(0.45, 0),
	MouseButtonPosition = UDim2.fromScale(0.13, 0.1),
	MouseButtonSize = UDim2.fromScale(0.34, 0.36),
	MouseButtonCornerRadius = UDim.new(0.35, 0),
	MouseButtonColor = Color3.fromRGB(255, 190, 60),
	MouseDividerPosition = UDim2.fromScale(0.5, 0.1),
	MouseDividerSize = UDim2.fromScale(0.05, 0.36),
	MouseDividerColor = Color3.fromRGB(40, 40, 40),

	-- Keys and texts
	DropKey = "G", -- InventoryController DROP_KEY
	DropText = "Drop",
	ViewKey = "V", -- CameraController TOGGLE_VIEW_KEY
	FirstPersonText = "First person",
	ThirdPersonText = "Third person",

	ZIndex = 5,
}
